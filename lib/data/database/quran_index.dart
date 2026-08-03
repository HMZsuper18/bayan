import '../models/navigation_target.dart';
import '../models/verse_model.dart';
import 'hive_service.dart';

class QuranIndexService {
  QuranIndexService._();
  static final QuranIndexService instance = QuranIndexService._();

  bool _initialized = false;

  final Map<int, int> _surahFirstPage = {};
  final Map<int, int> _surahFirstVerse = {};
  final Map<int, int> _juzFirstPage = {};
  final Map<int, int> _juzFirstVerse = {};
  final Map<int, int> _hizbFirstPage = {};
  final Map<int, int> _hizbFirstVerse = {};
  final Map<int, int> _pageJuz = {};
  final Map<int, int> _pageSurahId = {};
  final Map<int, String> _pageSurahName = {};

  void init() {
    if (_initialized) return;
    _initialized = true;

    final verses = HiveService.versesBox.values;

    final juzVerses = <int, List<VerseModel>>{};
    for (final v in verses) {
      (juzVerses.putIfAbsent(v.juz, () => <VerseModel>[])..add(v));
    }

    for (final entry in juzVerses.entries) {
      entry.value.sort((a, b) => a.id.compareTo(b.id));
      final sorted = entry.value;
      _juzFirstPage[entry.key] = sorted.first.page;
      _juzFirstVerse[entry.key] = sorted.first.id;

      final midIdx = sorted.length >> 1;
      _hizbFirstPage[2 * entry.key - 1] = sorted.first.page;
      _hizbFirstVerse[2 * entry.key - 1] = sorted.first.id;
      _hizbFirstPage[2 * entry.key] = sorted[midIdx].page;
      _hizbFirstVerse[2 * entry.key] = sorted[midIdx].id;
    }

    final surahVerses = <int, List<VerseModel>>{};
    for (final v in verses) {
      (surahVerses.putIfAbsent(v.surahId, () => <VerseModel>[])..add(v));
    }
    for (final entry in surahVerses.entries) {
      entry.value.sort((a, b) => a.id.compareTo(b.id));
      _surahFirstPage[entry.key] = entry.value.first.page;
      _surahFirstVerse[entry.key] = entry.value.first.id;
    }

    final pageVerses = <int, List<VerseModel>>{};
    for (final v in verses) {
      (pageVerses.putIfAbsent(v.page, () => <VerseModel>[])..add(v));
    }
    for (final entry in pageVerses.entries) {
      entry.value.sort((a, b) => a.id.compareTo(b.id));
      _pageJuz[entry.key] = entry.value.first.juz;
      _pageSurahId[entry.key] = entry.value.first.surahId;
      final surah = HiveService.surahsBox.get(entry.value.first.surahId);
      _pageSurahName[entry.key] = surah?.name ?? '';
    }
  }

  void _ensureInitialized() {
    if (!_initialized) init();
  }

  int getSurahPage(int surahId) { _ensureInitialized(); return _surahFirstPage[surahId] ?? 1; }
  int getSurahStartVerse(int surahId) { _ensureInitialized(); return _surahFirstVerse[surahId] ?? 1; }
  int getJuzPage(int juzNum) { _ensureInitialized(); return _juzFirstPage[juzNum] ?? 1; }
  int getJuzStartVerse(int juzNum) { _ensureInitialized(); return _juzFirstVerse[juzNum] ?? 1; }
  int getHizbPage(int hizbNum) { _ensureInitialized(); return _hizbFirstPage[hizbNum] ?? 1; }
  int getHizbStartVerse(int hizbNum) { _ensureInitialized(); return _hizbFirstVerse[hizbNum] ?? 1; }
  int getPageJuz(int pageNum) { _ensureInitialized(); return _pageJuz[pageNum] ?? 1; }
  int getPageSurahId(int pageNum) { _ensureInitialized(); return _pageSurahId[pageNum] ?? 1; }
  String getPageSurahName(int pageNum) { _ensureInitialized(); return _pageSurahName[pageNum] ?? ''; }

  NavigationTarget? navigateToSurah(int surahId) {
    _ensureInitialized();
    final page = _surahFirstPage[surahId];
    final verse = _surahFirstVerse[surahId] ?? 1;
    if (page == null) return null;
    final surah = HiveService.surahsBox.get(surahId);
    return NavigationTarget(
      navigationType: 'surah',
      targetPage: page,
      surahName: surah?.name ?? '',
      surahNumber: surahId,
      targetVerse: verse,
    );
  }

  NavigationTarget? navigateToJuz(int juzNum) {
    _ensureInitialized();
    final page = _juzFirstPage[juzNum];
    final verse = _juzFirstVerse[juzNum] ?? 1;
    if (page == null) return null;
    final surahId = _pageSurahId[page] ?? 1;
    final surah = HiveService.surahsBox.get(surahId);
    return NavigationTarget(
      navigationType: 'juz',
      targetPage: page,
      surahName: surah?.name ?? '',
      surahNumber: surahId,
      targetVerse: verse,
    );
  }

  NavigationTarget? navigateToHizb(int hizbNum) {
    _ensureInitialized();
    final page = _hizbFirstPage[hizbNum];
    final verse = _hizbFirstVerse[hizbNum] ?? 1;
    if (page == null) return null;
    final surahId = _pageSurahId[page] ?? 1;
    final surah = HiveService.surahsBox.get(surahId);
    return NavigationTarget(
      navigationType: 'hizb',
      targetPage: page,
      surahName: surah?.name ?? '',
      surahNumber: surahId,
      targetVerse: verse,
    );
  }
}
