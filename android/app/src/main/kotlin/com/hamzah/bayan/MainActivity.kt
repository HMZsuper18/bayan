package com.hamzah.bayan

import android.content.ComponentName
import android.content.Intent
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val DOWNLOAD_CHANNEL = "com.hamzah.bayan/download_manager"
    private val NOTIFICATION_CHANNEL = "com.hamzah.bayan/adhan_notifications"
    private val ICON_CHANNEL = "com.hamzah.bayan/app_icon"
    private val APP_CHANNEL = "com.hamzah.bayan/app"
    private var bridge: DownloadManagerBridge? = null
    private var notifBridge: AdhanNotificationBridge? = null
    private val mainHandler = Handler(Looper.getMainLooper())
    private var pendingBackgroundPlay = false
    private var pendingIconPrevious: String? = null

    // Reuse the single cached engine (also booted headlessly by
    // WidgetControlsReceiver) so playback and widget state live in one isolate.
    override fun provideFlutterEngine(context: android.content.Context): FlutterEngine? =
        BayanEngine.getOrCreate(context)

    // The engine outlives the Activity — audio keeps playing when the
    // activity is destroyed/recreated, and widget taps never need it.
    override fun shouldDestroyEngineWithHost(): Boolean = false

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        noteBackgroundPlay(intent)
        if (pendingBackgroundPlay) overridePendingTransition(0, 0)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        noteBackgroundPlay(intent)
        if (pendingBackgroundPlay) overridePendingTransition(0, 0)
    }

    override fun onResume() {
        super.onResume()
        // moveTaskToBack is ignored before onResume — moving here backgrounds
        // the task before the first frame draws, so a cold-start widget
        // play/control tap never flashes the app on screen.
        if (pendingBackgroundPlay) {
            val moved = moveTaskToBack(true)
            android.util.Log.i("Bayan", "onResume background attempt moved=$moved")
            if (moved) {
                overridePendingTransition(0, 0)
                pendingBackgroundPlay = false
            }
        }
    }

    private fun noteBackgroundPlay(intent: Intent?) {
        android.util.Log.i("Bayan", "noteBackgroundPlay bg=${intent?.getBooleanExtra("bayan_background_play", false)} host=${intent?.data?.host}")
        if (intent?.getBooleanExtra("bayan_background_play", false) == true) {
            pendingBackgroundPlay = true
            // Move the task out the instant the intent arrives so the app is
            // never visible for widget play/control taps (no flash). Retries
            // cover the case where moveTaskToBack is ignored before resume;
            // the first successful call clears the flag.
            mainHandler.removeCallbacks(moveToBackground)
            mainHandler.post(moveToBackground)
            mainHandler.postDelayed(moveToBackground, 400)
            mainHandler.postDelayed(moveToBackground, 2500)
        } else {
            pendingBackgroundPlay = false
            mainHandler.removeCallbacks(moveToBackground)
        }
    }

    private val moveToBackground = Runnable {
        if (pendingBackgroundPlay && !isFinishing && moveTaskToBack(true)) {
            overridePendingTransition(0, 0)
            pendingBackgroundPlay = false
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        // Deliberately NOT calling super: plugins are registered exactly once
        // in BayanEngine.getOrCreate. Super would re-run
        // GeneratedPluginRegistrant against the cached engine on every
        // activity (re)creation.

        val dmChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, DOWNLOAD_CHANNEL)
        bridge = DownloadManagerBridge(this, dmChannel)
        bridge?.register()
        dmChannel.setMethodCallHandler { call, result -> bridge?.handle(call, result) }

        val notifChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, NOTIFICATION_CHANNEL)
        notifBridge = AdhanNotificationBridge(this, notifChannel)
        notifChannel.setMethodCallHandler { call, result -> notifBridge?.handle(call, result) }

        val iconChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ICON_CHANNEL)
        iconChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "switchIcon" -> {
                    val variant = call.argument<String>("variant") ?: "Classic"
                    val previous = componentName?.className
                    // Keep the running alias alive until finalize() so the
                    // activity is not torn down mid-switch (looks like a crash).
                    val changed = IconSwitcher.switchTo(this, variant, previous)
                    getSharedPreferences("bayan_prefs", MODE_PRIVATE)
                        .edit().putString("app_icon_variant", variant).apply()
                    pendingIconPrevious = if (changed) previous else null
                    result.success(changed && IconSwitcher.hasMiuiHome(this))
                }
                "finalizeIconSwitch" -> {
                    val previous = pendingIconPrevious
                    pendingIconPrevious = null
                    val disabledPrevious = IconSwitcher.finalize(this, previous)
                    result.success(true)
                    if (disabledPrevious != null) {
                        mainHandler.post { relaunchToCurrentIcon(disabledPrevious) }
                    }
                }
                "openLauncherSettings" -> {
                    result.success(IconSwitcher.openLauncherSettings(this))
                }
                else -> result.notImplemented()
            }
        }

        // Widget-driven actions call this as soon as they are handled so the
        // app returns to the background immediately (no fixed 700ms wait).
        val appChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, APP_CHANNEL)
        appChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "moveToBackground" -> {
                    pendingBackgroundPlay = true
                    mainHandler.removeCallbacks(moveToBackground)
                    mainHandler.post(moveToBackground)
                    mainHandler.postDelayed(moveToBackground, 1500)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        val prefs = getSharedPreferences("bayan_prefs", MODE_PRIVATE)
        val savedVariant = prefs.getString("app_icon_variant", "Classic") ?: "Classic"
        IconSwitcher.ensureEnabled(this, savedVariant)
    }

    private fun relaunchToCurrentIcon(previousClassName: String) {
        if (isFinishing) return
        val variant = getSharedPreferences("bayan_prefs", MODE_PRIVATE)
            .getString("app_icon_variant", "Classic") ?: "Classic"
        val alias = IconSwitcher.componentClassName(variant)?.substringAfterLast('.')
            ?: return
        val target = ComponentName(this, "com.hamzah.bayan.$alias")
        val intent = Intent(Intent.ACTION_MAIN).apply {
            addCategory(Intent.CATEGORY_LAUNCHER)
            component = target
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                Intent.FLAG_ACTIVITY_CLEAR_TASK or
                Intent.FLAG_ACTIVITY_NO_ANIMATION
        }
        try {
            startActivity(intent)
        } catch (_: Exception) {
            return
        }
        finish()
        overridePendingTransition(0, 0)
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        bridge?.unregister()
        bridge = null
        notifBridge = null
        mainHandler.removeCallbacks(moveToBackground)
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
