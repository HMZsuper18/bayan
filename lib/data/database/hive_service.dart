import 'package:hive_flutter/hive_flutter.dart';
import '../models/surah_model.dart';
import '../models/verse_model.dart';
import '../models/reciter_model.dart';
import '../models/search_result_model.dart';
import 'quran_index.dart';

class HiveService {
  static const String _surahsBox = 'surahs';
  static const String _versesBox = 'verses';
  static const String _recitersBox = 'reciters';
  static const String _tafseerBox = 'tafseer';
  static const String _qiraatBox = 'qiraat';
  static const String _translationBox = 'translations';
  static const String _bookmarksBox = 'bookmarks';
  static const String _downloadCheckpointsBox = 'download_checkpoints';

  static Future<void> init() async {
    await Hive.initFlutter();
    Hive.registerAdapter(SurahModelAdapter());
    Hive.registerAdapter(VerseModelAdapter());
    Hive.registerAdapter(ReciterModelAdapter());
    await Future.wait([
      Hive.openBox<SurahModel>(_surahsBox),
      Hive.openBox<VerseModel>(_versesBox),
      Hive.openBox<ReciterModel>(_recitersBox),
      Hive.openBox<String>(_tafseerBox),
      Hive.openBox<String>(_qiraatBox),
      Hive.openBox<String>(_translationBox),
      Hive.openBox<String>(_bookmarksBox),
      Hive.openBox<String>(_downloadCheckpointsBox),
    ]);
  }

  static Box<SurahModel> get surahsBox => Hive.box<SurahModel>(_surahsBox);
  static Box<VerseModel> get versesBox => Hive.box<VerseModel>(_versesBox);
  static Box<ReciterModel> get recitersBox =>
      Hive.box<ReciterModel>(_recitersBox);
  static Box<String> get tafseerBox => Hive.box<String>(_tafseerBox);
  static Box<String> get qiraatBox => Hive.box<String>(_qiraatBox);
  static Box<String> get translationBox => Hive.box<String>(_translationBox);
  static Box<String> get bookmarksBox => Hive.box<String>(_bookmarksBox);
  static Box<String> get downloadCheckpointsBox =>
      Hive.box<String>(_downloadCheckpointsBox);

  static Future<void> seedSurahs(List<SurahModel> surahs) async {
    final box = surahsBox;
    if (box.isEmpty) {
      for (final surah in surahs) {
        await box.put(surah.id, surah);
      }
    }
  }

  static Future<void> seedVerses(List<VerseModel> verses) async {
    final box = versesBox;
    if (box.isEmpty) {
      for (final verse in verses) {
        await box.put(verse.id, verse);
      }
    }
  }

  static Future<void> seedReciters(List<ReciterModel> reciters) async {
    final box = recitersBox;
    if (box.isEmpty) {
      for (final reciter in reciters) {
        await box.put(reciter.id, reciter);
      }
    }
  }

  static Future<void> seedTafseer(Map<String, String> entries) async {
    final box = tafseerBox;
    if (box.isEmpty) {
      await box.putAll(entries);
    }
  }

  static Future<void> seedQiraat(Map<String, String> entries) async {
    final box = qiraatBox;
    if (box.isEmpty) {
      await box.putAll(entries);
    }
  }

  static Future<void> seedTranslations(Map<String, String> entries) async {
    final box = translationBox;
    if (box.isEmpty) {
      await box.putAll(entries);
    }
  }

  static List<SurahModel> getAllSurahs() => surahsBox.values.toList();

  static VerseModel? getVerse(int verseId) => versesBox.get(verseId);

  static List<VerseModel> getVersesBySurah(int surahId) {
    return versesBox.values.where((v) => v.surahId == surahId).toList();
  }

  static List<VerseModel> getVersesByPage(int page) {
    return versesBox.values.where((v) => v.page == page).toList();
  }

  static String? getTafseer(String verseKey, {String language = 'ar'}) {
    final String? result;
    if (language == 'ar') {
      result = tafseerBox.get(verseKey);
    } else {
      result = tafseerBox.get('$language:$verseKey');
    }
    return result ?? tafseerBox.get(verseKey);
  }

  static String? getTranslation(String verseKey, {String language = 'ar'}) {
    return translationBox.get('tr_$language:$verseKey');
  }

  static String? getQiraat(String verseKey) => qiraatBox.get(verseKey);

  static List<ReciterModel> getAllReciters() => recitersBox.values.toList();

  static List<int> getDownloadCheckpoint(String reciterId) {
    final raw = downloadCheckpointsBox.get(reciterId);
    if (raw == null || raw.isEmpty) return [];
    return raw.split(',').map(int.parse).toList();
  }

  static void saveDownloadCheckpoint(String reciterId, List<int> completedSurahs) {
    downloadCheckpointsBox.put(
      reciterId,
      completedSurahs.map((s) => s.toString()).join(','),
    );
  }

  static void clearDownloadCheckpoint(String reciterId) {
    downloadCheckpointsBox.delete(reciterId);
  }

  static String _normalizeArabic(String s) {
    return s
        .replaceAll(RegExp(r'[\u064B-\u0652\u0640\u0670\u0653-\u065F]'), '')
        .replaceAll(RegExp(r'[أإآٱ\u0671]'), 'ا')
        .replaceAll('ة', 'ه')
        .replaceAll('ى', 'ي')
        .replaceAll(RegExp(r'[^\u0621-\u064A0-9 ]'), '')
        .trim();
  }

  static String _normalizeEnglish(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  static int _levenshtein(String a, String b, [int maxDist = 3]) {
    if (a.length < b.length) return _levenshtein(b, a, maxDist);
    if (b.isEmpty) return a.length;
    if (a.length - b.length > maxDist) return maxDist + 1;
    var prev = List.generate(b.length + 1, (i) => i);
    var curr = List.filled(b.length + 1, 0);
    for (var i = 0; i < a.length; i++) {
      curr[0] = i + 1;
      var rowMin = curr[0];
      for (var j = 0; j < b.length; j++) {
        final cost = a[i] == b[j] ? 0 : 1;
        curr[j + 1] = [
          curr[j] + 1,
          prev[j + 1] + 1,
          prev[j] + cost,
        ].reduce((x, y) => x < y ? x : y);
        if (curr[j + 1] < rowMin) rowMin = curr[j + 1];
      }
      if (rowMin > maxDist) return maxDist + 1;
      final tmp = prev;
      prev = curr;
      curr = tmp;
    }
    return prev.last;
  }

  static int _fuzzyThreshold(String query) {
    final len = query.length;
    if (len <= 3) return 1;
    if (len <= 6) return 2;
    return 3;
  }

  static int? _parseNumber(String s) {
    const arabic = '٠١٢٣٤٥٦٧٨٩';
    var result = 0;
    var found = false;
    for (var i = 0; i < s.length; i++) {
      final idx = arabic.indexOf(s[i]);
      if (idx >= 0) {
        result = result * 10 + idx;
        found = true;
      } else if (s[i].codeUnitAt(0) >= 48 && s[i].codeUnitAt(0) <= 57) {
        result = result * 10 + (s[i].codeUnitAt(0) - 48);
        found = true;
      } else if (found) {
        break;
      }
    }
    return found ? result : null;
  }

  static List<String>? _cachedNormalizedSurahNames;
  static List<String>? _cachedNormalizedEnglishNames;

  static const int _maxSearchResults = 10;

  static void _ensureSurahCache() {
    if (_cachedNormalizedSurahNames != null) return;
    _cachedNormalizedSurahNames =
        surahsBox.values.map((s) => _normalizeArabic(s.name)).toList();
    _cachedNormalizedEnglishNames =
        surahsBox.values.map((s) => _normalizeEnglish(s.englishName)).toList();
  }

  static SearchResults search(String rawQuery) {
    final q = rawQuery.trim();
    if (q.isEmpty) return const SearchResults();

    _ensureSurahCache();

    final allSurahs = surahsBox.values.toList();
    final surahs = <SurahModel>[];
    final seenSurahIds = <int>{};

    final num = _parseNumber(q);
    final stripped = q.replaceAll(RegExp(r'[\d\u0660-\u0669]'), '').trim();
    final hasArabic = RegExp(r'[\u0621-\u064A]').hasMatch(stripped);
    final hasEnglish = RegExp(r'[a-zA-Z]').hasMatch(stripped);

    // Numeric queries: match surahs by surah number and by page number.
    if (num != null && !hasArabic && !hasEnglish) {
      if (num >= 1 && num <= 114 && seenSurahIds.add(num)) {
        final s = surahsBox.get(num);
        if (s != null) surahs.add(s);
      }
      if (num >= 1 && num <= 604) {
        final pageSurahId = QuranIndexService.instance.getPageSurahId(num);
        if (seenSurahIds.add(pageSurahId)) {
          final s = surahsBox.get(pageSurahId);
          if (s != null) surahs.add(s);
        }
      }
      return SearchResults(surahs: surahs);
    }

    // Arabic name search
    if (hasArabic) {
      final normalizedQuery = _normalizeArabic(stripped);
      if (normalizedQuery.isNotEmpty) {
        _matchSurahs(
          allSurahs,
          _cachedNormalizedSurahNames!,
          normalizedQuery,
          surahs,
          seenSurahIds,
        );
      }
    }

    // English name search
    if (hasEnglish || stripped.isNotEmpty) {
      final normEnglishQuery = _normalizeEnglish(stripped);
      if (normEnglishQuery.isNotEmpty) {
        _matchSurahs(
          allSurahs,
          _cachedNormalizedEnglishNames!,
          normEnglishQuery,
          surahs,
          seenSurahIds,
          wordSplit: true,
        );
      }
    }

    return SearchResults(surahs: surahs);
  }

  /// Matches surahs against a normalized query. Exact/substring matches are
  /// preferred; fuzzy matches are only used as a fallback. Results are capped
  /// at [_maxSearchResults].
  static void _matchSurahs(
    List<SurahModel> allSurahs,
    List<String> normalizedNames,
    String normalizedQuery,
    List<SurahModel> out,
    Set<int> seenIds, {
    bool wordSplit = false,
  }) {
    for (int i = 0; i < allSurahs.length && out.length < _maxSearchResults; i++) {
      final s = allSurahs[i];
      if (seenIds.contains(s.id)) continue;
      if (normalizedNames[i].contains(normalizedQuery)) {
        seenIds.add(s.id);
        out.add(s);
      }
    }
    if (out.isNotEmpty) return;

    final threshold = _fuzzyThreshold(normalizedQuery);
    for (int i = 0; i < allSurahs.length && out.length < _maxSearchResults; i++) {
      final s = allSurahs[i];
      if (seenIds.contains(s.id)) continue;
      if (_levenshtein(normalizedNames[i], normalizedQuery, threshold) <=
          threshold) {
        seenIds.add(s.id);
        out.add(s);
        continue;
      }
      if (wordSplit) {
        final words = s.englishName
            .toLowerCase()
            .split(RegExp(r'[^a-z0-9]+'))
            .where((w) => w.isNotEmpty);
        for (final word in words) {
          if (_levenshtein(word, normalizedQuery, threshold) <= threshold) {
            seenIds.add(s.id);
            out.add(s);
            break;
          }
        }
      }
    }
  }

  static List<SurahModel> searchSurahs(String query) {
    return search(query).surahs;
  }
}