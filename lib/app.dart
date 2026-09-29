import 'package:flutter/material.dart';
import 'l10n/app_localizations.dart';
import 'core/widgets/glass_container.dart';
import 'core/theme/app_theme.dart';
import 'data/database/seed_data.dart';
import 'data/database/settings_service.dart';
import 'features/dashboard/presentation/dashboard_screen.dart';
import 'services/prayer_times_widget_service.dart';

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
      await SeedData.seedAll();
      if (mounted) PrayerTimesWidgetService.refresh();
    });
  }

  void toggleTheme() {
    setState(() {
      _isDark = !_isDark;
      SettingsService.isDarkMode = _isDark;
    });
    PrayerTimesWidgetService.refresh();
  }

  void rebuild() {
    setState(() {
      _uiFontSize = SettingsService.uiFontSize;
      _isDark = SettingsService.isDarkMode;
      _locale = _localeFromCode(SettingsService.uiLanguage);
    });
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