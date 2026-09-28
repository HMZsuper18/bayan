package com.hamzah.bayan

import android.app.WallpaperManager
import android.content.Context
import android.graphics.BitmapFactory
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class WallpaperBridge(
    private val context: Context,
    private val channel: MethodChannel
) {
    fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "setWallpaper" -> {
                val path = call.argument<String>("path")
                val which = call.argument<String>("which") ?: "both"
                if (path == null) {
                    result.error("BAD_ARGS", "path is required", null)
                    return
                }
                try {
                    val bitmap = BitmapFactory.decodeFile(path)
                    if (bitmap == null) {
                        result.error("DECODE_FAILED", "Could not decode image", null)
                        return
                    }
                    val manager = WallpaperManager.getInstance(context)
                    val flags = when (which) {
                        "home" -> WallpaperManager.FLAG_SYSTEM
                        "lock" -> WallpaperManager.FLAG_LOCK
                        else -> WallpaperManager.FLAG_SYSTEM or WallpaperManager.FLAG_LOCK
                    }
                    manager.setBitmap(bitmap, null, true, flags)
                    bitmap.recycle()
                    result.success(true)
                } catch (e: Exception) {
                    result.error("SET_FAILED", e.message, null)
                }
            }
            "syncPrayerTimes" -> {
                val prayerTimes = call.argument<List<Map<String, Any>>>("prayerTimes")
                if (prayerTimes != null) {
                    val prefs = context.getSharedPreferences("bayan_prefs", Context.MODE_PRIVATE)
                    val editor = prefs.edit()
                    for (prayer in prayerTimes) {
                        val name = prayer["name"] as? String ?: continue
                        val hour = prayer["hour"] as? Int ?: continue
                        val minute = prayer["minute"] as? Int ?: continue
                        editor.putInt("prayer_${name}_hour", hour)
                        editor.putInt("prayer_${name}_minute", minute)
                    }
                    editor.apply()
                }
                result.success(true)
            }
            else -> result.notImplemented()
        }
    }
}
