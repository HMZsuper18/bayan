package com.hamzah.bayan

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class PackageReplacedReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        if (intent?.action == Intent.ACTION_MY_PACKAGE_REPLACED) {
            // Re-enable the default alias so `flutter run` / `adb am start`
            // can always find a valid launcher component. The manifest
            // resolver picks the first MAIN+LAUNCHER entry (Classic), so it
            // must be enabled. The actual variant is enforced by
            // ensureEnabled() in MainActivity.onCreate on the next cold start.
            IconSwitcher.reEnableDefault(context)
        }
    }
}
