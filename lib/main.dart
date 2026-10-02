import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import 'core/widget_launch.dart';
import 'data/database/hive_service.dart';
import 'data/database/settings_service.dart';
import 'services/default_reciter_service.dart';
import 'services/download_notification_service.dart';
import 'services/media_session_service.dart';
import 'services/widget_control_handler.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // First: widget play/pause/cancel must reach the engine even when it was
  // booted headlessly by WidgetControlsReceiver (no Activity, no UI yet).
  WidgetControlHandler.register();

  ErrorWidget.builder = (details) => const SizedBox.shrink();

  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Uncaught error: $error\n$stack');
    return true;
  };

  await HiveService.init();
  await SettingsService.init();
  await DefaultReciterService.init();
  WidgetControlHandler.markReady();

  // Capture the widget launch URI before the first frame so play/control
  // actions can run at first build instead of a post-frame channel hop.
  try {
    WidgetLaunch.uri = await HomeWidget.initiallyLaunchedFromHomeWidget();
  } catch (_) {}

  // Publish playback to the system media session (control centre / lock screen)
  await MediaSessionService.instance.init();

  // Mirror in-flight downloads into a system notification (and keep the
  // foreground service ready for them)
  await DownloadNotificationService.instance.init();

  runApp(const App());
}
