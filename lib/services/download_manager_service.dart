import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

class DownloadManagerService {
  DownloadManagerService._();
  static final DownloadManagerService instance = DownloadManagerService._();

  static const _channel = MethodChannel('com.hamzah.bayan/download_manager');

  bool _initialized = false;

  final _progressController = StreamController<DMProgress>.broadcast();
  final _statusController = StreamController<Map<String, String>>.broadcast();
  final _activeController = StreamController<Set<String>>.broadcast();

  final Set<String> _activeReciters = {};
  final Map<String, double> _progress = {};
  Timer? _pollTimer;

  Stream<DMProgress> get progressStream => _progressController.stream;
  Stream<Map<String, String>> get statusStream => _statusController.stream;
  Stream<Set<String>> get activeStream => _activeController.stream;

  bool get isDownloading => _activeReciters.isNotEmpty;
  Set<String> get activeReciters => Set.unmodifiable(_activeReciters);

  void initialize() {
    if (_initialized) return;
    _initialized = true;
    _channel.setMethodCallHandler(_onMethodCall);
  }

  Future<void> _onMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onDownloadComplete':
        final args = call.arguments as Map;
        final reciterId = args['reciterId'] as String;
        debugPrint('DownloadManager: surah complete for $reciterId');
        break;
    }
  }

  Future<String> get _recitersDir async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${appDir.path}/reciters');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir.path;
  }

  Future<void> submitToDownloadManager({
    required String reciterId,
    required List<int> surahs,
    required Map<int, String> urlsBySurah,
  }) async {
    if (surahs.isEmpty) return;

    final dir = await _recitersDir;
    final ids = <int>[];
    final urls = <String>[];
    final paths = <String>[];

    for (final surah in surahs) {
      final url = urlsBySurah[surah];
      if (url == null || url.isEmpty) continue;
      final surahKey = surah.toString().padLeft(3, '0');
      ids.add(surah);
      urls.add(url);
      paths.add('$dir/$surahKey.opus');
    }

    if (ids.isEmpty) return;

    _activeReciters.add(reciterId);
    _progress[reciterId] = 0.0;
    _emitActive();

    try {
      final result = await _channel.invokeMethod('startDownloads', {
        'reciterId': reciterId,
        'ids': ids,
        'urls': urls,
        'paths': paths,
      });
      final started = (result as Map)['started'] as int;
      debugPrint('DownloadManager: started $started requests for $reciterId');
      _statusController.add({reciterId: 'Background download started ($started files)'});
      _startPolling();
    } catch (e) {
      debugPrint('DownloadManager: failed to start: $e');
      _activeReciters.remove(reciterId);
      _emitActive();
    }
  }

  Future<void> pauseDownloadManager(String reciterId) async {
    try {
      await _channel.invokeMethod('pauseDownloads', reciterId);
      _activeReciters.remove(reciterId);
      _progress.remove(reciterId);
      _emitActive();
      _statusController.add({reciterId: 'Background download paused'});
      if (_activeReciters.isEmpty) _stopPolling();
    } catch (e) {
      debugPrint('DownloadManager: pause failed: $e');
    }
  }

  Future<void> cancelDownloadManager(String reciterId) async {
    try {
      await _channel.invokeMethod('cancelDownloads', reciterId);
      _activeReciters.remove(reciterId);
      _progress.remove(reciterId);
      _emitActive();
      if (_activeReciters.isEmpty) _stopPolling();
    } catch (e) {
      debugPrint('DownloadManager: cancel failed: $e');
    }
  }

  Future<void> cancelAll() async {
    try {
      await _channel.invokeMethod('cancelAll');
      _activeReciters.clear();
      _progress.clear();
      _emitActive();
      _stopPolling();
    } catch (e) {
      debugPrint('DownloadManager: cancelAll failed: $e');
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) => _pollProgress());
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> _pollProgress() async {
    if (_activeReciters.isEmpty) {
      _stopPolling();
      return;
    }
    try {
      final result = await _channel.invokeMethod('queryProgress');
      final data = Map<String, dynamic>.from(result as Map);

      for (final entry in data.entries) {
        final reciterId = entry.key;
        final info = Map<String, dynamic>.from(entry.value as Map);
        final received = (info['received'] as num).toDouble();
        final total = (info['total'] as num).toDouble();
        final complete = info['complete'] as bool;

        if (total > 0) {
          final fraction = (received / total).clamp(0.0, 1.0);
          _progress[reciterId] = fraction;
          _progressController.add(DMProgress(reciterId: reciterId, fraction: fraction));
          final pct = (fraction * 100).clamp(0, 100).toStringAsFixed(1);
          _statusController.add({reciterId: 'Downloading... $pct%'});
        }

        if (complete) {
          _activeReciters.remove(reciterId);
          _progress.remove(reciterId);
          _statusController.add({reciterId: 'Download complete!'});
        }
      }

      _emitActive();
      if (_activeReciters.isEmpty) _stopPolling();
    } catch (e) {
      debugPrint('DownloadManager: poll failed: $e');
    }
  }

  void _emitActive() {
    if (!_activeController.isClosed) {
      _activeController.add(Set.unmodifiable(_activeReciters));
    }
  }

  Future<void> flushCompletedToInternal() async {
    try {
      await _channel.invokeMethod('flushCompletedToInternal');
    } catch (e) {
      debugPrint('DownloadManager: flushCompletedToInternal failed: $e');
    }
  }

  void dispose() {
    _stopPolling();
    _progressController.close();
    _statusController.close();
    _activeController.close();
  }
}

class DMProgress {
  final String reciterId;
  final double fraction;

  const DMProgress({required this.reciterId, required this.fraction});
}
