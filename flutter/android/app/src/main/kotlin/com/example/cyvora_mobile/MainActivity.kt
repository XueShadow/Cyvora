package com.example.cyvora_mobile

import android.content.ComponentName
import android.content.Intent
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val notificationQueueStorage by lazy {
        NotificationQueueStorage(applicationContext)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isNotificationListenerEnabled" -> {
                        val enabled = NotificationManagerCompat.isEnabled(this)
                        result.success(enabled)
                    }
                    "openNotificationListenerSettings" -> {
                        startActivity(Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS))
                        result.success(null)
                    }
                    "getPendingMessageNotifications" -> {
                        runNotificationStorageOperation(result) {
                            notificationQueueStorage.pendingNotifications()
                        }
                    }
                    "removePendingMessageNotification" -> {
                        runNotificationStorageOperation(result) {
                            notificationQueueStorage.remove(call.argument<String>("id"))
                            null
                        }
                    }
                    "markPendingMessageNotificationCompleted" -> {
                        runNotificationStorageOperation(result) {
                            notificationQueueStorage.markCompleted(call.argument<String>("id"))
                            null
                        }
                    }
                    "clearPendingMessageNotifications" -> {
                        runNotificationStorageOperation(result) {
                            notificationQueueStorage.clear()
                            null
                        }
                    }
                    "getMessageMonitoringConsent" -> {
                        runNotificationStorageOperation(result) {
                            notificationQueueStorage.isMonitoringConsentGranted()
                        }
                    }
                    "setMessageMonitoringConsent" -> {
                        runNotificationStorageOperation(result) {
                            val granted = call.argument<Boolean>("granted")
                                ?: throw IllegalArgumentException("A consent value is required.")
                            notificationQueueStorage.setMonitoringConsentGranted(granted)
                            null
                        }
                    }
                    "getNotificationRetentionDays" -> {
                        runNotificationStorageOperation(result) {
                            notificationQueueStorage.retentionDays()
                        }
                    }
                    "setNotificationRetentionDays" -> {
                        runNotificationStorageOperation(result) {
                            val days = call.argument<Int>("days")
                                ?: throw IllegalArgumentException("A retention period is required.")
                            notificationQueueStorage.setRetentionDays(days)
                            null
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun runNotificationStorageOperation(
        result: MethodChannel.Result,
        operation: () -> Any?,
    ) {
        try {
            result.success(operation())
        } catch (error: NotificationStorageException) {
            result.error(
                "notification_storage_error",
                error.message ?: "Secure notification storage is unavailable.",
                null,
            )
        } catch (error: IllegalArgumentException) {
            result.error(
                "invalid_notification_setting",
                error.message ?: "The notification setting is invalid.",
                null,
            )
        }
    }

    companion object {
        private const val CHANNEL = "cyvora/notification_scanning"
    }
}

private object NotificationManagerCompat {
    fun isEnabled(activity: MainActivity): Boolean {
        val enabledPackages = Settings.Secure.getString(
            activity.contentResolver,
            "enabled_notification_listeners",
        ) ?: return false
        return enabledPackages.split(":").any {
            ComponentName.unflattenFromString(it)?.packageName == activity.packageName
        }
    }
}
