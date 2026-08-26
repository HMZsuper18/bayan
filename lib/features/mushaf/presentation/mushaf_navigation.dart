import 'package:flutter/material.dart';
import '../../../data/database/hive_service.dart';
import '../../../data/database/settings_service.dart';
import '../../../data/models/navigation_target.dart';
import 'mushaf_page_viewer.dart';
import 'mushaf_screen.dart';

/// Opens the mushaf using the user's preferred layout (pages vs surahs).
class MushafNavigation {
  MushafNavigation._();

  static bool get _usePages => SettingsService.mushafLayout == 'pages';

  static Widget _pagesView({
    required int page,
    int? verseId,
    int? openTafseerForVerseId,
  }) {
    return MushafPageViewer(
      initialPage: page,
      initialVerseId: verseId,
      openTafseerForVerseId: openTafseerForVerseId,
    );
  }

  static Widget _surahView({
    required int surahId,
    int? verseNumber,
    int? openTafseerForVerseId,
  }) {
    return MushafScreen(
      initialSurahId: surahId,
      initialVerseNumber: verseNumber,
      openTafseerForVerseId: openTafseerForVerseId,
    );
  }

  static Widget forPage(int page, {int? verseId}) {
    if (_usePages) return _pagesView(page: page, verseId: verseId);

    if (verseId != null) {
      final verse = HiveService.getVerse(verseId);
      if (verse != null) {
        return _surahView(
          surahId: verse.surahId,
          verseNumber: verse.verseNumber,
        );
      }
    }

    final pageVerses = HiveService.getVersesByPage(page);
    if (pageVerses.isNotEmpty) {
      final first = pageVerses.first;
      return _surahView(
        surahId: first.surahId,
        verseNumber: first.verseNumber,
      );
    }

    return _surahView(surahId: 1);
  }

  static Widget forSurah(int surahId, {int? verseNumber, int? verseId}) {
    if (_usePages) {
      if (verseId != null) {
        final verse = HiveService.getVerse(verseId);
        if (verse != null) {
          return _pagesView(page: verse.page, verseId: verse.id);
        }
      }
      if (verseNumber != null) {
        final verses = HiveService.getVersesBySurah(surahId);
        final verse = verses.where((v) => v.verseNumber == verseNumber).firstOrNull;
        if (verse != null) {
          return _pagesView(page: verse.page, verseId: verse.id);
        }
      }
      final page = HiveService.getVersesBySurah(surahId).firstOrNull?.page ?? 1;
      return _pagesView(page: page);
    }

    return _surahView(surahId: surahId, verseNumber: verseNumber);
  }

  static Widget forVerse({
    required int surahId,
    required int verseNumber,
    required int page,
    required int verseId,
    int? openTafseerForVerseId,
  }) {
    if (_usePages) {
      return _pagesView(
        page: page,
        verseId: verseId,
        openTafseerForVerseId: openTafseerForVerseId,
      );
    }
    return _surahView(
      surahId: surahId,
      verseNumber: verseNumber,
      openTafseerForVerseId: openTafseerForVerseId,
    );
  }

  static Widget forTarget(NavigationTarget target) {
    if (_usePages) {
      return _pagesView(
        page: target.targetPage,
        verseId: target.targetVerse,
      );
    }
    final verse = HiveService.getVerse(target.targetVerse);
    return _surahView(
      surahId: verse?.surahId ?? target.surahNumber,
      verseNumber: verse?.verseNumber,
    );
  }

  /// Opens the mushaf at the user's last saved position, converted to the
  /// active layout (page view or surah view).
  static Widget forSavedPosition() {
    if (_usePages) {
      return _pagesView(page: SettingsService.lastMushafPage);
    }
    return _surahView(surahId: SettingsService.lastMushafSurahId);
  }

  static Future<void> open(
    BuildContext context,
    Widget page, {
    bool replace = false,
  }) {
    final route = MaterialPageRoute(builder: (_) => page);
    if (replace) {
      return Navigator.of(context).pushReplacement(route);
    }
    return Navigator.of(context).push(route);
  }

  static void openOnNextFrame(BuildContext context, Widget page) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      open(context, page);
    });
  }
}
