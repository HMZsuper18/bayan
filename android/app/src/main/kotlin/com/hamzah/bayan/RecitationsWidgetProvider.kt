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
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent

class RecitationsWidgetProvider : AppWidgetProvider() {

    companion object {
        private const val MAX_ROWS = 8
        private const val LIGHT_TITLE = 0xFF00674F.toInt()
        private const val LIGHT_TEXT = 0xFF1A1A1A.toInt()
        private const val LIGHT_ICON = 0xFF00674F.toInt()
        private const val DARK_TITLE = 0xFF4CAF9F.toInt()
        private const val DARK_TEXT = 0xFFE8E8E0.toInt()
        private const val DARK_ICON = 0xFF4CAF9F.toInt()
        private const val PLAY_REQUEST_BASE = 70
    }

    private data class RowIds(val row: Int, val name: Int, val play: Int)

    private fun idsFor(i: Int): RowIds = when (i) {
        1 -> RowIds(R.id.reciter_1_row, R.id.reciter_1_name, R.id.play_reciter_1)
        2 -> RowIds(R.id.reciter_2_row, R.id.reciter_2_name, R.id.play_reciter_2)
        3 -> RowIds(R.id.reciter_3_row, R.id.reciter_3_name, R.id.play_reciter_3)
        4 -> RowIds(R.id.reciter_4_row, R.id.reciter_4_name, R.id.play_reciter_4)
        5 -> RowIds(R.id.reciter_5_row, R.id.reciter_5_name, R.id.play_reciter_5)
        6 -> RowIds(R.id.reciter_6_row, R.id.reciter_6_name, R.id.play_reciter_6)
        7 -> RowIds(R.id.reciter_7_row, R.id.reciter_7_name, R.id.play_reciter_7)
        else -> RowIds(R.id.reciter_8_row, R.id.reciter_8_name, R.id.play_reciter_8)
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        val prefs = prefs(context)
        for (appWidgetId in appWidgetIds) {
            updateWidget(
                context, appWidgetManager, appWidgetId, prefs,
                appWidgetManager.getAppWidgetOptions(appWidgetId)
            )
        }
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle?
    ) {
        updateWidget(context, appWidgetManager, appWidgetId, prefs(context), newOptions)
    }

    private fun prefs(context: Context): SharedPreferences =
        context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)

    private fun selectLayout(width: Int, height: Int): Int = when {
        height in 1..84 -> R.layout.recitations_widget_banner
        width < 240 -> R.layout.recitations_widget_compact
        width >= 300 && height >= 160 -> R.layout.recitations_widget_large
        else -> R.layout.recitations_widget
    }

    private fun visibleRowsFor(layoutId: Int, prefs: SharedPreferences): Int {
        val available = prefs.getInt("reciter_count", 0)
            .coerceIn(0, MAX_ROWS)
        return when (layoutId) {
            R.layout.recitations_widget_banner -> minOf(available, 2)
            R.layout.recitations_widget_compact -> minOf(available, 3)
            R.layout.recitations_widget_large -> available
            else -> minOf(available, 4)
        }.coerceAtLeast(minOf(available, 1))
    }

    private fun updateWidget(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        prefs: SharedPreferences,
        options: Bundle?
    ) {
        val width = options?.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH) ?: 0
        val height = options?.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT) ?: 0
        val layoutId = selectLayout(width, height)

        val views = RemoteViews(context.packageName, layoutId)
        val isDark = resolveDark(context, prefs)
        val showRows = visibleRowsFor(layoutId, prefs)

        applyTexts(context, views, prefs, showRows)
        applyClicks(context, views, prefs, showRows)
        applyTheme(views, isDark, showRows)

        appWidgetManager.updateAppWidget(appWidgetId, views)
    }

    private fun resolveLang(context: Context, prefs: SharedPreferences): String {
        prefs.getString("widget_lang", null)?.let { return it }
        return when (context.resources.configuration.locales.get(0).language) {
            "ar" -> "ar"
            "ur" -> "ur"
            else -> "en"
        }
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

    private fun applyTexts(context: Context, views: RemoteViews, prefs: SharedPreferences, showRows: Int) {
        val title = prefs.getString("reciters_widget_title", null)
            ?: context.getString(R.string.recitations_widget_title)
        views.setTextViewText(R.id.widget_title, title)

        for (i in 1..MAX_ROWS) {
            val ids = idsFor(i)
            val name = prefs.getString("reciter_${i}_name", null)
            val visible = i <= showRows && !name.isNullOrEmpty()
            views.setViewVisibility(ids.row, if (visible) View.VISIBLE else View.GONE)
            if (visible) {
                views.setTextViewText(ids.name, name)
            }
        }
    }

    private fun applyClicks(context: Context, views: RemoteViews, prefs: SharedPreferences, showRows: Int) {
        for (i in 1..showRows) {
            val ids = idsFor(i)
            val reciterId = prefs.getString("reciter_${i}_id", null) ?: continue
            if (reciterId.isEmpty()) continue

            val playIntent = Intent(context, MainActivity::class.java).apply {
                action = HomeWidgetLaunchIntent.HOME_WIDGET_LAUNCH_ACTION
                data = Uri.parse("bayan://play/$reciterId")
                putExtra("bayan_background_play", true)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            val pending = PendingIntent.getActivity(
                context,
                PLAY_REQUEST_BASE + i,
                playIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(ids.play, pending)
        }
    }

    private fun applyTheme(views: RemoteViews, isDark: Boolean, showRows: Int) {
        val bg = if (isDark) R.drawable.widget_bg_night else R.drawable.widget_bg_day
        val chipBg = if (isDark) R.drawable.chip_bg_night else R.drawable.chip_bg_day
        val titleColor = if (isDark) DARK_TITLE else LIGHT_TITLE
        val textColor = if (isDark) DARK_TEXT else LIGHT_TEXT
        val iconColor = if (isDark) DARK_ICON else LIGHT_ICON

        views.setInt(R.id.widget_root, "setBackgroundResource", bg)
        views.setTextColor(R.id.widget_title, titleColor)

        for (i in 1..MAX_ROWS) {
            val ids = idsFor(i)
            if (i <= showRows) {
                views.setInt(ids.row, "setBackgroundResource", chipBg)
                views.setTextColor(ids.name, textColor)
                if (Build.VERSION.SDK_INT >= 29) {
                    views.setColorStateList(
                        ids.play,
                        "setImageTintList",
                        ColorStateList.valueOf(iconColor)
                    )
                }
            }
        }
    }
}
