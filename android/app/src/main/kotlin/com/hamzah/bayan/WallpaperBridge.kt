package com.hamzah.bayan

import android.app.WallpaperManager
import android.content.Context
import android.content.Intent
import android.graphics.BitmapFactory
import android.os.Build
import android.provider.Settings
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

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
            "setLiveWallpaper" -> {
                try {
                    val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                        val componentName = android.content.ComponentName(
                            context,
                            IslamicLiveWallpaperService::class.java
                        )
                        Intent(WallpaperManager.ACTION_CHANGE_LIVE_WALLPAPER).apply {
                            putExtra(
                                WallpaperManager.EXTRA_LIVE_WALLPAPER_COMPONENT,
                                componentName
                            )
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                    } else {
                        Intent(WallpaperManager.ACTION_CHANGE_LIVE_WALLPAPER).apply {
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                    }
                    context.startActivity(intent)
                    result.success(true)
                } catch (e: Exception) {
                    result.error("LIVE_FAILED", e.message, null)
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
            "openLiveWallpaperSettings" -> {
                try {
                    val intent = Intent(WallpaperManager.ACTION_LIVE_WALLPAPER_CHOOSER)
                    intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    context.startActivity(intent)
                    result.success(true)
                } catch (e: Exception) {
                    result.error("SETTINGS_FAILED", e.message, null)
                }
            }
            else -> result.notImplemented()
        }
    }
}
