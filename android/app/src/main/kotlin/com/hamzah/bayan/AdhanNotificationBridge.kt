package com.hamzah.bayan

import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.ActivityCompat
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.Calendar

class AdhanNotificationBridge(
    private val context: Context,
    private val channel: MethodChannel
) {
    companion object {
        const val CHANNEL_ID_ADHAN = "adhan_notifications"
        const val CHANNEL_ID_REMINDER = "adhan_reminder"
        const val ACTION_ADHAN = "com.hamzah.bayan.ADHAN_ACTION"
        const val EXTRA_PRAYER_NAME = "prayer_name"
        const val EXTRA_PRAYER_HOUR = "prayer_hour"
        const val EXTRA_PRAYER_MINUTE = "prayer_minute"

        private val PRAYER_NAMES = listOf("fajr", "dhuhr", "asr", "maghrib", "isha")

        fun cancelAll(context: Context) {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            for (prayer in PRAYER_NAMES) {
                for (isReminder in listOf(false, true)) {
                    val requestCode = prayer.hashCode() * 100 + if (isReminder) 1 else 0
                    val intent = Intent(context, AdhanReceiver::class.java)
                    val pendingIntent = PendingIntent.getBroadcast(
                        context,
                        requestCode,
                        intent,
                        PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE
                    )
                    if (pendingIntent != null) {
                        alarmManager.cancel(pendingIntent)
                        pendingIntent.cancel()
                    }
                }
            }
        }
    }

    private val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager

    fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "scheduleNotifications" -> {
                @Suppress("UNCHECKED_CAST")
                val prayerTimes = call.argument<List<Map<String, Any>>>("prayerTimes") ?: emptyList()
                val reminderMinutes = call.argument<Int>("reminderMinutes") ?: 10
                scheduleAll(prayerTimes, reminderMinutes)
                result.success(true)
            }
            "cancelAll" -> {
                cancelAll(context)
                result.success(true)
            }
            "isNotificationsEnabled" -> {
                result.success(isNotificationsEnabled())
            }
            "requestExactAlarmPermission" -> {
                result.success(requestExactAlarmPermission())
            }
            "canScheduleExactAlarms" -> {
                result.success(canScheduleExactAlarms())
            }
            "openNotificationSettings" -> {
                openNotificationSettings()
                result.success(true)
            }
            else -> result.notImplemented()
        }
    }

    private fun isNotificationsEnabled(): Boolean {
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            manager.areNotificationsEnabled() &&
                ActivityCompat.checkSelfPermission(
                    context, android.Manifest.permission.POST_NOTIFICATIONS
                ) == android.content.pm.PackageManager.PERMISSION_GRANTED
        } else {
            manager.areNotificationsEnabled()
        }
    }

    private fun canScheduleExactAlarms(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            alarmManager.canScheduleExactAlarms()
        } else {
            true
        }
    }

    private fun requestExactAlarmPermission(): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            if (!alarmManager.canScheduleExactAlarms()) {
                val intent = Intent("android.app.action.REQUEST_SCHEDULE_EXACT_ALARM").apply {
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK
                }
                context.startActivity(intent)
                return false
            }
        }
        return true
    }

    private fun openNotificationSettings() {
        val intent = Intent().apply {
            action = android.provider.Settings.ACTION_APP_NOTIFICATION_SETTINGS
            putExtra(android.provider.Settings.EXTRA_APP_PACKAGE, context.packageName)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK
        }
        context.startActivity(intent)
    }

    fun createNotificationChannels() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

            val adhanChannel = NotificationChannel(
                CHANNEL_ID_ADHAN,
                "Adhan",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Notifications at prayer time"
                enableVibration(true)
            }

            val reminderChannel = NotificationChannel(
                CHANNEL_ID_REMINDER,
                "Adhan Reminder",
                NotificationManager.IMPORTANCE_DEFAULT
            ).apply {
                description = "Reminder before prayer time"
            }

            manager.createNotificationChannel(adhanChannel)
            manager.createNotificationChannel(reminderChannel)
        }
    }

    private fun scheduleAll(prayerTimes: List<Map<String, Any>>, reminderMinutes: Int) {
        createNotificationChannels()

        val now = Calendar.getInstance()

        for (prayer in prayerTimes) {
            val name = prayer["name"] as? String ?: continue
            val hour = prayer["hour"] as? Int ?: continue
            val minute = prayer["minute"] as? Int ?: continue

            // Schedule at-prayer-time notification
            scheduleAlarmWithTomorrow(
                prayerName = name,
                hour = hour,
                minute = minute,
                isReminder = false,
                now = now
            )

            // Schedule reminder notification
            if (reminderMinutes > 0) {
                scheduleAlarmWithTomorrow(
                    prayerName = name,
                    hour = hour,
                    minute = minute - reminderMinutes,
                    isReminder = true,
                    now = now
                )
            }
        }
    }

    private fun scheduleAlarmWithTomorrow(
        prayerName: String,
        hour: Int,
        minute: Int,
        isReminder: Boolean,
        now: Calendar
    ) {
        var target = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, hour.coerceIn(0, 23))
            set(Calendar.MINUTE, minute.coerceIn(0, 59))
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }

        // If the time has already passed today, schedule for tomorrow
        if (target.before(now)) {
            target = Calendar.getInstance().apply {
                add(Calendar.DAY_OF_YEAR, 1)
                set(Calendar.HOUR_OF_DAY, hour.coerceIn(0, 23))
                set(Calendar.MINUTE, minute.coerceIn(0, 59))
                set(Calendar.SECOND, 0)
                set(Calendar.MILLISECOND, 0)
            }
        }

        val requestCode = (prayerName.hashCode() * 100 + if (isReminder) 1 else 0)

        val intent = Intent(context, AdhanReceiver::class.java).apply {
            action = ACTION_ADHAN
            putExtra(EXTRA_PRAYER_NAME, prayerName)
            putExtra(EXTRA_PRAYER_HOUR, hour)
            putExtra(EXTRA_PRAYER_MINUTE, minute)
            putExtra("is_reminder", isReminder)
        }

        val pendingIntent = PendingIntent.getBroadcast(
            context,
            requestCode,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            if (alarmManager.canScheduleExactAlarms()) {
                alarmManager.setExactAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP,
                    target.timeInMillis,
                    pendingIntent
                )
            } else {
                alarmManager.set(
                    AlarmManager.RTC_WAKEUP,
                    target.timeInMillis,
                    pendingIntent
                )
            }
        } else {
            alarmManager.setExactAndAllowWhileIdle(
                AlarmManager.RTC_WAKEUP,
                target.timeInMillis,
                pendingIntent
            )
        }
    }
}
