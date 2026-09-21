package com.hamzah.bayan

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val DOWNLOAD_CHANNEL = "com.hamzah.bayan/download_manager"
    private val NOTIFICATION_CHANNEL = "com.hamzah.bayan/adhan_notifications"
    private val ICON_CHANNEL = "com.hamzah.bayan/app_icon"
    private var bridge: DownloadManagerBridge? = null
    private var notifBridge: AdhanNotificationBridge? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

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
                    IconSwitcher.switchTo(this, variant)
                    getSharedPreferences("bayan_prefs", MODE_PRIVATE)
                        .edit().putString("app_icon_variant", variant).apply()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        val prefs = getSharedPreferences("bayan_prefs", MODE_PRIVATE)
        val savedVariant = prefs.getString("app_icon_variant", "Classic") ?: "Classic"
        IconSwitcher.ensureEnabled(this, savedVariant)
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        bridge?.unregister()
        bridge = null
        notifBridge = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
