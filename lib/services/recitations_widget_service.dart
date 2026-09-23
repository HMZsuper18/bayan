import 'dart:ui';

import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:home_widget/home_widget.dart';

import '../core/utils/reciter_utils.dart';
import '../data/database/hive_service.dart';
import '../data/database/settings_service.dart';
import '../data/models/reciter_model.dart';
import '../l10n/app_localizations.dart';
import 'reciter_store_service.dart';

/// Pushes data to the home screen recitations widget:
///
/// * reciter list — **downloaded reciters only**, ranked by the user's real
///   listen counts, then by [ReciterModel.popularity] (most famous first).
///   Slots with no downloaded reciter stay blank on the widget.
/// * playback playbar state (reciter, surah, progress, paused/playing).
/// * language / theme so the native provider can follow the app.
class RecitationsWidgetService {
  RecitationsWidgetService._();

  static const _widgetName = 'RecitationsWidgetProvider';

  /// Maximum slots pushed to the widget (4x4 = 8 rows x 2 columns).
  static const maxReciters = 16;
  static const _settingsBox = 'settings';

  static String _listenKey(String reciterId) => 'reciter_listen_count_$reciterId';

  static void recordListen(String reciterId) {
    try {
      final box = Hive.box<String>(_settingsBox);
      final current = int.tryParse(box.get(_listenKey(reciterId)) ?? '') ?? 0;
      box.put(_listenKey(reciterId), (current + 1).toString());
    } catch (_) {}
  }

  static int listenCount(String reciterId) {
    try {
      final box = Hive.box<String>(_settingsBox);
      return int.tryParse(box.get(_listenKey(reciterId)) ?? '') ?? 0;
    } catch (_) {
      return 0;
    }
  }

  static Future<void> update({
    String? lastPlayedReciterId,
    String? lastPlayedReciterName,
  }) async {
    try {
      final l10n = await AppLocalizations.delegate.load(
        Locale(SettingsService.uiLanguage),
      );
      final selected = await _selectReciters(lastPlayedReciterId);

      for (var i = 0; i < maxReciters; i++) {
        final key = 'reciter_${i + 1}';
        if (i < selected.length) {
          final r = selected[i];
          await HomeWidget.saveWidgetData('${key}_id', r.id);
          await HomeWidget.saveWidgetData(
            '${key}_name',
            reciterDisplayName(l10n, r),
          );
        } else {
          // Blank slot: not downloaded (or not enough reciters).
          await HomeWidget.saveWidgetData('${key}_id', '');
          await HomeWidget.saveWidgetData('${key}_name', '');
        }
      }

      await HomeWidget.saveWidgetData('reciter_count', selected.length);
      await HomeWidget.saveWidgetData('widget_lang', SettingsService.uiLanguage);
      await HomeWidget.saveWidgetData(
        'widget_theme',
        SettingsService.isDarkMode ? 'dark' : 'light',
      );
      await HomeWidget.saveWidgetData('reciters_widget_title', l10n.reciters);
      await HomeWidget.saveWidgetData(
        'reciters_empty_label',
        l10n.downloadReciter,
      );
      await HomeWidget.saveWidgetData('widget_player_stop_label', l10n.stop);
      await HomeWidget.saveWidgetData('widget_player_cancel_label', l10n.cancel);
      await HomeWidget.saveWidgetData('widget_player_toggle_label', l10n.pause);

      await HomeWidget.updateWidget(name: _widgetName);
    } on MissingPluginException {
      // home_widget not available on desktop.
    }
  }

  /// Lightweight push of the playbar state; called (throttled) by the audio
  /// service whenever playback starts, pauses, advances a surah, or stops.
  static Future<void> syncPlayback({
    required bool active,
    ReciterModel? reciter,
    int? surahId,
    bool paused = false,
    int progress = 0,
  }) async {
    try {
      await HomeWidget.saveWidgetData('widget_player_active', active);

      if (active && reciter != null) {
        final l10n = await AppLocalizations.delegate.load(
          Locale(SettingsService.uiLanguage),
        );
        final surah =
            surahId != null ? HiveService.surahsBox.get(surahId) : null;
        final surahName = surah == null
            ? ''
            : (SettingsService.uiLanguage == 'en'
                ? surah.englishName
                : surah.name);

        await HomeWidget.saveWidgetData(
          'widget_player_name',
          reciterDisplayName(l10n, reciter),
        );
        await HomeWidget.saveWidgetData(
          'widget_player_surah',
          surahName.isEmpty ? '' : '${l10n.surahLabel} $surahName',
        );
        await HomeWidget.saveWidgetData('widget_player_paused', paused);
        await HomeWidget.saveWidgetData(
          'widget_player_progress',
          progress.clamp(0, 100).toInt(),
        );
        await HomeWidget.saveWidgetData(
          'widget_player_toggle_label',
          paused ? l10n.resume : l10n.pause,
        );
        await HomeWidget.saveWidgetData('widget_player_stop_label', l10n.stop);
        await HomeWidget.saveWidgetData(
          'widget_player_cancel_label',
          l10n.cancel,
        );
        await HomeWidget.saveWidgetData(
          'widget_lang',
          SettingsService.uiLanguage,
        );
        await HomeWidget.saveWidgetData(
          'widget_theme',
          SettingsService.isDarkMode ? 'dark' : 'light',
        );
      }

      await HomeWidget.updateWidget(name: _widgetName);
    } on MissingPluginException {
      // home_widget not available on desktop.
    }
  }

  static Future<void> refresh() async {
    await update();
  }

  /// Downloaded reciters only, ranked by the user's listen counts first and
  /// by [ReciterModel.popularity] (famous fill) second. Undownloaded reciters
  /// are never returned — their widget slots stay blank.
  static Future<List<ReciterModel>> _selectReciters(String? preferId) async {
    final downloadedIds = await _downloadedIds();
    var pool = <ReciterModel>[];
    try {
      pool = HiveService.getAllReciters();
    } catch (_) {}

    final downloaded =
        pool.where((r) => downloadedIds.contains(r.id)).toList();
    if (downloaded.isEmpty) return const [];

    downloaded.sort((a, b) {
      final byListen = listenCount(b.id).compareTo(listenCount(a.id));
      if (byListen != 0) return byListen;
      return b.popularity.compareTo(a.popularity);
    });

    if (preferId != null) {
      final idx = downloaded.indexWhere((r) => r.id == preferId);
      if (idx > 0) {
        final preferred = downloaded.removeAt(idx);
        downloaded.insert(0, preferred);
      }
    }

    return downloaded.take(maxReciters).toList();
  }

  static Future<Set<String>> _downloadedIds() async {
    try {
      return await ReciterStoreService.instance.getDownloadedReciterIds();
    } catch (_) {
      return <String>{};
    }
  }
}
