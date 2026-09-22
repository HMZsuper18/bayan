import 'dart:ui';

import 'package:flutter/material.dart';
import 'data/database/hive_service.dart';
import 'data/database/settings_service.dart';
import 'services/default_reciter_service.dart';
import 'services/adhan_notification_service.dart';
import 'services/app_icon_service.dart';
import 'services/ayah_widget_service.dart';
import 'services/dhikr_widget_service.dart';
import 'services/prayer_times_widget_service.dart';
import 'services/recitations_widget_service.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  ErrorWidget.builder = (details) => const SizedBox.shrink();

  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Uncaught error: $error\n$stack');
    return true;
  };

  await HiveService.init();
  await SettingsService.init();
  await DefaultReciterService.init();

  // Sync saved icon variant to native side
  AppIconService.instance.init();

  // Reschedule adhan notifications on startup (recovers after reboot)
  AdhanNotificationService.instance.rescheduleFromSettings();

  // Push initial content to home screen widgets
  AyahWidgetService.update();
  DhikrWidgetService.update();
  PrayerTimesWidgetService.update([]);
  RecitationsWidgetService.update();

  runApp(const App());
}
