import 'package:dio/dio.dart';
import '../models/wallpaper_model.dart';

class WallpaperRepository {
  static const _baseUrl = 'https://hmzsuper18.github.io';
  static const _jsonPath = '/bayan/wallpapers.json';

  final Dio _dio;

  WallpaperRepository({Dio? dio}) : _dio = dio ?? Dio();

  Future<List<WallpaperCategory>> fetchWallpapers() async {
    final response = await _dio.get('$_baseUrl$_jsonPath');
    final data = response.data as Map<String, dynamic>;
    final categories = data['categories'] as List;
    return categories
        .map((e) => WallpaperCategory.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  String resolveUrl(String relativeUrl) {
    if (relativeUrl.startsWith('http')) return relativeUrl;
    return '$_baseUrl/$relativeUrl';
  }
}
