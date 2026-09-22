import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:home_widget/home_widget.dart';
import '../data/database/settings_service.dart';
import '../data/models/prayer_time_model.dart';
import '../l10n/app_localizations.dart';

class PrayerTimesWidgetService {
  PrayerTimesWidgetService._();

  static const _widgetName = 'PrayerTimesWidgetProvider';
  static List<PrayerTimeModel>? _lastTimes;

  static Future<void> update(List<PrayerTimeModel> times) async {
    if (times.isNotEmpty) {
      _lastTimes = times;
      try {
        for (final t in times) {
          final base = 'prayer_${t.name.toLowerCase()}';
          await HomeWidget.saveWidgetData('${base}_hour', t.time.hour);
          await HomeWidget.saveWidgetData('${base}_minute', t.time.minute);
        }
      } on MissingPluginException {
        return;
      }
    }
    await _saveMeta();
    try {
      await HomeWidget.updateWidget(name: _widgetName);
    } on MissingPluginException {
      // home_widget is not implemented on desktop; ignore.
    }
  }

  static Future<void> refresh() async {
    await update(_lastTimes ?? const []);
  }

  /// Pushes UI language, theme, and localized strings so the native widget
  /// matches the in-app Arabic / English / Urdu experience and light/dark mode.
  static Future<void> _saveMeta() async {
    try {
      final lang = SettingsService.uiLanguage;
      final l10n = await AppLocalizations.delegate.load(Locale(lang));
      await HomeWidget.saveWidgetData('widget_lang', lang);
      await HomeWidget.saveWidgetData(
        'widget_theme',
        SettingsService.isDarkMode ? 'dark' : 'light',
      );
      await HomeWidget.saveWidgetData('prayer_widget_title', l10n.prayerTimes);
      await HomeWidget.saveWidgetData('label_fajr', l10n.fajr);
      await HomeWidget.saveWidgetData('label_dhuhr', l10n.dhuhr);
      await HomeWidget.saveWidgetData('label_asr', l10n.asr);
      await HomeWidget.saveWidgetData('label_maghrib', l10n.maghrib);
      await HomeWidget.saveWidgetData('label_isha', l10n.isha);
      await HomeWidget.saveWidgetData('label_location', l10n.updateLocation);
    } on MissingPluginException {
      // home_widget is not implemented on desktop; ignore.
    }
  }
}
