import 'package:flutter/services.dart';
import 'package:home_widget/home_widget.dart';
import '../data/database/settings_service.dart';

/// Syncs theme so the OCR home-screen widget matches the in-app light/dark mode.
class OcrWidgetService {
  OcrWidgetService._();

  static const _widgetName = 'OcrWidgetProvider';

  static Future<void> update() async {
    try {
      await HomeWidget.saveWidgetData(
        'widget_theme',
        SettingsService.isDarkMode ? 'dark' : 'light',
      );
      await HomeWidget.updateWidget(name: _widgetName);
    } on MissingPluginException {
      // home_widget is not implemented on desktop; ignore.
    }
  }

  static Future<void> refresh() async {
    await update();
  }
}