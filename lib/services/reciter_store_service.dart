import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'dart:math' as math;
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:bayan/data/database/hive_service.dart';
import 'package:bayan/data/models/reciter_model.dart';

/// A simple counting semaphore used to cap the total number of concurrent
/// HTTP connections opened towards the CDN.
class _Semaphore {
  _Semaphore(this._max);

  final int _max;
  int _used = 0;
  final _queue = <Completer<void>>[];

  Future<void> acquire() async {
    if (_used < _max) {
      _used++;
      return;
    }
    final completer = Completer<void>();
    _queue.add(completer);
    await completer.future;
    _used++;
  }

  void release() {
    _used--;
    if (_queue.isNotEmpty) {
      _queue.removeAt(0).complete();
    }
  }
}

class _CachedPattern {
  final String pattern;
  final bool usePadded;

  const _CachedPattern(this.pattern, this.usePadded);
}

class DownloadProgress {
  final String reciterId;
  final int received;
  final int total;

  const DownloadProgress({
    required this.reciterId,
    required this.received,
    required this.total,
  });

  double get fraction => total > 0 ? received / total : 0.0;
}

class ReciterStoreService {
  ReciterStoreService._();
  static final ReciterStoreService instance = ReciterStoreService._();

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
    ),
  );
  final _progressController = StreamController<DownloadProgress>.broadcast();
  final _statusController = StreamController<Map<String, String>>.broadcast();
  final _activeController = StreamController<Set<String>>.broadcast();
  final Map<String, CancelToken> _cancelTokens = {};
  final Map<String, double> _currentProgress = {};

  /// Cap on concurrent HTTP connections to the audio CDN. Large surahs are
  /// split across multiple range requests, so this bounds total parallelism
  /// without overwhelming the CDN or exhausting device sockets.
  static const int _maxDownloadConnections = 16;

  /// Maximum number of byte-range chunks a single file is split into.
  static const int _maxChunks = 8;

  /// Files at least this large are downloaded via parallel range requests.
  static const int _chunkedDownloadMinSize = 4 * 1024 * 1024;

  final _Semaphore _connectionLimiter = _Semaphore(_maxDownloadConnections);

  Stream<DownloadProgress> get progressStream => _progressController.stream;
  Stream<Map<String, String>> get statusStream => _statusController.stream;

  /// Emits the set of active download ids whenever the set changes
  /// (download started, completed, or cancelled).
  Stream<Set<String>> get activeStream => _activeController.stream;

  void _emitActive() {
    if (!_activeController.isClosed) {
      _activeController.add(Set.unmodifiable(_downloading));
    }
  }

  double getDownloadProgress(String reciterId) =>
      _currentProgress[reciterId] ?? 0.0;

  Set<String> get activeDownloads => Set.unmodifiable(_downloading);

  static Future<String> get _recitersDir async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${appDir.path}/reciters');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir.path;
  }

  Future<String> _reciterDir(String reciterId) async {
    final base = await _recitersDir;
    final dir = Directory('$base/$reciterId');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir.path;
  }

  Future<bool> isReciterDownloaded(String reciterId) async {
    return _validateReciterData(reciterId);
  }

  Future<bool> _validateReciterData(String reciterId) async {
    final dir = await _reciterDir(reciterId);
    const surahCount = 114;
    const minSize = 1024;
    for (int i = 1; i <= surahCount; i++) {
      final f = File('$dir/${i.toString().padLeft(3, '0')}.opus');
      if (!await f.exists() || (await f.length()) < minSize) return false;
    }
    return true;
  }

  Future<void> clearReciterData(String reciterId) async {
    final dir = await _reciterDir(reciterId);
    final dirObj = Directory(dir);
    if (await dirObj.exists()) {
      await dirObj.delete(recursive: true);
    }
  }

  Future<Set<String>> getDownloadedReciterIds() async {
    final base = await _recitersDir;
    final baseDir = Directory(base);
    if (!await baseDir.exists()) return {};
    final ids = <String>{};
    final entries = await baseDir.list().toList();
    for (final entry in entries) {
      if (entry is Directory) {
        final reciterId = entry.path.split('/').last;
        if (await _validateReciterData(reciterId)) {
          ids.add(reciterId);
        }
      }
    }
    return ids;
  }

  Future<List<ReciterModel>> getDownloadedReciters() async {
    final downloadedIds = await getDownloadedReciterIds();
    final allReciters = HiveService.getAllReciters();
    return allReciters.where((r) => downloadedIds.contains(r.id)).toList();
  }

  final Set<String> _downloading = {};

  // chapter_recitation IDs from /resources/qaris (NOT /resources/recitations)
  // These are used with /chapter_recitations/{id}/{surah} to resolve audio URLs.
  // Reciters without an entry will use their audioBaseUrl fallback directly.
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
  };

  bool isDownloading(String reciterId) => _downloading.contains(reciterId);

  Future<void> cancelDownload(String reciterId) async {
    _downloading.remove(reciterId);
    _emitActive();
    final token = _cancelTokens.remove(reciterId);
    if (token != null && !token.isCancelled) {
      token.cancel();
    }
    _currentProgress.remove(reciterId);
    // Remove every byte for this reciter so a later download starts over
    // from scratch instead of resuming stale/partial data.
    try {
      final dir = Directory('${await _recitersDir}/$reciterId');
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    } catch (_) {}
  }

  Future<Map<String, dynamic>?> _fetchChapterRecitationData({
    required int recitationId,
    required int surahNumber,
    bool includeSegments = false,
    CancelToken? cancelToken,
  }) async {
    final url =
        'https://api.quran.com/api/v4/chapter_recitations/$recitationId/$surahNumber'
        '${includeSegments ? '?segments=true' : ''}';
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        url,
        cancelToken: cancelToken,
        options: Options(
          receiveTimeout: const Duration(seconds: 15),
          sendTimeout: const Duration(seconds: 15),
        ),
      );
      return response.data;
    } catch (_) {
      return null;
    }
  }

  final Map<String, _CachedPattern> _cachedAudioUrlPatterns = {};

  void _cachePattern(String reciterId, int surah, String apiUrl) {
    final padded = surah.toString().padLeft(3, '0');
    final unPadded = surah.toString();
    if (apiUrl.contains(padded)) {
      _cachedAudioUrlPatterns[reciterId] = _CachedPattern(
        apiUrl.replaceAll(padded, '{surah}'),
        true,
      );
    } else if (apiUrl.contains(unPadded)) {
      _cachedAudioUrlPatterns[reciterId] = _CachedPattern(
        apiUrl.replaceAll(unPadded, '{surah}'),
        false,
      );
    } else {
      _cachedAudioUrlPatterns[reciterId] = _CachedPattern(apiUrl, false);
    }
  }

  /// Fetches audio URLs (and server-reported file sizes) for all 114 surahs
  /// in a single request. Empty maps if unavailable.
  Future<({Map<int, String> urls, Map<int, int> sizes})> _fetchAllAudioUrls(
    ReciterModel reciter,
    CancelToken cancelToken,
  ) async {
    final urls = <int, String>{};
    final sizes = <int, int>{};
    final recitationId = _chapterRecitationIds[reciter.id];
    if (recitationId == null) {
      return (urls: urls, sizes: sizes);
    }

    try {
      final response = await _dio.get<Map<String, dynamic>>(
        'https://api.quran.com/api/v4/chapter_recitations/$recitationId',
        cancelToken: cancelToken,
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
              urls[chapterId] = url;
              final size = f['file_size'];
              if (size is num) sizes[chapterId] = size.toInt();
            }
          }
        }
      }
    } catch (_) {}

    return (urls: urls, sizes: sizes);
  }

  Future<bool> _downloadAudioFile({
    required ReciterModel reciter,
    required int surah,
    required String filePath,
    required CancelToken cancelToken,
    String? resolvedUrl,
    void Function(int received, int total)? onProgress,
  }) async {
    await _cleanupPartials(filePath);

    final urls = <String>[];
    void addUrl(String u) {
      if (u.isNotEmpty && !urls.contains(u)) urls.add(u);
    }

    String? apiUrl;

    // 1. Use the pre-resolved URL when available (no per-surah API call).
    if (resolvedUrl != null) {
      addUrl(resolvedUrl);
      apiUrl = resolvedUrl;
    }

    final recitationId = _chapterRecitationIds[reciter.id];

    // 2. Fetch API URL as fallback (authoritative source)
    if (recitationId != null && resolvedUrl == null) {
      try {
        final data = await _fetchChapterRecitationData(
          recitationId: recitationId,
          surahNumber: surah,
        );
        final audioFile = data?['audio_file'];
        if (audioFile is Map<String, dynamic>) {
          apiUrl = audioFile['audio_url'] as String?;
          if (apiUrl != null && apiUrl.isNotEmpty) {
            addUrl(apiUrl);
          }
        }
      } catch (_) {}
    }

    // 3. Try cached pattern as fallback
    final cached = _cachedAudioUrlPatterns[reciter.id];
    if (cached != null) {
      final surahStr = cached.usePadded
          ? surah.toString().padLeft(3, '0')
          : surah.toString();
      addUrl(cached.pattern.replaceAll('{surah}', surahStr));
    }

    // 4. Preferred path: parallel byte-range download of the authoritative
    // URL. Single connections cap throughput on large surahs; splitting the
    // file across several connections multiplies the transfer rate.
    final primaryUrl = apiUrl ?? (urls.isNotEmpty ? urls.first : null);
    if (primaryUrl != null && !cancelToken.isCancelled) {
      final size = await _probeFileSize(primaryUrl, cancelToken);
      if (size != null && size >= _chunkedDownloadMinSize) {
        for (int attempt = 0; attempt < 2; attempt++) {
          if (cancelToken.isCancelled) return false;
          final ok = await _downloadFileChunked(
            url: primaryUrl,
            filePath: filePath,
            size: size,
            cancelToken: cancelToken,
            onProgress: onProgress,
          );
          if (ok) {
            if (apiUrl != null) {
              _cachePattern(reciter.id, surah, apiUrl);
            }
            return true;
          }
          await _cleanupPartials(filePath);
          await Future.delayed(const Duration(milliseconds: 500));
        }
      }
    }

    // 5. Fallback: sequential single-stream download over each candidate URL.
    for (final url in urls) {
      if (cancelToken.isCancelled) return false;
      for (int attempt = 0; attempt < 2; attempt++) {
        if (cancelToken.isCancelled) return false;
        try {
          await _dio.download(
            url,
            filePath,
            options: Options(
              headers: {HttpHeaders.acceptEncodingHeader: 'identity'},
              receiveTimeout: const Duration(seconds: 120),
              sendTimeout: const Duration(seconds: 30),
              validateStatus: (status) =>
                  status != null && status >= 200 && status < 300,
            ),
            cancelToken: cancelToken,
            onReceiveProgress: onProgress,
          );

          if (apiUrl != null && url == apiUrl) {
            _cachePattern(reciter.id, surah, apiUrl);
          }
          return true;
        } catch (_) {
          if (cancelToken.isCancelled) return false;
          if (await File(filePath).exists()) {
            await File(filePath).delete();
          }
          await Future.delayed(const Duration(milliseconds: 500));
        }
      }
    }
    return false;
  }

  /// Asks the CDN for the real byte size of [url] using a 1-byte range probe.
  /// Returns null when range requests are unsupported or the request fails,
  /// in which case callers fall back to a single-stream download.
  Future<int?> _probeFileSize(String url, CancelToken cancelToken) async {
    try {
      final response = await _dio.get<List<int>>(
        url,
        cancelToken: cancelToken,
        options: Options(
          headers: {
            'Range': 'bytes=0-0',
            HttpHeaders.acceptEncodingHeader: 'identity',
          },
          receiveTimeout: const Duration(seconds: 20),
          sendTimeout: const Duration(seconds: 20),
          validateStatus: (status) => status == 206 || status == 200,
          responseType: ResponseType.bytes,
        ),
      );
      if (response.statusCode == 206) {
        final contentRange = response.headers.value('content-range') ?? '';
        final match = RegExp(r'bytes\s+0-0/(\d+)').firstMatch(contentRange);
        if (match != null) return int.tryParse(match.group(1)!);
      }
    } catch (_) {}
    return null;
  }

  int _chunkCountForSize(int size) {
    if (size >= 64 * 1024 * 1024) return 8;
    if (size >= 16 * 1024 * 1024) return 6;
    return 4;
  }

  /// Downloads [filePath] in parallel byte-range chunks and concatenates
  /// them. Returns true only when every chunk succeeded and the merged file
  /// matches the expected size.
  Future<bool> _downloadFileChunked({
    required String url,
    required String filePath,
    required int size,
    required CancelToken cancelToken,
    void Function(int received, int total)? onProgress,
  }) async {
    final chunkCount = _chunkCountForSize(size);
    final chunkSize = (size + chunkCount - 1) ~/ chunkCount;
    final received = List<int>.filled(chunkCount, 0);

    final futures = <Future<bool>>[];
    for (int i = 0; i < chunkCount; i++) {
      final start = i * chunkSize;
      final end = math.min(size - 1, start + chunkSize - 1);
      futures.add(
        _downloadChunk(
          url: url,
          filePath: filePath,
          index: i,
          start: start,
          end: end,
          cancelToken: cancelToken,
          onChunkProgress: (bytes) {
            received[i] = bytes;
            final total = received.fold<int>(0, (a, b) => a + b);
            onProgress?.call(total, size);
          },
        ),
      );
    }

    final results = await Future.wait(futures);
    if (results.contains(false)) return false;
    if (cancelToken.isCancelled) return false;

    final out = File(filePath);
    var failed = false;
    final sink = out.openWrite();
    try {
      for (int i = 0; i < chunkCount; i++) {
        final chunkFile = File('$filePath.part$i');
        if (!await chunkFile.exists()) {
          failed = true;
          break;
        }
        await sink.addStream(chunkFile.openRead());
        await chunkFile.delete();
      }
    } catch (_) {
      failed = true;
    } finally {
      await sink.close();
    }

    if (failed) {
      await _cleanupPartials(filePath);
      return false;
    }
    return (await out.length()) == size;
  }

  Future<bool> _downloadChunk({
    required String url,
    required String filePath,
    required int index,
    required int start,
    required int end,
    required CancelToken cancelToken,
    required void Function(int) onChunkProgress,
  }) async {
    final chunkPath = '$filePath.part$index';
    await _connectionLimiter.acquire();
    try {
      for (int attempt = 0; attempt < 2; attempt++) {
        if (cancelToken.isCancelled) return false;
        try {
          await _dio.download(
            url,
            chunkPath,
            options: Options(
              headers: {
                'Range': 'bytes=$start-$end',
                HttpHeaders.acceptEncodingHeader: 'identity',
              },
              receiveTimeout: const Duration(seconds: 120),
              sendTimeout: const Duration(seconds: 30),
              validateStatus: (status) => status == 206,
            ),
            cancelToken: cancelToken,
            onReceiveProgress: (receivedChunk, _) {
              onChunkProgress(receivedChunk);
            },
          );
          if (cancelToken.isCancelled) return false;
          final expected = end - start + 1;
          return (await File(chunkPath).length()) == expected;
        } catch (_) {
          if (cancelToken.isCancelled) return false;
          await _deleteFile(chunkPath);
          await Future.delayed(const Duration(milliseconds: 400));
        }
      }
    } finally {
      _connectionLimiter.release();
    }
    return false;
  }

  Future<void> _cleanupPartials(String filePath) async {
    for (int i = 0; i < _maxChunks; i++) {
      await _deleteFile('$filePath.part$i');
    }
  }

  Future<void> _deleteFile(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }

  /// Returns true when an existing surah file is fully downloaded. Leftover
  /// `.part` files mean a chunked download was interrupted, so the target is
  /// stale. Otherwise the real size is probed from the CDN and compared
  /// against the file length; if probing is unavailable the file is trusted.
  Future<bool> _isFileComplete(
    String filePath,
    String? resolvedUrl,
    CancelToken cancelToken,
  ) async {
    for (int i = 0; i < _maxChunks; i++) {
      if (await File('$filePath.part$i').exists()) return false;
    }
    if (resolvedUrl == null) return true;
    final size = await _probeFileSize(resolvedUrl, cancelToken);
    if (size == null) return true;
    return (await File(filePath).length()) >= size;
  }


  Future<List<dynamic>?> _fetchTimestamps({
    required String reciterId,
    required int surah,
    CancelToken? cancelToken,
  }) async {
    final chapterRecitationId = _chapterRecitationIds[reciterId];
    if (chapterRecitationId == null) return null;

    final apiData = await _fetchChapterRecitationData(
      recitationId: chapterRecitationId,
      surahNumber: surah,
      includeSegments: true,
      cancelToken: cancelToken,
    );
    final audioFile = apiData?['audio_file'];
    if (audioFile is! Map<String, dynamic>) return null;

    final timestamps = audioFile['timestamps'];
    if (timestamps is List && timestamps.isNotEmpty) return timestamps;
    return null;
  }

  /// Ensures verse timing JSON exists for [surahId], fetching it if missing.
  /// Returns the parsed timestamps list, or null if unavailable.
  Future<List<dynamic>?> ensureTimestamps(String reciterId, int surahId) async {
    final dir = await _reciterDir(reciterId);
    final surahKey = surahId.toString().padLeft(3, '0');
    final segmentsPath = '$dir/$surahKey.segments.json';
    final segmentsFile = File(segmentsPath);

    if (await segmentsFile.exists()) {
      try {
        final data = jsonDecode(await segmentsFile.readAsString());
        if (data is List && data.isNotEmpty) return data;
      } catch (_) {}
    }

    final timestamps = await _fetchTimestamps(
      reciterId: reciterId,
      surah: surahId,
    );
    if (timestamps == null) return null;

    await segmentsFile.writeAsString(jsonEncode(timestamps));

    final indexFile = File('$dir/segments.json');
    Map<String, dynamic> index = {};
    if (await indexFile.exists()) {
      try {
        final existing = jsonDecode(await indexFile.readAsString());
        if (existing is Map<String, dynamic>) index = existing;
      } catch (_) {}
    }
    index[surahKey] = timestamps;
    await indexFile.writeAsString(jsonEncode(index));

    return timestamps;
  }

  void _emitStatus(String reciterId, String message) {
    _statusController.add({reciterId: message});
  }

  Future<void> downloadReciter(ReciterModel reciter) async {
    print('Starting download of reciter ${reciter.id}');
    if (_downloading.contains(reciter.id)) return;
    _downloading.add(reciter.id);
    _emitActive();
    _currentProgress[reciter.id] = 0.0;
    _emitStatus(reciter.id, 'Starting download...');

    final cancelToken = CancelToken();
    _cancelTokens[reciter.id] = cancelToken;

    try {
      // Keep any already-complete surah files so an interrupted or repeated
      // download resumes instead of restarting from scratch. downloadSurah
      // validates each existing file against its real size before reusing it.
      final dir = await _reciterDir(reciter.id);
      _emitStatus(reciter.id, 'Download directory ready');

      // Resolve all 114 audio URLs up front with a single request, so workers
      // can start transferring immediately instead of waiting on 114 serial
      // API round-trips (one per surah).
      final resolvedUrls = await _fetchAllAudioUrls(reciter, cancelToken);
      final urlsBySurah = resolvedUrls.urls;
      final sizesBySurah = resolvedUrls.sizes;
      final resolvedCount = urlsBySurah.length;
      if (resolvedCount == 0) {
        _emitStatus(reciter.id, 'Resolving audio URLs...');
      } else {
        _emitStatus(reciter.id, 'Audio URLs resolved ($resolvedCount/114)');
      }

      const surahCount = 114;
      const downloadWorkers = 10;
      int completedSurahs = 0;
      int nextDownload = 1;

      // Progress is weighted by actual bytes so the bar reflects real
      // transfer volume: surah sizes vary enormously (001 ~1MB vs 002 ~120MB),
      // so counting surahs equally makes the bar crawl on the big ones.
      // Server-reported sizes act as the denominator when available.
      final totalBytes = sizesBySurah.values.fold<int>(0, (a, b) => a + b);
      int completedBytes = 0;
      final activeReceived = <int, int>{};

      // Fraction-based fallback used only when sizes are unavailable.
      final activeProgress = <int, double>{};
      double lastReportedFraction = -1;

      void emitProgress({bool force = false}) {
        // The reciter was cancelled while a chunk/progress callback fired.
        // Suppress the event so stale progress doesn't resurrect the row.
        if (!_downloading.contains(reciter.id)) return;
        double fraction;
        if (totalBytes > 0) {
          final activeBytes = activeReceived.values.fold<int>(0, (a, b) => a + b);
          fraction = (completedBytes + activeBytes) / totalBytes;
        } else {
          final sumActive = activeProgress.values.fold(0.0, (a, b) => a + b);
          fraction = (completedSurahs + sumActive) / surahCount;
        }
        fraction = fraction.clamp(0.0, 1.0);
        if (!force && (fraction - lastReportedFraction).abs() < 0.001) return;
        lastReportedFraction = fraction;
        _currentProgress[reciter.id] = fraction;
        _progressController.add(
          DownloadProgress(
            reciterId: reciter.id,
            received: (fraction * 10000).round(),
            total: 10000,
          ),
        );
        final pct = (fraction * 100).clamp(0, 100).toStringAsFixed(2);
        _emitStatus(reciter.id, 'Downloading... $pct%');
      }

      emitProgress(force: true);

      Future<void> downloadSurah(int surah) async {
        final surahKey = surah.toString().padLeft(3, '0');
        final filePath = '$dir/$surahKey.opus';

        final file = File(filePath);
        if (await file.exists()) {
          final existingSize = await file.length();
          if (existingSize > 1024 &&
              await _isFileComplete(filePath, urlsBySurah[surah], cancelToken)) {
            completedBytes += existingSize;
            completedSurahs++;
            emitProgress();
            return;
          }
          if (await file.exists()) await file.delete();
        }

        final downloaded = await _downloadAudioFile(
          reciter: reciter,
          surah: surah,
          filePath: filePath,
          cancelToken: cancelToken,
          resolvedUrl: urlsBySurah[surah],
          onProgress: (received, total) {
            activeReceived[surah] = received;
            activeProgress[surah] = total > 0 ? received / total : 0.0;
            emitProgress();
          },
        );

        if (downloaded) {
          completedBytes += await file.length();
          completedSurahs++;
        }
        activeReceived.remove(surah);
        activeProgress.remove(surah);
        emitProgress();
      }

      Future<void> worker() async {
        while (_downloading.contains(reciter.id)) {
          final surah = nextDownload;
          if (surah > surahCount) break;
          nextDownload++;
          await downloadSurah(surah);
        }
      }

      await Future.wait([
        for (int i = 0; i < downloadWorkers; i++) worker(),
      ]);

      if (!_downloading.contains(reciter.id)) return;

      _emitStatus(reciter.id, 'Fetching verse timestamps...');
      final segmentsIndex = <String, dynamic>{};
      int timestampFetches = 0;
      const timestampBatchSize = 12;
      for (int i = 1; i <= surahCount; i += timestampBatchSize) {
        if (!_downloading.contains(reciter.id)) break;
        final batch = <Future<void>>[];
        for (int j = i; j < i + timestampBatchSize && j <= surahCount; j++) {
          final surahKey = j.toString().padLeft(3, '0');
          final audioFile = File('$dir/$surahKey.opus');
          if (!await audioFile.exists() || (await audioFile.length()) <= 1024) {
            continue;
          }
          final segFile = File('$dir/$surahKey.segments.json');
          if (await segFile.exists()) {
            try {
              segmentsIndex[surahKey] = jsonDecode(
                await segFile.readAsString(),
              );
              timestampFetches++;
            } catch (_) {}
            continue;
          }
          batch.add(
            _fetchTimestamps(
                  reciterId: reciter.id,
                  surah: j,
                  cancelToken: cancelToken,
                )
                .then((timestamps) async {
                  if (timestamps != null) {
                    await segFile.writeAsString(jsonEncode(timestamps));
                    segmentsIndex[surahKey] = timestamps;
                    timestampFetches++;
                  }
                })
                .catchError((_) {})
                .timeout(const Duration(seconds: 15), onTimeout: () {}),
          );
        }
        if (batch.isNotEmpty) {
          await Future.wait(batch);
        }
      }
      _emitStatus(
        reciter.id,
        'Fetched timestamps for $timestampFetches surahs',
      );

      if (!_downloading.contains(reciter.id)) return;

      _emitStatus(reciter.id, 'Validating download...');
      int actualCount = 0;
      for (int i = 1; i <= surahCount; i++) {
        final f = File('$dir/${i.toString().padLeft(3, '0')}.opus');
        if (await f.exists() && (await f.length()) > 1024) actualCount++;
      }

      if (actualCount >= surahCount) {
        final tsFile = File('$dir/timestamps.json');
        await tsFile.writeAsString(
          '{"downloaded_at": "${DateTime.now().toIso8601String()}"}',
        );
        final allSegmentsFile = File('$dir/segments.json');
        await allSegmentsFile.writeAsString(jsonEncode(segmentsIndex));
        _currentProgress[reciter.id] = 1.0;
        _progressController.add(
          DownloadProgress(
            reciterId: reciter.id,
            received: surahCount,
            total: surahCount,
          ),
        );
        _emitStatus(reciter.id, 'Download complete!');
      } else {
        _emitStatus(
          reciter.id,
          'Partial download: $actualCount/$surahCount surahs',
        );
        _currentProgress[reciter.id] = actualCount / surahCount;
        _progressController.add(
          DownloadProgress(
            reciterId: reciter.id,
            received: actualCount,
            total: surahCount,
          ),
        );
      }
    } finally {
      _downloading.remove(reciter.id);
      _emitActive();
      _cancelTokens.remove(reciter.id);
      _currentProgress.remove(reciter.id);
    }
  }

  void dispose() {
    _progressController.close();
    _activeController.close();
  }
}
