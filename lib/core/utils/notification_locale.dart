import 'dart:ui';

/// Resolve the locale used for system-facing surfaces (notifications).
///
/// System notifications are read outside the app, so they follow the device
/// language rather than the in-app UI language. When the device speaks a
/// language the app does not ship, fall back to [fallbackLanguageCode] (the
/// in-app UI language).
///
/// Pure and widget-free so it stays unit-testable.
Locale resolveNotificationLocale(
  Locale system,
  List<Locale> supported,
  String fallbackLanguageCode,
) {
  for (final locale in supported) {
    if (locale.languageCode == system.languageCode) return locale;
  }
  return Locale(fallbackLanguageCode);
}
