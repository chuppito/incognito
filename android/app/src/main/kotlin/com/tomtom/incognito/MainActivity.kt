package com.tomtom.incognito

import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream

class MainActivity : FlutterActivity() {

    private val channelName = "com.tomtom.incognito/notifications"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val store = NotificationStore.getInstance(applicationContext)
        val prefs = NotificationPrefs(applicationContext)
        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)

        // Pont en direct : quand une notif arrive pendant que l'app est ouverte
        NotificationListener.onNewNotification = { data ->
            runOnUiThread {
                channel.invokeMethod("onNotificationReceived", data)
            }
        }

        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "isNotificationAccessGranted" -> {
                    result.success(isNotificationAccessGranted())
                }

                "openNotificationAccessSettings" -> {
                    startActivity(Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS))
                    result.success(null)
                }

                "getInstalledApps" -> {
                    result.success(getInstalledApps())
                }

                "getListenedApps" -> {
                    result.success(prefs.getListenedApps().toList())
                }

                "setListenedApps" -> {
                    @Suppress("UNCHECKED_CAST")
                    val apps = (call.arguments as List<String>).toSet()
                    prefs.setListenedApps(apps)
                    result.success(null)
                }

                "getSilentApps" -> {
                    result.success(prefs.getSilentApps().toList())
                }

                "setSilentApps" -> {
                    @Suppress("UNCHECKED_CAST")
                    val apps = (call.arguments as List<String>).toSet()
                    prefs.setSilentApps(apps)
                    result.success(null)
                }

                "getHistory" -> {
                    val args = call.arguments as Map<*, *>
                    val limit = (args["limit"] as? Int) ?: 100
                    val offset = (args["offset"] as? Int) ?: 0
                    result.success(store.getHistory(limit, offset))
                }

                "deleteNotification" -> {
                    val id = (call.arguments as Number).toLong()
                    result.success(store.deleteById(id))
                }

                "clearHistory" -> {
                    result.success(store.clearAll())
                }

                "clearHistoryForPackage" -> {
                    val packageName = call.arguments as String
                    result.success(store.clearForPackage(packageName))
                }

                else -> result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        NotificationListener.onNewNotification = null
        super.onDestroy()
    }

    private fun isNotificationAccessGranted(): Boolean {
        val enabledListeners = Settings.Secure.getString(
            contentResolver, "enabled_notification_listeners"
        ) ?: return false
        return enabledListeners.contains(applicationContext.packageName)
    }

    /**
     * Liste les applications utilisateur installées (hors apps système sans icône
     * de lancement), avec leur icône encodée en PNG base64, pour le sélecteur
     * "quelles apps écouter" côté Flutter.
     */
    private fun getInstalledApps(): List<Map<String, Any?>> {
        val pm = packageManager
        val launcherApps = pm.getInstalledApplications(PackageManager.GET_META_DATA)
        val result = mutableListOf<Map<String, Any?>>()

        for (appInfo in launcherApps) {
            // On ne garde que les apps qui ont une activité de lancement (visibles
            // par l'utilisateur), pour éviter de noyer la liste avec des services système.
            if (pm.getLaunchIntentForPackage(appInfo.packageName) == null) continue
            if (appInfo.packageName == applicationContext.packageName) continue

            val label = pm.getApplicationLabel(appInfo).toString()
            val iconBase64 = try {
                drawableToBase64(pm.getApplicationIcon(appInfo))
            } catch (e: Exception) {
                null
            }

            result.add(
                mapOf(
                    "packageName" to appInfo.packageName,
                    "appName" to label,
                    "icon" to iconBase64,
                    "isSystemApp" to (appInfo.flags and ApplicationInfo.FLAG_SYSTEM != 0)
                )
            )
        }

        return result.sortedBy { (it["appName"] as String).lowercase() }
    }

    private fun drawableToBase64(drawable: Drawable): String {
        val bitmap = if (drawable is BitmapDrawable) {
            drawable.bitmap
        } else {
            val width = if (drawable.intrinsicWidth > 0) drawable.intrinsicWidth else 96
            val height = if (drawable.intrinsicHeight > 0) drawable.intrinsicHeight else 96
            val bmp = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
            val canvas = android.graphics.Canvas(bmp)
            drawable.setBounds(0, 0, canvas.width, canvas.height)
            drawable.draw(canvas)
            bmp
        }
        val stream = ByteArrayOutputStream()
        bitmap.compress(Bitmap.CompressFormat.PNG, 100, stream)
        return android.util.Base64.encodeToString(stream.toByteArray(), android.util.Base64.NO_WRAP)
    }
}
