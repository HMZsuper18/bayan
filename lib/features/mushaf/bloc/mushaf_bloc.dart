import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../data/models/surah_model.dart';
import '../../../data/models/verse_model.dart';
import '../../../data/repositories/quran_repository.dart';
import '../../../data/database/settings_service.dart';

part 'mushaf_event.dart';
part 'mushaf_state.dart';

class MushafBloc extends Bloc<MushafEvent, MushafState> {
  final QuranRepository _repository;

  MushafBloc({required QuranRepository repository})
      : _repository = repository,
        super(const MushafState()) {
    on<LoadSurah>(_onLoadSurah);
    on<NextSurah>(_onNextSurah);
    on<PreviousSurah>(_onPreviousSurah);
    on<SelectVerse>(_onSelectVerse);
    on<LoadTafseer>(_onLoadTafseer);
    on<ClearSelection>(_onClearSelection);
  }

  void _onLoadSurah(LoadSurah event, Emitter<MushafState> emit) {
    final surah = _repository.getSurahById(event.surahId);
    final verses = _repository.getVersesBySurah(event.surahId);
    emit(state.copyWith(
      surah: surah,
      verses: verses,
      selectedVerse: null,
      tafseer: null,
      qiraat: null,
    ));
  }

  void _onNextSurah(NextSurah event, Emitter<MushafState> emit) {
    if (state.surah != null && state.surah!.id < 114) {
      add(LoadSurah(state.surah!.id + 1));
    }
  }

  void _onPreviousSurah(PreviousSurah event, Emitter<MushafState> emit) {
    if (state.surah != null && state.surah!.id > 1) {
      add(LoadSurah(state.surah!.id - 1));
    }
  }

  void _onSelectVerse(SelectVerse event, Emitter<MushafState> emit) {
    emit(state.copyWith(selectedVerse: event.verse));
  }

  void _onLoadTafseer(LoadTafseer event, Emitter<MushafState> emit) {
    final key = '${state.surah?.id}:${event.verseNumber}';
    final lang = SettingsService.tafseerLanguage;
    final tafseer = _repository.getTafseer(key, language: lang);
    final qiraat = _repository.getQiraat(key);
    emit(state.copyWith(tafseer: tafseer, qiraat: qiraat));
  }

  void _onClearSelection(ClearSelection event, Emitter<MushafState> emit) {
    emit(state.copyWith(
      selectedVerse: null,
      tafseer: null,
      qiraat: null,
    ));
  }
}