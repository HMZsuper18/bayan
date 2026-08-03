import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:hive/hive.dart';

import '../data/models/reciter_model.dart';
import '../data/database/hive_service.dart';
import 'reciter_store_service.dart';

enum PlaybackMode { singleVerse, fromVerseToEnd, fullSurah }

class VerseTimestamp {
  final String verseKey;
  final int startMs;
  final int endMs;

  const VerseTimestamp({
    required this.verseKey,
    required this.startMs,
    required this.endMs,
  });
}

class PlaybackState {
  final bool isPlaying;
  final bool isLoading;
  final ReciterModel? reciter;
  final int? surahId;
  final int? currentVerseNumber;
  final int? startVerseNumber;
  final PlaybackMode mode;
  final Duration position;
  final Duration duration;

  const PlaybackState({
    this.isPlaying = false,
    this.isLoading = false,
    this.reciter,
    this.surahId,
    this.currentVerseNumber,
    this.startVerseNumber,
    this.mode = PlaybackMode.fullSurah,
    this.position = Duration.zero,
    this.duration = Duration.zero,
  });

  bool get isEmpty => reciter == null;

  PlaybackState copyWith({
    bool? isPlaying,
    bool? isLoading,
    ReciterModel? reciter,
    int? surahId,
    int? currentVerseNumber,
    int? startVerseNumber,
    PlaybackMode? mode,
    Duration? position,
    Duration? duration,
    bool clearVerse = false,
  }) {
    return PlaybackState(
      isPlaying: isPlaying ?? this.isPlaying,
      isLoading: isLoading ?? this.isLoading,
      reciter: reciter ?? this.reciter,
      surahId: surahId ?? this.surahId,
      currentVerseNumber: clearVerse ? null : (currentVerseNumber ?? this.currentVerseNumber),
      startVerseNumber: clearVerse ? null : (startVerseNumber ?? this.startVerseNumber),
      mode: mode ?? this.mode,
      position: position ?? this.position,
      duration: duration ?? this.duration,
    );
  }
}

class AudioPlaybackService {
  AudioPlaybackService._();
  static final AudioPlaybackService instance = AudioPlaybackService._();

  final AudioPlayer _player = AudioPlayer();
  final _stateController = StreamController<PlaybackState>.broadcast();
  PlaybackState _state = const PlaybackState();
  List<VerseTimestamp> _currentTimestamps = [];
  int _currentSurahId = 0;
  ReciterModel? _currentReciter;
  bool _listenersSetup = false;

  AudioPlayer get player => _player;

  static const String _lastReciterKey = 'last_reciter_id';

  Stream<PlaybackState> get stateStream => _stateController.stream;
  PlaybackState get currentState => _state;

  void _ensureListeners() {
    if (_listenersSetup) return;
    _listenersSetup = true;

    _player.positionStream.listen((position) {
      if (_state.mode == PlaybackMode.singleVerse) {
        // ClippingAudioSource reports clip-relative positions.
        _state = _state.copyWith(position: position);
        _emitState();
        return;
      }

      final verseNum = _verseAtPosition(position);
      if (verseNum != null && verseNum != _state.currentVerseNumber) {
        _state = _state.copyWith(
          currentVerseNumber: verseNum,
          position: position,
        );
        _emitState();
      } else {
        _state = _state.copyWith(position: position);
        _emitState();
      }
    });

    _player.durationStream.listen((duration) {
      if (duration != null) {
        _state = _state.copyWith(duration: duration);
        _emitState();
      }
    });

    _player.playerStateStream.listen((playerState) {
      final isPlaying = playerState.playing;
      final isCompleted = playerState.processingState == ProcessingState.completed;

      if (isCompleted) {
        _handlePlaybackComplete();
      } else {
        _state = _state.copyWith(isPlaying: isPlaying);
        _emitState();
      }
    });
  }

  void _emitState() {
    if (!_stateController.isClosed) {
      _stateController.add(_state);
    }
  }

  Future<String> _recitersDir() async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${appDir.path}/reciters');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir.path;
  }

  Future<String> _surahPath(String reciterId, int surahId) async {
    final base = await _recitersDir();
    final surahKey = surahId.toString().padLeft(3, '0');
    return '$base/$reciterId/$surahKey.opus';
  }

  Future<List<VerseTimestamp>> _loadTimestamps(String reciterId, int surahId) async {
    final raw = await ReciterStoreService.instance.ensureTimestamps(
      reciterId,
      surahId,
    );
    if (raw == null || raw.isEmpty) {
      // Fallback: try local aggregate index or legacy filenames.
      final fromDisk = await _readTimestampsFromDisk(reciterId, surahId);
      if (fromDisk == null || fromDisk.isEmpty) return [];
      return _parseTimestamps(fromDisk);
    }
    return _parseTimestamps(raw);
  }

  Future<List<dynamic>?> _readTimestampsFromDisk(
    String reciterId,
    int surahId,
  ) async {
    final base = await _recitersDir();
    final surahKey = surahId.toString().padLeft(3, '0');
    final candidates = [
      File('$base/$reciterId/$surahKey.segments.json'),
      File('$base/$reciterId/$surahId.segments.json'),
    ];

    for (final file in candidates) {
      if (!await file.exists()) continue;
      try {
        final data = jsonDecode(await file.readAsString());
        if (data is List && data.isNotEmpty) return data;
      } catch (_) {}
    }

    final indexFile = File('$base/$reciterId/segments.json');
    if (await indexFile.exists()) {
      try {
        final index = jsonDecode(await indexFile.readAsString());
        if (index is Map) {
          final entry = index[surahKey] ?? index['$surahId'];
          if (entry is List && entry.isNotEmpty) return entry;
        }
      } catch (_) {}
    }
    return null;
  }

  List<VerseTimestamp> _parseTimestamps(List<dynamic> raw) {
    final timestamps = <VerseTimestamp>[];

    for (final entry in raw) {
      if (entry is! Map) continue;
      final verseKey = entry['verse_key'] as String?;
      if (verseKey == null || verseKey.isEmpty) continue;

      final fromRaw = entry['timestamp_from'];
      final toRaw = entry['timestamp_to'];
      if (fromRaw != null && toRaw != null) {
        final startMs = fromRaw is int ? fromRaw : int.tryParse(fromRaw.toString());
        final endMs = toRaw is int ? toRaw : int.tryParse(toRaw.toString());
        if (startMs != null && endMs != null && endMs > startMs) {
          timestamps.add(VerseTimestamp(
            verseKey: verseKey,
            startMs: startMs,
            endMs: endMs,
          ));
          continue;
        }
      }

      // Fallback: derive verse range from word-level segments
      // format: [word_index, start_ms, end_ms]
      final segments = entry['segments'];
      if (segments is! List || segments.isEmpty) continue;

      int startMs = -1;
      int endMs = 0;
      for (final seg in segments) {
        int? from;
        int? to;
        if (seg is List && seg.length >= 3) {
          from = seg[1] is int ? seg[1] as int : int.tryParse(seg[1].toString());
          to = seg[2] is int ? seg[2] as int : int.tryParse(seg[2].toString());
        } else if (seg is List && seg.length >= 2) {
          from = seg[0] is int ? seg[0] as int : int.tryParse(seg[0].toString());
          to = seg[1] is int ? seg[1] as int : int.tryParse(seg[1].toString());
        } else if (seg is Map) {
          from = seg['from'] is int
              ? seg['from'] as int
              : int.tryParse(seg['from'].toString());
          to = seg['to'] is int
              ? seg['to'] as int
              : int.tryParse(seg['to'].toString());
        }
        if (from == null || to == null) continue;
        if (startMs < 0) startMs = from;
        endMs = to;
      }

      if (startMs >= 0 && endMs > startMs) {
        timestamps.add(VerseTimestamp(
          verseKey: verseKey,
          startMs: startMs,
          endMs: endMs,
        ));
      }
    }

    timestamps.sort((a, b) => a.startMs.compareTo(b.startMs));
    return timestamps;
  }

  VerseTimestamp? _findTimestamp(int verseNumber) {
    final key = '$_currentSurahId:$verseNumber';
    for (final ts in _currentTimestamps) {
      if (ts.verseKey == key) return ts;
    }
    return null;
  }

  int? _verseAtPosition(Duration position) {
    final ms = position.inMilliseconds;
    for (final ts in _currentTimestamps) {
      if (ms >= ts.startMs && ms < ts.endMs) {
        final parts = ts.verseKey.split(':');
        if (parts.length == 2) return int.tryParse(parts[1]);
      }
    }
    if (_currentTimestamps.isNotEmpty) {
      final last = _currentTimestamps.last;
      if (ms >= last.startMs) {
        final parts = last.verseKey.split(':');
        if (parts.length == 2) return int.tryParse(parts[1]);
      }
    }
    return null;
  }

  void _handlePlaybackComplete() {
    if (_state.mode == PlaybackMode.singleVerse) {
      _state = _state.copyWith(isPlaying: false);
      _emitState();
    } else if (_state.mode == PlaybackMode.fromVerseToEnd) {
      _state = _state.copyWith(isPlaying: false);
      _emitState();
    } else {
      _playNextSurah();
    }
  }

  Future<void> _playNextSurah() async {
    final nextSurahId = (_state.surahId ?? 0) + 1;
    if (nextSurahId > 114) {
      _state = _state.copyWith(isPlaying: false);
      _emitState();
      return;
    }
    await _playSurahInternal(nextSurahId, mode: PlaybackMode.fullSurah);
  }

  Future<void> _playSurahInternal(int surahId, {
    required PlaybackMode mode,
    int? fromVerse,
  }) async {
    final reciter = _currentReciter;
    if (reciter == null) return;

    final path = await _surahPath(reciter.id, surahId);
    if (!await File(path).exists()) return;

    _state = _state.copyWith(isLoading: true, isPlaying: false);
    _emitState();

    _currentSurahId = surahId;
    _currentTimestamps = await _loadTimestamps(reciter.id, surahId);

    _ensureListeners();

    _state = _state.copyWith(
      isLoading: false,
      reciter: reciter,
      surahId: surahId,
      startVerseNumber: fromVerse ?? 1,
      currentVerseNumber: fromVerse ?? 1,
      mode: mode,
      position: Duration.zero,
      duration: Duration.zero,
    );
    _emitState();

    try {
      if (mode == PlaybackMode.singleVerse && fromVerse != null) {
        final ts = _findTimestamp(fromVerse);
        if (ts != null) {
          await _player.setAudioSource(
            ClippingAudioSource(
              start: Duration(milliseconds: ts.startMs),
              end: Duration(milliseconds: ts.endMs),
              child: AudioSource.file(path),
            ),
          );
          await _player.play();
          return;
        }
        // No timing data — fall back to playing the surah audio file rather
        // than silently refusing (which left a phantom paused mini player).
        await _player.setFilePath(path);
        await _player.play();
        return;
      }

      await _player.setFilePath(path);

      if (fromVerse != null && _currentTimestamps.isNotEmpty) {
        final ts = _findTimestamp(fromVerse);
        if (ts != null) {
          await _player.seek(Duration(milliseconds: ts.startMs));
        }
      }

      await _player.play();
    } catch (_) {
      _currentSurahId = 0;
      _currentTimestamps = [];
      _currentReciter = null;
      _state = const PlaybackState();
      _emitState();
    }
  }

  Future<void> playFullSurah(int surahId, {required ReciterModel reciter}) async {
    _currentReciter = reciter;
    _saveLastReciter(reciter.id);
    await _playSurahInternal(surahId, mode: PlaybackMode.fullSurah);
  }

  Future<void> playSingleVerse({
    required int surahId,
    required int verseNumber,
    required ReciterModel reciter,
  }) async {
    _currentReciter = reciter;
    _saveLastReciter(reciter.id);
    await _playSurahInternal(
      surahId,
      mode: PlaybackMode.singleVerse,
      fromVerse: verseNumber,
    );
  }

  Future<void> playFromVerseToEnd({
    required int surahId,
    required int verseNumber,
    required ReciterModel reciter,
  }) async {
    _currentReciter = reciter;
    _saveLastReciter(reciter.id);
    await _playSurahInternal(
      surahId,
      mode: PlaybackMode.fromVerseToEnd,
      fromVerse: verseNumber,
    );
  }

  Future<void> playAllSurahs({required ReciterModel reciter, int startSurahId = 1}) async {
    _currentReciter = reciter;
    _saveLastReciter(reciter.id);
    await _playSurahInternal(startSurahId, mode: PlaybackMode.fullSurah);
  }

  Future<void> togglePlayPause() async {
    if (_state.isEmpty) return;
    if (_player.playing) {
      await _player.pause();
      _state = _state.copyWith(isPlaying: false);
    } else {
      await _player.play();
      _state = _state.copyWith(isPlaying: true);
    }
    _emitState();
  }

  Future<void> stop() async {
    await _player.stop();
    _currentSurahId = 0;
    _currentTimestamps = [];
    _state = const PlaybackState();
    _emitState();
  }

  Future<void> seek(Duration position) async {
    await _player.seek(position);
  }

  Future<void> cancelDownload(String reciterId) async {
    ReciterStoreService.instance.cancelDownload(reciterId);
  }

  void _saveLastReciter(String reciterId) {
    try {
      final box = Hive.box<String>('settings');
      box.put(_lastReciterKey, reciterId);
    } catch (_) {}
  }

  ReciterModel? getLastReciter() {
    final id = _lastReciterId;
    if (id.isEmpty) return null;
    try {
      final allReciters = HiveService.getAllReciters();
      for (final r in allReciters) {
        if (r.id == id) return r;
      }
    } catch (_) {}
    return null;
  }

  String get _lastReciterId {
    try {
      final box = Hive.box<String>('settings');
      return box.get(_lastReciterKey) ?? '';
    } catch (_) {
      return '';
    }
  }

  void dispose() {
    _player.dispose();
    _stateController.close();
  }
}
