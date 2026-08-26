import 'package:flutter/services.dart';
import 'package:home_widget/home_widget.dart';
import '../data/models/prayer_time_model.dart';

class PrayerTimesWidgetService {
  PrayerTimesWidgetService._();

  static const _widgetName = 'PrayerTimesWidgetProvider';
  static List<PrayerTimeModel>? _lastTimes;

  static Future<void> update(List<PrayerTimeModel> times) async {
    _lastTimes = times;
    try {
      for (final t in times) {
        final base = 'prayer_${t.name.toLowerCase()}';
        await HomeWidget.saveWidgetData('${base}_hour', t.time.hour);
        await HomeWidget.saveWidgetData('${base}_minute', t.time.minute);
      }
      await HomeWidget.updateWidget(name: _widgetName);
    } on MissingPluginException {
      // home_widget is not implemented on desktop; ignore.
    }
  }

  static Future<void> refresh() async {
    if (_lastTimes != null) {
      await update(_lastTimes!);
    }
  }
}
