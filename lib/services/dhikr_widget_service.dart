import 'package:flutter/services.dart';
import 'package:home_widget/home_widget.dart';
import '../core/utils/azkar_time_logic.dart';

/// Pushes time-appropriate azkar to the home screen dhikr widget.
class DhikrWidgetService {
  DhikrWidgetService._();
  static const _widgetName = 'DhikrWidgetProvider';

  static Future<void> update() async {
    try {
      final now = DateTime.now();
      final type = getAzkarType(now);
      final item = getAzkarItem(type, now);
      final lang = 'ar';

      await HomeWidget.saveWidgetData('dhikr_text', item.text);
      await HomeWidget.saveWidgetData('dhikr_reference',
          item.translatedReference(lang) ?? item.reference ?? '');
      await HomeWidget.updateWidget(name: _widgetName);
    } on MissingPluginException {
      // home_widget not available on desktop.
    }
  }

  static Future<void> refresh() async {
    await update();
  }
}
