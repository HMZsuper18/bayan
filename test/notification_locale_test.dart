import 'dart:ui';

import 'package:bayan/core/utils/notification_locale.dart';
import 'package:bayan/l10n/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final supported = AppLocalizations.supportedLocales;

  group('resolveNotificationLocale', () {
    test('matches a supported system language exactly', () {
      expect(
        resolveNotificationLocale(const Locale('ar'), supported, 'en'),
        const Locale('ar'),
      );
      expect(
        resolveNotificationLocale(const Locale('ur'), supported, 'en'),
        const Locale('ur'),
      );
      expect(
        resolveNotificationLocale(const Locale('en'), supported, 'ar'),
        const Locale('en'),
      );
    });

    test('ignores the region and still matches', () {
      expect(
        resolveNotificationLocale(const Locale('ar', 'EG'), supported, 'en'),
        const Locale('ar'),
      );
      expect(
        resolveNotificationLocale(const Locale('ur', 'PK'), supported, 'en'),
        const Locale('ur'),
      );
    });

    test('falls back to the in-app language for unsupported systems', () {
      expect(
        resolveNotificationLocale(const Locale('fr'), supported, 'ar'),
        const Locale('ar'),
      );
      expect(
        resolveNotificationLocale(const Locale('de'), supported, 'en'),
        const Locale('en'),
      );
      expect(
        resolveNotificationLocale(const Locale('id'), supported, 'ur'),
        const Locale('ur'),
      );
    });
  });
}
