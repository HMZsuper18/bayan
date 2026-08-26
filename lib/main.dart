import 'dart:ui';

import 'package:flutter/material.dart';
import 'data/database/hive_service.dart';
import 'data/database/settings_service.dart';
import 'services/default_reciter_service.dart';
import 'services/background_download_service.dart';
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
  await BackgroundDownloadService.instance.initialize();
  runApp(const App());
}
