part of 'wallpaper_bloc.dart';

abstract class WallpaperEvent extends Equatable {
  const WallpaperEvent();

  @override
  List<Object?> get props => [];
}

class LoadWallpapers extends WallpaperEvent {
  const LoadWallpapers();
}

class SelectCategory extends WallpaperEvent {
  final String categoryId;

  const SelectCategory(this.categoryId);

  @override
  List<Object?> get props => [categoryId];
}
