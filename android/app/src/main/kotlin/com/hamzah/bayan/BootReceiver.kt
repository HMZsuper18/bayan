package com.hamzah.bayan

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        if (intent?.action != Intent.ACTION_BOOT_COMPLETED &&
            intent?.action != "android.intent.action.QUICKBOOT_POWERON") {
            return
        }

        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val enabled = prefs.getString("flutter.adhan_enabled", null) == "true"
        if (!enabled) return

        // Launch MainActivity which will re-schedule via the Flutter engine
        val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)?.apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra("reschedule_adhan", true)
        }
        launchIntent?.let { context.startActivity(it) }
    }
}
