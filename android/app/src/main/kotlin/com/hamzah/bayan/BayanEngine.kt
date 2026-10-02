package com.hamzah.bayan

import android.content.Context
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugins.GeneratedPluginRegistrant
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

/**
 * Single cached FlutterEngine shared by MainActivity and the widget control
 * receiver. Keeping one engine alive means widget taps (play, pause, cancel)
 * reach Dart without ever starting an Activity — no window, no flash.
 */
object BayanEngine {
    const val ID = "bayan_engine"

    fun cached(): FlutterEngine? = FlutterEngineCache.getInstance().get(ID)

    fun getOrCreate(context: Context): FlutterEngine {
        cached()?.let { return it }
        val app = context.applicationContext
        // FlutterEngine construction must run on the main thread (FlutterJNI
        // @UiThread) — the receiver calls this from a worker.
        if (Looper.myLooper() == Looper.getMainLooper()) return create(app)
        var result: FlutterEngine? = null
        val latch = CountDownLatch(1)
        Handler(Looper.getMainLooper()).post {
            result = try {
                create(app)
            } catch (t: Throwable) {
                android.util.Log.e("BayanEngine", "engine create failed", t)
                null
            }
            latch.countDown()
        }
        if (!latch.await(5, TimeUnit.SECONDS)) error("engine create timed out")
        return result ?: error("engine create failed")
    }

    private fun create(app: Context): FlutterEngine {
        cached()?.let { return it }
        val engine = FlutterEngine(app)
        GeneratedPluginRegistrant.registerWith(engine)
        FlutterEngineCache.getInstance().put(ID, engine)
        engine.dartExecutor.executeDartEntrypoint(
            DartExecutor.DartEntrypoint.createDefault(),
        )
        return engine
    }
}
