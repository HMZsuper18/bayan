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

class OcrWidgetProvider : AppWidgetProvider() {

    companion object {
        private const val LIGHT_ICON = 0xFF00674F.toInt()
        private const val DARK_ICON = 0xFF4CAF9F.toInt()
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            updateWidget(context, appWidgetManager, appWidgetId)
        }
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle?
    ) {
        updateWidget(context, appWidgetManager, appWidgetId)
    }

    private fun updateWidget(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int
    ) {
        val views = RemoteViews(context.packageName, R.layout.ocr_widget)

        val prefs: SharedPreferences =
            context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
        val isDark = resolveDark(context, prefs)

        views.setInt(
            R.id.ocr_root,
            "setBackgroundResource",
            if (isDark) R.drawable.widget_bg_night else R.drawable.widget_bg_day
        )

        if (Build.VERSION.SDK_INT >= 29) {
            views.setColorStateList(
                R.id.ocr_icon, "setImageTintList",
                ColorStateList.valueOf(if (isDark) DARK_ICON else LIGHT_ICON)
            )
        }

        val scannerIntent = Intent(context, MainActivity::class.java).apply {
            action = HomeWidgetLaunchIntent.HOME_WIDGET_LAUNCH_ACTION
            data = Uri.parse("bayan://scanner")
        }
        val scannerPendingIntent = PendingIntent.getActivity(
            context, 6, scannerIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        views.setOnClickPendingIntent(R.id.ocr_root, scannerPendingIntent)
        views.setOnClickPendingIntent(R.id.ocr_icon, scannerPendingIntent)

        appWidgetManager.updateAppWidget(appWidgetId, views)
    }

    private fun resolveDark(context: Context, prefs: SharedPreferences): Boolean {
        when (prefs.getString("widget_theme", null)) {
            "dark" -> return true
            "light" -> return false
        }
        val mode = context.resources.configuration.uiMode and
                android.content.res.Configuration.UI_MODE_NIGHT_MASK
        return mode == android.content.res.Configuration.UI_MODE_NIGHT_YES
    }
}