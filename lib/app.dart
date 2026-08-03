import 'package:flutter/material.dart';
import 'l10n/app_localizations.dart';
import 'core/widgets/glass_container.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_text_styles.dart';
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
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        fontFamily: 'Tajawal',
        scaffoldBackgroundColor: Colors.transparent,
        colorScheme: ColorScheme.dark(
          primary: AppColors.primaryGreen,
          primaryContainer: AppColors.primaryGreen.withValues(alpha: 0.2),
          secondary: AppColors.primaryGreenLight,
          surface: Colors.transparent,
          onPrimary: AppColors.white,
          onSecondary: AppColors.white,
          onSurface: const Color(0xFFE8E8E0),
          onPrimaryContainer: const Color(0xFFE8E8E0),
        ),
        textTheme: TextTheme(
          headlineLarge: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
          headlineMedium: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, letterSpacing: 0.3),
          titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, letterSpacing: 0.3),
          bodyLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, letterSpacing: 0.5),
          bodyMedium: TextStyle(fontSize: 13, fontWeight: FontWeight.w400, letterSpacing: 0.3),
          bodySmall: TextStyle(fontSize: 11, fontWeight: FontWeight.w400, letterSpacing: 0.3),
          labelLarge: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: 0.5),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.transparent,
          foregroundColor: const Color(0xFFE8E8E0),
          elevation: 0,
          centerTitle: true,
          scrolledUnderElevation: 0,
          titleTextStyle: AppTextStyles.arabicTitle.copyWith(
            color: const Color(0xFFE8E8E0),
            fontSize: 20,
          ),
          iconTheme: IconThemeData(color: const Color(0xFFE8E8E0)),
        ),
        cardTheme: CardThemeData(
          color: Colors.transparent,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        dividerColor: const Color(0xFF333333),
        dialogTheme: DialogThemeData(
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        bottomSheetTheme: BottomSheetThemeData(
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
      ),
      themeMode: _isDark ? ThemeMode.dark : ThemeMode.light,
      home: const DashboardScreen(),
    ),
    );
  }
}