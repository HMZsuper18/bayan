import 'dart:async';

import 'package:flutter/material.dart';
import 'l10n/app_localizations.dart';
import 'core/widgets/glass_container.dart';
import 'core/theme/app_theme.dart';
import 'data/database/seed_data.dart';
import 'data/database/settings_service.dart';
import 'features/dashboard/presentation/dashboard_screen.dart';
import 'services/adhan_notification_service.dart';
import 'services/app_icon_service.dart';
import 'services/ayah_widget_service.dart';
import 'services/dhikr_widget_service.dart';
import 'services/ocr_widget_service.dart';
import 'services/prayer_times_widget_service.dart';
import 'services/reciter_store_service.dart';
import 'services/recitations_widget_service.dart';

class App extends StatefulWidget {
  const App({super.key});

  static AppState? of(BuildContext context) {
    return context.findAncestorStateOfType<AppState>();
  }

  @override
  State<App> createState() => AppState();
}

class AppState extends State<App> {
  bool _isDark = false;
  double _uiFontSize = 14;
  Locale? _locale;

  @override
  void initState() {
    super.initState();
    _isDark = SettingsService.isDarkMode;
    _uiFontSize = SettingsService.uiFontSize;
    _locale = _localeFromCode(SettingsService.uiLanguage);
    GlassConfig.enableBlur = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Non-critical startup work — kept off the cold-start critical path so
      // widget taps (play/store) reach their action faster.
      AppIconService.instance.init();
      AdhanNotificationService.instance.rescheduleFromSettings();
      AyahWidgetService.update();
      DhikrWidgetService.update();
      PrayerTimesWidgetService.update([]);
      RecitationsWidgetService.syncPlayback(active: false);
      RecitationsWidgetService.update();
      OcrWidgetService.update();
      await SeedData.seedAll();
      // Pick up any reciter a previous run left half-downloaded. Deferred to
      // the first frame so the download foreground service may start while
      // the activity is fully resumed.
      unawaited(ReciterStoreService.instance.resumePartialDownloads());
      if (mounted) {
        PrayerTimesWidgetService.refresh();
        RecitationsWidgetService.refresh();
        AyahWidgetService.refresh();
      }
    });
  }

  void toggleTheme() {
    setState(() {
      _isDark = !_isDark;
      SettingsService.isDarkMode = _isDark;
    });
    PrayerTimesWidgetService.refresh();
    RecitationsWidgetService.refresh();
    OcrWidgetService.refresh();
    DhikrWidgetService.refresh();
    AyahWidgetService.refresh();
  }

  void rebuild() {
    setState(() {
      _uiFontSize = SettingsService.uiFontSize;
      _isDark = SettingsService.isDarkMode;
      _locale = _localeFromCode(SettingsService.uiLanguage);
    });
    PrayerTimesWidgetService.refresh();
    RecitationsWidgetService.refresh();
    OcrWidgetService.refresh();
    DhikrWidgetService.refresh();
    AyahWidgetService.refresh();
  }

  Locale _localeFromCode(String code) {
    switch (code) {
      case 'en':
        return const Locale('en');
      case 'ur':
        return const Locale('ur');
      default:
        return const Locale('ar');
    }
  }

  @override
  Widget build(BuildContext context) {
    final scale = _uiFontSize / 14.0;
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
      child: MaterialApp(
      title: AppLocalizations.of(context)?.appTitle ?? 'Bayan',
      debugShowCheckedModeBanner: false,
      locale: _locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: _isDark ? ThemeMode.dark : ThemeMode.light,
      home: const DashboardScreen(),
    ),
    );
  }
}