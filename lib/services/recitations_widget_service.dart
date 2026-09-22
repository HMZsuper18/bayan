import 'dart:math';
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

/// Pushes up to [maxRows] reciters to the home screen recitations widget:
/// most-listened first (tracked in Hive), then random fill from downloaded
/// reciters (falling back to the full seeded list).
class RecitationsWidgetService {
  RecitationsWidgetService._();

  static const _widgetName = 'RecitationsWidgetProvider';
  static const maxRows = 8;
  static const _settingsBox = 'settings';

  /// Seed order used when no listening history exists yet.
  static const _fallbackIds = [
    'mishary',
    'sudais',
    'shuraim',
    'muaiqly',
    'dosari',
    'ghamdi',
    'abdulbasit',
    'husary',
  ];

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
      final reciters = await _selectReciters(lastPlayedReciterId);
      final selected = reciters.take(maxRows).toList();

      for (var i = 0; i < maxRows; i++) {
        final key = 'reciter_${i + 1}';
        if (i < selected.length) {
          final r = selected[i];
          await HomeWidget.saveWidgetData('${key}_id', r.id);
          await HomeWidget.saveWidgetData(
            '${key}_name',
            reciterDisplayName(l10n, r),
          );
        } else {
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

      await HomeWidget.updateWidget(name: _widgetName);
    } on MissingPluginException {
      // home_widget not available on desktop.
    }
  }

  static Future<void> refresh() async {
    await update();
  }

  /// Most-listened first, then random fill from available reciters.
  static Future<List<ReciterModel>> _selectReciters(String? preferId) async {
    final downloadedIds = await _downloadedIds();
    var pool = <ReciterModel>[];
    try {
      pool = HiveService.getAllReciters();
    } catch (_) {}

    if (pool.isEmpty) {
      return const [];
    }

    final byId = {for (final r in pool) r.id: r};
    final ranked = <ReciterModel>[];
    final seen = <String>{};

    void add(ReciterModel r) {
      if (seen.add(r.id)) ranked.add(r);
    }

    if (preferId != null && byId.containsKey(preferId)) {
      add(byId[preferId]!);
    }

    // Prefer downloaded reciters that have listening history.
    final withHistory = pool.where((r) => listenCount(r.id) > 0).toList()
      ..sort((a, b) => listenCount(b.id).compareTo(listenCount(a.id)));
    for (final r in withHistory) {
      add(r);
    }

    // Random fill from downloaded reciters, then any remaining seeded ones.
    final random = Random();
    List<ReciterModel> shuffled(List<ReciterModel> list) {
      final copy = List<ReciterModel>.from(list)..shuffle(random);
      return copy;
    }

    final downloaded = pool.where((r) => downloadedIds.contains(r.id)).toList();
    for (final r in shuffled(downloaded)) {
      add(r);
    }

    for (final id in _fallbackIds) {
      final r = byId[id];
      if (r != null) add(r);
    }

    for (final r in shuffled(pool)) {
      add(r);
    }

    return ranked;
  }

  static Future<Set<String>> _downloadedIds() async {
    try {
      return await ReciterStoreService.instance.getDownloadedReciterIds();
    } catch (_) {
      return <String>{};
    }
  }
}
