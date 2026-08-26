import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';
import 'package:bayan/data/models/reciter_model.dart';
import 'package:bayan/services/reciter_store_service.dart';
import 'package:bayan/services/download_manager_service.dart';

class HybridDownloadService with WidgetsBindingObserver {
  HybridDownloadService._();
  static final HybridDownloadService instance = HybridDownloadService._();

  final ReciterStoreService _dartEngine = ReciterStoreService.instance;
  final DownloadManagerService _dm = DownloadManagerService.instance;

  bool _initialized = false;

  final Map<String, ReciterModel> _activeReciters = {};

  Timer? _handoffTimer;

  void initialize() {
    if (_initialized) return;
    _initialized = true;
    WidgetsBinding.instance.addObserver(this);
    _dm.initialize();
  }

  Future<void> startDownload(ReciterModel reciter) {
    _activeReciters[reciter.id] = reciter;
    return _dartEngine.downloadReciter(reciter);
  }

  void cancelDownload(String reciterId) {
    _activeReciters.remove(reciterId);
    _dartEngine.cancelDownload(reciterId);
    _dm.cancelDownloadManager(reciterId);
  }

  void pauseDownload(String reciterId) {
    _dartEngine.pauseDownload(reciterId);
  }

  void resumeDownload(String reciterId) {
    _activeReciters.remove(reciterId);
    _dartEngine.resumeDownload(reciterId);
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _handoffTimer?.cancel();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _handoffTimer?.cancel();
      _handoffTimer = Timer(const Duration(seconds: 30), _handoffToDownloadManager);
    } else if (state == AppLifecycleState.resumed) {
      _handoffTimer?.cancel();
      _onResume();
    }
  }

  Future<void> _handoffToDownloadManager() async {
    for (final entry in Map.from(_activeReciters).entries) {
      final reciterId = entry.key;
      final reciter = entry.value;

      if (!_dartEngine.isDownloading(reciterId)) continue;

      _dartEngine.pauseDownload(reciterId);

      try {
        await _submitRemainingToDM(reciter);
      } catch (e) {
        debugPrint('HybridDownload: handoff failed for $reciterId: $e');
      }
    }
  }

  Future<void> _onResume() async {
    _dm.flushCompletedToInternal();

    await Future.delayed(const Duration(milliseconds: 500));

    for (final reciterId in List.from(_activeReciters.keys)) {
      if (_dm.activeReciters.contains(reciterId)) {
        await _dm.cancelDownloadManager(reciterId);
      }

      final reciter = _activeReciters[reciterId];
      if (reciter != null && !_dartEngine.isDownloading(reciterId)) {
        _dartEngine.resumeDownload(reciterId);
      }
    }
  }

  Future<void> _submitRemainingToDM(ReciterModel reciter) async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${appDir.path}/reciters/${reciter.id}');
    if (!await dir.exists()) await dir.create(recursive: true);

    final missingSurahs = <int>[];
    for (int i = 1; i <= 114; i++) {
      final surahKey = i.toString().padLeft(3, '0');
      final f = File('${dir.path}/$surahKey.opus');
      if (!await f.exists() || (await f.length()) <= 1024) {
        missingSurahs.add(i);
      }
    }

    if (missingSurahs.isEmpty) return;

    final recitationId = _chapterRecitationIds[reciter.id];
    if (recitationId == null) return;

    final urlsBySurah = <int, String>{};
    try {
      final dio = Dio();
      final response = await dio.get<Map<String, dynamic>>(
        'https://api.quran.com/api/v4/chapter_recitations/$recitationId',
        options: Options(
          receiveTimeout: const Duration(seconds: 20),
          sendTimeout: const Duration(seconds: 20),
        ),
      );
      final files = response.data?['audio_files'];
      if (files is List) {
        for (final f in files) {
          if (f is Map) {
            final chapterId = f['chapter_id'];
            final url = f['audio_url'];
            if (chapterId is int && url is String && url.isNotEmpty) {
              urlsBySurah[chapterId] = url;
            }
          }
        }
      }
      dio.close();
    } catch (e) {
      debugPrint('HybridDownload: URL resolution failed: $e');
      return;
    }

    if (urlsBySurah.isEmpty) return;

    await _dm.submitToDownloadManager(
      reciterId: reciter.id,
      surahs: missingSurahs,
      urlsBySurah: urlsBySurah,
    );
  }

  static const Map<String, int> _chapterRecitationIds = {
    'mishary': 7,
    'abdulbasit': 1,
    'husary': 6,
    'minshawi': 9,
    'sudais': 3,
    'shuraim': 10,
    'muaiqly': 159,
    'dosari': 97,
    'ajmi': 19,
    'ghamdi': 13,
    'banna': 129,
    'huthaify': 167,
    'shatri': 4,
    'rifai': 5,
    'qasim': 11,
    'fares': 14,
    'tunaiji': 161,
  };
}
