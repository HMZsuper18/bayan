import 'dart:async';
import 'package:bayan/data/models/reciter_model.dart';
import 'package:bayan/services/reciter_store_service.dart';
import 'package:bayan/services/background_download_service.dart';

class HybridDownloadService {
  HybridDownloadService._();
  static final HybridDownloadService instance = HybridDownloadService._();

  final ReciterStoreService _dartEngine = ReciterStoreService.instance;
  final BackgroundDownloadService _bgService = BackgroundDownloadService.instance;

  bool _initialized = false;

  void initialize() {
    if (_initialized) return;
    _initialized = true;
    _bgService.initialize();
  }

  Future<void> startDownload(ReciterModel reciter) async {
    await _bgService.startDownload(reciter);
    return _dartEngine.downloadReciter(reciter);
  }

  void cancelDownload(String reciterId) {
    _dartEngine.cancelDownload(reciterId);
  }

  void pauseDownload(String reciterId) {
    _dartEngine.pauseDownload(reciterId);
  }

  void resumeDownload(String reciterId) {
    _dartEngine.resumeDownload(reciterId);
  }

  void dispose() {
    _bgService.dispose();
  }
}
