import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:home_widget/home_widget.dart';
import '../core/utils/quran_text_normalizer.dart';
import '../data/database/hive_service.dart';
import '../data/database/settings_service.dart';
import '../l10n/app_localizations.dart';
import 'ayah_of_week_service.dart';

/// Pushes this week's ayah (and theme / UI-language metadata) to the home
/// screen ayah widget so it mirrors the dashboard's Ayah-of-the-Week card.
class AyahWidgetService {
  AyahWidgetService._();
  static const _widgetName = 'AyahWidgetProvider';

  static String _arabicIndic(int n) {
    const digits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    return n.toString().split('').map((c) => digits[int.parse(c)]).join();
  }

  static Future<void> update() async {
    try {
      final lang = SettingsService.uiLanguage;
      final trLang = SettingsService.translationLanguage;
      final l10n = await AppLocalizations.delegate.load(Locale(lang));

      await HomeWidget.saveWidgetData(
        'widget_theme',
        SettingsService.isDarkMode ? 'dark' : 'light',
      );
      await HomeWidget.saveWidgetData('widget_lang', lang);
      await HomeWidget.saveWidgetData('ayah_title', l10n.ayahOfTheWeek);
      await HomeWidget.saveWidgetData(
        'ayah_week',
        AyahOfWeekService.weekLabel,
      );

      final verse = AyahOfWeekService.verse;
      final surah = verse == null
          ? null
          : HiveService.surahsBox.get(verse.surahId);
      if (verse == null || surah == null) {
        // Hive not seeded yet — clear content; the next refresh after seed
        // (or the next app open) will fill it in.
        await HomeWidget.saveWidgetData('ayah_text', '');
        await HomeWidget.saveWidgetData('ayah_translation', '');
        await HomeWidget.saveWidgetData('ayah_reference', '');
        await HomeWidget.updateWidget(name: _widgetName);
        return;
      }

      final translation = trLang != 'ar'
          ? HiveService.getTranslation(
              '${verse.surahId}:${verse.verseNumber}',
              language: trLang,
            )
          : null;
      final surahName = switch (trLang) {
        'en' => surah.englishName,
        _ => surah.name,
      };
      final reference = trLang == 'en'
          ? '$surahName ${verse.verseNumber}'
          : '${l10n.surah} $surahName — ${_arabicIndic(verse.verseNumber)}';

      await HomeWidget.saveWidgetData(
        'ayah_text',
        QuranTextNormalizer.preProcessForDisplay(verse.textUthmani),
      );
      await HomeWidget.saveWidgetData('ayah_translation', translation ?? '');
      await HomeWidget.saveWidgetData('ayah_reference', reference);
      await HomeWidget.updateWidget(name: _widgetName);
    } on MissingPluginException {
      // home_widget not available on desktop.
    }
  }

  static Future<void> refresh() async {
    await update();
  }
}
