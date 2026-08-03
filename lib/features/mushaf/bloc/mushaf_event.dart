part of 'mushaf_bloc.dart';

abstract class MushafEvent extends Equatable {
  const MushafEvent();

  @override
  List<Object?> get props => [];
}

class LoadSurah extends MushafEvent {
  final int surahId;

  const LoadSurah(this.surahId);

  @override
  List<Object?> get props => [surahId];
}

class NextSurah extends MushafEvent {
  const NextSurah();
}

class PreviousSurah extends MushafEvent {
  const PreviousSurah();
}

class SelectVerse extends MushafEvent {
  final VerseModel verse;

  const SelectVerse(this.verse);

  @override
  List<Object?> get props => [verse];
}

class LoadTafseer extends MushafEvent {
  final int verseNumber;

  const LoadTafseer(this.verseNumber);

  @override
  List<Object?> get props => [verseNumber];
}

class ClearSelection extends MushafEvent {
  const ClearSelection();
}