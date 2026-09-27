package com.hamzah.bayan

import android.content.Context
import android.content.res.AssetManager
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.LinearGradient
import android.graphics.Paint
import android.graphics.Path
import android.graphics.PorterDuff
import android.graphics.PorterDuffColorFilter
import android.graphics.RadialGradient
import android.graphics.RectF
import android.graphics.Shader
import android.os.SystemClock
import android.service.wallpaper.WallpaperService
import android.view.SurfaceHolder
import kotlin.math.*
import kotlin.random.Random

/**
 * Realistic day/night seascape live wallpaper.
 *
 * A calm sea below a horizon line, with:
 * - Multi-stop sky gradients blended between prayer-time anchored palettes
 *   (dawn → morning → day → golden hour → sunset → dusk → night)
 * - Volumetric cumulus clouds: multi-octave Perlin/Worley density raymarched
 *   with Beer-Lambert extinction and Henyey-Greenstein scattering, shipped as
 *   pre-rendered sprites (ours0..ours8) in 3 parallax layers that cross-fade
 *   between two silhouettes; mirrored on the water
 * - Sun and moon riding the same clockwise arc: rise at the LEFT horizon, peak
 *   top of the sky, set at the RIGHT; the moon's shape and its rising time
 *   follow the real Hijri phase (Umm al-Qura)
 * - Horizon haze and a rippled sun-glitter path down the water
 * - Star field on a rotating celestial sphere (4x Earth rate), fading at dusk
 * - Sea reflection columns under the sun/moon with shimmering spread
 * - Perspective wave lines drifting near the surface
 *
 * Time anchors come from real prayer times (synced from Flutter into
 * SharedPreferences). Runs at ~20fps, pauses when not visible.
 */
/** Sun/moon geometry. Both bodies ride the same clockwise half-ellipse, and the
 *  arc dips a full radius below the horizon at both ends, so the body grows out
 *  of / sinks into the sea instead of popping. [k]/[waxing] describe the moon's
 *  illumination (unused for the sun). */
private data class Body(
    val kind: String, val p: Float, val x: Float, val y: Float,
    val r: Float, val vis: Float, val occ: Float, val elevN: Float,
    val k: Float = 1f, val waxing: Boolean = true,
)

class IslamicLiveWallpaperService : WallpaperService() {

    /** One point on the celestial sphere (unit vector) + its appearance. */
    data class Star(
        val ux: Float, val uy: Float, val uz: Float, val size: Float,
        val twinkleSpeed: Float, val phase: Float, val tint: Float,
    )

    /** Pre-rendered cumulus art for one cloud (silhouette + top-lit copy). */
    private class CloudArt(val full: Bitmap, val lit: Bitmap)

    /** One cloud: placement, parallax layer and its two morphable sprites. */
    private data class Cloud(
        val baseX: Float,
        val yFrac: Float,
        val speed: Float,
        val size: Float,
        val aspect: Float,
        val art: CloudArt,
        val art2: CloudArt,
        val depth: Int,
        val alpha: Float,
        val haze: Float,
        val morph: Float,
        val morphPh: Float,
        val bob: Float,
    )

    /** Illumination of the moon for the current Hijri day. */
    private data class MoonPhase(
        val phase: Float,
        val k: Float,
        val waxing: Boolean,
        val lagH: Float,
        val monthLen: Int,
    )

    /** Full color set of one time-of-day keyframe. */
    private data class Pal(
        val skyTop: Int,
        val skyMid: Int,
        val skyLow: Int,
        val seaFar: Int,
        val seaNear: Int,
        val cloud: Int,
        val cloudShade: Int,
    )

    override fun onCreateEngine(): Engine {
        return IslamicEngine()
    }

    inner class IslamicEngine : Engine() {

        private var visible = false
        private var surfaceAvailable = false
        private var renderThread: RenderThread? = null

        override fun onVisibilityChanged(isVisible: Boolean) {
            visible = isVisible
            if (isVisible) {
                if (surfaceAvailable && renderThread == null) {
                    renderThread = RenderThread().also { it.start() }
                }
            } else {
                renderThread?.running = false
                renderThread = null
            }
        }

        override fun onSurfaceCreated(holder: SurfaceHolder) {
            super.onSurfaceCreated(holder)
            surfaceAvailable = true
            if (visible && renderThread == null) {
                renderThread = RenderThread().also { it.start() }
            }
        }

        override fun onSurfaceDestroyed(holder: SurfaceHolder) {
            super.onSurfaceDestroyed(holder)
            surfaceAvailable = false
            renderThread?.running = false
            renderThread = null
        }

        inner class RenderThread : Thread() {
            @Volatile var running = true
            private val frameInterval = 50L // ~20fps

            // Prayer times from SharedPreferences
            private var fajrHour = 5; private var fajrMinute = 0
            private var sunriseHour = 6; private var sunriseMinute = 0
            private var dhuhrHour = 12; private var dhuhrMinute = 0
            private var asrHour = 15; private var asrMinute = 0
            private var maghribHour = 18; private var maghribMinute = 0
            private var ishaHour = 19; private var ishaMinute = 0

            private var fajrFrac = 5f / 24f
            private var sunriseFrac = 6f / 24f
            private var dhuhrFrac = 12f / 24f
            private var asrFrac = 15f / 24f
            private var maghribFrac = 18f / 24f
            private var ishaFrac = 19f / 24f

            // Dead-sky margin: the sinking body must be fully under the sea
            // before the other one starts to emerge (~7 min each side at dusk).
            private val bodyGap = 0.005f

            // Today's Hijri date — drives the moon's phase and rising time.
            private var hijriDay = 15
            private var hijriMonthLen = 30

            private val stars = mutableListOf<Star>()
            private val clouds = mutableListOf<Cloud>()

            // Cached paints (allocated once)
            private val paint = Paint(Paint.ANTI_ALIAS_FLAG)
            private val starPaint = Paint(Paint.ANTI_ALIAS_FLAG)
            private val glintPaint = Paint()
            private val bodyPaint = Paint(Paint.ANTI_ALIAS_FLAG)
            private val glowPaint = Paint(Paint.ANTI_ALIAS_FLAG)
            private val corePaint = Paint(Paint.ANTI_ALIAS_FLAG)
            private val reflPaint = Paint(Paint.ANTI_ALIAS_FLAG)
            private val wavePaint = Paint(Paint.ANTI_ALIAS_FLAG)
            private val cloudPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { isFilterBitmap = true }
            private val rect = RectF()
            private val hazeRect = RectF()
            private val path = Path()

            // Cached shaders / palette state
            private var anchors: List<Pair<Float, Pal>> = emptyList()
            private var skyShader: Shader? = null
            private var seaShader: Shader? = null
            private var bandShader: Shader? = null
            private var hazeShader: Shader? = null
            private var shaderKey = ""
            private var glowKey = ""
            private var frameCount = 0
            private var assetW = 0
            private var assetH = 0

            // Cached tint filters. Cloud colours vary per cloud (haze) and per
            // frame (backlight), so they are memoised by colour value.
            private var reflectTint = PorterDuffColorFilter(Color.WHITE, PorterDuff.Mode.SRC_IN)
            private val tintCache = HashMap<Int, PorterDuffColorFilter>()

            private fun tintOf(color: Int): PorterDuffColorFilter =
                tintCache.getOrPut(color) { PorterDuffColorFilter(color, PorterDuff.Mode.SRC_IN) }

            private val horizon: Float get() = lastH * HORIZON_FRAC
            private var lastW = 0f
            private var lastH = 0f

            // ------------------------------------------------------------ time

            private fun frac(h: Int, m: Int) = (h * 60f + m) / 1440f

            private fun loadPrayerTimes() {
                val prefs = this@IslamicLiveWallpaperService.getSharedPreferences("bayan_prefs", Context.MODE_PRIVATE)
                fajrHour = prefs.getInt("prayer_fajr_hour", 5)
                fajrMinute = prefs.getInt("prayer_fajr_minute", 0)
                sunriseHour = prefs.getInt("prayer_sunrise_hour", 6)
                sunriseMinute = prefs.getInt("prayer_sunrise_minute", 0)
                dhuhrHour = prefs.getInt("prayer_dhuhr_hour", 12)
                dhuhrMinute = prefs.getInt("prayer_dhuhr_minute", 0)
                asrHour = prefs.getInt("prayer_asr_hour", 15)
                asrMinute = prefs.getInt("prayer_asr_minute", 0)
                maghribHour = prefs.getInt("prayer_maghrib_hour", 18)
                maghribMinute = prefs.getInt("prayer_maghrib_minute", 0)
                ishaHour = prefs.getInt("prayer_isha_hour", 19)
                ishaMinute = prefs.getInt("prayer_isha_minute", 0)

                fajrFrac = frac(fajrHour, fajrMinute)
                sunriseFrac = frac(sunriseHour, sunriseMinute)
                dhuhrFrac = frac(dhuhrHour, dhuhrMinute)
                asrFrac = frac(asrHour, asrMinute)
                maghribFrac = frac(maghribHour, maghribMinute)
                ishaFrac = frac(ishaHour, ishaMinute)
                buildAnchors()
                refreshHijri()
            }

            /** Today's Hijri date from the bundled Umm al-Qura table. */
            private fun refreshHijri() {
                val c = java.util.Calendar.getInstance()
                val (y, m, d) = HijriCalendar.fromGregorian(
                    c.get(java.util.Calendar.YEAR),
                    c.get(java.util.Calendar.MONTH) + 1,
                    c.get(java.util.Calendar.DAY_OF_MONTH),
                )
                hijriDay = d
                hijriMonthLen = HijriCalendar.daysInMonth(y, m)
            }

            /** Illumination of the moon for the current Hijri day. */
            private fun moonPhase(tod: Float): MoonPhase {
                // Phase is fixed per civil day: adding `tod` would step the
                // terminator a full synodic fraction at the midnight wrap and
                // make the 24h cycle jump.
                val age = (hijriDay - 1).toFloat()          // days since new moon
                val phase = (((age / SYNODIC) % 1f) + 1f) % 1f
                return MoonPhase(
                    phase = phase,
                    k = (1f - cos(phase * 2f * PI.toFloat())) * 0.5f,
                    waxing = phase < 0.5f,
                    lagH = phase * 24f,                   // hours behind the sun
                    monthLen = hijriMonthLen,
                )
            }

            private fun buildAnchors() {
                // Keep ascending order; guard against odd user settings.
                val raw = listOf(
                    fajrFrac to DAWN,
                    (sunriseFrac - 0.017f).coerceAtLeast(fajrFrac) to SUNRISE,
                    (sunriseFrac + 0.083f) to DAY,
                    asrFrac to AFTERNOON,
                    (maghribFrac - 0.050f).coerceAtLeast(asrFrac) to GOLDEN,
                    (maghribFrac + 0.006f) to SUNSET,
                    (maghribFrac + 0.052f) to DUSK,
                    (ishaFrac + 0.045f) to NIGHT,
                )
                anchors = raw.sortedBy { it.first }
            }

            private fun getTimeOfDayFraction(): Float {
                val now = java.util.Calendar.getInstance()
                val hour = now.get(java.util.Calendar.HOUR_OF_DAY)
                val minute = now.get(java.util.Calendar.MINUTE)
                val second = now.get(java.util.Calendar.SECOND)
                return (hour * 3600f + minute * 60f + second) / 86400f
            }

            /** Interpolated palette for [tod] (0..1, wraps at midnight). */
            private fun paletteAt(tod: Float): Pal {
                val a = anchors
                if (a.isEmpty()) return NIGHT
                var i = -1
                for (k in a.indices) if (tod >= a[k].first) i = k
                val f0: Float
                val f1: Float
                val p0: Pal
                val p1: Pal
                when {
                    i == -1 -> { // between midnight and first anchor → wrap from last
                        f0 = a.last().first - 1f
                        f1 = a.first().first
                        p0 = a.last().second
                        p1 = a.first().second
                    }
                    i == a.lastIndex -> { // past last anchor → wrap to first
                        f0 = a.last().first
                        f1 = a.first().first + 1f
                        p0 = a.last().second
                        p1 = a.first().second
                    }
                    else -> {
                        f0 = a[i].first
                        f1 = a[i + 1].first
                        p0 = a[i].second
                        p1 = a[i + 1].second
                    }
                }
                val t = ((tod - f0) / (f1 - f0).coerceAtLeast(1e-5f)).coerceIn(0f, 1f)
                return lerpPal(p0, p1, smooth01(t))
            }

            private fun smooth01(x: Float): Float {
                val t = x.coerceIn(0f, 1f)
                return t * t * (3f - 2f * t)
            }

            private fun lerpC(a: Int, b: Int, t: Float): Int {
                val ia = Color.alpha(a); val ib = Color.alpha(b)
                val ar = Color.red(a); val br = Color.red(b)
                val ag = Color.green(a); val bg = Color.green(b)
                val ab = Color.blue(a); val bb = Color.blue(b)
                return Color.argb(
                    (ia + (ib - ia) * t).toInt(),
                    (ar + (br - ar) * t).toInt(),
                    (ag + (bg - ag) * t).toInt(),
                    (ab + (bb - ab) * t).toInt(),
                )
            }

            private fun lerpPal(a: Pal, b: Pal, t: Float) = Pal(
                lerpC(a.skyTop, b.skyTop, t),
                lerpC(a.skyMid, b.skyMid, t),
                lerpC(a.skyLow, b.skyLow, t),
                lerpC(a.seaFar, b.seaFar, t),
                lerpC(a.seaNear, b.seaNear, t),
                lerpC(a.cloud, b.cloud, t),
                lerpC(a.cloudShade, b.cloudShade, t),
            )

            /** 0 at deep night, 1 at solar noon. */
            private fun dayLight(tod: Float): Float {
                if (tod <= sunriseFrac || tod >= maghribFrac) return 0f
                val p = (tod - sunriseFrac) / (maghribFrac - sunriseFrac).coerceAtLeast(1e-4f)
                return sin(p * PI).toFloat().coerceIn(0f, 1f)
            }

            /** Star visibility: 0 in day, 1 at night, smooth fades at edges. */
            private fun starFade(tod: Float): Float {
                val d = when {
                    tod in sunriseFrac..maghribFrac -> 0f
                    tod > maghribFrac -> (tod - maghribFrac).coerceAtMost(0.05f) / 0.05f
                    else -> (sunriseFrac - tod).coerceAtMost(0.05f) / 0.05f
                }
                return smooth01(d)
            }

            /** 0..1 warmth right around sunrise / sunset (glow & band). */
            private fun warmFactor(tod: Float): Float {
                val d = minOf(kotlin.math.abs(tod - sunriseFrac), kotlin.math.abs(tod - maghribFrac))
                return smooth01(1f - (d / 0.055f).coerceIn(0f, 1f))
            }

            // ------------------------------------------------------------ init

            override fun run() {
                loadPrayerTimes()
                val holder = this@IslamicEngine.surfaceHolder
                var initialized = false

                while (running) {
                    if (!surfaceAvailable) {
                        sleep(frameInterval)
                        continue
                    }
                    if (++frameCount % 600 == 0) loadPrayerTimes() // refresh prefs ~every 30s

                    val canvas: Canvas? = try {
                        holder.lockCanvas()
                    } catch (e: Exception) {
                        sleep(frameInterval)
                        continue
                    }

                    if (canvas == null) {
                        sleep(frameInterval)
                        continue
                    }

                    try {
                        if (initialized &&
                            (canvas.width != assetW || canvas.height != assetH)
                        ) {
                            initialized = false // surface resized/rotated → rebuild assets
                        }
                        if (!initialized && canvas.width > 0 && canvas.height > 0) {
                            initAssets(canvas.width, canvas.height)
                            initialized = true
                        }
                        drawFrame(canvas)
                    } catch (e: Exception) {
                        // Skip broken frame
                    } finally {
                        try {
                            holder.unlockCanvasAndPost(canvas)
                        } catch (e: Exception) {
                            // Ignore
                        }
                    }

                    sleep(frameInterval)
                }
            }

            private fun initAssets(w: Int, h: Int) {
                assetW = w
                assetH = h
                // Deterministic starfield: uniform points on the celestial sphere
                val rand = Random(42)
                stars.clear()
                repeat(STAR_COUNT) {
                    val z = rand.nextFloat() * 2f - 1f
                    val a = rand.nextFloat() * 2f * PI.toFloat()
                    val rr = sqrt(max(0f, 1f - z * z))
                    stars.add(
                        Star(
                            ux = rr * cos(a),
                            uy = rr * sin(a),
                            uz = z,
                            size = 0.8f + rand.nextFloat() * 2.2f,
                            twinkleSpeed = 0.3f + rand.nextFloat() * 2f,
                            phase = rand.nextFloat() * 360f,
                            tint = rand.nextFloat(),
                        )
                    )
                }

                // Cumulus sprites: 3 parallax layers, two silhouettes each so the
                // shapes can cross-fade as they drift.
                clouds.clear()
                val randC = Random(77)
                repeat(CLOUD_COUNT) { i ->
                    val layer = i * LAYER_SPEED.size / CLOUD_COUNT
                    val hReq = (SPRITE_H * (0.70f + randC.nextFloat() * 0.60f)).toInt()
                    // Pre-rendered volumetric sprites (ours0..ours8): decode
                    // only. buildCloudArt is the fallback if an asset is absent.
                    val artA = loadCloudArt(assets, i, 0) ?: buildCloudArt(1000 + i, hReq)
                    val artB = loadCloudArt(assets, i, 1) ?: buildCloudArt(3000 + i, hReq)
                    clouds.add(
                        Cloud(
                            baseX = randC.nextFloat(),
                            yFrac = -0.07f + randC.nextFloat() * 0.46f,
                            speed = (0.0026f + randC.nextFloat() * 0.0044f) *
                                CLOUD_SPEED_MULT * LAYER_SPEED[layer],
                            size = (0.34f + randC.nextFloat() * 0.90f) * LAYER_SIZE[layer],
                            aspect = artA.full.height.toFloat() / SPRITE_H,
                            art = artA,
                            art2 = artB,
                            depth = layer,
                            alpha = LAYER_ALPHA[layer],
                            haze = LAYER_HAZE[layer],
                            morph = 0.045f + randC.nextFloat() * 0.045f,
                            morphPh = randC.nextFloat() * TWO_PI,
                            bob = randC.nextFloat() * TWO_PI,
                        )
                    )
                }
            }

            // ------------------------------------------------------------ draw

            private fun ensureShaders(tod: Float, pal: Pal) {
                val w = lastW
                val h = lastH
                if (w <= 0 || h <= 0) return
                val key = "${(tod * 4000f).toInt()}|${w.toInt()}|${h.toInt()}|${anchors.size}" +
                    "|${pal.skyTop}|${pal.seaNear}"
                if (key == shaderKey) return
                shaderKey = key
                tintCache.clear() // palette moved: memoised cloud tints are stale

                val hz = horizon
                skyShader = LinearGradient(
                    0f, 0f, 0f, hz,
                    intArrayOf(pal.skyTop, pal.skyMid, pal.skyLow),
                    floatArrayOf(0f, 0.5f, 1f),
                    Shader.TileMode.CLAMP,
                )
                val seaMid = lerpC(pal.seaFar, pal.seaNear, 0.45f)
                seaShader = LinearGradient(
                    0f, hz, 0f, h,
                    intArrayOf(pal.seaFar, seaMid, pal.seaNear),
                    floatArrayOf(0f, 0.45f, 1f),
                    Shader.TileMode.CLAMP,
                )
                val warm = warmFactor(tod)
                bandShader = if (warm > 0.01f) {
                    val glow = lerpC(pal.skyLow, Color.rgb(255, 196, 150), 0.65f)
                    LinearGradient(
                        0f, hz - h * 0.14f, 0f, hz,
                        intArrayOf(Color.TRANSPARENT, lerpC(Color.TRANSPARENT, glow, warm)),
                        floatArrayOf(0f, 1f),
                        Shader.TileMode.CLAMP,
                    )
                } else null

                // Soft haze that hides the sky/sea seam
                val hazeH = h * 0.045f
                val hazeTop = hz - hazeH * 0.55f
                val hazeAlpha = (70 + 90 * warm + 40 * dayLight(tod)).toInt().coerceIn(0, 255)
                val hazeCol = lerpC(pal.skyLow, Color.WHITE, 0.35f + 0.35f * warm)
                hazeShader = LinearGradient(
                    0f, hazeTop, 0f, hazeTop + hazeH,
                    intArrayOf(
                        Color.TRANSPARENT,
                        lerpC(Color.TRANSPARENT, hazeCol, hazeAlpha / 255f * 0.71f),
                        lerpC(Color.TRANSPARENT, hazeCol, hazeAlpha / 255f),
                        lerpC(Color.TRANSPARENT, hazeCol, hazeAlpha / 255f * 0.71f),
                        Color.TRANSPARENT,
                    ),
                    floatArrayOf(0f, 0.25f, 0.5f, 0.75f, 1f),
                    Shader.TileMode.CLAMP,
                )
                hazeRect.set(0f, hazeTop, w, hazeTop + hazeH)

                // Cloud reflection tint follows the palette; per-cloud tints are
                // memoised on demand by tintOf().
                reflectTint = PorterDuffColorFilter(
                    lerpC(pal.cloud, pal.seaFar, 0.72f), PorterDuff.Mode.SRC_IN
                )
            }

            private fun drawFrame(canvas: Canvas) {
                val w = canvas.width.toFloat()
                val h = canvas.height.toFloat()
                if (w <= 0 || h <= 0) return
                lastW = w; lastH = h

                // Animation clock: monotonic seconds. Wall-clock time has ~1e3s
                // magnitude, which a Float cannot resolve (motions would freeze).
                val anim = SystemClock.uptimeMillis() / 1000.0
                val tod = getTimeOfDayFraction()
                val pal = paletteAt(tod)
                val hz = horizon
                ensureShaders(tod, pal)

                // 1. Sky
                skyShader?.let {
                    paint.shader = it
                    canvas.drawRect(0f, 0f, w, hz, paint)
                    paint.shader = null
                }

                // 2. Warm band hugging the horizon at dawn/dusk
                bandShader?.let {
                    paint.shader = it
                    canvas.drawRect(0f, hz - h * 0.14f, w, hz, paint)
                    paint.shader = null
                }

                // 3. Stars (rotating celestial sphere, fading in after sunset)
                drawStars(canvas, w, hz, tod, anim)

                // 4. Sun by day, moon by night — always above the horizon
                val dl = dayLight(tod)
                if (dl > 0f) drawSun(canvas, w, hz, tod, pal)
                else drawMoon(canvas, w, hz, tod)

                // 5. Clouds (3 parallax layers drifting across the sky)
                drawClouds(canvas, w, hz, tod, anim, pal)

                // 6. Sea
                seaShader?.let {
                    paint.shader = it
                    canvas.drawRect(0f, hz, w, h, paint)
                    paint.shader = null
                }

                // 7. Horizon haze (softens the sky/sea seam)
                hazeShader?.let {
                    paint.shader = it
                    canvas.drawRect(hazeRect, paint)
                    paint.shader = null
                }

                // 8. Sun glitter path / moon path
                if (dl > 0f) drawSunReflection(canvas, w, hz, h, tod, anim, pal)
                else drawMoonReflection(canvas, w, hz, h, tod, anim)

                // 9. Mirrored cloud smears + 10. ripple lines
                drawCloudReflections(canvas, w, hz, h, anim, dl, pal)
                drawWaves(canvas, w, hz, h, anim, dl, pal)
            }

            /** Night sky on a rotating celestial sphere (stars wheel past us). */
            private fun drawStars(canvas: Canvas, w: Float, hz: Float, tod: Float, anim: Double) {
                val fade = starFade(tod)
                if (fade <= 0.01f) return
                val scale = 1.15f * w
                val px = w * 0.5f
                val py = hz * 0.52f
                // 4 Earth turns a day → 60°/hour, and it wraps seamlessly at midnight
                val theta = TWO_PI_D * STAR_SPEED_MULT * tod
                val ct = cos(theta).toFloat()
                val st = sin(theta).toFloat()
                val nx = STAR_POLE[0]; val ny = STAR_POLE[1]; val nz = STAR_POLE[2]
                glintPaint.strokeWidth = 1f
                for (star in stars) {
                    // Rodrigues rotation about the pole, then orthographic projection
                    val dot = nx * star.ux + ny * star.uy + nz * star.uz
                    val cx = ny * star.uz - nz * star.uy
                    val cy = nz * star.ux - nx * star.uz
                    val cz = nx * star.uy - ny * star.ux
                    val vx = star.ux * ct + cx * st + nx * dot * (1f - ct)
                    val vy = star.uy * ct + cy * st + ny * dot * (1f - ct)
                    val vz = star.uz * ct + cz * st + nz * dot * (1f - ct)
                    if (vz <= 0.02f) continue                 // behind the viewer
                    val x = px + vx * scale
                    val y = py + vy * scale
                    if (x < -40f || x > w + 40f || y < -40f || y > hz - 4f) continue
                    val tw = (sin(anim * star.twinkleSpeed + star.phase) + 1.0) * 0.5
                    val a = ((70.0 + tw * 170.0) * fade * min(1.0, vz * 1.6))
                        .toInt().coerceIn(0, 255)
                    if (a <= 0) continue
                    val r = star.size * (0.7f + 0.3f * tw.toFloat()) +
                        (if (star.size > 2.2f) 0.8f else 0f)
                    val cr = (255 - 35 * star.tint).toInt()
                    val cg = (252 - 20 * star.tint).toInt()
                    val cb = (238 + 17 * star.tint).toInt()
                    starPaint.color = Color.argb(a, cr, cg, cb)
                    canvas.drawCircle(x, y, r, starPaint)
                    if (star.size > 2.6f) {                    // diffraction glint
                        val g = max(1f, r * 1.9f)
                        val gl = (a * 0.45f).toInt().coerceIn(0, 255)
                        glintPaint.color = Color.argb(gl, cr, cg, cb)
                        canvas.drawLine(x - g, y, x + g, y, glintPaint)
                        canvas.drawLine(x, y - g, x, y + g, glintPaint)
                    }
                }
            }

            private fun withAlpha(color: Int, alpha: Int) = Color.argb(
                alpha.coerceIn(0, 255),
                Color.red(color), Color.green(color), Color.blue(color),
            )

            /** Sun and moon geometry.
             *
             *  Both bodies trace the same clockwise half-ellipse: they rise at the
             *  LEFT horizon, climb to the top of the sky and sink at the RIGHT.
             *  Each arc only lives inside its own window, and the windows are
             *  separated by a dead-sky gap, so the outgoing body is always fully
             *  under the sea before the other one emerges. */
            private fun bodyState(tod: Float, w: Float, hz: Float): Body {
                val mp = moonPhase(tod)
                if (dayLight(tod) > 0f) {
                    // sun lives in [sunrise, maghrib - bodyGap]; afterwards p clamps
                    // to 1 and the disc sits exactly at/below the horizon (vis = 0)
                    val p = ((tod - sunriseFrac) /
                        (maghribFrac - bodyGap - sunriseFrac).coerceAtLeast(1e-4f))
                        .coerceIn(0f, 1f)
                    return mkBody("sun", p, w, hz, w * 0.052f, 0.52f, mp)
                }
                // Moon is above the horizon for 12h centred on `lag` hours after
                // sunset (lag = phase * 24h), clamped to the safe night
                // [maghrib + bodyGap, fajr] so it can never clash with the sun.
                val safe0 = bodyGap * 24f
                val nightH = ((1f + fajrFrac) - (maghribFrac + bodyGap)) * 24f
                val a0 = min(max(mp.lagH - 12f, safe0), nightH)
                val a1 = min(max(mp.lagH, safe0), nightH)
                val cur = (if (tod >= maghribFrac) tod - (maghribFrac + bodyGap)
                    else tod + 1f - (maghribFrac + bodyGap)) * 24f
                val p = if ((a1 - a0) < 1e-3f) 0f
                    else ((cur - a0) / (a1 - a0)).coerceIn(0f, 1f)
                return mkBody("moon", p, w, hz, w * 0.046f, 0.46f, mp)
            }

            private fun mkBody(
                kind: String, p: Float, w: Float, hz: Float, r: Float,
                arc: Float, mp: MoonPhase,
            ): Body {
                val x = w * (0.16f + 0.68f * p)       // clockwise: left → right
                val elevN = sin(p.coerceIn(0f, 1f) * PI).toFloat()
                val y = hz + r - elevN * (hz * arc + r)
                val emerge = hz + r - y
                return Body(
                    kind, p, x, y, r,
                    vis = smooth01(emerge / (r * 0.30f)),
                    occ = (emerge / (r * 0.50f)).coerceIn(0f, 1f),
                    elevN = elevN,
                    k = if (kind == "sun") 1f else mp.k,
                    waxing = kind == "sun" || mp.waxing,
                )
            }

            /** Sun climbing the clockwise arc from the left horizon to the right. */
            private fun drawSun(canvas: Canvas, w: Float, hz: Float, tod: Float, pal: Pal) {
                val b = bodyState(tod, w, hz)
                val v = b.vis
                if (v <= 0.005f) return
                val x = b.x
                val y = b.y
                val r = b.r
                val cool = 1f - warmFactor(tod)

                val halo = lerpC(Color.rgb(255, 240, 205), Color.rgb(255, 255, 252), cool)
                val core = lerpC(Color.rgb(255, 216, 152), Color.rgb(250, 253, 250), cool)
                val a0 = ((215 + (95 - 215) * cool) * v)
                val a1 = ((150 + (45 - 150) * cool) * v)
                val a2 = ((70 + (12 - 70) * cool) * v)

                val key = "sun|${(x / 6f).toInt()}|${(y / 6f).toInt()}|${(warmFactor(tod) * 24f).toInt()}|${r.toInt()}|${(v * 40f).toInt()}"
                if (key != glowKey) {
                    glowKey = key
                    glowPaint.shader = RadialGradient(
                        x, y, r * 6f,
                        intArrayOf(
                            withAlpha(halo, a0.toInt()),
                            withAlpha(halo, a1.toInt()),
                            withAlpha(halo, a2.toInt()),
                            Color.TRANSPARENT,
                        ),
                        floatArrayOf(0f, 0.30f, 0.62f, 1f),
                        Shader.TileMode.CLAMP,
                    )
                    corePaint.shader = RadialGradient(
                        x, y, r * 2.1f,
                        intArrayOf(
                            withAlpha(core, (255 * v).toInt()),
                            withAlpha(core, (235 * v).toInt()),
                            withAlpha(core, (150 * v).toInt()),
                            Color.TRANSPARENT,
                        ),
                        floatArrayOf(0f, 0.30f, 0.62f, 1f),
                        Shader.TileMode.CLAMP,
                    )
                }
                canvas.drawCircle(x, y, r * 6f, glowPaint)
                canvas.drawCircle(x, y, r * 2.1f, corePaint)
                bodyPaint.color = lerpC(Color.rgb(255, 247, 220), Color.rgb(255, 255, 253), cool)
                bodyPaint.alpha = (255 * v).toInt().coerceIn(0, 255)
                canvas.drawCircle(x, y, r, bodyPaint)
                bodyPaint.alpha = 255
            }

            /** Moon riding the night arc, drawn with its real phase. */
            private fun drawMoon(canvas: Canvas, w: Float, hz: Float, tod: Float) {
                val b = bodyState(tod, w, hz)
                val v = b.vis
                if (v <= 0.005f) return
                val x = b.x
                val y = b.y
                val r = b.r
                val kg = 0.25f + 0.75f * b.k            // halo fades with the light

                val key = "moon|${(x / 6f).toInt()}|${(y / 6f).toInt()}|${r.toInt()}|" +
                    "${(v * 40f).toInt()}|${(b.k * 40f).toInt()}"
                if (key != glowKey) {
                    glowKey = key
                    glowPaint.shader = RadialGradient(
                        x, y, r * 5.5f,
                        intArrayOf(
                            Color.argb((120 * v * kg).toInt(), 196, 210, 244),
                            Color.argb((55 * v * kg).toInt(), 196, 210, 244),
                            Color.argb((18 * v * kg).toInt(), 196, 210, 244),
                            Color.TRANSPARENT,
                        ),
                        floatArrayOf(0f, 0.30f, 0.62f, 1f),
                        Shader.TileMode.CLAMP,
                    )
                    corePaint.shader = RadialGradient(
                        x, y, r * 1.9f,
                        intArrayOf(
                            Color.argb((255 * v * kg).toInt(), 238, 242, 252),
                            Color.argb((230 * v * kg).toInt(), 238, 242, 252),
                            Color.argb((120 * v * kg).toInt(), 238, 242, 252),
                            Color.TRANSPARENT,
                        ),
                        floatArrayOf(0f, 0.30f, 0.62f, 1f),
                        Shader.TileMode.CLAMP,
                    )
                }
                canvas.drawCircle(x, y, r * 5.5f, glowPaint)
                canvas.drawCircle(x, y, r * 1.9f, corePaint)
                drawMoonPhase(canvas, x, y, r, b.k, b.waxing, v)
            }

            /**
             * Phase-accurate disc: the dark hemisphere plus a terminator ellipse.
             * The lit half faces right while waxing and left while waning; before
             * half light the ellipse carves a crescent out of it, after it the
             * ellipse bulges the light past the centre line (gibbous).
             */
            private fun drawMoonPhase(
                canvas: Canvas, x: Float, y: Float, r: Float,
                k: Float, waxing: Boolean, vis: Float,
            ) {
                val rx = abs(1f - 2f * k)               // terminator semi-minor axis
                val disc = RectF(x - r, y - r, x + r, y + r)
                val ell = RectF(x - rx * r, y - r, x + rx * r, y + r)

                // unlit part of the disc
                bodyPaint.color = Color.rgb(26, 30, 46)
                bodyPaint.alpha = ((0.10f + 0.12f * k) * 255f * vis).toInt().coerceIn(0, 255)
                canvas.drawCircle(x, y, r, bodyPaint)

                // lit part: clip to the lit hemisphere, widened by the terminator
                // ellipse once the moon is more than half full.
                bodyPaint.color = Color.rgb(240, 240, 232)
                bodyPaint.alpha = ((0.55f + 0.45f * k) * 255f * vis).toInt().coerceIn(0, 255)
                canvas.save()
                path.rewind()
                path.fillType = Path.FillType.WINDING
                if (waxing) path.addArc(disc, -90f, 180f) else path.addArc(disc, 90f, 180f)
                path.close()
                if (k >= 0.5f) path.addOval(ell, Path.Direction.CW)
                canvas.clipPath(path)

                path.rewind()
                if (k >= 0.5f) {
                    path.fillType = Path.FillType.WINDING
                    path.addCircle(x, y, r, Path.Direction.CW)
                } else {
                    path.fillType = Path.FillType.EVEN_ODD
                    path.addCircle(x, y, r, Path.Direction.CW)
                    path.addOval(ell, Path.Direction.CW)
                }
                canvas.drawPath(path, bodyPaint)
                canvas.restore()
                bodyPaint.alpha = 255
                path.rewind()
                path.fillType = Path.FillType.WINDING
            }

            /** Clouds: 3 parallax layers of cross-fading sprites, with a shaded
             *  belly and a cap lit from the side the sun/moon sits on. */
            private fun drawClouds(
                canvas: Canvas, w: Float, hz: Float, tod: Float, anim: Double, pal: Pal
            ) {
                val warm = warmFactor(tod)
                val bodyX = bodyState(tod, w, hz).x
                for (ci in clouds.indices) {
                    val c = clouds[ci]
                    val spW = c.art.full.width.toFloat()
                    val spH = c.art.full.height.toFloat()
                    val m = (0.5 + 0.5 * sin(anim * TWO_PI_D * c.morph + c.morphPh)).toFloat()
                    val cloudW = w * 0.58f * c.size
                    val cloudH = cloudW * (spH / spW)
                    val x = ((((c.baseX + anim * c.speed) % 1.5) - 0.25) * w).toFloat()
                    val cy = (hz * (0.14f + c.yFrac) +
                        sin(anim * 0.11 + c.bob) * hz * 0.006).toFloat()
                    if (cy + cloudH * 0.5f > hz - 10f) continue

                    rect.set(x - cloudW / 2f, cy - cloudH / 2f, x + cloudW / 2f, cy + cloudH / 2f)
                    // silver lining: warm rim when a low sun/moon sits behind it
                    val backlit = warm * smooth01(1f - abs(x - bodyX) / (w * 0.38f))
                    val bl = (backlit * 16f).toInt() / 16f     // memoised by colour
                    val shade = tintOf(lerpC(pal.cloudShade, pal.skyLow, c.haze))
                    val lit = tintOf(lerpC(pal.cloud, Color.rgb(255, 236, 202), bl * 0.85f))
                    val aBase = 245f * c.alpha
                    val aLit = min(255f, 255f * c.alpha * (1f + 0.45f * bl))

                    // the baked-in light ramp always points right; mirror the pair
                    // when the body is on the left instead of storing both.
                    canvas.save()
                    if (bodyX < x) {
                        val mx = (rect.left + rect.right) * 0.5f
                        canvas.translate(2f * mx, 0f)
                        canvas.scale(-1f, 1f)
                    }
                    when {
                        m < 0.04f -> drawCloudPair(canvas, c.art, rect, shade, lit, aBase, aLit, 1f)
                        m > 0.96f -> drawCloudPair(canvas, c.art2, rect, shade, lit, aBase, aLit, 1f)
                        else -> {
                            drawCloudPair(canvas, c.art, rect, shade, lit, aBase, aLit, 1f - m)
                            drawCloudPair(canvas, c.art2, rect, shade, lit, aBase, aLit, m)
                        }
                    }
                    canvas.restore()
                }
            }

            private fun drawCloudPair(
                canvas: Canvas, art: CloudArt, box: RectF,
                shade: PorterDuffColorFilter, lit: PorterDuffColorFilter,
                aBase: Float, aLit: Float, wgt: Float,
            ) {
                if (wgt <= 0.02f) return
                cloudPaint.colorFilter = shade
                cloudPaint.alpha = (aBase * wgt).toInt().coerceIn(0, 255)
                canvas.drawBitmap(art.full, null, box, cloudPaint)
                cloudPaint.colorFilter = lit
                cloudPaint.alpha = (aLit * wgt).toInt().coerceIn(0, 255)
                canvas.drawBitmap(art.lit, null, box, cloudPaint)
            }

            private fun drawSunReflection(
                canvas: Canvas, w: Float, hz: Float, h: Float, tod: Float, anim: Double, pal: Pal
            ) {
                val b = bodyState(tod, w, hz)
                if (b.occ <= 0f) return
                val warm = warmFactor(tod)
                val maxAlpha = (150 + 70 * warm).toInt()
                val col = lerpC(Color.rgb(255, 251, 240), Color.rgb(255, 240, 202), warm)
                drawReflectionColumn(canvas, b.x, hz, h, b.r, anim, maxAlpha, col,
                    b.elevN, b.occ, 7.3f)
            }

            private fun drawMoonReflection(
                canvas: Canvas, w: Float, hz: Float, h: Float, tod: Float, anim: Double
            ) {
                val b = bodyState(tod, w, hz)
                if (b.occ <= 0f) return
                drawReflectionColumn(canvas, b.x, hz, h, b.r, anim, 115,
                    Color.rgb(230, 236, 250), b.elevN, b.occ, 11.9f)
            }

            /** Glitter path: short patch at the peak, long low path near the horizon. */
            private fun drawReflectionColumn(
                canvas: Canvas, cx: Float, hz: Float, h: Float, bodyR: Float,
                anim: Double, maxAlpha: Int, color: Int, elevN: Float, occ: Float, seed: Float
            ) {
                val timeSec = anim
                val seaH = h - hz
                if (seaH <= 0f) return
                val peak = maxAlpha * (1.30f - 0.78f * elevN) * occ
                if (peak < 5f) return
                val steps = 150
                val spanY = seaH * (0.66f - 0.44f * elevN)
                val stepPx = spanY / (steps - 1)
                val cr = Color.red(color); val cg = Color.green(color); val cb = Color.blue(color)
                for (i in 0 until steps) {
                    val t = i / (steps - 1f)
                    val y = hz + 3f + t * spanY
                    val nb = 0.5f + 0.5f * sin(i * 2.31 + timeSec * 1.7 + seed).toFloat()
                    if (nb < 0.34f) continue
                    val nw = 0.5f + 0.5f * sin(i * 1.13 + timeSec * 0.9 + seed * 1.7).toFloat()
                    val nz = 0.5f + 0.5f * sin(i * 3.77 + timeSec * 2.3 + seed * 0.7).toFloat()
                    val halfW = bodyR * (0.34f + 1.00f * t) * (0.45f + 0.55f * nw) *
                        (1f - 0.22f * elevN)
                    val jitter = (nz - 0.5f) * 2f * (bodyR * 0.35f + 55f * t)
                    val a = (peak * (1f - t).pow(1.7f) *
                        (0.30f + 0.70f * nb) * (0.55f + 0.45f * nw)).toInt()
                    if (a <= 3) continue
                    reflPaint.color = Color.argb(a.coerceIn(0, 255), cr, cg, cb)
                    val thick = maxOf(2.5f, stepPx * 0.95f + 2f * t)
                    rect.set(cx - halfW + jitter, y, cx + halfW + jitter, y + thick)
                    canvas.drawRoundRect(rect, thick / 2f, thick / 2f, reflPaint)
                }
            }

            /** Mirrored, squashed smears of clouds just below the horizon. */
            private fun drawCloudReflections(
                canvas: Canvas, w: Float, hz: Float, h: Float, anim: Double, dl: Float, pal: Pal
            ) {
                val baseA = (8 + 52 * dl).toInt()
                if (baseA <= 3) return
                cloudPaint.alpha = baseA
                cloudPaint.colorFilter = reflectTint
                for (ci in clouds.indices) {
                    val c = clouds[ci]
                    val spW = c.art.full.width.toFloat()
                    val spH = c.art.full.height.toFloat()
                    val cloudW = w * 0.58f * c.size
                    val cloudH = cloudW * (spH / spW)
                    val x = ((((c.baseX + anim * c.speed) % 1.5) - 0.25) * w).toFloat()
                    val cy = (hz * (0.14f + c.yFrac) +
                        sin(anim * 0.11 + c.bob) * hz * 0.006).toFloat()
                    if (cy + cloudH * 0.5f > hz - 10f) continue

                    val rw = cloudW * 0.94f
                    val rh = cloudH * 0.28f
                    // Mirror about the horizon: y' = 2 * (hz + 2) - y
                    canvas.save()
                    canvas.translate(0f, 2f * (hz + 2f))
                    canvas.scale(1f, -1f)
                    rect.set(x - rw / 2f, hz - rh, x + rw / 2f, hz)
                    canvas.drawBitmap(c.art.full, null, rect, cloudPaint)
                    canvas.restore()
                }
            }

            /** Broken ripple lines drifting slowly toward the viewer. */
            private fun drawWaves(
                canvas: Canvas, w: Float, hz: Float, h: Float, anim: Double, dl: Float, pal: Pal
            ) {
                val seaH = h - hz
                if (seaH <= 4f) return
                val timeSec = anim
                val base = pal.seaNear
                val wr = (Color.red(base) + (255 - Color.red(base)) * 0.6f).toInt()
                val wg = (Color.green(base) + (255 - Color.green(base)) * 0.6f).toInt()
                val wb = (Color.blue(base) + (255 - Color.blue(base)) * 0.6f).toInt()
                wavePaint.style = Paint.Style.STROKE
                wavePaint.strokeCap = Paint.Cap.ROUND

                val sc = (w / 1080f).coerceIn(0.6f, 2.5f)
                val lines = 30
                for (i in 0 until lines) {
                    val t = i / (lines - 1f)
                    val y = hz + 4f + t.pow(1.35f) * (seaH - 12f)
                    val amp = (0.6f + 6.0f * t) * sc
                    val wl = (36f + 170f * t) * sc
                    val phase = timeSec * (0.55f + (i % 6) * 0.19f) + i * 1.7f
                    val alpha = ((30 + 66 * t) * (0.45f + 0.55f * dl) + (1f - dl) * 10f).toInt()
                    if (alpha <= 3) continue
                    wavePaint.strokeWidth = max(1f, (1f + 3f * t) * sc * 0.9f)
                    val seg = (16f + 40f * t) * sc
                    var x = 0f
                    while (x < w) {
                        val v = sin(x / (wl * 2.6f) + phase * 1.3 + i * 0.9).toFloat()
                        if (v > -0.1f) {
                            val run = seg * (0.7f + 0.7f * max(v, 0.05f))
                            val twoPi = (2f * PI).toFloat()
                            val y1 = y + sin(x / wl * twoPi + phase).toFloat() * amp
                            val y2 = y + sin((x + run) / wl * twoPi + phase).toFloat() * amp
                            val aa = (alpha * (0.45f + 0.55f * min(1f, v + 0.35f))).toInt()
                            wavePaint.color = Color.argb(aa.coerceIn(0, 255), wr, wg, wb)
                            path.rewind()
                            path.moveTo(x, y1)
                            path.lineTo(x + run, y2)
                            canvas.drawPath(path, wavePaint)
                        }
                        x += seg * 1.55f
                    }
                }
            }
        }
    }

    companion object {
        private const val HORIZON_FRAC = 0.63f

        // Cloud sprites are rendered offline by wallpaper_preview.py and
        // shipped under assets/clouds/ (9 clouds x 2 silhouettes x (full, lit)
        // = 36 bitmaps, ~1.3MB). Keeping them modest matters for decode cost.
        private const val SPRITE_W = 400
        private const val SPRITE_H = 240

        // ---- cloud base tuning (mirrors wallpaper_preview.py; verify.py gates) ----
        private const val DISC_P = 0.10f   // disc profile exponent: flat core, crisp rim
        private const val BN1_CELLS = 4    // control points of the single base wave
        private const val BASE_OCT = 0.30f // base wave amplitude before normalising (x h)
        private const val SQ = 0.15f       // tanh squash limit (x h)
        private const val BASE_PP = 0.24f  // guaranteed base peak-to-peak after norm (x h)
        private const val SOFT_R = 0.175f  // base-edge soft ramp (x h)
        private const val BULGE = 0.05f    // centre dip of the base line (x h)
        private const val N_LOBES = 6      // hanging lobes on the base line
        private const val ERODE = 0.60f    // wispy-edge erosion strength
        private const val LUMP_AMP = 0.95f // envelope lumpiness breaking the ellipse

        private const val TWO_PI = 6.2831855f
        private const val TWO_PI_D = 6.283185307179586
        /** Mean synodic month (days) — the moon's phase cycle. */
        private const val SYNODIC = 29.530588853f

        // ---- star field ----
        private const val STAR_COUNT = 1900
        private const val STAR_SPEED_MULT = 4.0 // 60 deg/hour = 4x Earth's rate
        /** Celestial pole (unit vector): projected off the top-left of the sky. */
        private val STAR_POLE = normalize(-0.50f, -0.78f, 0.44f)

        // ---- clouds: 3 parallax layers, far/hazy/slow -> near/sharp/fast ----
        private const val CLOUD_SPEED_MULT = 5f
        private const val CLOUD_COUNT = 9
        private val LAYER_SPEED = floatArrayOf(0.60f, 1.00f, 1.40f)
        private val LAYER_ALPHA = floatArrayOf(0.78f, 0.93f, 1.00f)
        private val LAYER_HAZE = floatArrayOf(0.42f, 0.16f, 0.00f)
        private val LAYER_SIZE = floatArrayOf(0.85f, 1.00f, 1.15f)

        private fun normalize(x: Float, y: Float, z: Float): FloatArray {
            val n = sqrt(x * x + y * y + z * z)
            return floatArrayOf(x / n, y / n, z / n)
        }

        // ------------------------------------------------ procedural clouds

        private fun smooth01f(x: Float): Float {
            val t = x.coerceIn(0f, 1f)
            return t * t * (3f - 2f * t)
        }

        private fun addDisc(mask: FloatArray, w: Int, h: Int, cx: Float, cy: Float, r: Float) {
            if (r <= 0f) return
            val x0 = max(0, (cx - r).toInt())
            val x1 = min(w - 1, (cx + r).toInt() + 1)
            val y0 = max(0, (cy - r).toInt())
            val y1 = min(h - 1, (cy + r).toInt() + 1)
            if (x1 < x0 || y1 < y0) return
            val invR = 1f / r
            for (y in y0..y1) {
                val dy = (y - cy) * invR
                val row = y * w
                for (x in x0..x1) {
                    val dx = (x - cx) * invR
                    val d2 = dx * dx + dy * dy
                    if (d2 >= 1f) continue
                    val a = (1f - d2).pow(DISC_P)
                    val i = row + x
                    if (a > mask[i]) mask[i] = a
                }
            }
        }

        private fun boxBlur(a: FloatArray, w: Int, h: Int, radius: Int) {
            if (radius < 1) return
            val tmp = FloatArray(a.size)
            val div = (radius * 2 + 1).toFloat()
            for (y in 0 until h) {
                val row = y * w
                var sum = 0f
                for (k in -radius..radius) sum += a[row + k.coerceIn(0, w - 1)]
                for (x in 0 until w) {
                    tmp[row + x] = sum / div
                    sum += a[row + (x + radius + 1).coerceIn(0, w - 1)]
                    sum -= a[row + (x - radius).coerceIn(0, w - 1)]
                }
            }
            for (x in 0 until w) {
                var sum = 0f
                for (k in -radius..radius) sum += tmp[k.coerceIn(0, h - 1) * w + x]
                for (y in 0 until h) {
                    a[y * w + x] = sum / div
                    sum += tmp[(y + radius + 1).coerceIn(0, h - 1) * w + x]
                    sum -= tmp[(y - radius).coerceIn(0, h - 1) * w + x]
                }
            }
        }

        private fun noise1d(w: Int, cells: Int, seed: Int): FloatArray {
            val rnd = Random(seed)
            val g = FloatArray(cells + 1) { rnd.nextFloat() }
            val out = FloatArray(w)
            for (x in 0 until w) {
                val p = x.toFloat() / w * cells
                val i = p.toInt().coerceIn(0, cells - 1)
                out[x] = g[i] + (g[i + 1] - g[i]) * smooth01f(p - i)
            }
            return out
        }

        private fun noise2d(w: Int, h: Int, cellsY: Int, cellsX: Int, seed: Int): FloatArray {
            val rnd = Random(seed)
            val gw = cellsX + 1
            val g = FloatArray(gw * (cellsY + 1)) { rnd.nextFloat() }
            val out = FloatArray(w * h)
            for (y in 0 until h) {
                val py = y.toFloat() / h * cellsY
                val iy = py.toInt().coerceIn(0, cellsY - 1)
                val fy = smooth01f(py - iy)
                val r0 = iy * gw
                val r1 = (iy + 1) * gw
                val rowOut = y * w
                for (x in 0 until w) {
                    val px = x.toFloat() / w * cellsX
                    val ix = px.toInt().coerceIn(0, cellsX - 1)
                    val fx = smooth01f(px - ix)
                    val a = g[r0 + ix] + (g[r0 + ix + 1] - g[r0 + ix]) * fx
                    val b = g[r1 + ix] + (g[r1 + ix + 1] - g[r1 + ix]) * fx
                    out[rowOut + x] = a + (b - a) * fy
                }
            }
            return out
        }

        /**
         * Builds one cumulus sprite: soft lobes inside an envelope that rounds
         * only the crown, blurred into a single organic silhouette, then a
         * ragged noise-driven base so the bottom is never a blade cut.
         * Split into a plain copy and a top-lit copy.
         */
        /**
         * Cloud sprites are rendered offline by wallpaper_preview.py -- the
         * visual source of truth -- and shipped as PNGs, so the app and the
         * preview are pixel-identical and startup only decodes 36 small
         * bitmaps instead of raymarching a 3-D density volume on the render
         * thread (which would leave the surface blank for many seconds).
         *
         * Returns null when an asset is missing so the caller can fall back to
         * the procedural builder below.
         */
        private fun loadCloudArt(
            assets: AssetManager,
            index: Int,
            variant: Int,
        ): CloudArt? {
            val opts = BitmapFactory.Options().apply {
                inPreferredConfig = Bitmap.Config.ARGB_8888
            }
            val full = runCatching {
                assets.open("clouds/cloud_${index}_${variant}_full.png").use {
                    BitmapFactory.decodeStream(it, null, opts)
                }
            }.getOrNull() ?: return null
            val lit = runCatching {
                assets.open("clouds/cloud_${index}_${variant}_lit.png").use {
                    BitmapFactory.decodeStream(it, null, opts)
                }
            }.getOrNull() ?: return null
            if (full.width == 0 || full.height == 0) return null
            return CloudArt(full, lit)
        }

        private fun buildCloudArt(seed: Int, hReq: Int): CloudArt {
            val w = SPRITE_W
            val h = hReq.coerceIn(120, 520)
            val rnd = Random(seed)
            val mask = FloatArray(w * h)

            val cx = w * 0.5f
            val cy = h * 0.54f
            val ax = w * 0.45f
            val ay = h * 0.44f

            // Base row: ragged condensation-level base spanning the full body
            val baseY = h * (0.66f + rnd.nextFloat() * 0.05f)
            var x = cx - ax * 0.92f
            while (x < cx + ax * 0.92f) {
                val r = h * (0.15f + rnd.nextFloat() * 0.11f)
                addDisc(mask, w, h, x, baseY, r)
                x += r * (0.60f + rnd.nextFloat() * 0.35f)
            }

            // Main volume packed inside the envelope
            repeat(14) {
                val ang = rnd.nextFloat() * 2f * PI.toFloat()
                val rad = rnd.nextFloat().pow(0.55f)
                val lx = cx + cos(ang) * rad * ax * 0.88f
                val ly = cy + sin(ang) * rad * ay * 0.88f
                val r = h * (0.34f - 0.18f * rad) * (0.75f + 0.55f * rnd.nextFloat())
                addDisc(mask, w, h, lx, ly, r)
            }

            // Cauliflower bumps, biased to the top
            repeat(24) {
                val lx = cx + (rnd.nextFloat() - 0.5f) * ax * 1.7f
                val ly = cy - rnd.nextFloat().pow(0.7f) * ay * 0.95f + ay * 0.18f
                val r = h * (0.06f + rnd.nextFloat() * 0.11f)
                addDisc(mask, w, h, lx, ly, r)
            }

            // Tiny billowing knots along the top silhouette
            repeat(52) {
                val lx = cx + (rnd.nextFloat() - 0.5f) * ax * 1.75f
                val ly = cy - (0.25f + rnd.nextFloat().pow(1.5f) * 0.70f) * ay * 1.05f +
                    ay * 0.18f
                val r = h * (0.020f + rnd.nextFloat() * 0.048f)
                addDisc(mask, w, h, lx, ly, r)
            }

            // Envelope: an ellipse rounds the crown, but the lower half is barely
            // constrained (3x ay) so the ragged cut -- not the envelope -- defines
            // the base. A noise term breaks the perfect curve so it reads lumpy.
            val lump = noise2d(w, h, 5, 11, seed + 9)
            val invAx2 = 1f / (ax * ax)
            val invAy2 = 1f / (ay * ay)
            for (y in 0 until h) {
                val dy = y - cy
                val ey2 = dy * dy * invAy2
                val lower = dy >= 0f
                val row = y * w
                for (col in 0 until w) {
                    val dx = col - cx
                    val ex2 = dx * dx * invAx2
                    val env = (if (lower) 1f - ex2 - ey2 * (1f / 9f) else 1f - ex2 - ey2) +
                        (lump[row + col] - 0.5f) * LUMP_AMP
                    val e = env * 5.0f
                    mask[row + col] =
                        if (e <= 0f) 0f
                        else mask[row + col] * min(1f, e).pow(0.45f)
                }
            }

            boxBlur(mask, w, h, max(1, (h * 0.022f).toInt()))
            boxBlur(mask, w, h, max(1, (h * 0.022f).toInt()))

            // Ragged cumulus base: one low-frequency wave plus round lobes hanging
            // below the condensation level. High-frequency octaves are deliberately
            // absent -- they produced icicle spikes instead of cumulus.
            val bn1 = noise1d(w, BN1_CELLS, seed + 7)
            val softRange = h * SOFT_R
            val lobeX = FloatArray(N_LOBES)
            val lobeR = FloatArray(N_LOBES)
            val lobeD = FloatArray(N_LOBES)
            for (li in 0 until N_LOBES) {
                lobeX[li] = cx + (rnd.nextFloat() - 0.5f) * ax * 1.7f
                lobeR[li] = h * (0.10f + rnd.nextFloat() * 0.14f)
                lobeD[li] = h * (0.020f + rnd.nextFloat() * 0.030f)
            }
            val sq = h * SQ
            val wave = FloatArray(w)
            for (col in 0 until w) {
                val raw = (bn1[col] - 0.5f) * h * BASE_OCT
                wave[col] = tanh(raw / sq)
            }
            // Normalise inside the measured window so every seed gets the same
            // guaranteed base spread (verify.py gates on it).
            val lo = (w * 0.18f).toInt()
            val hi = (w * 0.82f).toInt()
            var wMin = Float.MAX_VALUE
            var wMax = -Float.MAX_VALUE
            for (col in lo until hi) {
                val v = wave[col]
                if (v < wMin) wMin = v
                if (v > wMax) wMax = v
            }
            val span = wMax - wMin
            val mid = 0.5f * (wMax + wMin)
            val scale = if (span > 1e-6f) h * BASE_PP / span else 1f
            for (col in 0 until w) wave[col] = (wave[col] - mid) * scale
            for (col in 0 until w) {
                val rel = abs(col - cx) / ax
                val bulge = (1f - min(rel, 1f).pow(2f)) * h * BULGE
                var cut = baseY + bulge + wave[col]
                for (li in 0 until N_LOBES) {
                    val t = ((col - lobeX[li]) / lobeR[li]).coerceIn(-1f, 1f)
                    cut += lobeD[li] * sqrt(max(0f, 1f - t * t))
                }
                cut = cut.coerceIn(h * 0.45f, h * 0.97f)
                for (y in 0 until h) {
                    mask[y * w + col] *= smooth01f((cut - y) / softRange)
                }
            }

            // Cauliflower texture
            val n1 = noise2d(w, h, 7, 18, seed + 1)
            val n2 = noise2d(w, h, 16, 42, seed + 2)
            val n3 = noise2d(w, h, 34, 90, seed + 3)
            for (i in mask.indices) {
                val noise = 0.5f * n1[i] + 0.33f * n2[i] + 0.17f * n3[i]
                mask[i] = (mask[i] * (0.82f + 0.18f * noise) * 1.20f).coerceIn(0f, 1f)
            }

            // Wispy edge erosion: high-frequency noise only bites in the outer
            // band, so the core stays dense while the skirt frays into filaments.
            val hf = noise2d(w, h, 46, 120, seed + 5)
            for (i in mask.indices) {
                val band = ((0.62f - mask[i]) / 0.5f).coerceIn(0f, 1f)
                mask[i] = mask[i] * (1f - band * ERODE * (1f - hf[i]))
            }

            // Fade at the sprite borders so no bounding box can show
            val mx = w * 0.05f
            val my = h * 0.10f
            for (col in 0 until w) {
                val d = min(col, w - 1 - col).toFloat()
                val win = smooth01f(d / mx)
                for (y in 0 until h) mask[y * w + col] *= win
            }
            for (y in 0 until h) {
                val win = smooth01f(y / my)
                val row = y * w
                for (col in 0 until w) mask[row + col] *= win
            }

            // Write the silhouette copy and the top-lit copy
            val fullBmp = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
            val litBmp = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
            val fullPix = IntArray(w * h)
            val litPix = IntArray(w * h)
            val denom = max(1f, h - 1f)
            val xDenom = max(1f, (w - 1).toFloat())
            for (y in 0 until h) {
                val yy = y / denom
                val ramp = max(0f, min(1f, (0.88f - yy) / 0.88f)).pow(0.90f)
                val litRamp = 0.72f + 0.28f * ramp
                val row = y * w
                for (col in 0 until w) {
                    val i = row + col
                    // Horizontal light ramp (bright at the right); the pair is
                    // mirrored at draw time when the light is on the left.
                    val xRamp = 0.5f + 0.5f * col / xDenom
                    val a = (mask[i] * 255f).toInt().coerceIn(0, 255)
                    val la = (mask[i] * litRamp * xRamp * 255f).toInt().coerceIn(0, 255)
                    fullPix[i] = (a shl 24) or 0x00FFFFFF
                    litPix[i] = (la shl 24) or 0x00FFFFFF
                }
            }
            fullBmp.setPixels(fullPix, 0, w, 0, 0, w, h)
            litBmp.setPixels(litPix, 0, w, 0, 0, w, h)
            return CloudArt(fullBmp, litBmp)
        }

        // -------------------------------------------------------- keyframes
        // Sky: top → mid → horizon.  Sea: far (at horizon) → near (bottom).

        private val DAWN = Pal(
            skyTop = Color.rgb(43, 53, 110),
            skyMid = Color.rgb(129, 104, 145),
            skyLow = Color.rgb(239, 169, 144),
            seaFar = Color.rgb(224, 166, 153),
            seaNear = Color.rgb(97, 93, 138),
            cloud = Color.rgb(246, 206, 196),
            cloudShade = Color.rgb(160, 130, 150),
        )

        private val SUNRISE = Pal(
            skyTop = Color.rgb(74, 131, 197),
            skyMid = Color.rgb(158, 200, 233),
            skyLow = Color.rgb(255, 217, 178),
            seaFar = Color.rgb(205, 217, 224),
            seaNear = Color.rgb(112, 163, 186),
            cloud = Color.rgb(255, 246, 236),
            cloudShade = Color.rgb(186, 190, 204),
        )

        private val DAY = Pal(
            skyTop = Color.rgb(48, 116, 202),
            skyMid = Color.rgb(110, 180, 224),
            skyLow = Color.rgb(196, 230, 236),
            seaFar = Color.rgb(150, 208, 212),
            seaNear = Color.rgb(56, 140, 156),
            cloud = Color.rgb(255, 255, 255),
            cloudShade = Color.rgb(158, 182, 204),
        )

        private val AFTERNOON = Pal(
            skyTop = Color.rgb(62, 126, 204),
            skyMid = Color.rgb(136, 194, 226),
            skyLow = Color.rgb(210, 234, 226),
            seaFar = Color.rgb(158, 206, 204),
            seaNear = Color.rgb(68, 146, 156),
            cloud = Color.rgb(255, 253, 247),
            cloudShade = Color.rgb(176, 192, 200),
        )

        private val GOLDEN = Pal(
            skyTop = Color.rgb(86, 120, 194),
            skyMid = Color.rgb(212, 166, 176),
            skyLow = Color.rgb(255, 204, 166),
            seaFar = Color.rgb(246, 196, 172),
            seaNear = Color.rgb(146, 140, 168),
            cloud = Color.rgb(255, 226, 206),
            cloudShade = Color.rgb(184, 142, 146),
        )

        private val SUNSET = Pal(
            skyTop = Color.rgb(112, 116, 184),
            skyMid = Color.rgb(238, 158, 158),
            skyLow = Color.rgb(255, 196, 164),
            seaFar = Color.rgb(248, 184, 166),
            seaNear = Color.rgb(150, 128, 152),
            cloud = Color.rgb(255, 208, 190),
            cloudShade = Color.rgb(166, 120, 134),
        )

        private val DUSK = Pal(
            skyTop = Color.rgb(40, 44, 92),
            skyMid = Color.rgb(136, 92, 120),
            skyLow = Color.rgb(212, 128, 116),
            seaFar = Color.rgb(168, 116, 122),
            seaNear = Color.rgb(58, 52, 86),
            cloud = Color.rgb(150, 122, 140),
            cloudShade = Color.rgb(96, 80, 104),
        )

        private val NIGHT = Pal(
            skyTop = Color.rgb(5, 7, 18),
            skyMid = Color.rgb(12, 16, 34),
            skyLow = Color.rgb(34, 42, 68),
            seaFar = Color.rgb(44, 54, 82),
            seaNear = Color.rgb(10, 12, 22),
            cloud = Color.rgb(64, 70, 96),
            cloudShade = Color.rgb(34, 38, 56),
        )
    }
}
