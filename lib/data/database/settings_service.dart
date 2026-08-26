import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

class SettingsService {
  static const String _boxName = 'settings';

  static Box<String>? _box;
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;
    _box = await Hive.openBox<String>(_boxName);
    _initialized = true;
    translationLanguageNotifier.value = translationLanguage;
  }

  static Box<String> get _b {
    if (!_initialized) {
      throw StateError('SettingsService not initialized. Call SettingsService.init() first.');
    }
    return _box!;
  }

  static const String _fontSizeKey = 'font_size';
  static const String _uiFontSizeKey = 'ui_font_size';
  static const String _themeKey = 'theme_mode';
  static const String _latitudeKey = 'latitude';
  static const String _longitudeKey = 'longitude';
  static const String _lastLocationUpdateKey = 'last_location_update';
  static const String _lastLocationAttemptKey = 'last_location_attempt';
  static const String _uiLangKey = 'ui_lang';
  static const String _tafseerLangKey = 'tafseer_lang';
  static const String _mushafLayoutKey = 'mushaf_layout';
  static const String _translationLangKey = 'translation_lang';
  static const String _lastMushafPageKey = 'last_mushaf_page';
  static const String _lastMushafSurahKey = 'last_mushaf_surah';
  static const String _cameraRationaleKey = 'camera_rationale_shown';

  static double get fontSize {
    final val = _b.get(_fontSizeKey);
    return val != null ? double.tryParse(val) ?? 22.0 : 22.0;
  }

  static set fontSize(double value) {
    _b.put(_fontSizeKey, value.toString());
  }

  static double get uiFontSize {
    final val = _b.get(_uiFontSizeKey);
    return val != null ? double.tryParse(val) ?? 14.0 : 14.0;
  }

  static set uiFontSize(double value) {
    _b.put(_uiFontSizeKey, value.toString());
  }

  static bool get isDarkMode {
    return _b.get(_themeKey) == 'dark';
  }

  static set isDarkMode(bool value) {
    _b.put(_themeKey, value ? 'dark' : 'light');
  }

  static String get uiLanguage => _b.get(_uiLangKey) ?? 'ar';

  static set uiLanguage(String value) {
    _b.put(_uiLangKey, value);
  }

  static String get tafseerLanguage => _b.get(_tafseerLangKey) ?? 'ar';

  static set tafseerLanguage(String value) {
    _b.put(_tafseerLangKey, value);
  }

  static double get latitude {
    final val = _b.get(_latitudeKey);
    return val != null ? double.tryParse(val) ?? 21.4225 : 21.4225;
  }

  static set latitude(double value) {
    _b.put(_latitudeKey, value.toString());
  }

  static double get longitude {
    final val = _b.get(_longitudeKey);
    return val != null ? double.tryParse(val) ?? 39.8262 : 39.8262;
  }

  static set longitude(double value) {
    _b.put(_longitudeKey, value.toString());
  }

  /// Timestamp of the last successful GPS location fix, or null when the user
  /// has never updated their location (fresh install / cleared data).
  static DateTime? get lastLocationUpdate {
    final val = _b.get(_lastLocationUpdateKey);
    return val != null ? DateTime.tryParse(val) : null;
  }

  static set lastLocationUpdate(DateTime value) {
    _b.put(_lastLocationUpdateKey, value.toIso8601String());
  }

  /// Timestamp of the last location refresh attempt (successful or declined),
  /// used so a first-open auto-prompt is only shown once.
  static DateTime? get lastLocationAttempt {
    final val = _b.get(_lastLocationAttemptKey);
    return val != null ? DateTime.tryParse(val) : null;
  }

  static set lastLocationAttempt(DateTime value) {
    _b.put(_lastLocationAttemptKey, value.toIso8601String());
  }

  static String get mushafLayout => _b.get(_mushafLayoutKey) ?? 'surahs';

  static set mushafLayout(String value) {
    _b.put(_mushafLayoutKey, value);
  }

  /// Last mushaf page (1–604) the user stopped at, regardless of layout, so
  /// the "open mushaf" button resumes where they left off even after switching
  /// between page and surah views.
  static int get lastMushafPage =>
      int.tryParse(_b.get(_lastMushafPageKey) ?? '') ?? 1;

  static set lastMushafPage(int value) {
    _b.put(_lastMushafPageKey, value.toString());
  }

  /// Surah of the last position, kept in sync with [lastMushafPage].
  static int get lastMushafSurahId =>
      int.tryParse(_b.get(_lastMushafSurahKey) ?? '') ?? 1;

  static set lastMushafSurahId(int value) {
    _b.put(_lastMushafSurahKey, value.toString());
  }

  /// Whether the in-app camera rationale (shown before the OS permission
  /// prompt) has been acknowledged, so it only appears once.
  static bool get cameraRationaleShown => _b.get(_cameraRationaleKey) == 'true';

  static void markCameraRationaleShown() {
    _b.put(_cameraRationaleKey, 'true');
  }

  static final translationLanguageNotifier = ValueNotifier<String>('en');

  static String get translationLanguage => _b.get(_translationLangKey) ?? 'en';

  static set translationLanguage(String value) {
    _b.put(_translationLangKey, value);
    translationLanguageNotifier.value = value;
  }
}