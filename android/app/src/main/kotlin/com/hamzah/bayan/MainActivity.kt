package com.hamzah.bayan

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.hamzah.bayan/download_manager"
    private var bridge: DownloadManagerBridge? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        bridge = DownloadManagerBridge(this, channel)
        bridge?.register()
        channel.setMethodCallHandler { call, result -> bridge?.handle(call, result) }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        bridge?.unregister()
        bridge = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
