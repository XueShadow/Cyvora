package com.example.cyvora_mobile

import android.app.Notification
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log
import java.nio.charset.StandardCharsets
import java.util.UUID

class MessageNotificationListenerService : NotificationListenerService() {
    private val queueStorage by lazy { NotificationQueueStorage(this) }

    override fun onListenerConnected() {
        super.onListenerConnected()
        try {
            queueStorage.purgeExpiredAndSchedule()
        } catch (_: NotificationStorageException) {
            Log.e(TAG, "Could not maintain encrypted notification storage.")
        }
    }

    override fun onListenerDisconnected() {
        super.onListenerDisconnected()
        if (NotificationListenerAccess.isEnabled(this)) return
        try {
            queueStorage.setMonitoringConsentGranted(false)
        } catch (_: NotificationStorageException) {
            Log.e(TAG, "Could not disable monitoring after access was revoked.")
        }
    }

    override fun onNotificationPosted(statusBarNotification: StatusBarNotification) {
        if (statusBarNotification.packageName == packageName) return

        try {
            queueStorage.withMonitoringEnabled(statusBarNotification.packageName) {
                processNotification(statusBarNotification)
            }
        } catch (_: NotificationStorageException) {
            Log.e(TAG, "Could not securely store a notification preview.")
        }
    }

    private fun processNotification(statusBarNotification: StatusBarNotification) {
        val notification = statusBarNotification.notification
        if (notification.flags and Notification.FLAG_ONGOING_EVENT != 0 ||
            notification.flags and Notification.FLAG_GROUP_SUMMARY != 0
        ) return

        val extras = notification.extras
        val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString()?.trim().orEmpty()
        val text = (
            extras.getCharSequence(Notification.EXTRA_BIG_TEXT)
                ?: extras.getCharSequence(Notification.EXTRA_TEXT)
            )?.toString()?.trim().orEmpty()
        if (title.isEmpty() && text.isEmpty() ||
            SensitiveNotificationFilter.shouldDiscard(title, text) ||
            looksPromotional(title, text)
        ) {
            return
        }

        val notificationKey = statusBarNotification.key
        val notificationGroupId = UUID.nameUUIDFromBytes(
            notificationKey.toByteArray(StandardCharsets.UTF_8),
        ).toString()
        val id = UUID.nameUUIDFromBytes(
            "$notificationKey:${statusBarNotification.postTime}"
                .toByteArray(StandardCharsets.UTF_8),
        ).toString()
        queueStorage.enqueue(
            id = id,
            notificationGroupId = notificationGroupId,
            title = title.take(MAX_TITLE_LENGTH),
            text = text.take(MAX_TEXT_LENGTH),
            packageName = statusBarNotification.packageName,
            receivedAt = statusBarNotification.postTime,
        )
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
        private const val TAG = "CyvoraNotificationQueue"
        private const val MAX_TITLE_LENGTH = 120
        private const val MAX_TEXT_LENGTH = 1000
    }
}
