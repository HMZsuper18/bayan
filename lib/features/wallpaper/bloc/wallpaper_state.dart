part of 'wallpaper_bloc.dart';

class WallpaperState extends Equatable {
  final List<WallpaperCategory> categories;
  final String? selectedCategoryId;
  final bool isLoading;
  final String? error;

  const WallpaperState({
    this.categories = const [],
    this.selectedCategoryId,
    this.isLoading = false,
    this.error,
  });

  WallpaperCategory? get selectedCategory {
    if (selectedCategoryId == null) return null;
    for (final c in categories) {
      if (c.id == selectedCategoryId) return c;
    }
    return null;
  }

  List<WallpaperCategory> get displayCategories {
    if (selectedCategoryId == null) return categories;
    return categories.where((c) => c.id == selectedCategoryId).toList();
  }

  WallpaperState copyWith({
    List<WallpaperCategory>? categories,
    String? selectedCategoryId,
    bool? isLoading,
    String? error,
    bool clearSelected = false,
  }) {
    return WallpaperState(
      categories: categories ?? this.categories,
      selectedCategoryId: clearSelected
          ? null
          : (selectedCategoryId ?? this.selectedCategoryId),
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  @override
  List<Object?> get props =>
      [categories, selectedCategoryId, isLoading, error];
}
