import 'package:flutter/services.dart';
import 'package:home_widget/home_widget.dart';
import '../data/database/hive_service.dart';

/// Pushes the 2 most recently downloaded reciters to the recitations widget.
class RecitationsWidgetService {
  RecitationsWidgetService._();
  static const _widgetName = 'RecitationsWidgetProvider';

  static Future<void> update() async {
    try {
      final reciters = HiveService.getAllReciters();
      // Pick first 2 as "recent" (could be refined with last-played tracking).
      final top2 = reciters.take(2).toList();

      if (top2.isNotEmpty) {
        await HomeWidget.saveWidgetData('reciter_1_name', top2[0].name);
        await HomeWidget.saveWidgetData('reciter_1_id', top2[0].id);
      }
      if (top2.length > 1) {
        await HomeWidget.saveWidgetData('reciter_2_name', top2[1].name);
        await HomeWidget.saveWidgetData('reciter_2_id', top2[1].id);
      }

      await HomeWidget.updateWidget(name: _widgetName);
    } on MissingPluginException {
      // home_widget not available on desktop.
    }
  }

  static Future<void> refresh() async {
    await update();
  }
}
