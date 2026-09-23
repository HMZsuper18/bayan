package com.hamzah.bayan

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.content.res.ColorStateList
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.Rect
import android.graphics.Typeface
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.view.View
import android.widget.RemoteViews
import androidx.core.content.res.ResourcesCompat
import es.antonborri.home_widget.HomeWidgetLaunchIntent

/// Home screen reciters widget.
///
/// * List mode shows up to 16 **downloaded** reciters (slots pushed by the
///   Flutter side; empty slots stay blank), ranked most-listened / most
///   famous first. Scales 2x1 → 4x4 showing more reciters as it grows.
///   When nothing is downloaded it shows a tappable "Download reciter" chip
///   that opens the reciters store in the app.
/// * Player mode shows a playbar (progress + pause/continue, cancel)
///   whenever a reciter is playing — from the app or from this widget.
/// * All text is rendered with the Tajawal font as bitmaps, like the prayer
///   times widget. Follows the app's dark/light theme, language and RTL.
class RecitationsWidgetProvider : AppWidgetProvider() {

    companion object {
        private const val MAX_SLOTS = 16
        private const val LIGHT_TITLE = 0xFF00674F.toInt()
        private const val LIGHT_TEXT = 0xFF1A1A1A.toInt()
        private const val LIGHT_ICON = 0xFF00674F.toInt()
        private const val DARK_TITLE = 0xFF4CAF9F.toInt()
        private const val DARK_TEXT = 0xFFE8E8E0.toInt()
        private const val DARK_ICON = 0xFF4CAF9F.toInt()
        private const val PLAY_REQUEST_BASE = 70
        private const val REQUEST_TOGGLE = 270
        private const val REQUEST_CANCEL = 272
        private const val REQUEST_STORE = 273

        /// Total byte budget for reciter-name bitmaps so a 16-name 4x4
        /// widget stays safely under the ~1MB binder transaction limit.
        private const val NAME_BUDGET_BYTES = 750_000
        private const val DEBUG_W = "debug_w"
        private const val DEBUG_H = "debug_h"
    }

    private data class SlotIds(val row: Int, val name: Int, val play: Int)

    private data class Sizes(
        val titleSp: Float,
        val nameSp: Float,
        val playerNameSp: Float,
        val playerSurahSp: Float,
        val labelSp: Float,
        /// Progress bar height in dp; 0 keeps the layout's XML height.
        val progressDp: Float = 0f,
    )

    private fun idsFor(i: Int): SlotIds = when (i) {
        1 -> SlotIds(R.id.reciter_1_row, R.id.reciter_1_name, R.id.play_reciter_1)
        2 -> SlotIds(R.id.reciter_2_row, R.id.reciter_2_name, R.id.play_reciter_2)
        3 -> SlotIds(R.id.reciter_3_row, R.id.reciter_3_name, R.id.play_reciter_3)
        4 -> SlotIds(R.id.reciter_4_row, R.id.reciter_4_name, R.id.play_reciter_4)
        5 -> SlotIds(R.id.reciter_5_row, R.id.reciter_5_name, R.id.play_reciter_5)
        6 -> SlotIds(R.id.reciter_6_row, R.id.reciter_6_name, R.id.play_reciter_6)
        7 -> SlotIds(R.id.reciter_7_row, R.id.reciter_7_name, R.id.play_reciter_7)
        8 -> SlotIds(R.id.reciter_8_row, R.id.reciter_8_name, R.id.play_reciter_8)
        9 -> SlotIds(R.id.reciter_9_row, R.id.reciter_9_name, R.id.play_reciter_9)
        10 -> SlotIds(R.id.reciter_10_row, R.id.reciter_10_name, R.id.play_reciter_10)
        11 -> SlotIds(R.id.reciter_11_row, R.id.reciter_11_name, R.id.play_reciter_11)
        12 -> SlotIds(R.id.reciter_12_row, R.id.reciter_12_name, R.id.play_reciter_12)
        13 -> SlotIds(R.id.reciter_13_row, R.id.reciter_13_name, R.id.play_reciter_13)
        14 -> SlotIds(R.id.reciter_14_row, R.id.reciter_14_name, R.id.play_reciter_14)
        15 -> SlotIds(R.id.reciter_15_row, R.id.reciter_15_name, R.id.play_reciter_15)
        else -> SlotIds(R.id.reciter_16_row, R.id.reciter_16_name, R.id.play_reciter_16)
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

    /// QA helper: render the widget with forced option dimensions so each
    /// size tier (2x1/2x2/4x2/4x4) can be verified without resizing the
    /// widget in the launcher. Real updates always pass through onUpdate.
    /// Extra `refresh_real=true` redraws with the launcher's real options.
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.getBooleanExtra("refresh_real", false)) {
            val mgr = AppWidgetManager.getInstance(context)
            onUpdate(
                context, mgr,
                mgr.getAppWidgetIds(ComponentName(context, RecitationsWidgetProvider::class.java))
            )
            return
        }
        val tw = intent.getIntExtra(DEBUG_W, -1)
        val th = intent.getIntExtra(DEBUG_H, -1)
        if (tw >= 0 && th >= 0) {
            val mgr = AppWidgetManager.getInstance(context)
            val ids = mgr.getAppWidgetIds(
                ComponentName(context, RecitationsWidgetProvider::class.java)
            )
            val opts = Bundle().apply {
                putInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, tw)
                putInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, th)
            }
            for (id in ids) updateWidget(context, mgr, id, prefs(context), opts)
            return
        }
        super.onReceive(context, intent)
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

    private data class LayoutChoice(
        val layoutId: Int,
        val sizes: Sizes,
        val maxSlots: Int,
        val player: Boolean,
        val compactPlayer: Boolean,
        val showTitle: Boolean = true,
        /// 2x1 player: the top bar shows only the surah name (header style)
        /// instead of the widget title, and there is no surah line in the chip.
        val playerHeaderSurah: Boolean = false,
    )

    // Launcher cell ≈ 148x141dp (measured: options report
    // 2x1≈(296,141) 2x2≈(296,283) 4x2≈(592,283) 4x4≈(592,566)).
    // Midpoint buckets: 2-col < 440 <= 4-col; 1-row < 210 <= 2-row
    // < 425 <= 4-row.
    private fun selectLayout(width: Int, height: Int, player: Boolean): LayoutChoice {
        val wide = width >= 440
        val shortH = height < 210
        val midH = height < 425

        if (player) {
            return when {
                // Ultra-short strips / 1-wide columns keep the icon-only bar.
                height in 1..84 || width < 240 -> LayoutChoice(
                    R.layout.recitations_widget_player_compact,
                    Sizes(titleSp = 11f, nameSp = 10f, playerNameSp = 10f, playerSurahSp = 8f, labelSp = 7f),
                    maxSlots = 0, player = true, compactPlayer = true,
                )
                // 2x1: surah in the top bar (header style), reciter + visible
                // progress bar in the chip.
                !wide && shortH -> LayoutChoice(
                    R.layout.recitations_widget_player_2x1,
                    Sizes(titleSp = 14f, nameSp = 12f, playerNameSp = 13f, playerSurahSp = 9f, labelSp = 8f),
                    maxSlots = 0, player = true, compactPlayer = false,
                    playerHeaderSurah = true,
                )
                // 4x2: smaller reciter name, surah smaller than the reciter,
                // thicker progress bar (was 8dp — "too thin").
                wide && midH -> LayoutChoice(
                    R.layout.recitations_widget_player,
                    Sizes(titleSp = 16f, nameSp = 13f, playerNameSp = 13f, playerSurahSp = 9f, labelSp = 10f, progressDp = 12f),
                    maxSlots = 0, player = true, compactPlayer = false,
                )
                // 4x4 (and other wide/tall).
                wide -> LayoutChoice(
                    R.layout.recitations_widget_player,
                    Sizes(titleSp = 17f, nameSp = 13f, playerNameSp = 16f, playerSurahSp = 12f, labelSp = 10f),
                    maxSlots = 0, player = true, compactPlayer = false,
                )
                // 2x2: keep the reciter prominent, shrink the surah line.
                midH -> LayoutChoice(
                    R.layout.recitations_widget_player,
                    Sizes(titleSp = 15f, nameSp = 13f, playerNameSp = 14f, playerSurahSp = 9f, labelSp = 9f),
                    maxSlots = 0, player = true, compactPlayer = false,
                )
                // 2x4 and other leftovers.
                else -> LayoutChoice(
                    R.layout.recitations_widget_player,
                    Sizes(titleSp = 17f, nameSp = 13f, playerNameSp = 16f, playerSurahSp = 12f, labelSp = 10f),
                    maxSlots = 0, player = true, compactPlayer = false,
                )
            }
        }
        return when {
            // Short/narrow: hide the title so reciter chips sit at the very
            // top of the widget ("higher" in 2x1).
            height in 1..90 -> LayoutChoice(
                R.layout.recitations_widget_banner,
                Sizes(titleSp = 11f, nameSp = 10f, playerNameSp = 10f, playerSurahSp = 8f, labelSp = 7f),
                maxSlots = 2, player = false, compactPlayer = false, showTitle = false,
            )
            width < 240 -> LayoutChoice(
                R.layout.recitations_widget_compact,
                Sizes(titleSp = 12f, nameSp = 11f, playerNameSp = 11f, playerSurahSp = 9f, labelSp = 8f),
                maxSlots = 4, player = false, compactPlayer = false, showTitle = false,
            )
            // 4x2 (and 4x1): 6 chips as a 3x2 grid, smaller names.
            wide && midH -> LayoutChoice(
                R.layout.recitations_widget_4x2,
                Sizes(titleSp = 16f, nameSp = 11f, playerNameSp = 16f, playerSurahSp = 12f, labelSp = 10f),
                maxSlots = 6, player = false, compactPlayer = false,
            )
            // 4x4: just 4 chips as a 2x2 grid — big cells, bigger names.
            wide -> LayoutChoice(
                R.layout.recitations_widget_4x4,
                Sizes(titleSp = 17f, nameSp = 15f, playerNameSp = 16f, playerSurahSp = 12f, labelSp = 10f),
                maxSlots = 4, player = false, compactPlayer = false,
            )
            // 2x1: one full-height row, 2 chips side by side (the old
            // 2-column x 4-row default crushed row 1 and cropped names).
            shortH -> LayoutChoice(
                R.layout.recitations_widget_2x1,
                Sizes(titleSp = 14f, nameSp = 12f, playerNameSp = 14f, playerSurahSp = 11f, labelSp = 9f),
                maxSlots = 2, player = false, compactPlayer = false,
            )
            // 2x2 keeps the default 2-column x 4-row list (8 slots).
            midH -> LayoutChoice(
                R.layout.recitations_widget,
                Sizes(titleSp = 15f, nameSp = 13f, playerNameSp = 14f, playerSurahSp = 11f, labelSp = 9f),
                maxSlots = 8, player = false, compactPlayer = false,
            )
            // 2x4 and other leftovers.
            else -> LayoutChoice(
                R.layout.recitations_widget_large,
                Sizes(titleSp = 17f, nameSp = 13f, playerNameSp = 16f, playerSurahSp = 12f, labelSp = 10f),
                maxSlots = 16, player = false, compactPlayer = false,
            )
        }
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
        val active = prefs.getBoolean("widget_player_active", false)
        val (layoutId, sizes, maxSlots, player, compactPlayer, showTitle, playerHeaderSurah) =
            selectLayout(width, height, active)
        android.util.Log.d(
            "RecitationsWidget",
            "options w=$width h=$height player=$active layout=${context.resources.getResourceEntryName(layoutId)} bundle=$options"
        )
        try {
            val sizeList = options?.get("appWidgetSizes")
            android.util.Log.d("RecitationsWidget", "sizes=$sizeList")
        } catch (t: Throwable) {
            android.util.Log.d("RecitationsWidget", "sizes expand failed: $t")
        }

        val views = RemoteViews(context.packageName, layoutId)
        val isDark = resolveDark(context, prefs)
        val lang = resolveLang(context, prefs)

        try {
            applyDirection(views, lang)
            if (player) {
                applyPlayer(context, views, prefs, sizes, isDark, lang, compactPlayer, playerHeaderSurah)
            } else {
                if (!showTitle) {
                    views.setViewVisibility(R.id.title_row, View.GONE)
                }
                applyList(context, views, prefs, sizes, isDark, lang, maxSlots, showTitle)
            }
            appWidgetManager.updateAppWidget(appWidgetId, views)
        } catch (t: Throwable) {
            android.util.Log.e("RecitationsWidget", "update failed", t)
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

    // ---- Tajawal bitmap text rendering (same pipeline as the prayer widget) ----

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

    /// Renders [text] with Tajawal. By default the bitmap is ARGB at 2×
    /// density (same as the prayer times widget). When [opaqueBg] is set the
    /// bitmap is RGB_565 drawn on that exact chip color at 1× density — used
    /// for the (potentially long) reciter names so a 4x4 widget with 16 names
    /// stays well under the binder transaction limit.
    private fun textBitmap(
        context: Context,
        text: String,
        typeface: Typeface?,
        sizeSp: Float,
        color: Int,
        outScale: Float = 2f,
        opaqueBg: Int? = null,
    ): Bitmap {
        val metrics = context.resources.displayMetrics
        val textSizePx = sizeSp * metrics.scaledDensity
        // Final bitmap at outScale× logical px; density is set to match so the
        // ImageView intrinsic size stays in dp while the drawable renders
        // sharper than 1×.
        val ss = 4f

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
        val hiType = if (opaqueBg != null) Bitmap.Config.RGB_565 else Bitmap.Config.ARGB_8888
        val hi = Bitmap.createBitmap(hiW, hiH, hiType)
        val hiCanvas = Canvas(hi)
        if (opaqueBg != null) hiCanvas.drawColor(opaqueBg)
        hiCanvas.drawText(
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

    private fun applyDirection(views: RemoteViews, lang: String) {
        if (Build.VERSION.SDK_INT >= 23) {
            val direction =
                if (lang == "ar" || lang == "ur") View.LAYOUT_DIRECTION_RTL
                else View.LAYOUT_DIRECTION_LTR
            views.setInt(R.id.widget_root, "setLayoutDirection", direction)
        }
    }

    private fun applyTitle(
        context: Context,
        views: RemoteViews,
        prefs: SharedPreferences,
        sizes: Sizes,
        isDark: Boolean
    ) {
        loadTypefaces(context)
        views.setInt(R.id.title_row, "setGravity", android.view.Gravity.START or android.view.Gravity.CENTER_VERTICAL)
        val titleColor = if (isDark) DARK_TITLE else LIGHT_TITLE
        val title = prefs.getString("reciters_widget_title", null)
            ?: context.getString(R.string.recitations_widget_title)
        views.setImageViewBitmap(
            R.id.widget_title,
            textBitmap(context, title, boldTypeface, sizes.titleSp, titleColor)
        )
    }

    // ---- List mode ----

    private fun applyList(
        context: Context,
        views: RemoteViews,
        prefs: SharedPreferences,
        sizes: Sizes,
        isDark: Boolean,
        lang: String,
        maxSlots: Int,
        showTitle: Boolean,
    ) {
        loadTypefaces(context)
        if (showTitle) applyTitle(context, views, prefs, sizes, isDark)

        val available = prefs.getInt("reciter_count", 0).coerceIn(0, maxSlots)
        val nameColor = if (isDark) DARK_TEXT else LIGHT_TEXT
        val iconColor = if (isDark) DARK_ICON else LIGHT_ICON
        val chipBg = if (isDark) R.drawable.chip_bg_night else R.drawable.chip_bg_day
        val chipColor = if (isDark) 0xFF1A3A2A.toInt() else 0xFFE8F5F0.toInt()

        var anyVisible = false
        var nameBytes = 0
        for (i in 1..maxSlots) {
            val ids = idsFor(i)
            val name = prefs.getString("reciter_${i}_name", null)
            val id = prefs.getString("reciter_${i}_id", null)
            // A slot is shown only when the Flutter side pushed a downloaded
            // reciter into it; otherwise it stays blank.
            val visible = i <= available && !name.isNullOrEmpty() && !id.isNullOrEmpty()
            views.setViewVisibility(ids.row, if (visible) View.VISIBLE else View.GONE)
            if (visible) {
                anyVisible = true
                // Crisp 2x text, degrading only if the byte budget would be
                // exceeded (large widgets with 16 long names).
                var scale = 2f
                var bmp = textBitmap(
                    context, name, mediumTypeface, sizes.nameSp, nameColor,
                    outScale = scale, opaqueBg = chipColor,
                )
                while (scale > 1f && nameBytes + bmp.byteCount > NAME_BUDGET_BYTES) {
                    bmp.recycle()
                    scale = if (scale > 1.5f) 1.5f else 1f
                    bmp = textBitmap(
                        context, name, mediumTypeface, sizes.nameSp, nameColor,
                        outScale = scale, opaqueBg = chipColor,
                    )
                }
                nameBytes += bmp.byteCount
                views.setImageViewBitmap(ids.name, bmp)
                views.setInt(ids.row, "setBackgroundResource", chipBg)
                if (Build.VERSION.SDK_INT >= 29) {
                    views.setColorStateList(
                        ids.play,
                        "setImageTintList",
                        ColorStateList.valueOf(iconColor)
                    )
                }
                applyPlayClick(context, views, ids, id, i)
            }
        }
        android.util.Log.d("RecitationsWidget", "name bitmap bytes=$nameBytes")

        // Nothing downloaded: replace the blank area with a tappable
        // "Download reciter" chip that opens the reciters store.
        if (!anyVisible) {
            views.setViewVisibility(R.id.rows_container, View.GONE)
            views.setViewVisibility(R.id.empty_state, View.VISIBLE)
            views.setInt(R.id.empty_state, "setBackgroundResource", chipBg)
            val emptyLabel = prefs.getString("reciters_empty_label", null)
                ?: context.getString(R.string.recitations_download_reciter)
            views.setImageViewBitmap(
                R.id.empty_state_text,
                textBitmap(
                    context, emptyLabel, boldTypeface, sizes.titleSp, nameColor,
                )
            )
            applyStoreClick(context, views)
        } else {
            views.setViewVisibility(R.id.rows_container, View.VISIBLE)
            views.setViewVisibility(R.id.empty_state, View.GONE)
        }

        views.setInt(R.id.widget_root, "setBackgroundResource",
            if (isDark) R.drawable.widget_bg_night else R.drawable.widget_bg_day)
    }

    /// Opens the reciters store in the foreground (the user needs the UI
    /// to pick a reciter — no background-play extra on this intent).
    private fun applyStoreClick(context: Context, views: RemoteViews) {
        val intent = Intent(context, MainActivity::class.java).apply {
            action = HomeWidgetLaunchIntent.HOME_WIDGET_LAUNCH_ACTION
            data = Uri.parse("bayan://store")
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        val pending = PendingIntent.getActivity(
            context,
            REQUEST_STORE,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        views.setOnClickPendingIntent(R.id.empty_state, pending)
        views.setOnClickPendingIntent(R.id.empty_state_text, pending)
        android.util.Log.d("RecitationsWidget", "store click wired")
    }

    private fun applyPlayClick(
        context: Context,
        views: RemoteViews,
        ids: SlotIds,
        reciterId: String,
        index: Int
    ) {
        // Broadcast (not Activity) so playback starts without any window
        // appearing — no flash, works even on a cold process via the
        // headless cached engine. Whole row is tappable (not just the
        // 28dp ▸ icon) — a tiny target reads as "needs many taps".
        val playIntent = Intent(context, WidgetControlsReceiver::class.java).apply {
            data = Uri.parse("bayan://play/$reciterId")
        }
        val pending = PendingIntent.getBroadcast(
            context,
            PLAY_REQUEST_BASE + index,
            playIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        views.setOnClickPendingIntent(ids.play, pending)
        views.setOnClickPendingIntent(ids.row, pending)
        views.setOnClickPendingIntent(ids.name, pending)
    }

    // ---- Player (playbar) mode ----

    private fun applyPlayer(
        context: Context,
        views: RemoteViews,
        prefs: SharedPreferences,
        sizes: Sizes,
        isDark: Boolean,
        lang: String,
        compact: Boolean,
        headerSurah: Boolean = false,
    ) {
        loadTypefaces(context)
        val nameColor = if (isDark) DARK_TEXT else LIGHT_TEXT
        val iconColor = if (isDark) DARK_ICON else LIGHT_ICON
        val titleColor = if (isDark) DARK_TITLE else LIGHT_TITLE
        val paused = prefs.getBoolean("widget_player_paused", false)

        views.setInt(R.id.widget_root, "setBackgroundResource",
            if (isDark) R.drawable.widget_bg_night else R.drawable.widget_bg_day)
        views.setInt(R.id.player_chip, "setBackgroundResource",
            if (isDark) R.drawable.chip_bg_night else R.drawable.chip_bg_day)

        val surah = prefs.getString("widget_player_surah", null)
        if (headerSurah) {
            // 2x1: top bar carries only the surah name, styled like the
            // header (bold, title color, START gravity).
            if (!surah.isNullOrEmpty()) {
                views.setInt(R.id.title_row, "setGravity",
                    android.view.Gravity.START or android.view.Gravity.CENTER_VERTICAL)
                views.setImageViewBitmap(
                    R.id.widget_title,
                    textBitmap(context, surah, boldTypeface, sizes.titleSp, titleColor)
                )
            } else {
                applyTitle(context, views, prefs, sizes, isDark)
            }
        } else if (!compact) {
            applyTitle(context, views, prefs, sizes, isDark)
        }

        val playerName = prefs.getString("widget_player_name", null)
        if (!playerName.isNullOrEmpty()) {
            val chipColor = if (isDark) 0xFF1A3A2A.toInt() else 0xFFE8F5F0.toInt()
            views.setViewVisibility(R.id.player_name, View.VISIBLE)
            views.setImageViewBitmap(
                R.id.player_name,
                textBitmap(
                    context, playerName, boldTypeface, sizes.playerNameSp, nameColor,
                    outScale = 2f, opaqueBg = chipColor,
                )
            )
        } else {
            views.setViewVisibility(R.id.player_name, View.GONE)
        }

        if (!headerSurah) {
            if (!surah.isNullOrEmpty()) {
                views.setViewVisibility(R.id.player_surah, View.VISIBLE)
                views.setImageViewBitmap(
                    R.id.player_surah,
                    textBitmap(context, surah, mediumTypeface, sizes.playerSurahSp, nameColor)
                )
            } else {
                views.setViewVisibility(R.id.player_surah, View.GONE)
            }
        }

        val progress = prefs.getInt("widget_player_progress", 0).coerceIn(0, 100)
        views.setInt(R.id.player_progress, "setProgress", progress)
        if (sizes.progressDp > 0f && Build.VERSION.SDK_INT >= 31) {
            try {
                views.setViewLayoutHeight(
                    R.id.player_progress,
                    sizes.progressDp * context.resources.displayMetrics.density,
                    android.util.TypedValue.COMPLEX_UNIT_PX,
                )
            } catch (t: Throwable) {
                android.util.Log.w("RecitationsWidget", "progress height failed", t)
            }
        }

        views.setImageViewResource(
            R.id.player_toggle,
            if (paused) R.drawable.ic_widget_play else R.drawable.ic_widget_pause
        )

        if (!compact) {
            val toggleLabel = prefs.getString("widget_player_toggle_label", null)
                ?: context.getString(if (paused) R.string.recitations_resume else R.string.recitations_pause)
            val cancelLabel = prefs.getString("widget_player_cancel_label", null)
                ?: context.getString(R.string.recitations_cancel)
            views.setImageViewBitmap(
                R.id.player_toggle_label,
                textBitmap(context, toggleLabel, mediumTypeface, sizes.labelSp, nameColor)
            )
            views.setImageViewBitmap(
                R.id.player_cancel_label,
                textBitmap(context, cancelLabel, mediumTypeface, sizes.labelSp, nameColor)
            )
        }

        if (Build.VERSION.SDK_INT >= 29) {
            for (btn in intArrayOf(R.id.player_toggle, R.id.player_cancel)) {
                views.setColorStateList(btn, "setImageTintList", ColorStateList.valueOf(iconColor))
            }
        }

        applyControlClick(context, views, R.id.player_toggle, "bayan://widget/toggle", REQUEST_TOGGLE)
        applyControlClick(context, views, R.id.player_cancel, "bayan://widget/cancel", REQUEST_CANCEL)
    }

    private fun applyControlClick(
        context: Context,
        views: RemoteViews,
        viewId: Int,
        uri: String,
        requestCode: Int
    ) {
        // Broadcast keeps the app in the background — pausing/resuming/
        // cancelling never brings a window to the front.
        val intent = Intent(context, WidgetControlsReceiver::class.java).apply {
            data = Uri.parse(uri)
        }
        val pending = PendingIntent.getBroadcast(
            context,
            requestCode,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        views.setOnClickPendingIntent(viewId, pending)
    }
}
