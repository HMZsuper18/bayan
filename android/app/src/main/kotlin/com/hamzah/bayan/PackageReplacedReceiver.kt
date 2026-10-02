package com.hamzah.bayan

import android.appwidget.AppWidgetManager
import android.content.BroadcastReceiver
import android.content.ComponentName
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

            // Push fresh RemoteViews (fonts, layout, theme) to every placed widget.
            refreshWidgets<PrayerTimesWidgetProvider>(context)
            refreshWidgets<RecitationsWidgetProvider>(context)
            refreshWidgets<DhikrWidgetProvider>(context)
            refreshWidgets<AyahWidgetProvider>(context)
            refreshWidgets<OcrWidgetProvider>(context)
        }
    }

    private inline fun <reified T : android.appwidget.AppWidgetProvider> refreshWidgets(context: Context) {
        val mgr = AppWidgetManager.getInstance(context)
        val ids = mgr.getAppWidgetIds(ComponentName(context, T::class.java))
        if (ids.isEmpty()) return
        val provider = T::class.java.getDeclaredConstructor().newInstance()
        provider.onUpdate(context, mgr, ids)
    }
}
