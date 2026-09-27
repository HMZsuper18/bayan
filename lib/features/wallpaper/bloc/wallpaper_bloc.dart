import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../data/models/wallpaper_model.dart';
import '../../../data/repositories/wallpaper_repository.dart';

part 'wallpaper_event.dart';
part 'wallpaper_state.dart';

/// Synthetic id for the animated (live) wallpaper category.
const String kLiveCategoryId = 'live';

/// Synthetic id for the single live-wallpaper entry inside that category.
const String kLiveWallpaperId = 'live';

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
      // The animated live wallpaper gets its own trailing category with a
      // single synthetic entry (handled specially in the UI).
      final all = [
        ...categories,
        const WallpaperCategory(
          id: kLiveCategoryId,
          name: 'Live',
          images: [
            Wallpaper(id: kLiveWallpaperId, title: 'Live', url: ''),
          ],
        ),
      ];
      emit(state.copyWith(
        categories: all,
        selectedCategoryId: all.first.id,
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
