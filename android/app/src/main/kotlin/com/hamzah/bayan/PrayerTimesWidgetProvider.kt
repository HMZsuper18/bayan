package com.hamzah.bayan

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.Rect
import android.graphics.Typeface
import android.net.Uri
import android.os.Bundle
import android.widget.RemoteViews
import androidx.core.content.res.ResourcesCompat
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import java.util.Locale

class PrayerTimesWidgetProvider : AppWidgetProvider() {

    companion object {
        private val PRAYERS = listOf("fajr", "dhuhr", "asr", "maghrib", "isha")

        private const val LIGHT_TITLE = 0xFF00674F.toInt()
        private const val LIGHT_TEXT = 0xFF1A1A1A.toInt()

        private const val DARK_TITLE = 0xFF4CAF9F.toInt()
        private const val DARK_TEXT = 0xFFE8E8E0.toInt()
    }

    private data class Ids(val label: Int, val time: Int, val chip: Int)

    private data class TextSizes(val titleSp: Float, val labelSp: Float, val timeSp: Float)

    private fun idsFor(prayer: String): Ids = when (prayer) {
        "fajr" -> Ids(R.id.prayer_fajr_label, R.id.prayer_fajr_time, R.id.chip_fajr)
        "dhuhr" -> Ids(R.id.prayer_dhuhr_label, R.id.prayer_dhuhr_time, R.id.chip_dhuhr)
        "asr" -> Ids(R.id.prayer_asr_label, R.id.prayer_asr_time, R.id.chip_asr)
        "maghrib" -> Ids(R.id.prayer_maghrib_label, R.id.prayer_maghrib_time, R.id.chip_maghrib)
        else -> Ids(R.id.prayer_isha_label, R.id.prayer_isha_time, R.id.chip_isha)
    }

    private fun fallbackLabelId(prayer: String): Int = when (prayer) {
        "fajr" -> R.string.prayer_label_fajr
        "dhuhr" -> R.string.prayer_label_dhuhr
        "asr" -> R.string.prayer_label_asr
        "maghrib" -> R.string.prayer_label_maghrib
        else -> R.string.prayer_label_isha
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

    private data class LayoutChoice(val layoutId: Int, val sizes: TextSizes)

    private fun selectLayout(width: Int, height: Int): LayoutChoice = when {
        height in 1..84 -> LayoutChoice(
            R.layout.prayer_times_widget_banner,
            TextSizes(titleSp = 10f, labelSp = 7f, timeSp = 7f)
        )
        width < 240 -> LayoutChoice(
            R.layout.prayer_times_widget_compact,
            TextSizes(titleSp = 11f, labelSp = 8f, timeSp = 8f)
        )
        width >= 300 && height >= 160 -> LayoutChoice(
            R.layout.prayer_times_widget_large,
            TextSizes(titleSp = 17f, labelSp = 14f, timeSp = 13f)
        )
        else -> LayoutChoice(
            R.layout.prayer_times_widget,
            TextSizes(titleSp = 15f, labelSp = 12f, timeSp = 10f)
        )
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
        val (layoutId, sizes) = selectLayout(width, height)

        val views = RemoteViews(context.packageName, layoutId)
        val lang = resolveLang(context, prefs)
        val isDark = resolveDark(context, prefs)

        try {
            applyTexts(context, views, prefs, sizes, isDark, lang)
            applyTimes(context, views, prefs, lang, sizes, isDark)
            applyChrome(views, isDark)
            applyClicks(context, views)
            appWidgetManager.updateAppWidget(appWidgetId, views)
            android.util.Log.i("PrayerTimesWidget", "updated id=$appWidgetId ${width}x${height} layout=${Integer.toHexString(layoutId)}")
        } catch (t: Throwable) {
            android.util.Log.e("PrayerTimesWidget", "update failed", t)
        }
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

    private var boldTypeface: Typeface? = null
    private var mediumTypeface: Typeface? = null

    private fun loadTypefaces(context: Context) {
        if (boldTypeface == null) {
            boldTypeface = loadFont(context, "fonts/tajawal_bold.ttf", R.font.tajawal_bold)
        }
        if (mediumTypeface == null) {
            mediumTypeface = loadFont(context, "fonts/tajawal_medium.ttf", R.font.tajawal_medium)
        }
    }

    private fun loadFont(context: Context, assetPath: String, fontRes: Int): Typeface? {
        return try {
            Typeface.createFromAsset(context.assets, assetPath)
        } catch (e: Exception) {
            try {
                ResourcesCompat.getFont(context, fontRes)
            } catch (e2: Exception) {
                null
            }
        }
    }

    private fun textBitmap(
        context: Context,
        text: String,
        typeface: Typeface?,
        sizeSp: Float,
        color: Int
    ): Bitmap {
        val metrics = context.resources.displayMetrics
        val textSizePx = sizeSp * metrics.scaledDensity
        // Final bitmap at 2× logical px; density*2 → ImageView intrinsic size stays 1× dp,
        // but the drawable downsamples from 2× for sharp glyphs.
        val ss = 4f
        val outScale = 2f

        fun makePaint(scale: Float) = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            this.typeface = typeface ?: Typeface.DEFAULT
            textSize = textSizePx * scale
            setColor(color)
            textAlign = Paint.Align.CENTER
            isSubpixelText = true
        }

        val hiPaint = makePaint(ss)
        val bounds = Rect()
        hiPaint.getTextBounds(text, 0, text.length, bounds)
        val hiW = (bounds.width() + 8).coerceAtLeast(1)
        val hiH = (bounds.height() + 8).coerceAtLeast(1)
        val hi = Bitmap.createBitmap(hiW, hiH, Bitmap.Config.ARGB_8888)
        Canvas(hi).drawText(
            text,
            hiW / 2f,
            hiH / 2f - (bounds.top + bounds.bottom) / 2f,
            hiPaint
        )

        val outW = ((hiW / ss) * outScale).toInt().coerceAtLeast(1)
        val outH = ((hiH / ss) * outScale).toInt().coerceAtLeast(1)
        val out = Bitmap.createScaledBitmap(hi, outW, outH, true)
        if (out !== hi) hi.recycle()
        out.density = (metrics.densityDpi * outScale).toInt()
        return out
    }

    private fun applyTexts(
        context: Context,
        views: RemoteViews,
        prefs: SharedPreferences,
        sizes: TextSizes,
        isDark: Boolean,
        lang: String
    ) {
        loadTypefaces(context)
        val isRtl = lang == "ar" || lang == "ur"
        val titleGravity =
            if (isRtl) android.view.Gravity.END or android.view.Gravity.CENTER_VERTICAL
            else android.view.Gravity.START or android.view.Gravity.CENTER_VERTICAL
        views.setInt(R.id.title_row, "setGravity", titleGravity)

        val titleColor = if (isDark) DARK_TITLE else LIGHT_TITLE
        val title = prefs.getString("prayer_widget_title", null)
            ?: context.getString(R.string.prayer_widget_title)
        views.setImageViewBitmap(
            R.id.widget_title,
            textBitmap(context, title, boldTypeface, sizes.titleSp, titleColor)
        )

        val labelColor = if (isDark) DARK_TEXT else LIGHT_TEXT
        for (prayer in PRAYERS) {
            val label = prefs.getString("label_$prayer", null)
                ?: context.getString(fallbackLabelId(prayer))
            views.setImageViewBitmap(
                idsFor(prayer).label,
                textBitmap(context, label, mediumTypeface, sizes.labelSp, labelColor)
            )
        }
    }

    private fun applyTimes(
        context: Context,
        views: RemoteViews,
        prefs: SharedPreferences,
        lang: String,
        sizes: TextSizes,
        isDark: Boolean
    ) {
        loadTypefaces(context)
        val timeColor = if (isDark) DARK_TEXT else LIGHT_TEXT
        for (prayer in PRAYERS) {
            val hour = prefs.getInt("prayer_${prayer}_hour", -1)
            val minute = prefs.getInt("prayer_${prayer}_minute", -1)
            val text = if (hour in 0..23 && minute in 0..59) {
                formatTime(hour, minute, lang)
            } else {
                "--:--"
            }
            views.setImageViewBitmap(
                idsFor(prayer).time,
                textBitmap(context, text, mediumTypeface, sizes.timeSp, timeColor)
            )
        }
    }

    /**
     * Always 12-hour with a localized meridiem: en → AM/PM, ar → ص/م, ur → ص/ش.
     * Midnight and noon both render as 12, never 0.
     */
    private fun formatTime(hour24: Int, minute: Int, lang: String): String {
        val h12 = when (val h = hour24 % 12) {
            0 -> 12
            else -> h
        }
        val isPm = hour24 >= 12
        val period = when (lang) {
            "ar" -> if (isPm) "م" else "ص"
            "ur" -> if (isPm) "ش" else "ص"
            else -> if (isPm) "PM" else "AM"
        }
        return String.format(Locale.US, "%d:%02d%s", h12, minute, period)
    }

    private fun applyChrome(views: RemoteViews, isDark: Boolean) {
        val bg = if (isDark) R.drawable.widget_bg_night else R.drawable.widget_bg_day
        val chipBg = if (isDark) R.drawable.chip_bg_night else R.drawable.chip_bg_day

        views.setInt(R.id.widget_root, "setBackgroundResource", bg)
        for (prayer in PRAYERS) {
            views.setInt(idsFor(prayer).chip, "setBackgroundResource", chipBg)
        }
    }

    private fun applyClicks(context: Context, views: RemoteViews) {
        val openIntent = Intent(context, MainActivity::class.java).apply {
            action = HomeWidgetLaunchIntent.HOME_WIDGET_LAUNCH_ACTION
            data = Uri.parse("bayan://widget/prayer_times")
        }
        val openPendingIntent = PendingIntent.getActivity(
            context, 2, openIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        views.setOnClickPendingIntent(R.id.widget_title, openPendingIntent)
    }
}
