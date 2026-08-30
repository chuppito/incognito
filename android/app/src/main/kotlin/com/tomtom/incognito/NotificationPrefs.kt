package com.tomtom.incognito

import android.content.Context

/**
 * Préférences partagées entre MainActivity (réglages depuis Flutter) et
 * NotificationListener (lecture au moment où une notification arrive).
 *
 * - "listenedApps"  : packages dont on capture les notifications dans l'historique
 * - "silentApps"    : parmi les apps écoutées, celles pour lesquelles on supprime
 *                     la notification système (bandeau) après l'avoir capturée
 */
class NotificationPrefs(context: Context) {

    private val prefs = context.applicationContext.getSharedPreferences(
        "incognito_prefs", Context.MODE_PRIVATE
    )

    fun getListenedApps(): Set<String> =
        prefs.getStringSet("listenedApps", emptySet()) ?: emptySet()

    fun setListenedApps(apps: Set<String>) {
        prefs.edit().putStringSet("listenedApps", apps).apply()
    }

    fun getSilentApps(): Set<String> =
        prefs.getStringSet("silentApps", emptySet()) ?: emptySet()

    fun setSilentApps(apps: Set<String>) {
        prefs.edit().putStringSet("silentApps", apps).apply()
    }

    fun isListened(packageName: String): Boolean = packageName in getListenedApps()

    fun isSilent(packageName: String): Boolean = packageName in getSilentApps()
}
