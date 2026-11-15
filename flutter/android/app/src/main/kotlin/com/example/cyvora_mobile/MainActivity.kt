package com.example.cyvora_mobile

import android.content.ComponentName
import android.content.Intent
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject

class MainActivity : FlutterActivity() {
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
                        result.success(readPendingNotifications())
                    }
                    "removePendingMessageNotification" -> {
                        removePendingNotification(call.argument<String>("id"))
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun readPendingNotifications(): List<Map<String, Any>> {
        val preferences = getSharedPreferences(
            MessageNotificationListenerService.PREFERENCES_NAME,
            MODE_PRIVATE,
        )
        val queue = runCatching {
            JSONArray(
                preferences.getString(
                    MessageNotificationListenerService.PENDING_KEY,
                    "[]",
                ),
            )
        }.getOrDefault(JSONArray())
        return (0 until queue.length()).mapNotNull { index ->
            val item = queue.optJSONObject(index) ?: return@mapNotNull null
            mapOf(
                "id" to item.optString("id"),
                "title" to item.optString("title"),
                "text" to item.optString("text"),
                "packageName" to item.optString("packageName"),
                "receivedAt" to item.optLong("receivedAt"),
            )
        }
    }

    private fun removePendingNotification(id: String?) {
        if (id == null) return
        val preferences = getSharedPreferences(
            MessageNotificationListenerService.PREFERENCES_NAME,
            MODE_PRIVATE,
        )
        val queue = runCatching {
            JSONArray(
                preferences.getString(
                    MessageNotificationListenerService.PENDING_KEY,
                    "[]",
                ),
            )
        }.getOrDefault(JSONArray())
        val remaining = JSONArray()
        for (index in 0 until queue.length()) {
            val item = queue.optJSONObject(index)
            if (item != null && item.optString("id") != id) remaining.put(item)
        }
        preferences.edit()
            .putString(MessageNotificationListenerService.PENDING_KEY, remaining.toString())
            .apply()
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
