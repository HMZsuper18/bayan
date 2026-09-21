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
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent

class RecitationsWidgetProvider : AppWidgetProvider() {

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
        val layoutId = if (isCompact) R.layout.recitations_widget_compact else R.layout.recitations_widget

        val views = RemoteViews(context.packageName, layoutId)
        val isDark = isDarkMode(context)
        val iconColor = if (isDark) 0xFF4CAF9F.toInt() else 0xFF00674F.toInt()

        val reciter1Name = prefs.getString("reciter_1_name", null) ?: "مشاري العفاسي"
        val reciter1Id = prefs.getString("reciter_1_id", null) ?: "ar.alafasy"
        val reciter2Name = prefs.getString("reciter_2_name", null) ?: "عبدالرحمن السديس"
        val reciter2Id = prefs.getString("reciter_2_id", null) ?: "ar.abdurrahmaanassudais"

        if (isCompact) {
            views.setTextViewText(R.id.compact_reciter_1_name, reciter1Name)
            views.setTextViewText(R.id.compact_reciter_2_name, reciter2Name)
        } else {
            views.setTextViewText(R.id.reciter_1_name, reciter1Name)
            views.setTextViewText(R.id.reciter_2_name, reciter2Name)
        }

        if (Build.VERSION.SDK_INT >= 29) {
            val playId1 = if (isCompact) R.id.compact_play_reciter_1 else R.id.play_reciter_1
            val playId2 = if (isCompact) R.id.compact_play_reciter_2 else R.id.play_reciter_2
            views.setColorStateList(playId1, "setImageTintList", ColorStateList.valueOf(iconColor))
            views.setColorStateList(playId2, "setImageTintList", ColorStateList.valueOf(iconColor))
        }

        val play1Intent = Intent(context, MainActivity::class.java).apply {
            action = HomeWidgetLaunchIntent.HOME_WIDGET_LAUNCH_ACTION
            data = Uri.parse("bayan://play/$reciter1Id")
        }
        val play1PendingIntent = PendingIntent.getActivity(
            context, 7, play1Intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val playId1 = if (isCompact) R.id.compact_play_reciter_1 else R.id.play_reciter_1
        views.setOnClickPendingIntent(playId1, play1PendingIntent)

        val play2Intent = Intent(context, MainActivity::class.java).apply {
            action = HomeWidgetLaunchIntent.HOME_WIDGET_LAUNCH_ACTION
            data = Uri.parse("bayan://play/$reciter2Id")
        }
        val play2PendingIntent = PendingIntent.getActivity(
            context, 8, play2Intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val playId2 = if (isCompact) R.id.compact_play_reciter_2 else R.id.play_reciter_2
        views.setOnClickPendingIntent(playId2, play2PendingIntent)

        appWidgetManager.updateAppWidget(appWidgetId, views)
    }

    private fun isDarkMode(context: Context): Boolean {
        val mode = context.resources.configuration.uiMode and
                android.content.res.Configuration.UI_MODE_NIGHT_MASK
        return mode == android.content.res.Configuration.UI_MODE_NIGHT_YES
    }
}
