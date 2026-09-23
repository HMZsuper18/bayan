package com.hamzah.bayan

import android.appwidget.AppWidgetManager
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

/**
 * Handles play/pause/cancel taps on the reciters widget without starting the
 * Activity: a broadcast reaches the cached FlutterEngine directly over a
 * MethodChannel, so no window is ever shown (no flash, no task snapshot).
 *
 * When the process (and engine) is dead:
 *  - play: boots the cached engine headlessly and starts playback;
 *  - pause/cancel: playback is already gone — clears the stale playbar and
 *    redraws the widget locally instead of launching the app.
 */
class WidgetControlsReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        val uri = intent.data?.toString() ?: return
        val method: String
        val args: String?
        when {
            uri.startsWith("bayan://play/") -> {
                method = "play"
                args = uri.removePrefix("bayan://play/")
            }
            uri.startsWith("bayan://widget/toggle") -> {
                method = "toggle"
                args = null
            }
            uri.startsWith("bayan://widget/stop") ||
                uri.startsWith("bayan://widget/cancel") -> {
                method = "stop"
                args = null
            }
            else -> return
        }

        val pending = goAsync()
        Thread {
            try {
                handle(context, method, args)
            } catch (t: Throwable) {
                android.util.Log.e(TAG, "handle $method failed", t)
            } finally {
                pending.finish()
            }
        }.start()
    }

    private fun handle(context: Context, method: String, args: String?) {
        var engine = BayanEngine.cached()
        if (engine == null && method == "play") {
            engine = BayanEngine.getOrCreate(context)
        }
        if (engine == null) {
            clearStalePlayer(context)
            return
        }
        if (!invokeUntilReady(engine, method, args)) {
            android.util.Log.e(TAG, "dart did not accept $method")
        }
    }

    private fun invokeUntilReady(
        engine: FlutterEngine,
        method: String,
        args: String?,
    ): Boolean {
        val channel = MethodChannel(engine.dartExecutor.binaryMessenger, CONTROL_CHANNEL)
        val mainHandler = Handler(Looper.getMainLooper())
        repeat(ATTEMPTS) {
            val latch = CountDownLatch(1)
            var ok = false
            mainHandler.post {
                channel.invokeMethod(method, args, object : MethodChannel.Result {
                    override fun success(result: Any?) {
                        ok = true
                        latch.countDown()
                    }

                    override fun error(
                        errorCode: String,
                        errorMessage: String?,
                        errorDetails: Any?,
                    ) {
                        latch.countDown()
                    }

                    override fun notImplemented() {
                        latch.countDown()
                    }
                })
            }
            // No reply within the window means Dart is wedged — do NOT retry
            // (the in-flight call may still execute; retrying could double-toggle).
            // Generous: a cold `play` includes ExoPlayer setup + widget sync.
            if (!latch.await(2000, TimeUnit.MILLISECONDS)) return false
            if (ok) return true
            // Handler not registered yet (engine still booting) — quick error, retry.
            Thread.sleep(50)
        }
        return false
    }

    private fun clearStalePlayer(context: Context) {
        context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
            .edit()
            .putBoolean("widget_player_active", false)
            .putBoolean("widget_player_paused", false)
            .apply()
        val mgr = AppWidgetManager.getInstance(context)
        val ids = mgr.getAppWidgetIds(
            ComponentName(context, RecitationsWidgetProvider::class.java),
        )
        if (ids.isNotEmpty()) {
            RecitationsWidgetProvider().onUpdate(context, mgr, ids)
        }
    }

    companion object {
        const val TAG = "WidgetControls"
        const val CONTROL_CHANNEL = "com.hamzah.bayan/widget_controls"
        // Fast-error cycles only (handler not registered yet during boot) —
        // a slow Dart reply ends the loop via the 2s await above.
        private const val ATTEMPTS = 40
    }
}
