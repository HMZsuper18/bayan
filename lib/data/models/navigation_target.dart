class NavigationTarget {
  final String navigationType;
  final int targetPage;
  final String surahName;
  final int surahNumber;
  final int targetVerse;

  const NavigationTarget({
    required this.navigationType,
    required this.targetPage,
    required this.surahName,
    required this.surahNumber,
    required this.targetVerse,
  });

  Map<String, dynamic> toJson() => {
    'navigation_type': navigationType,
    'target_page': targetPage,
    'surah_name': surahName,
    'surah_number': surahNumber,
    'target_verse': targetVerse,
  };
}
