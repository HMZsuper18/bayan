class BookmarkModel {
  final int verseId;
  final int surahId;
  final int verseNumber;
  final int page;
  final DateTime addedAt;

  const BookmarkModel({
    required this.verseId,
    required this.surahId,
    required this.verseNumber,
    required this.page,
    required this.addedAt,
  });

  factory BookmarkModel.fromJson(Map<String, dynamic> json) {
    return BookmarkModel(
      verseId: json['verseId'] as int,
      surahId: json['surahId'] as int,
      verseNumber: json['verseNumber'] as int,
      page: json['page'] as int,
      addedAt: DateTime.parse(json['addedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'verseId': verseId,
      'surahId': surahId,
      'verseNumber': verseNumber,
      'page': page,
      'addedAt': addedAt.toIso8601String(),
    };
  }
}