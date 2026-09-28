import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../data/models/wallpaper_model.dart';
import '../../../data/repositories/wallpaper_repository.dart';

part 'wallpaper_event.dart';
part 'wallpaper_state.dart';

class WallpaperBloc extends Bloc<WallpaperEvent, WallpaperState> {
  final WallpaperRepository _repository;

  WallpaperBloc({required WallpaperRepository repository})
      : _repository = repository,
        super(const WallpaperState()) {
    on<LoadWallpapers>(_onLoadWallpapers);
    on<SelectCategory>(_onSelectCategory);
  }

  Future<void> _onLoadWallpapers(
    LoadWallpapers event,
    Emitter<WallpaperState> emit,
  ) async {
    emit(state.copyWith(isLoading: true, error: null));
    try {
      final categories = await _repository.fetchWallpapers();
      emit(state.copyWith(
        categories: categories,
        selectedCategoryId: categories.first.id,
        isLoading: false,
      ));
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  void _onSelectCategory(SelectCategory event, Emitter<WallpaperState> emit) {
    emit(state.copyWith(selectedCategoryId: event.categoryId, error: null));
  }
}
