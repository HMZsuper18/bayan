part of 'mushaf_bloc.dart';

class MushafState extends Equatable {
  final SurahModel? surah;
  final List<VerseModel> verses;
  final VerseModel? selectedVerse;
  final String? tafseer;
  final String? qiraat;
  final bool isLoading;

  const MushafState({
    this.surah,
    this.verses = const [],
    this.selectedVerse,
    this.tafseer,
    this.qiraat,
    this.isLoading = false,
  });

  MushafState copyWith({
    SurahModel? surah,
    List<VerseModel>? verses,
    VerseModel? selectedVerse,
    String? tafseer,
    String? qiraat,
    bool? isLoading,
  }) {
    return MushafState(
      surah: surah ?? this.surah,
      verses: verses ?? this.verses,
      selectedVerse: selectedVerse,
      tafseer: tafseer,
      qiraat: qiraat,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  @override
  List<Object?> get props =>
      [surah, verses, selectedVerse, tafseer, qiraat, isLoading];
}