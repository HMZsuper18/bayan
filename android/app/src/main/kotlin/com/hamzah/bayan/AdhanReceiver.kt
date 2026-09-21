package com.hamzah.bayan

import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import androidx.core.app.NotificationCompat
import java.util.Locale

class AdhanReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != AdhanNotificationBridge.ACTION_ADHAN) return

        val prayerName = intent.getStringExtra(AdhanNotificationBridge.EXTRA_PRAYER_NAME) ?: return
        val hour = intent.getIntExtra(AdhanNotificationBridge.EXTRA_PRAYER_HOUR, -1)
        val minute = intent.getIntExtra(AdhanNotificationBridge.EXTRA_PRAYER_MINUTE, -1)
        val isReminder = intent.getBooleanExtra("is_reminder", false)

        val displayName = getDisplayName(prayerName)
        val timeStr = String.format(Locale.getDefault(), "%02d:%02d", hour, minute)

        val title = if (isReminder) {
            "$displayName in ${intent.getIntExtra("reminder_minutes", 10)} minutes"
        } else {
            "$displayName has begun"
        }

        val body = "Prayer time: $timeStr"

        // Open app on notification tap
        val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)?.apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val pendingIntent = PendingIntent.getActivity(
            context,
            0,
            launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val channelId = if (isReminder) {
            AdhanNotificationBridge.CHANNEL_ID_REMINDER
        } else {
            AdhanNotificationBridge.CHANNEL_ID_ADHAN
        }

        val notification = NotificationCompat.Builder(context, channelId)
            .setSmallIcon(android.R.drawable.ic_popup_reminder)
            .setContentTitle(title)
            .setContentText(body)
            .setPriority(if (isReminder) NotificationCompat.PRIORITY_DEFAULT else NotificationCompat.PRIORITY_HIGH)
            .setContentIntent(pendingIntent)
            .setAutoCancel(true)
            .build()

        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val notificationId = prayerName.hashCode() + if (isReminder) 1000 else 0
        manager.notify(notificationId, notification)
    }

    private fun getDisplayName(prayerName: String): String {
        return when (prayerName.lowercase()) {
            "fajr" -> "Fajr"
            "dhuhr" -> "Dhuhr"
            "asr" -> "Asr"
            "maghrib" -> "Maghrib"
            "isha" -> "Isha"
            else -> prayerName.replaceFirstChar { it.uppercase() }
        }
    }
}
