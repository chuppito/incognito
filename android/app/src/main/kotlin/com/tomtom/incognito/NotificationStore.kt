package com.tomtom.incognito

import android.content.ContentValues
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper

/**
 * Stockage local SQLite de l'historique des notifications interceptées.
 *
 * Le texte est volontairement conservé intégralement. L'interface Flutter
 * affiche seulement un aperçu dans la liste et le contenu complet dans
 * NotificationDetailScreen.
 */
class NotificationStore(context: Context) :
    SQLiteOpenHelper(context.applicationContext, DB_NAME, null, DB_VERSION) {

    companion object {
        private const val DB_NAME = "incognito_notifications.db"
        private const val DB_VERSION = 2
        private const val TABLE = "notifications"

        @Volatile
        private var instance: NotificationStore? = null

        fun getInstance(context: Context): NotificationStore =
            instance ?: synchronized(this) {
                instance ?: NotificationStore(context).also { instance = it }
            }
    }

    override fun onCreate(db: SQLiteDatabase) {
        db.execSQL(
            """
            CREATE TABLE $TABLE (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                package_name TEXT NOT NULL,
                app_name TEXT NOT NULL,
                title TEXT,
                text TEXT,
                timestamp INTEGER NOT NULL,
                conversation_key TEXT
            )
            """.trimIndent()
        )
        db.execSQL("CREATE INDEX idx_notifications_timestamp ON $TABLE(timestamp DESC)")
        db.execSQL("CREATE INDEX idx_notifications_conversation ON $TABLE(conversation_key)")
    }

    override fun onUpgrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) {
        if (oldVersion < 2) {
            db.execSQL("ALTER TABLE $TABLE ADD COLUMN conversation_key TEXT")
            db.execSQL("CREATE INDEX idx_notifications_conversation ON $TABLE(conversation_key)")
        }
    }

    fun insert(
        packageName: String,
        appName: String,
        title: String?,
        text: String?,
        timestamp: Long,
        conversationKey: String? = null
    ): Long {
        val values = ContentValues().apply {
            put("package_name", packageName)
            put("app_name", appName)
            put("title", title ?: "")
            put("text", text ?: "")
            put("timestamp", timestamp)
            put("conversation_key", conversationKey ?: "")
        }
        return writableDatabase.insert(TABLE, null, values)
    }

    fun getHistory(limit: Int, offset: Int): List<Map<String, Any?>> {
        val results = mutableListOf<Map<String, Any?>>()
        val cursor = readableDatabase.query(
            TABLE, null, null, null, null, null,
            "timestamp DESC, id DESC", "$offset,$limit"
        )
        cursor.use {
            while (it.moveToNext()) {
                results.add(
                    mapOf(
                        "id" to it.getLong(it.getColumnIndexOrThrow("id")),
                        "packageName" to it.getString(it.getColumnIndexOrThrow("package_name")),
                        "appName" to it.getString(it.getColumnIndexOrThrow("app_name")),
                        "title" to it.getString(it.getColumnIndexOrThrow("title")),
                        "text" to it.getString(it.getColumnIndexOrThrow("text")),
                        "timestamp" to it.getLong(it.getColumnIndexOrThrow("timestamp")),
                        "conversationKey" to it.getString(it.getColumnIndexOrThrow("conversation_key"))
                    )
                )
            }
        }
        return results
    }

    fun deleteById(id: Long): Int =
        writableDatabase.delete(TABLE, "id = ?", arrayOf(id.toString()))

    fun clearAll(): Int = writableDatabase.delete(TABLE, null, null)

    fun clearForPackage(packageName: String): Int =
        writableDatabase.delete(TABLE, "package_name = ?", arrayOf(packageName))
}
