package com.example.cyvora_mobile

import android.content.ComponentName
import android.content.Context
import android.provider.Settings

internal object NotificationListenerAccess {
    fun isEnabled(context: Context): Boolean {
        val enabledPackages = Settings.Secure.getString(
            context.contentResolver,
            "enabled_notification_listeners",
        ) ?: return false
        val component = ComponentName(
            context,
            MessageNotificationListenerService::class.java,
        )
        return enabledPackages.split(":").any {
            ComponentName.unflattenFromString(it) == component
        }
    }
}
