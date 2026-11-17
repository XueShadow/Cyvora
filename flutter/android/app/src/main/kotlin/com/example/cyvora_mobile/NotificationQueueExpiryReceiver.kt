package com.example.cyvora_mobile

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

class NotificationQueueExpiryReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        if (intent?.action != ACTION_EXPIRE_NOTIFICATION_QUEUE) return
        try {
            NotificationQueueStorage(context).purgeExpiredAndSchedule()
        } catch (_: NotificationStorageException) {
            Log.e(TAG, "Could not expire encrypted notification data.")
        }
    }

    companion object {
        const val ACTION_EXPIRE_NOTIFICATION_QUEUE =
            "com.example.cyvora.EXPIRE_NOTIFICATION_QUEUE"
        private const val TAG = "CyvoraNotificationQueue"
    }
}
