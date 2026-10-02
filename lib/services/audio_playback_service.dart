import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:hive/hive.dart';

import '../data/models/reciter_model.dart';
import '../data/database/hive_service.dart';
import 'reciter_store_service.dart';
import 'recitations_widget_service.dart';

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
  DateTime? _lastWidgetSync;
  String _widgetSignature = '';

  AudioPlayer get player => _player;

  static const String _lastReciterKey = 'last_reciter_id';
  static const String _lastSurahKey = 'last_surah_id';

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
    _syncWidgetPlayback();
  }

  /// Mirrors the playback state onto the home screen widget playbar.
  /// Pushes immediately whenever reciter/surah/playing-state changes and
  /// otherwise at most every 3 seconds (for the progress bar).
  void _syncWidgetPlayback({bool force = false}) {
    final s = _state;
    final active = s.reciter != null;
    final signature =
        '${s.reciter?.id}|${s.surahId}|${s.isPlaying}|${s.isLoading}';
    final now = DateTime.now();
    final last = _lastWidgetSync;
    if (!force &&
        signature == _widgetSignature &&
        last != null &&
        now.difference(last) < const Duration(seconds: 3)) {
      return;
    }
    _widgetSignature = signature;
    _lastWidgetSync = now;

    final progress = s.duration.inMilliseconds > 0
        ? ((s.position.inMilliseconds * 100) / s.duration.inMilliseconds)
            .round()
            .clamp(0, 100)
            .toInt()
        : 0;

    RecitationsWidgetService.syncPlayback(
      active: active,
      reciter: s.reciter,
      surahId: s.surahId,
      paused: active && !s.isPlaying && !s.isLoading,
      progress: progress,
    );
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
      stop();
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
      // Whole mushaf finished — hide the widget playbar.
      RecitationsWidgetService.syncPlayback(active: false);
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
    _saveLastSurah(surahId);
    _currentTimestamps = await _loadTimestamps(reciter.id, surahId);

    // Detect Isti'adhah / Basmalah offset: some audio files have a
    // pre-recitation invocation prepended before the actual verses,
    // shifting all content forward.  The Quran.com timestamps are
    // aligned to clean audio, so we compare the file's total duration
    // with the last timestamp to find the extra leading content.
    await _adjustTimestampsForIstiadhah(path);

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

  /// A gap between the file duration and the last segment boundary smaller
  /// than this is normal container/padding slop, not prepended content.
  static const int gapThresholdMs = 1000;

  /// No Isti'adhah invocation is longer than this.  A gap above it means the
  /// segment data does not belong to this file, so shifting would be worse
  /// than leaving the timestamps alone.
  static const int maxPreambleMs = 6000;

  /// How far every verse timestamp must be shifted to line up with [audioMs]
  /// of actual audio, in milliseconds (0 = leave the timestamps alone).
  ///
  /// The gap between the file duration and the last segment can be prepended
  /// Isti'adhah (shift forward) or trailing content such as a closing du'a
  /// (shift nothing) — and only the length is observable, so the decision
  /// leans on two guards:
  ///
  ///  * segments whose first verse already starts past 0 carry the preamble
  ///    offset themselves, so shifting would double-count it;
  ///  * a gap past [maxPreambleMs] is far too long to be an invocation.
  static int timestampShiftMs({
    required int audioMs,
    required List<VerseTimestamp> timestamps,
  }) {
    if (timestamps.isEmpty) return 0;
    final sorted = [...timestamps]
      ..sort((a, b) => a.startMs.compareTo(b.startMs));
    final gap = audioMs - sorted.last.endMs;
    if (gap <= gapThresholdMs) return 0;
    if (sorted.first.startMs > 0) return 0;
    if (gap > maxPreambleMs) return 0;
    return gap;
  }

  /// Probes the audio file's total duration and, when it is longer than the
  /// segment data describes, shifts every verse boundary forward by the
  /// preamble amount decided by [timestampShiftMs].
  Future<void> _adjustTimestampsForIstiadhah(String audioPath) async {
    if (_currentTimestamps.isEmpty) return;

    try {
      // Use a temporary player so the main player stays untouched.
      final probe = AudioPlayer();
      await probe.setFilePath(audioPath);
      // Wait up to 5 s for the duration to resolve.
      final duration = await probe.durationStream
          .firstWhere((d) => d != null)
          .timeout(const Duration(seconds: 5), onTimeout: () => null)
          .catchError((_) => null);
      await probe.dispose();

      if (duration == null) return;

      final shift = timestampShiftMs(
        audioMs: duration.inMilliseconds,
        timestamps: _currentTimestamps,
      );
      if (shift == 0) return;

      _currentTimestamps = _currentTimestamps.map((ts) => VerseTimestamp(
        verseKey: ts.verseKey,
        startMs: ts.startMs + shift,
        endMs: ts.endMs + shift,
      )).toList();
    } catch (_) {}
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
      await pause();
    } else {
      await play();
    }
  }

  /// Resumes playback, or restarts the last recitation when nothing is loaded
  /// (e.g. a play command coming from the system media notification).
  Future<void> play() async {
    if (_state.isEmpty) {
      await _resumeLast();
      return;
    }
    await _player.play();
    _state = _state.copyWith(isPlaying: true);
    _emitState();
  }

  Future<void> pause() async {
    if (_state.isEmpty) return;
    await _player.pause();
    _state = _state.copyWith(isPlaying: false);
    _emitState();
  }

  /// Skips forward: next verse in single-verse mode, otherwise next surah.
  Future<void> playNext() async {
    if (_state.isEmpty) return;
    final surahId = _state.surahId;
    if (_state.mode == PlaybackMode.singleVerse &&
        surahId != null &&
        _currentReciter != null) {
      final nextVerse = (_state.currentVerseNumber ?? 1) + 1;
      if (nextVerse <= _verseCount(surahId)) {
        await playSingleVerse(
          surahId: surahId,
          verseNumber: nextVerse,
          reciter: _currentReciter!,
        );
        return;
      }
    }
    await _playNextSurah();
  }

  /// Seeks back to the start when more than 3 s in, otherwise jumps to the
  /// previous verse/surah — the behaviour users expect from a media player.
  Future<void> playPrevious() async {
    if (_state.isEmpty) return;
    final surahId = _state.surahId;
    if (surahId == null || _currentReciter == null) return;

    if (_player.position > const Duration(seconds: 3)) {
      await _player.seek(Duration.zero);
      return;
    }

    if (_state.mode == PlaybackMode.singleVerse) {
      final prevVerse = (_state.currentVerseNumber ?? 1) - 1;
      if (prevVerse >= 1) {
        await playSingleVerse(
          surahId: surahId,
          verseNumber: prevVerse,
          reciter: _currentReciter!,
        );
        return;
      }
    }

    final prevSurahId = surahId - 1;
    if (prevSurahId < 1) {
      await _playSurahInternal(surahId, mode: _state.mode);
      return;
    }
    await _playSurahInternal(prevSurahId, mode: PlaybackMode.fullSurah);
  }

  Future<void> _resumeLast() async {
    final reciter = getLastReciter();
    final surahId = _lastSurahId;
    if (reciter == null || surahId <= 0) return;
    await playFullSurah(surahId, reciter: reciter);
  }

  int _verseCount(int surahId) {
    try {
      return HiveService.surahsBox.get(surahId)?.versesCount ?? 0;
    } catch (_) {
      return 0;
    }
  }

  Future<void> stop() async {
    await _player.stop();
    _currentSurahId = 0;
    _currentTimestamps = [];
    _state = const PlaybackState();
    _emitState();
    RecitationsWidgetService.syncPlayback(active: false);
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
    RecitationsWidgetService.recordListen(reciterId);
    RecitationsWidgetService.update();
  }

  void _saveLastSurah(int surahId) {
    try {
      final box = Hive.box<String>('settings');
      box.put(_lastSurahKey, surahId.toString());
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

  int get _lastSurahId {
    try {
      final box = Hive.box<String>('settings');
      return int.tryParse(box.get(_lastSurahKey) ?? '') ?? 0;
    } catch (_) {
      return 0;
    }
  }

  void dispose() {
    _player.dispose();
    _stateController.close();
  }
}
