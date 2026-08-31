package com.tomtom.incognito

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.os.Parcelable
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import java.util.LinkedHashMap

class NotificationListener : NotificationListenerService() {

    companion object {
        var onNewNotification: ((Map<String, Any?>) -> Unit)? = null
    }

    private lateinit var store: NotificationStore
    private lateinit var prefs: NotificationPrefs

    private val recentCache = object : LinkedHashMap<String, Long>(100, 0.75f, true) {
        override fun removeEldestEntry(eldest: MutableMap.MutableEntry<String, Long>?): Boolean {
            return size > 300
        }
    }

    private val dedupeWindowMs = 2000L

    private val incognitoChannelId = "captured_notifications"

    override fun onListenerConnected() {
        super.onListenerConnected()
        createIncognitoNotificationChannel()
    }

    private fun createIncognitoNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(NotificationManager::class.java)
        val channel = NotificationChannel(
            incognitoChannelId,
            "Notifications Incognito",
            NotificationManager.IMPORTANCE_DEFAULT
        ).apply {
            description = "Notifications générées par Incognito pour les applications surveillées"
        }
        manager.createNotificationChannel(channel)
    }

    override fun onCreate() {
        super.onCreate()
        store = NotificationStore.getInstance(applicationContext)
        prefs = NotificationPrefs(applicationContext)
    }

    override fun onNotificationPosted(sbn: StatusBarNotification) {
        val packageName = sbn.packageName
        val notification = sbn.notification ?: return
        val extras = notification.extras ?: return

        if (packageName == applicationContext.packageName) return
        if (!prefs.isListened(packageName)) return
        if ((notification.flags and Notification.FLAG_GROUP_SUMMARY) != 0) return

        val title = extractBestTitle(extras)
        val text = extractFullText(extras)
        if (title.isNullOrBlank() && text.isNullOrBlank()) return

        // groupKey est stable pour une conversation/notification groupée et
        // permet à l'UI de connaître l'origine conversationnelle sans exposer
        // de données supplémentaires.
        val conversationKey = buildConversationKey(packageName, sbn, extras)

        val fingerprint = buildString {
            append(packageName)
            append("|")
            append(sbn.key ?: "")
            append("|")
            append(title?.normalizeForCompare().orEmpty())
            append("|")
            append(text?.normalizeForCompare().orEmpty())
            append("|")
            append(conversationKey.orEmpty())
        }

        val now = System.currentTimeMillis()
        synchronized(recentCache) {
            val lastSeen = recentCache[fingerprint]
            if (lastSeen != null && now - lastSeen < dedupeWindowMs) return
            recentCache[fingerprint] = now

            val iterator = recentCache.entries.iterator()
            while (iterator.hasNext()) {
                val entry = iterator.next()
                if (now - entry.value > 15_000L) iterator.remove()
            }
        }

        val appName = try {
            val pm = applicationContext.packageManager
            pm.getApplicationLabel(pm.getApplicationInfo(packageName, 0)).toString()
        } catch (e: PackageManager.NameNotFoundException) {
            packageName
        }

        val timestamp = when {
            sbn.postTime > 0L -> sbn.postTime
            notification.`when` > 0L -> notification.`when`
            else -> now
        }

        val id = store.insert(
            packageName = packageName,
            appName = appName,
            title = title,
            text = text,
            timestamp = timestamp,
            conversationKey = conversationKey
        )

        onNewNotification?.invoke(
            mapOf(
                "id" to id,
                "packageName" to packageName,
                "appName" to appName,
                "title" to (title ?: ""),
                "text" to (text ?: ""),
                "timestamp" to timestamp,
                "conversationKey" to (conversationKey ?: "")
            )
        )

        if (prefs.isIncognitoNotificationsEnabled()) {
            postIncognitoNotification(
                id = id,
                appName = appName,
                title = title,
                text = text
            )
        }

        if (prefs.isSilent(packageName)) {
            cancelNotification(sbn.key)
        }
    }

    private fun extractBestTitle(extras: Bundle): String? {
        // Pour les messageries, EXTRA_CONVERSATION_TITLE est particulièrement
        // important : dans un groupe WhatsApp, EXTRA_TITLE peut contenir le nom
        // de l'expéditeur alors que EXTRA_CONVERSATION_TITLE contient le nom du
        // groupe. On le privilégie donc pour permettre le vrai regroupement.
        val conversationTitle = extras
            .getCharSequence(Notification.EXTRA_CONVERSATION_TITLE)
            ?.toString()
            ?.trim()
        if (!conversationTitle.isNullOrBlank()) return conversationTitle

        val titleBig = extras
            .getCharSequence(Notification.EXTRA_TITLE_BIG)
            ?.toString()
            ?.trim()
        if (!titleBig.isNullOrBlank()) return titleBig

        val title = extras
            .getCharSequence(Notification.EXTRA_TITLE)
            ?.toString()
            ?.trim()
        if (!title.isNullOrBlank()) return title

        return null
    }

    private fun extractFullText(extras: Bundle): String? {
        // MessagingStyle est prioritaire : Android y place souvent le vrai
        // contenu des conversations, même lorsque EXTRA_TEXT est tronqué.
        val messagingText = extractMessagingStyleText(extras)
        if (!messagingText.isNullOrBlank()) return messagingText

        val bigText = extras.getCharSequence(Notification.EXTRA_BIG_TEXT)
            ?.toString()?.trim()
        if (!bigText.isNullOrBlank()) return bigText

        val textLines = extras.getCharSequenceArray(Notification.EXTRA_TEXT_LINES)
            ?.map { it.toString().trim() }
            ?.filter { it.isNotBlank() }
            ?.distinct()
        if (!textLines.isNullOrEmpty()) return textLines.joinToString("\n")

        val text = extras.getCharSequence(Notification.EXTRA_TEXT)
            ?.toString()?.trim()
        if (!text.isNullOrBlank()) return text

        val subText = extras.getCharSequence(Notification.EXTRA_SUB_TEXT)
            ?.toString()?.trim()
        if (!subText.isNullOrBlank()) return subText

        // Certaines applications utilisent des clés non standard.
        val fallbackKeys = listOf(
            "android.text",
            "android.bigText",
            "android.title",
            "message",
            "body",
            "content"
        )
        for (key in fallbackKeys) {
            val value = extras.getCharSequence(key)?.toString()?.trim()
            if (!value.isNullOrBlank() && value != extractBestTitle(extras)) {
                return value
            }
        }

        return null
    }

    private fun extractMessagingStyleText(extras: Bundle): String? {
        val parcelables: Array<Parcelable> = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            extras.getParcelableArray(Notification.EXTRA_MESSAGES, Parcelable::class.java) ?: return null
        } else {
            @Suppress("DEPRECATION")
            extras.getParcelableArray(Notification.EXTRA_MESSAGES) ?: return null
        }

        val lines: List<String> = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            Notification.MessagingStyle.Message.getMessagesFromBundleArray(parcelables)
                .mapNotNull { msg ->
                    val messageText = msg.text?.toString()?.trim().orEmpty()
                    val sender = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                        msg.senderPerson?.name?.toString()?.trim().orEmpty()
                    } else {
                        @Suppress("DEPRECATION")
                        msg.sender?.toString()?.trim().orEmpty()
                    }

                    when {
                        messageText.isBlank() -> null
                        sender.isBlank() -> messageText
                        else -> "$sender: $messageText"
                    }
                }
        } else {
            parcelables.mapNotNull { parcelable ->
                val bundle = parcelable as? Bundle ?: return@mapNotNull null
                val messageText = bundle.getCharSequence("text")?.toString()?.trim().orEmpty()
                val sender = bundle.getCharSequence("sender")?.toString()?.trim().orEmpty()

                when {
                    messageText.isBlank() -> null
                    sender.isBlank() -> messageText
                    else -> "$sender: $messageText"
                }
            }
        }

        val cleaned = lines.map { it.trim() }.filter { it.isNotBlank() }.distinct()
        return if (cleaned.isNotEmpty()) cleaned.joinToString("\n") else null
    }

    private fun extractHistoricMessages(extras: Bundle): String? {
        val parcelables: Array<Parcelable> = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            extras.getParcelableArray(Notification.EXTRA_HISTORIC_MESSAGES, Parcelable::class.java) ?: return null
        } else {
            @Suppress("DEPRECATION")
            extras.getParcelableArray(Notification.EXTRA_HISTORIC_MESSAGES) ?: return null
        }

        val lines: List<String> = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            Notification.MessagingStyle.Message.getMessagesFromBundleArray(parcelables)
                .mapNotNull { msg -> msg.text?.toString()?.trim()?.takeIf { it.isNotBlank() } }
        } else {
            parcelables.mapNotNull { parcelable ->
                val bundle = parcelable as? Bundle ?: return@mapNotNull null
                bundle.getCharSequence("text")?.toString()?.trim()?.takeIf { it.isNotBlank() }
            }
        }

        val cleaned = lines.distinct()
        return if (cleaned.isNotEmpty()) cleaned.joinToString("\n") else null
    }

    private fun buildConversationKey(
        packageName: String,
        sbn: StatusBarNotification,
        extras: Bundle
    ): String? {
        // Le titre de conversation est l'identifiant le plus utile pour les
        // messageries modernes : pour un groupe WhatsApp, il permet de regrouper
        // les messages de plusieurs participants sous le nom du même groupe.
        val conversation = extras
            .getCharSequence(Notification.EXTRA_CONVERSATION_TITLE)
            ?.toString()
            ?.trim()
            ?.takeIf { it.isNotBlank() }

        val group = sbn.groupKey?.takeIf { it.isNotBlank() }

        return when {
            conversation != null -> "$packageName|conversation:${conversation.normalizeForCompare()}"
            group != null -> "$packageName|group:$group"
            else -> null
        }
    }

    private fun String.normalizeForCompare(): String {
        return trim().replace("\\s+".toRegex(), " ").lowercase()
    }

    private fun postIncognitoNotification(
        id: Long,
        appName: String,
        title: String?,
        text: String?
    ) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS) !=
            PackageManager.PERMISSION_GRANTED
        ) return

        createIncognitoNotificationChannel()

        val launchIntent = packageManager.getLaunchIntentForPackage(packageName) ?: return
        launchIntent.addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)

        val pendingIntent = PendingIntent.getActivity(
            this,
            id.toInt(),
            launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val displayTitle = title?.takeIf { it.isNotBlank() } ?: appName
        val displayText = text?.takeIf { it.isNotBlank() } ?: "Nouvelle notification capturée"

        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, incognitoChannelId)
        } else {
            Notification.Builder(this)
        }

        val notification = builder
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentTitle("$appName • $displayTitle")
            .setContentText(displayText)
            .setStyle(Notification.BigTextStyle().bigText(displayText))
            .setContentIntent(pendingIntent)
            .setAutoCancel(true)
            .setCategory(Notification.CATEGORY_MESSAGE)
            .build()

        val manager = getSystemService(NotificationManager::class.java)
        manager.notify((id and 0x7fffffffL).toInt(), notification)
    }
}
