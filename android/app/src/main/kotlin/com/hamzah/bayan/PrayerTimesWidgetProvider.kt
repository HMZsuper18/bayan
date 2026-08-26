package com.hamzah.bayan

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.content.res.ColorStateList
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.text.format.DateFormat
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import java.util.Calendar
import java.util.GregorianCalendar

class PrayerTimesWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        val prefs: SharedPreferences =
            context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
        for (appWidgetId in appWidgetIds) {
            val options = appWidgetManager.getAppWidgetOptions(appWidgetId)
            updateWidget(context, appWidgetManager, appWidgetId, prefs, options)
        }
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle?
    ) {
        val prefs: SharedPreferences =
            context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
        updateWidget(context, appWidgetManager, appWidgetId, prefs, newOptions)
    }

    private fun updateWidget(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        prefs: SharedPreferences,
        options: Bundle?
    ) {
        val width = options?.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH) ?: 0
        val isCompact = width < 300
        val layoutId = if (isCompact) R.layout.prayer_times_widget_compact else R.layout.prayer_times_widget

        val views = RemoteViews(context.packageName, layoutId)
        val isDark = isDarkMode(context)
        val iconColor = if (isDark) 0xFF4CAF9F.toInt() else 0xFF00674F.toInt()

        val names = listOf("fajr", "dhuhr", "asr", "maghrib", "isha")
        val timeIds = if (isCompact) {
            listOf(
                R.id.compact_prayer_fajr_time,
                R.id.compact_prayer_dhuhr_time,
                R.id.compact_prayer_asr_time,
                R.id.compact_prayer_maghrib_time,
                R.id.compact_prayer_isha_time,
            )
        } else {
            listOf(
                R.id.prayer_fajr_time,
                R.id.prayer_dhuhr_time,
                R.id.prayer_asr_time,
                R.id.prayer_maghrib_time,
                R.id.prayer_isha_time,
            )
        }

        val fmt = java.text.SimpleDateFormat(
            if (isCompact) "HH:mm" else "h:mm a",
            java.util.Locale.getDefault()
        )

        for (i in names.indices) {
            val hour = prefs.getInt("prayer_${names[i]}_hour", -1)
            val minute = prefs.getInt("prayer_${names[i]}_minute", -1)
            val formatted = if (hour >= 0 && minute >= 0) {
                val cal = GregorianCalendar().apply {
                    set(Calendar.HOUR_OF_DAY, hour)
                    set(Calendar.MINUTE, minute)
                }
                fmt.format(cal.time)
            } else {
                "--:--"
            }
            views.setTextViewText(timeIds[i], formatted)
        }

        if (Build.VERSION.SDK_INT >= 29) {
            views.setColorStateList(
                R.id.clock_icon, "setImageTintList",
                ColorStateList.valueOf(iconColor)
            )
            views.setColorStateList(
                R.id.location_button, "setImageTintList",
                ColorStateList.valueOf(iconColor)
            )
        }

        val locationIntent = Intent(context, MainActivity::class.java).apply {
            action = HomeWidgetLaunchIntent.HOME_WIDGET_LAUNCH_ACTION
            data = Uri.parse("bayan://location")
        }
        val locationPendingIntent = PendingIntent.getActivity(
            context, 1, locationIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        views.setOnClickPendingIntent(R.id.location_button, locationPendingIntent)

        appWidgetManager.updateAppWidget(appWidgetId, views)
    }

    private fun isDarkMode(context: Context): Boolean {
        val mode = context.resources.configuration.uiMode and
                android.content.res.Configuration.UI_MODE_NIGHT_MASK
        return mode == android.content.res.Configuration.UI_MODE_NIGHT_YES
    }
}
