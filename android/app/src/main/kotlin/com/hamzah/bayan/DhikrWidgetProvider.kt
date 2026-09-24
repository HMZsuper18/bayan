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
import android.text.Layout
import android.text.StaticLayout
import android.text.TextPaint
import android.text.TextUtils
import android.view.View
import android.widget.RemoteViews
import androidx.core.content.res.ResourcesCompat
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import kotlin.math.ceil

/**
 * Home-screen adhkar widget. Mirrors the dashboard's Azkar card:
 *  - theme (light/dark) and UI language (en/ar/ur + RTL) follow the app via
 *    `widget_theme` / `widget_lang` preferences pushed from Flutter;
 *  - all text is rendered with the Tajawal font as bitmaps (RemoteViews cannot
 *    style text reliably), same pipeline as the prayer times widget;
 *  - on the Friday Kahf window it shows a "Read Surat Al-Kahf" button that
 *    opens the mushaf; any other tap opens the in-app azkar share sheet.
 */
class DhikrWidgetProvider : AppWidgetProvider() {

    companion object {
        private const val LIGHT_TITLE = 0xFF00674F.toInt()
        private const val LIGHT_TEXT = 0xFF1A1A1A.toInt()

        private const val DARK_TITLE = 0xFF4CAF9F.toInt()
        private const val DARK_TEXT = 0xFFE8E8E0.toInt()

        // Accents matching the dashboard Azkar card.
        private const val ACCENT_MORNING = 0xFFF59E0B.toInt()
        private const val ACCENT_EVENING = 0xFF818CF8.toInt()
        private const val ACCENT_GENERAL = 0xFF14B8A6.toInt()
        private const val ACCENT_KAHF_LIGHT = 0xFF008A6A.toInt()
        private const val ACCENT_KAHF_DARK = 0xFF2BA482.toInt()
    }

    private data class TextSizes(
        val titleSp: Float,
        val bodySp: Float,
        val smallSp: Float,
        val kahfSp: Float,
        val bodyMaxLines: Int,
        val translationMaxLines: Int,
    )

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

    private fun updateWidget(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        prefs: SharedPreferences,
        options: Bundle?
    ) {
        val width = options?.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH) ?: 0
        val height = options?.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT) ?: 0
        val isCompact = width < 200
        // 4×2 and larger: scale type up so the dhikr uses the extra room.
        val isLarge = width >= 250 && height >= 100
        val layoutId = if (isCompact) R.layout.dhikr_widget_compact else R.layout.dhikr_widget
        val sizes = when {
            isCompact -> TextSizes(
                titleSp = 12f, bodySp = 11f, smallSp = 9f, kahfSp = 12f,
                bodyMaxLines = 4, translationMaxLines = 2,
            )
            isLarge -> TextSizes(
                titleSp = 18f, bodySp = 17f, smallSp = 13f, kahfSp = 17f,
                bodyMaxLines = 7, translationMaxLines = 3,
            )
            else -> TextSizes(
                titleSp = 16f, bodySp = 14f, smallSp = 11f, kahfSp = 14f,
                bodyMaxLines = 6, translationMaxLines = 3,
            )
        }
        val views = RemoteViews(context.packageName, layoutId)
        val lang = resolveLang(context, prefs)
        val isDark = resolveDark(context, prefs)
        val contentWidthPx = (
            (width - (if (isCompact) 16 else 28)) *
                context.resources.displayMetrics.density
            ).toInt().coerceAtLeast(1)

        try {
            applyChrome(views, isDark)
            applyDirection(views, lang)
            applyContent(context, views, prefs, sizes, isDark, lang, contentWidthPx)
            applyClicks(context, views)
            appWidgetManager.updateAppWidget(appWidgetId, views)
        } catch (t: Throwable) {
            android.util.Log.e("DhikrWidget", "update failed", t)
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

    /** Single-line Tajawal text → bitmap (same pipeline as the prayer times widget). */
    private fun textBitmap(
        context: Context,
        text: String,
        typeface: Typeface?,
        sizeSp: Float,
        color: Int
    ): Bitmap {
        val metrics = context.resources.displayMetrics
        val textSizePx = sizeSp * metrics.scaledDensity
        val ss = 4f
        val outScale = 2f

        val hiPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            this.typeface = typeface ?: Typeface.DEFAULT
            textSize = textSizePx * ss
            setColor(color)
            textAlign = Paint.Align.CENTER
            isSubpixelText = true
        }

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

    /** Multi-line wrapped Tajawal text → bitmap, centered, ellipsized at [maxLines]. */
    private fun wrappedTextBitmap(
        context: Context,
        text: String,
        typeface: Typeface?,
        sizeSp: Float,
        color: Int,
        maxWidthPx: Int,
        maxLines: Int
    ): Bitmap {
        val metrics = context.resources.displayMetrics
        val textSizePx = sizeSp * metrics.scaledDensity
        val ss = 4f
        val outScale = 2f
        val widthHi = (maxWidthPx * ss).toInt().coerceAtLeast(1)

        val paint = TextPaint(Paint.ANTI_ALIAS_FLAG).apply {
            this.typeface = typeface ?: Typeface.DEFAULT
            textSize = textSizePx * ss
            setColor(color)
            isSubpixelText = true
        }

        val layout = StaticLayout.Builder
            .obtain(text, 0, text.length, paint, widthHi)
            .setAlignment(Layout.Alignment.ALIGN_CENTER)
            .setLineSpacing(0f, 1.15f)
            // Arabic diacritics / Quranic marks sit above the font ascent —
            // without padding (or with includePad=false) they clip at the top.
            .setIncludePad(true)
            .setMaxLines(maxLines)
            .setEllipsize(TextUtils.TruncateAt.END)
            .build()

        // Extra room above the ascent for stacked harakat that still exceed
        // fontMetrics.ascent on some Tajawal glyphs.
        val extraTop = ceil(textSizePx * 0.2f).toInt().coerceAtLeast(1)
        val extraBottom = ceil(textSizePx * 0.1f).toInt().coerceAtLeast(1)
        val hiH = layout.height + extraTop + extraBottom
        val hi = Bitmap.createBitmap(widthHi, hiH, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(hi)
        canvas.save()
        canvas.translate(0f, extraTop.toFloat())
        layout.draw(canvas)
        canvas.restore()

        val outW = ((widthHi / ss) * outScale).toInt().coerceAtLeast(1)
        val outH = ((hiH / ss) * outScale).toInt().coerceAtLeast(1)
        val out = Bitmap.createScaledBitmap(hi, outW, outH, true)
        if (out !== hi) hi.recycle()
        out.density = (metrics.densityDpi * outScale).toInt()
        return out
    }

    /** Rounded pill containing single-line text — used for the period + reference chips. */
    private fun chipBitmap(
        context: Context,
        text: String,
        typeface: Typeface?,
        sizeSp: Float,
        textColor: Int,
        chipColor: Int
    ): Bitmap {
        val metrics = context.resources.displayMetrics
        val textSizePx = sizeSp * metrics.scaledDensity
        val ss = 4f
        val outScale = 2f
        val padH = 8f * metrics.density * ss
        val padV = 4f * metrics.density * ss
        val radius = 999f * metrics.density * ss

        val textPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            this.typeface = typeface ?: Typeface.DEFAULT
            textSize = textSizePx * ss
            setColor(textColor)
            textAlign = Paint.Align.CENTER
            isSubpixelText = true
        }

        val bounds = Rect()
        textPaint.getTextBounds(text, 0, text.length, bounds)
        val hiW = (bounds.width() + padH * 2).toInt().coerceAtLeast(1)
        val hiH = (bounds.height() + padV * 2).toInt().coerceAtLeast(1)
        val hi = Bitmap.createBitmap(hiW, hiH, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(hi)
        val bgPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = chipColor }
        canvas.drawRoundRect(0f, 0f, hiW.toFloat(), hiH.toFloat(), radius, radius, bgPaint)
        canvas.drawText(
            text,
            hiW / 2f,
            hiH / 2f - (bounds.top + bounds.bottom) / 2f,
            textPaint
        )

        val outW = ((hiW / ss) * outScale).toInt().coerceAtLeast(1)
        val outH = ((hiH / ss) * outScale).toInt().coerceAtLeast(1)
        val out = Bitmap.createScaledBitmap(hi, outW, outH, true)
        if (out !== hi) hi.recycle()
        out.density = (metrics.densityDpi * outScale).toInt()
        return out
    }

    private fun alpha(color: Int, a: Float): Int {
        val alpha = ((color ushr 24) * a).toInt().coerceIn(0, 255)
        return (color and 0x00FFFFFF) or (alpha shl 24)
    }

    private fun accentFor(type: String?, isDark: Boolean): Int = when (type) {
        "morning" -> ACCENT_MORNING
        "evening" -> ACCENT_EVENING
        "kahf" -> if (isDark) ACCENT_KAHF_DARK else ACCENT_KAHF_LIGHT
        else -> ACCENT_GENERAL
    }

    private fun titleFallbackId(type: String?): Int = when (type) {
        "morning" -> R.string.dhikr_title_morning
        "evening" -> R.string.dhikr_title_evening
        "kahf" -> R.string.dhikr_title_kahf
        "general" -> R.string.dhikr_title_general
        else -> R.string.dhikr_widget_title
    }

    private fun applyChrome(views: RemoteViews, isDark: Boolean) {
        val bg = if (isDark) R.drawable.widget_bg_night else R.drawable.widget_bg_day
        views.setInt(R.id.widget_root, "setBackgroundResource", bg)
    }

    private fun applyDirection(views: RemoteViews, lang: String) {
        val direction =
            if (lang == "ar" || lang == "ur") View.LAYOUT_DIRECTION_RTL
            else View.LAYOUT_DIRECTION_LTR
        views.setInt(R.id.widget_root, "setLayoutDirection", direction)
        views.setInt(R.id.title_row, "setLayoutDirection", direction)
        // Horizontal row: pack children toward the layout-direction start so
        // the title sits on the right under RTL (matching the dashboard card).
        val rowGravity =
            if (lang == "ar" || lang == "ur") {
                android.view.Gravity.END or android.view.Gravity.CENTER_VERTICAL
            } else {
                android.view.Gravity.START or android.view.Gravity.CENTER_VERTICAL
            }
        views.setInt(R.id.title_row, "setGravity", rowGravity)
    }

    private fun applyContent(
        context: Context,
        views: RemoteViews,
        prefs: SharedPreferences,
        sizes: TextSizes,
        isDark: Boolean,
        lang: String,
        contentWidthPx: Int
    ) {
        loadTypefaces(context)

        val type = prefs.getString("dhikr_type", null)
        val isKahf = type == "kahf"
        val accent = accentFor(type, isDark)
        val bodyColor = if (isDark) DARK_TEXT else LIGHT_TEXT
        val titleColor = if (isDark) DARK_TITLE else LIGHT_TITLE

        // Title (wrap-content at the layout-direction start; flips under RTL).
        val title = prefs.getString("dhikr_title", null)
            ?: context.getString(titleFallbackId(type))
        views.setImageViewBitmap(
            R.id.widget_title,
            textBitmap(context, title, boldTypeface, sizes.titleSp, titleColor)
        )

        // Period pill — accent-tinted chip like the dashboard's _PeriodPill.
        val period = prefs.getString("dhikr_period", null) ?: defaultPeriod(context, type)
        if (period.isNullOrEmpty()) {
            views.setViewVisibility(R.id.period_text, View.GONE)
        } else {
            views.setViewVisibility(R.id.period_text, View.VISIBLE)
            views.setImageViewBitmap(
                R.id.period_text,
                chipBitmap(
                    context, period, mediumTypeface, sizes.smallSp,
                    accent, alpha(accent, 0.14f)
                )
            )
        }

        if (isKahf) {
            views.setViewVisibility(R.id.dhikr_text, View.GONE)
            views.setViewVisibility(R.id.translation_text, View.GONE)
            views.setViewVisibility(R.id.ref_text, View.GONE)
            views.setViewVisibility(R.id.kahf_container, View.VISIBLE)
            val kahfLabel = prefs.getString("dhikr_kahf_label", null)
                ?: context.getString(R.string.dhikr_read_kahf)
            views.setImageViewBitmap(
                R.id.kahf_label,
                textBitmap(context, kahfLabel, boldTypeface, sizes.kahfSp, 0xFFFFFFFF.toInt())
            )
            return
        }

        views.setViewVisibility(R.id.kahf_container, View.GONE)

        val text = prefs.getString("dhikr_text", null)
            ?: "بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ"
        if (text.isBlank()) {
            views.setViewVisibility(R.id.dhikr_text, View.GONE)
        } else {
            views.setViewVisibility(R.id.dhikr_text, View.VISIBLE)
            // Arabic dhikr is always RTL-rendered text; ALIGN_CENTER + bidi handles it.
            views.setImageViewBitmap(
                R.id.dhikr_text,
                wrappedTextBitmap(
                    context, text, mediumTypeface, sizes.bodySp, bodyColor,
                    contentWidthPx, sizes.bodyMaxLines
                )
            )
        }

        val translation = prefs.getString("dhikr_translation", null) ?: ""
        if (translation.isBlank()) {
            views.setViewVisibility(R.id.translation_text, View.GONE)
        } else {
            views.setViewVisibility(R.id.translation_text, View.VISIBLE)
            views.setImageViewBitmap(
                R.id.translation_text,
                wrappedTextBitmap(
                    context, translation, mediumTypeface, sizes.smallSp,
                    alpha(bodyColor, 0.65f),
                    contentWidthPx, sizes.translationMaxLines
                )
            )
        }

        val reference = prefs.getString("dhikr_reference", null) ?: ""
        if (reference.isBlank()) {
            views.setViewVisibility(R.id.ref_text, View.GONE)
        } else {
            views.setViewVisibility(R.id.ref_text, View.VISIBLE)
            views.setImageViewBitmap(
                R.id.ref_text,
                chipBitmap(
                    context, reference, mediumTypeface, sizes.smallSp,
                    accent, alpha(accent, 0.14f)
                )
            )
        }
    }

    private fun defaultPeriod(context: Context, type: String?): String? = when (type) {
        "morning" -> "05:00–12:00"
        "evening" -> "20:00–01:00"
        "kahf" -> context.getString(R.string.dhikr_period_friday)
        "general" -> context.getString(R.string.dhikr_period_always)
        else -> null
    }

    private fun applyClicks(context: Context, views: RemoteViews) {
        // Single URI for the whole widget: Flutter recomputes the current state
        // and opens either the azkar share sheet or Surat Al-Kahf in the mushaf.
        val clickIntent = Intent(context, MainActivity::class.java).apply {
            action = HomeWidgetLaunchIntent.HOME_WIDGET_LAUNCH_ACTION
            data = Uri.parse("bayan://share/dhikr")
        }
        val clickPendingIntent = PendingIntent.getActivity(
            context, 2, clickIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        views.setOnClickPendingIntent(R.id.widget_root, clickPendingIntent)
        views.setOnClickPendingIntent(R.id.title_row, clickPendingIntent)
        views.setOnClickPendingIntent(R.id.dhikr_text, clickPendingIntent)
        views.setOnClickPendingIntent(R.id.kahf_container, clickPendingIntent)
    }
}
