import '../models/search_result_model.dart';
import '../database/hive_service.dart';
import '../database/quran_index.dart';
import '../models/surah_model.dart';
import '../models/verse_model.dart';
import '../models/reciter_model.dart';

class QuranRepository {
  List<SurahModel> getAllSurahs() => HiveService.getAllSurahs();

  SurahModel? getSurahById(int id) => HiveService.surahsBox.get(id);

  List<VerseModel> getVersesBySurah(int surahId) =>
      HiveService.getVersesBySurah(surahId);

  List<VerseModel> getVersesByPage(int page) =>
      HiveService.getVersesByPage(page);

  VerseModel? getVerse(int id) => HiveService.getVerse(id);

  String? getTafseer(String verseKey, {String language = 'ar'}) =>
      HiveService.getTafseer(verseKey, language: language);

  String? getTranslation(String verseKey, {String language = 'ar'}) =>
      HiveService.getTranslation(verseKey, language: language);

  String? getQiraat(String verseKey) => HiveService.getQiraat(verseKey);

  List<ReciterModel> getAllReciters() => HiveService.getAllReciters();

  SearchResults search(String query) => HiveService.search(query);

  List<SurahModel> searchSurahs(String query) => HiveService.searchSurahs(query);

  int getSurahPageStart(int surahId) =>
      QuranIndexService.instance.getSurahPage(surahId);
}