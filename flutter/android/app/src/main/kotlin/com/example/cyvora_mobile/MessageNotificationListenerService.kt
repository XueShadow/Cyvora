package com.example.cyvora_mobile

import android.app.Notification
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import org.json.JSONArray
import org.json.JSONObject

class MessageNotificationListenerService : NotificationListenerService() {
    override fun onNotificationPosted(statusBarNotification: StatusBarNotification) {
        if (statusBarNotification.packageName == packageName) return

        val notification = statusBarNotification.notification
        if (notification.flags and Notification.FLAG_ONGOING_EVENT != 0 ||
            notification.flags and Notification.FLAG_GROUP_SUMMARY != 0
        ) {
            return
        }

        val extras = notification.extras
        val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString()?.trim().orEmpty()
        val text = (
            extras.getCharSequence(Notification.EXTRA_BIG_TEXT)
                ?: extras.getCharSequence(Notification.EXTRA_TEXT)
            )?.toString()?.trim().orEmpty()
        if (title.isEmpty() && text.isEmpty() || looksPromotional(title, text)) return

        val preferences = getSharedPreferences(PREFERENCES_NAME, MODE_PRIVATE)
        val queue = runCatching {
            JSONArray(preferences.getString(PENDING_KEY, "[]"))
        }.getOrDefault(JSONArray())
        queue.put(
            JSONObject()
                .put("id", "${statusBarNotification.postTime}-${statusBarNotification.key.hashCode()}")
                .put("title", title)
                .put("text", text)
                .put("packageName", statusBarNotification.packageName)
                .put("receivedAt", statusBarNotification.postTime)
        )
        while (queue.length() > MAX_QUEUE_SIZE) queue.remove(0)
        preferences.edit().putString(PENDING_KEY, queue.toString()).apply()
    }

    private fun looksPromotional(title: String, text: String): Boolean {
        val value = "$title $text".lowercase()
        return listOf(
            "sponsored",
            "advertisement",
            "unsubscribe",
            "limited time offer",
            "shop now",
            "buy now",
            "sale ends",
        ).any(value::contains)
    }

    companion object {
        const val PREFERENCES_NAME = "cyvora_notification_scanning"
        const val PENDING_KEY = "pending_messages"
        const val MAX_QUEUE_SIZE = 50
    }
}
