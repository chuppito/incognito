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
        private const val DB_VERSION = 3
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
                conversation_key TEXT,
                sender TEXT NOT NULL DEFAULT '',
                message_key TEXT
            )
            """.trimIndent()
        )
        db.execSQL("CREATE TABLE IF NOT EXISTS captured_message_keys (message_key TEXT PRIMARY KEY)")
        db.execSQL("CREATE UNIQUE INDEX idx_notifications_message ON $TABLE(message_key)")
        db.execSQL("CREATE INDEX idx_notifications_timestamp ON $TABLE(timestamp DESC)")
        db.execSQL("CREATE INDEX idx_notifications_conversation ON $TABLE(conversation_key)")
    }

    override fun onUpgrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) {
        if (oldVersion < 2) {
            db.execSQL("ALTER TABLE $TABLE ADD COLUMN conversation_key TEXT")
            db.execSQL("CREATE INDEX idx_notifications_conversation ON $TABLE(conversation_key)")
        }
        if (oldVersion < 3) {
            db.execSQL("ALTER TABLE $TABLE ADD COLUMN sender TEXT NOT NULL DEFAULT ''")
            db.execSQL("ALTER TABLE $TABLE ADD COLUMN message_key TEXT")
            db.execSQL("CREATE TABLE IF NOT EXISTS captured_message_keys (message_key TEXT PRIMARY KEY)")
        db.execSQL("CREATE UNIQUE INDEX idx_notifications_message ON $TABLE(message_key)")
        }
    }

    fun insert(
        packageName: String,
        appName: String,
        title: String?,
        text: String?,
        timestamp: Long,
        conversationKey: String? = null,
        sender: String = "",
        messageKey: String? = null
    ): Long {
        val values = ContentValues().apply {
            put("package_name", packageName)
            put("app_name", appName)
            put("title", title ?: "")
            put("text", text ?: "")
            put("timestamp", timestamp)
            put("conversation_key", conversationKey ?: "")
            put("sender", sender)
            put("message_key", messageKey)
        }
        val db = writableDatabase
        db.beginTransaction()
        try {
            if (messageKey != null) {
                val keyValues = ContentValues().apply { put("message_key", messageKey) }
                if (db.insertWithOnConflict("captured_message_keys", null, keyValues,
                        SQLiteDatabase.CONFLICT_IGNORE) < 0L) {
                    db.setTransactionSuccessful()
                    return -1L
                }
            }
            val id = db.insertOrThrow(TABLE, null, values)
            db.setTransactionSuccessful()
            return id
        } finally {
            db.endTransaction()
        }
    }

    fun getHistory(limit: Int, offset: Int): List<Map<String, Any?>> {
        val results = mutableListOf<Map<String, Any?>>()
        val cursor = readableDatabase.query(
            TABLE, null, null, null, null, null,
            "timestamp DESC, id DESC", "${offset.coerceAtLeast(0)},${limit.coerceIn(1, 500)}"
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
                        "conversationKey" to it.getString(it.getColumnIndexOrThrow("conversation_key")),
                        "sender" to it.getString(it.getColumnIndexOrThrow("sender")),
                        "structured" to !it.isNull(it.getColumnIndexOrThrow("message_key"))
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

