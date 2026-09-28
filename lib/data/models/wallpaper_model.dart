import 'package:equatable/equatable.dart';

class Wallpaper extends Equatable {
  final String id;
  final String title;
  final String titleAr;
  final String titleUr;
  final String url;

  const Wallpaper({
    required this.id,
    required this.title,
    this.titleAr = '',
    this.titleUr = '',
    required this.url,
  });

  factory Wallpaper.fromJson(Map<String, dynamic> json) {
    return Wallpaper(
      id: json['id'] as String,
      title: json['title'] as String,
      titleAr: json['title_ar'] as String? ?? '',
      titleUr: json['title_ur'] as String? ?? '',
      url: json['url'] as String,
    );
  }

  /// Localized title; falls back to English when a translation is missing.
  String localizedTitle(String lang) {
    switch (lang) {
      case 'ar':
        return titleAr.isNotEmpty ? titleAr : title;
      case 'ur':
        return titleUr.isNotEmpty ? titleUr : title;
      default:
        return title;
    }
  }

  @override
  List<Object?> get props => [id, title, titleAr, titleUr, url];
}

class WallpaperCategory extends Equatable {
  final String id;
  final String name;
  final String nameAr;
  final String nameUr;
  final List<Wallpaper> images;

  const WallpaperCategory({
    required this.id,
    required this.name,
    this.nameAr = '',
    this.nameUr = '',
    required this.images,
  });

  factory WallpaperCategory.fromJson(Map<String, dynamic> json) {
    return WallpaperCategory(
      id: json['id'] as String,
      name: json['name'] as String,
      nameAr: json['name_ar'] as String? ?? '',
      nameUr: json['name_ur'] as String? ?? '',
      images: (json['images'] as List)
          .map((e) => Wallpaper.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  /// Localized category name; falls back to English when a translation is
  /// missing.
  String localizedName(String lang) {
    switch (lang) {
      case 'ar':
        return nameAr.isNotEmpty ? nameAr : name;
      case 'ur':
        return nameUr.isNotEmpty ? nameUr : name;
      default:
        return name;
    }
  }

  @override
  List<Object?> get props => [id, name, nameAr, nameUr, images];
}
