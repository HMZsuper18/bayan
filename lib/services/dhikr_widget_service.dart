import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:home_widget/home_widget.dart';
import '../core/utils/azkar_time_logic.dart';
import '../core/utils/quran_text_normalizer.dart';
import '../data/database/settings_service.dart';
import '../l10n/app_localizations.dart';

/// Pushes time-appropriate azkar (and its theme / UI-language metadata) to the
/// home screen dhikr widget so it mirrors the dashboard's Azkar card.
class DhikrWidgetService {
  DhikrWidgetService._();
  static const _widgetName = 'DhikrWidgetProvider';

  /// Refreshes the widget with the current time-appropriate azkar. When the
  /// dashboard's [AzkarController] already computed [type]/[item] (it has live
  /// prayer times for the Friday rule), pass them so the widget shows exactly
  /// what the card shows.
  static Future<void> update({
    AzkarWidgetType? type,
    AzkarItem? item,
  }) async {
    try {
      final now = DateTime.now();
      final resolvedType = type ?? getAzkarType(now);
      final resolvedItem = item ?? getAzkarItem(resolvedType, now);
      final lang = SettingsService.uiLanguage;
      // Translation follows the same setting as the dashboard Azkar card:
      // 'ar' = disabled (no translation), 'en'/'ur' show that language.
      final transLang = SettingsService.translationLanguage;
      final l10n = await AppLocalizations.delegate.load(Locale(lang));

      final isKahf = resolvedType == AzkarWidgetType.kahf;
      final title = switch (resolvedType) {
        AzkarWidgetType.morning => l10n.morningAzkar,
        AzkarWidgetType.evening => l10n.eveningAzkar,
        AzkarWidgetType.kahf => l10n.suratAlKahf,
        AzkarWidgetType.general => l10n.generalAzkar,
      };
      final period = switch (resolvedType) {
        AzkarWidgetType.morning => '05:00–12:00',
        AzkarWidgetType.evening => '20:00–01:00',
        AzkarWidgetType.kahf => l10n.friday,
        AzkarWidgetType.general => l10n.always,
      };

      await HomeWidget.saveWidgetData(
        'widget_theme',
        SettingsService.isDarkMode ? 'dark' : 'light',
      );
      await HomeWidget.saveWidgetData('widget_lang', lang);
      await HomeWidget.saveWidgetData(
        'dhikr_type',
        resolvedType.name,
      );
      await HomeWidget.saveWidgetData('dhikr_title', title);
      await HomeWidget.saveWidgetData('dhikr_period', period);
      await HomeWidget.saveWidgetData(
        'dhikr_text',
        isKahf
            ? ''
            : QuranTextNormalizer.preProcessForDisplay(resolvedItem.text),
      );
      await HomeWidget.saveWidgetData(
        'dhikr_translation',
        (isKahf ? null : resolvedItem.translatedText(transLang)) ?? '',
      );
      await HomeWidget.saveWidgetData(
        'dhikr_reference',
        isKahf
            ? ''
            : resolvedItem.translatedReference(lang) ??
                  resolvedItem.reference ??
                  '',
      );
      await HomeWidget.saveWidgetData(
        'dhikr_kahf_label',
        l10n.readSuratAlKahf,
      );
      await HomeWidget.updateWidget(name: _widgetName);
    } on MissingPluginException {
      // home_widget not available on desktop.
    }
  }

  static Future<void> refresh() async {
    await update();
  }
}
