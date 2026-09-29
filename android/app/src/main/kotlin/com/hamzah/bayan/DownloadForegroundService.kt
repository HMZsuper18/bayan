package com.hamzah.bayan

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import androidx.core.app.NotificationCompat

/**
 * Foreground service that keeps the reciter download alive while the app is
 * backgrounded and hosts the ongoing progress notification.
 *
 * Every user-visible string arrives from Dart already localized, including the
 * notification channel name, so this file holds no copy of its own. The only
 * exception is the manifest app label, used as a defensive fallback if the
 * service is ever started without a payload.
 */
class DownloadForegroundService : Service() {

    data class Payload(
        val channelName: String,
        val channelDescription: String,
        val title: String,
        val text: String,
        val progress: Int,
        val indeterminate: Boolean,
    )

    private var wakeLock: PowerManager.WakeLock? = null
    private var foreground = false

    private val notificationManager: NotificationManager
        get() = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

    override fun onCreate() {
        super.onCreate()
        instance = this
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        render()
        return START_NOT_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onTaskRemoved(rootIntent: Intent?) {
        // The Flutter engine dies with the task, so nothing would ever update
        // this notification again. Stop rather than strand a frozen one.
        stopSelf()
        super.onTaskRemoved(rootIntent)
    }

    override fun onDestroy() {
        wakeLock?.let { if (it.isHeld) it.release() }
        wakeLock = null
        notificationManager.cancel(NOTIFICATION_ID)
        instance = null
        super.onDestroy()
    }

    private fun render() {
        val payload = pending ?: fallbackPayload()
        ensureChannel(payload)
        val notification = build(payload)
        if (!foreground) {
            startAsForeground(notification)
            foreground = true
        } else {
            notificationManager.notify(NOTIFICATION_ID, notification)
        }
        acquireWakeLock()
    }

    private fun startAsForeground(notification: Notification) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC,
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    private fun acquireWakeLock() {
        if (wakeLock?.isHeld == true) return
        val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
        wakeLock = powerManager.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "bayan:download").apply {
            setReferenceCounted(false)
            acquire()
        }
    }

    private fun ensureChannel(payload: Payload) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val label = applicationInfo.loadLabel(packageManager).toString()
        val channel = NotificationChannel(
            CHANNEL_ID,
            payload.channelName.ifBlank { label },
            NotificationManager.IMPORTANCE_LOW,
        ).apply {
            if (payload.channelDescription.isNotBlank()) description = payload.channelDescription
            enableVibration(false)
            setSound(null, null)
            setShowBadge(false)
        }
        // Re-creating an existing channel updates its name/description, which is
        // how the notification follows a device language change.
        notificationManager.createNotificationChannel(channel)
    }

    private fun build(payload: Payload): Notification {
        val contentIntent = PendingIntent.getActivity(
            this,
            0,
            Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_stat_download)
            .setContentTitle(payload.title)
            .setContentText(payload.text)
            .setProgress(100, payload.progress.coerceIn(0, 100), payload.indeterminate)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setShowWhen(false)
            .setContentIntent(contentIntent)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setCategory(NotificationCompat.CATEGORY_PROGRESS)
            .build()
    }

    private fun fallbackPayload(): Payload {
        val label = applicationInfo.loadLabel(packageManager).toString()
        return Payload(label, "", label, "", 0, true)
    }

    companion object {
        const val CHANNEL_ID = "bayan_download_progress"
        const val NOTIFICATION_ID = 2001

        @Volatile
        private var pending: Payload? = null

        @Volatile
        var instance: DownloadForegroundService? = null
            private set

        /** Push a localized payload, starting the service on first use. */
        fun submit(context: Context, payload: Payload) {
            pending = payload
            val current = instance
            if (current != null) {
                current.render()
            } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(
                    Intent(context, DownloadForegroundService::class.java),
                )
            } else {
                context.startService(Intent(context, DownloadForegroundService::class.java))
            }
        }

        fun stop(context: Context) {
            pending = null
            val current = instance
            if (current != null) {
                current.stopSelf()
            } else {
                (context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager)
                    .cancel(NOTIFICATION_ID)
            }
        }
    }
}
