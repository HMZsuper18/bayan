import 'dart:async';
import 'dart:convert';
import '../data/database/hive_service.dart';
import '../data/models/bookmark_model.dart';
import '../data/models/verse_model.dart';

/// Cross-cutting singleton for user bookmarks. Persists each bookmark as JSON
/// in a dedicated Hive box and exposes a live stream for UI updates.
class BookmarkService {
  BookmarkService._();

  static final BookmarkService instance = BookmarkService._();

  final StreamController<List<BookmarkModel>> _controller =
      StreamController<List<BookmarkModel>>.broadcast();

  Stream<List<BookmarkModel>> get stream => _controller.stream;

  static String _key(int verseId) => verseId.toString();

  List<BookmarkModel> get bookmarks {
    final box = HiveService.bookmarksBox;
    final list = box.values.map((jsonStr) {
      try {
        return BookmarkModel.fromJson(json.decode(jsonStr) as Map<String, dynamic>);
      } catch (_) {
        return null;
      }
    }).whereType<BookmarkModel>().toList();
    list.sort((a, b) => b.addedAt.compareTo(a.addedAt));
    return list;
  }

  bool isBookmarked(int verseId) =>
      HiveService.bookmarksBox.containsKey(_key(verseId));

  Future<void> toggle(VerseModel verse) async {
    final box = HiveService.bookmarksBox;
    final key = _key(verse.id);
    if (box.containsKey(key)) {
      await box.delete(key);
    } else {
      await box.put(
        key,
        json.encode(
          BookmarkModel(
            verseId: verse.id,
            surahId: verse.surahId,
            verseNumber: verse.verseNumber,
            page: verse.page,
            addedAt: DateTime.now(),
          ).toJson(),
        ),
      );
    }
    _emit();
  }

  Future<void> remove(int verseId) async {
    await HiveService.bookmarksBox.delete(_key(verseId));
    _emit();
  }

  void _emit() {
    if (!_controller.isClosed) {
      _controller.add(bookmarks);
    }
  }
}