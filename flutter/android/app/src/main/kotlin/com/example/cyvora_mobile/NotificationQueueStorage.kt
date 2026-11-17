package com.example.cyvora_mobile

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import org.json.JSONArray
import org.json.JSONException
import org.json.JSONObject
import java.nio.charset.StandardCharsets
import java.security.GeneralSecurityException
import java.security.KeyStore
import java.util.UUID
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

class NotificationStorageException(
    message: String,
    cause: Throwable? = null,
) : Exception(message, cause)

internal class NotificationQueueStorage(context: Context) {
    private val appContext = context.applicationContext
    private val preferences = appContext.getSharedPreferences(
        PREFERENCES_NAME,
        Context.MODE_PRIVATE,
    )

    fun isMonitoringConsentGranted(): Boolean =
        preferences.getBoolean(MONITORING_CONSENT_KEY, false)

    fun setMonitoringConsentGranted(granted: Boolean) {
        val editor = preferences.edit().putBoolean(MONITORING_CONSENT_KEY, granted)
        if (granted) {
            editor.apply()
            return
        }
        val saved = editor
            .remove(ENCRYPTED_PENDING_KEY)
            .remove(LEGACY_PENDING_KEY)
            .commit()
        if (!saved) {
            throw NotificationStorageException(
                "Monitoring consent and queued previews could not be saved.",
            )
        }
        cancelExpiryAlarm()
    }

    fun retentionDays(): Int {
        val configured = preferences.getInt(RETENTION_DAYS_KEY, DEFAULT_RETENTION_DAYS)
        return configured.takeIf { it in RETENTION_OPTIONS } ?: DEFAULT_RETENTION_DAYS
    }

    fun setRetentionDays(days: Int) {
        require(days in RETENTION_OPTIONS) { "Unsupported notification retention period." }
        preferences.edit().putInt(RETENTION_DAYS_KEY, days).apply()
        purgeExpiredAndSchedule()
    }

    fun enqueue(
        id: String,
        title: String,
        text: String,
        packageName: String,
        receivedAt: Long,
    ) {
        if (!isMonitoringConsentGranted()) return

        val now = System.currentTimeMillis()
        if (receivedAt <= now - retentionDays() * MILLIS_PER_DAY) return
        val existing = pruneExpired(readQueue(), now)
        val updated = JSONArray()
        for (index in 0 until existing.length()) {
            val item = existing.optJSONObject(index) ?: continue
            if (item.optString("id") != id) updated.put(item)
        }
        updated.put(
            JSONObject()
                .put("id", id)
                .put("title", title)
                .put("text", text)
                .put("packageName", packageName)
                .put("receivedAt", receivedAt),
        )
        while (updated.length() > MAX_QUEUE_SIZE) updated.remove(0)
        writeQueue(updated)
        scheduleNextExpiry(updated, now)
    }

    fun pendingNotifications(): List<Map<String, Any>> {
        val now = System.currentTimeMillis()
        val stored = pruneExpired(readQueue(), now)
        val pending = JSONArray()
        val notifications = mutableListOf<Map<String, Any>>()
        for (index in 0 until stored.length()) {
            val item = stored.optJSONObject(index) ?: continue
            if (item.optBoolean("completed")) continue
            pending.put(item)
            notifications.add(
                mapOf(
                    "id" to item.optString("id"),
                    "title" to item.optString("title"),
                    "text" to item.optString("text"),
                    "packageName" to item.optString("packageName"),
                    "receivedAt" to item.optLong("receivedAt"),
                ),
            )
        }
        writeQueue(pending)
        scheduleNextExpiry(pending, now)
        return notifications
    }

    fun markCompleted(id: String?) {
        if (id.isNullOrEmpty()) return
        val now = System.currentTimeMillis()
        val current = pruneExpired(readQueue(), now)
        var changed = false
        for (index in 0 until current.length()) {
            val item = current.optJSONObject(index) ?: continue
            if (item.optString("id") == id) {
                item.put("completed", true)
                changed = true
                break
            }
        }
        if (changed) {
            writeQueue(current, durable = true)
            scheduleNextExpiry(current, now)
        }
    }

    fun remove(id: String?) {
        if (id.isNullOrEmpty()) return
        val now = System.currentTimeMillis()
        val current = pruneExpired(readQueue(), now)
        val remaining = JSONArray()
        for (index in 0 until current.length()) {
            val item = current.optJSONObject(index) ?: continue
            if (item.optString("id") != id) remaining.put(item)
        }
        writeQueue(remaining)
        scheduleNextExpiry(remaining, now)
    }

    fun clear() {
        val saved = preferences.edit()
            .remove(ENCRYPTED_PENDING_KEY)
            .remove(LEGACY_PENDING_KEY)
            .commit()
        if (!saved) {
            throw NotificationStorageException(
                "Pending notification previews could not be deleted.",
            )
        }
        cancelExpiryAlarm()
    }

    private fun cancelExpiryAlarm() {
        expiryAlarm()?.let { alarm ->
            alarm.cancel(expiryPendingIntent())
        }
    }

    fun purgeExpiredAndSchedule() {
        val now = System.currentTimeMillis()
        val queue = pruneExpired(readQueue(), now)
        writeQueue(queue)
        scheduleNextExpiry(queue, now)
    }

    private fun readQueue(): JSONArray {
        val encrypted = preferences.getString(ENCRYPTED_PENDING_KEY, null)
        if (encrypted != null) {
            return try {
                JSONArray(decrypt(encrypted))
            } catch (error: JSONException) {
                throw NotificationStorageException(
                    "Stored notification data is invalid.",
                    error,
                )
            }
        }

        val legacy = preferences.getString(LEGACY_PENDING_KEY, null) ?: return JSONArray()
        val queue = try {
            JSONArray(legacy)
        } catch (error: JSONException) {
            throw NotificationStorageException(
                "Existing notification data could not be migrated securely.",
                error,
            )
        }
        writeQueue(queue, durable = true)
        return queue
    }

    private fun writeQueue(queue: JSONArray, durable: Boolean = false) {
        val editor = preferences.edit().remove(LEGACY_PENDING_KEY)
        if (queue.length() == 0) {
            editor.remove(ENCRYPTED_PENDING_KEY)
        } else {
            editor.putString(ENCRYPTED_PENDING_KEY, encrypt(queue.toString()))
        }
        if (durable) {
            if (!editor.commit()) {
                throw NotificationStorageException(
                    "Encrypted notification data could not be saved.",
                )
            }
        } else {
            editor.apply()
        }
    }

    private fun pruneExpired(queue: JSONArray, now: Long): JSONArray {
        val cutoff = now - retentionDays() * MILLIS_PER_DAY
        val remaining = JSONArray()
        for (index in 0 until queue.length()) {
            val item = queue.optJSONObject(index) ?: continue
            if (item.optLong("receivedAt", 0L) > cutoff) remaining.put(item)
        }
        return remaining
    }

    private fun scheduleNextExpiry(queue: JSONArray, now: Long) {
        val alarm = expiryAlarm() ?: return
        if (queue.length() == 0) {
            alarm.cancel(expiryPendingIntent())
            return
        }

        val retentionMillis = retentionDays() * MILLIS_PER_DAY
        val nextExpiry = (0 until queue.length())
            .mapNotNull { queue.optJSONObject(it)?.optLong("receivedAt") }
            .minOfOrNull { it + retentionMillis }
            ?: return
        alarm.setAndAllowWhileIdle(
            AlarmManager.RTC_WAKEUP,
            maxOf(now, nextExpiry),
            expiryPendingIntent(),
        )
    }

    private fun expiryAlarm(): AlarmManager? =
        appContext.getSystemService(Context.ALARM_SERVICE) as? AlarmManager

    private fun expiryPendingIntent(): PendingIntent {
        val intent = Intent(appContext, NotificationQueueExpiryReceiver::class.java)
            .setAction(NotificationQueueExpiryReceiver.ACTION_EXPIRE_NOTIFICATION_QUEUE)
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                PendingIntent.FLAG_IMMUTABLE
            } else {
                0
            }
        return PendingIntent.getBroadcast(appContext, EXPIRY_REQUEST_CODE, intent, flags)
    }

    private fun encrypt(value: String): String {
        try {
            val cipher = Cipher.getInstance(TRANSFORMATION)
            cipher.init(Cipher.ENCRYPT_MODE, secretKey())
            cipher.updateAAD(ENCRYPTED_PENDING_KEY.toByteArray(StandardCharsets.UTF_8))
            val encrypted = cipher.doFinal(value.toByteArray(StandardCharsets.UTF_8))
            val payload = cipher.iv + encrypted
            return ENCRYPTED_PREFIX + Base64.encodeToString(payload, Base64.NO_WRAP)
        } catch (error: GeneralSecurityException) {
            throw NotificationStorageException(
                "Notification data could not be encrypted.",
                error,
            )
        }
    }

    private fun decrypt(value: String): String {
        try {
            if (!value.startsWith(ENCRYPTED_PREFIX)) {
                throw NotificationStorageException(
                    "Stored notification data uses an unsupported format.",
                )
            }
            val payload = Base64.decode(value.removePrefix(ENCRYPTED_PREFIX), Base64.NO_WRAP)
            if (payload.size <= GCM_IV_SIZE) {
                throw NotificationStorageException("Stored notification data is incomplete.")
            }
            val iv = payload.copyOfRange(0, GCM_IV_SIZE)
            val encrypted = payload.copyOfRange(GCM_IV_SIZE, payload.size)
            val cipher = Cipher.getInstance(TRANSFORMATION)
            cipher.init(
                Cipher.DECRYPT_MODE,
                secretKey(),
                GCMParameterSpec(GCM_TAG_SIZE_BITS, iv),
            )
            cipher.updateAAD(ENCRYPTED_PENDING_KEY.toByteArray(StandardCharsets.UTF_8))
            return String(cipher.doFinal(encrypted), StandardCharsets.UTF_8)
        } catch (error: GeneralSecurityException) {
            throw NotificationStorageException(
                "Stored notification data could not be decrypted.",
                error,
            )
        } catch (error: IllegalArgumentException) {
            throw NotificationStorageException(
                "Stored notification data is invalid.",
                error,
            )
        }
    }

    private fun secretKey(): SecretKey {
        val keyStore = KeyStore.getInstance(ANDROID_KEY_STORE).apply { load(null) }
        val existing = keyStore.getKey(KEY_ALIAS, null) as? SecretKey
        if (existing != null) return existing

        val generator = KeyGenerator.getInstance(
            KeyProperties.KEY_ALGORITHM_AES,
            ANDROID_KEY_STORE,
        )
        generator.init(
            KeyGenParameterSpec.Builder(
                KEY_ALIAS,
                KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT,
            )
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .setKeySize(KEY_SIZE_BITS)
                .setRandomizedEncryptionRequired(true)
                .build(),
        )
        return generator.generateKey()
    }

    companion object {
        const val PREFERENCES_NAME = "cyvora_notification_scanning"
        private const val LEGACY_PENDING_KEY = "pending_messages"
        private const val ENCRYPTED_PENDING_KEY = "encrypted_pending_messages_v1"
        private const val MONITORING_CONSENT_KEY = "message_monitoring_consent"
        private const val RETENTION_DAYS_KEY = "notification_retention_days"
        private const val DEFAULT_RETENTION_DAYS = 7
        private val RETENTION_OPTIONS = setOf(1, 7, 30)
        private const val MAX_QUEUE_SIZE = 50
        private const val MILLIS_PER_DAY = 24 * 60 * 60 * 1000L
        private const val KEY_ALIAS = "cyvora.notification.queue.v1"
        private const val ANDROID_KEY_STORE = "AndroidKeyStore"
        private const val TRANSFORMATION = "AES/GCM/NoPadding"
        private const val KEY_SIZE_BITS = 256
        private const val GCM_IV_SIZE = 12
        private const val GCM_TAG_SIZE_BITS = 128
        private const val ENCRYPTED_PREFIX = "v1:"
        private const val EXPIRY_REQUEST_CODE = 1037
    }
}
