import 'dart:async';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';

import '../core/utils/media_art_renderer.dart';
import '../core/utils/media_session_mapper.dart';
import '../data/database/hive_service.dart';
import '../data/models/reciter_model.dart';
import '../data/models/surah_model.dart';
import 'adhan_notification_service.dart';
import 'audio_playback_service.dart' as rec;

/// Publishes recitation playback to the system media session so recitations
/// can be controlled outside the app — control centre, lock screen, headset
/// and Bluetooth buttons, Android Auto — exactly like a regular media player.
///
/// The session is an *adapter*: [rec.AudioPlaybackService] stays the single
/// source of truth for playback and the in-app UI keeps listening to it
/// unchanged; this service only mirrors its state outwards and routes system
/// commands back in.
class MediaSessionService {
  MediaSessionService._();
  static final MediaSessionService instance = MediaSessionService._();

  RecitationAudioHandler? _handler;
  bool _initialised = false;

  /// The active handler, or `null` when no media session is available
  /// (desktop platforms, or if the plugin failed to register).
  RecitationAudioHandler? get handler => _handler;
  bool get isSupported => _handler != null;

  Future<void> init() async {
    if (_initialised) return;
    _initialised = true;

    // audio_service has no Linux/Windows implementation; calling into it
    // there would throw during start-up.
    if (!Platform.isAndroid && !Platform.isIOS) return;

    try {
      _handler = await AudioService.init(
        builder: RecitationAudioHandler.new,
        config: const AudioServiceConfig(
          androidNotificationChannelId: 'com.hamzah.bayan.media',
          androidNotificationChannelName: 'Recitation playback',
          androidNotificationChannelDescription:
              'Controls for Quran recitation playback',
          androidNotificationIcon: 'drawable/ic_stat_bayan',
          notificationColor: Color(0xFF00674F),
          // Keep the service in the foreground while paused: restarting a
          // foreground service from the background is restricted on Android 12+,
          // and the controls should stay reachable between ayat.
          androidStopForegroundOnPause: false,
          androidNotificationOngoing: false,
          artDownscaleWidth: MediaArtRenderer.artSize,
          artDownscaleHeight: MediaArtRenderer.artSize,
        ),
      );
    } catch (e) {
      debugPrint('Media session unavailable: $e');
      _handler = null;
    }
  }
}

/// Bridges [rec.AudioPlaybackService] to the system media session.
class RecitationAudioHandler extends BaseAudioHandler with SeekHandler {
  RecitationAudioHandler() {
    final service = rec.AudioPlaybackService.instance;
    _last = service.currentState;
    // The handler lives for the whole app lifetime, so the subscription is
    // never cancelled.
    service.stateStream.listen(_onStateChanged);
    if (!_last.isEmpty) {
      scheduleMicrotask(() => _onStateChanged(service.currentState));
    }
  }

  rec.PlaybackState _last = const rec.PlaybackState();

  String? _mediaKey;
  String? _artKey;
  Uri? _artUri;

  Duration _lastPosition = Duration.zero;
  DateTime _lastBroadcast = DateTime.fromMillisecondsSinceEpoch(0);
  bool _permissionRequested = false;

  // ---------------------------------------------------------------- commands

  @override
  Future<void> play() => rec.AudioPlaybackService.instance.play();

  @override
  Future<void> pause() => rec.AudioPlaybackService.instance.pause();

  @override
  Future<void> stop() => rec.AudioPlaybackService.instance.stop();

  @override
  Future<void> seek(Duration position) =>
      rec.AudioPlaybackService.instance.seek(position);

  @override
  Future<void> skipToNext() => rec.AudioPlaybackService.instance.playNext();

  @override
  Future<void> skipToPrevious() =>
      rec.AudioPlaybackService.instance.playPrevious();

  // Deliberately no `onTaskRemoved` override: swiping the app away must not
  // stop a recitation that is playing in the background.

  @override
  Future<void> onNotificationDeleted() =>
      rec.AudioPlaybackService.instance.stop();

  // ------------------------------------------------------------------ state

  void _onStateChanged(rec.PlaybackState state) {
    final previous = _last;
    _last = state;

    _updateMediaItem(state, previous);
    _updatePlaybackState(state, previous);

    if (state.isEmpty && previous.isEmpty) return;
    if (previous.isEmpty && !state.isEmpty) {
      unawaited(_requestNotificationPermissionOnce());
    }
  }

  void _updateMediaItem(rec.PlaybackState state, rec.PlaybackState? previous) {
    final reciter = state.reciter;
    final surahId = state.surahId;
    if (state.isEmpty || reciter == null || surahId == null) {
      if (_mediaKey != null) {
        _mediaKey = null;
        _artKey = null;
        _artUri = null;
        mediaItem.add(null);
      }
      return;
    }

    final key = '${reciter.id}:$surahId';
    final durationChanged =
        state.duration > Duration.zero && state.duration != previous?.duration;
    if (key == _mediaKey && !durationChanged) return;

    if (key != _mediaKey) {
      _mediaKey = key;
      _artKey = null;
      _artUri = null;
    }

    final surah = _surah(surahId);
    mediaItem.add(_buildItem(
      key: key,
      surahId: surahId,
      reciter: reciter,
      surah: surah,
      duration: state.duration,
    ));

    if (_artKey != key) {
      unawaited(_attachArtwork(
        key: key,
        reciter: reciter,
        surahId: surahId,
        surah: surah,
      ));
    }
  }

  void _updatePlaybackState(
    rec.PlaybackState state,
    rec.PlaybackState? previous,
  ) {
    if (!MediaSessionMapper.shouldBroadcast(
      current: state,
      previous: previous,
      lastBroadcastPosition: _lastPosition,
      lastBroadcastAt: _lastBroadcast,
    )) {
      return;
    }

    _lastPosition = state.position;
    _lastBroadcast = DateTime.now();
    playbackState.add(MediaSessionMapper.buildPlaybackState(state));
  }

  SurahModel? _surah(int surahId) {
    try {
      return HiveService.surahsBox.get(surahId);
    } catch (_) {
      return null;
    }
  }

  MediaItem _buildItem({
    required String key,
    required int surahId,
    required ReciterModel reciter,
    required SurahModel? surah,
    required Duration duration,
  }) {
    final title = (surah?.name.isNotEmpty ?? false)
        ? surah!.name
        : (surah?.englishName.isNotEmpty ?? false)
            ? surah!.englishName
            : 'Surah $surahId';
    return MediaItem(
      id: key,
      title: title,
      artist: reciter.name,
      album: surah?.englishName ?? '',
      duration: duration > Duration.zero ? duration : null,
      artUri: _artUri,
    );
  }

  Future<void> _attachArtwork({
    required String key,
    required ReciterModel reciter,
    required int surahId,
    required SurahModel? surah,
  }) async {
    _artKey = key;
    final file = await MediaArtRenderer.render(
      reciterId: reciter.id,
      surahId: surahId,
      surahArabicName: surah?.name ?? '',
      surahEnglishName: surah?.englishName ?? '',
      reciterName: reciter.name,
    );
    if (file == null || _mediaKey != key) return;

    _artUri = Uri.file(file.path);
    mediaItem.add(_buildItem(
      key: key,
      surahId: surahId,
      reciter: reciter,
      surah: surah,
      duration: _last.duration,
    ));
  }

  // -------------------------------------------------------------- permission

  Future<void> _requestNotificationPermissionOnce() async {
    if (_permissionRequested) return;
    _permissionRequested = true;
    await AdhanNotificationService.instance.requestNotificationPermission();
  }
}
