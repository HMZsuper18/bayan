import 'dart:io';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

/// Handles wallpaper operations via MethodChannel to native Android:
/// setting wallpapers, downloading images, and prayer times sync.
class WallpaperService {
  WallpaperService._();
  static final WallpaperService instance = WallpaperService._();

  static const _channel = MethodChannel('com.hamzah.bayan/wallpaper');

  /// Downloads an image from [url] and returns the local file path.
  Future<String> downloadImage(String url) async {
    final dio = Dio();
    final dir = await getApplicationDocumentsDirectory();
    final wallpaperDir = Directory('${dir.path}/wallpapers');
    if (!await wallpaperDir.exists()) {
      await wallpaperDir.create(recursive: true);
    }
    final fileName = url.split('/').last.split('?').first;
    final filePath = '${wallpaperDir.path}/$fileName';
    await dio.download(url, filePath);
    return filePath;
  }

  /// Crops the image at [srcPath] to the source rectangle
  /// ([cropX], [cropY], [cropW], [cropH] in source pixels), resizes the result
  /// to [outW]×[outH] and saves it under `wallpapers/crops/`.
  /// Returns the path of the cropped file.
  Future<String> cropAndSave({
    required String srcPath,
    required double cropX,
    required double cropY,
    required double cropW,
    required double cropH,
    required int outW,
    required int outH,
  }) async {
    final src = img.decodeImage(await File(srcPath).readAsBytes());
    if (src == null) {
      throw const FormatException('Could not decode wallpaper image');
    }
    final x = cropX.round().clamp(0, src.width - 1).toInt();
    final y = cropY.round().clamp(0, src.height - 1).toInt();
    final w = cropW.round().clamp(1, src.width - x).toInt();
    final h = cropH.round().clamp(1, src.height - y).toInt();

    var out = img.copyCrop(src, x: x, y: y, width: w, height: h);
    if (out.width != outW || out.height != outH) {
      out = img.copyResize(out, width: outW, height: outH);
    }

    final dir = await getApplicationDocumentsDirectory();
    final cropsDir = Directory('${dir.path}/wallpapers/crops');
    if (!await cropsDir.exists()) {
      await cropsDir.create(recursive: true);
    }
    final base = srcPath.split('/').last.split('?').first;
    final stem = base.contains('.')
        ? base.substring(0, base.lastIndexOf('.'))
        : base;
    final outPath = '${cropsDir.path}/${stem}_${outW}x$outH.jpg';
    await File(outPath).writeAsBytes(img.encodeJpg(out, quality: 92));
    return outPath;
  }

  /// Sets the wallpaper from a local file [path].
  /// [which] can be "home", "lock", or "both".
  Future<bool> setWallpaper(String path, {String which = 'both'}) async {
    try {
      final result = await _channel.invokeMethod<bool>('setWallpaper', {
        'path': path,
        'which': which,
      });
      return result ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  /// Syncs prayer times to SharedPreferences so the native
  /// WallpaperService can read them for sun/moon positioning.
  Future<void> syncPrayerTimes(List<Map<String, dynamic>> prayerTimes) async {
    try {
      await _channel.invokeMethod('syncPrayerTimes', {
        'prayerTimes': prayerTimes,
      });
    } on MissingPluginException {
      // Ignore on unsupported platforms
    } on PlatformException {
      // Ignore
    }
  }
}
