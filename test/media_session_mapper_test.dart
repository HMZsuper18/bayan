import 'package:audio_service/audio_service.dart' as audio;
import 'package:bayan/core/utils/media_session_mapper.dart';
import 'package:bayan/data/models/reciter_model.dart';
import 'package:bayan/services/audio_playback_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final reciter = ReciterModel(
    id: 'test-reciter',
    name: 'Test Reciter',
    arabicName: '',
    bio: '',
    imageAsset: '',
  );

  group('MediaSessionMapper.processingState', () {
    test('maps recitation states onto system states', () {
      expect(
        MediaSessionMapper.processingState(isEmpty: true, isLoading: false),
        audio.AudioProcessingState.idle,
      );
      expect(
        MediaSessionMapper.processingState(isEmpty: false, isLoading: true),
        audio.AudioProcessingState.loading,
      );
      expect(
        MediaSessionMapper.processingState(isEmpty: true, isLoading: true),
        audio.AudioProcessingState.loading,
      );
      expect(
        MediaSessionMapper.processingState(isEmpty: false, isLoading: false),
        audio.AudioProcessingState.ready,
      );
    });
  });

  group('MediaSessionMapper.shouldBroadcast', () {
    final startedAt = DateTime(2026, 9, 29, 12);

    PlaybackState playing({
      Duration position = const Duration(seconds: 30),
      Duration duration = const Duration(minutes: 4),
      bool isLoading = false,
    }) =>
        PlaybackState(
          isPlaying: true,
          isLoading: isLoading,
          reciter: reciter,
          position: position,
          duration: duration,
        );

    test('stays quiet before anything has played', () {
      expect(
        MediaSessionMapper.shouldBroadcast(
          current: const PlaybackState(),
          previous: null,
          lastBroadcastPosition: Duration.zero,
          lastBroadcastAt: startedAt,
        ),
        isFalse,
      );
    });

    test('stays quiet while the first surah loads with nothing to show yet',
        () {
      expect(
        MediaSessionMapper.shouldBroadcast(
          current: const PlaybackState(isLoading: true),
          previous: const PlaybackState(),
          lastBroadcastPosition: Duration.zero,
          lastBroadcastAt: startedAt,
        ),
        isFalse,
      );
    });

    test('broadcasts the moment playback starts', () {
      expect(
        MediaSessionMapper.shouldBroadcast(
          current: playing(),
          previous: const PlaybackState(),
          lastBroadcastPosition: Duration.zero,
          lastBroadcastAt: startedAt,
        ),
        isTrue,
      );
    });

    test('does not re-broadcast while the position advances normally', () {
      expect(
        MediaSessionMapper.shouldBroadcast(
          current: playing(position: const Duration(seconds: 31)),
          previous: playing(position: const Duration(seconds: 30)),
          lastBroadcastPosition: const Duration(seconds: 30),
          lastBroadcastAt: startedAt,
          now: startedAt.add(const Duration(seconds: 2)),
        ),
        isFalse,
      );
    });

    test('broadcasts a seek as a position jump', () {
      expect(
        MediaSessionMapper.shouldBroadcast(
          current: playing(position: const Duration(seconds: 90)),
          previous: playing(position: const Duration(seconds: 30)),
          lastBroadcastPosition: const Duration(seconds: 30),
          lastBroadcastAt: startedAt,
          now: startedAt.add(const Duration(seconds: 2)),
        ),
        isTrue,
      );
    });

    test('periodically corrects drift so the seek bar stays honest', () {
      expect(
        MediaSessionMapper.shouldBroadcast(
          current: playing(position: const Duration(seconds: 32)),
          previous: playing(position: const Duration(seconds: 31)),
          lastBroadcastPosition: const Duration(seconds: 31),
          lastBroadcastAt: startedAt,
          now: startedAt.add(const Duration(seconds: 16)),
        ),
        isTrue,
      );
    });

    test('broadcasts when recitation stops', () {
      expect(
        MediaSessionMapper.shouldBroadcast(
          current: const PlaybackState(),
          previous: playing(),
          lastBroadcastPosition: const Duration(seconds: 30),
          lastBroadcastAt: startedAt,
          now: startedAt.add(const Duration(seconds: 2)),
        ),
        isTrue,
      );
    });

    test('broadcasts while a surah is loading', () {
      expect(
        MediaSessionMapper.shouldBroadcast(
          current: playing(isLoading: true),
          previous: playing(),
          lastBroadcastPosition: const Duration(seconds: 30),
          lastBroadcastAt: startedAt,
          now: startedAt.add(const Duration(seconds: 2)),
        ),
        isTrue,
      );
    });
  });

  group('MediaSessionMapper.buildPlaybackState', () {

    test('offers prev, play/pause, next, stop and a seek bar', () {
      final state = MediaSessionMapper.buildPlaybackState(PlaybackState(
        isPlaying: true,
        reciter: reciter,
        position: const Duration(seconds: 5),
        duration: const Duration(seconds: 100),
      ));

      expect(state.playing, isTrue);
      expect(state.processingState, audio.AudioProcessingState.ready);
      expect(state.updatePosition, const Duration(seconds: 5));
      expect(
        state.controls.map((c) => c.action),
        [
          audio.MediaAction.skipToPrevious,
          audio.MediaAction.pause,
          audio.MediaAction.play,
          audio.MediaAction.skipToNext,
          audio.MediaAction.stop,
        ],
      );
      expect(state.systemActions, contains(audio.MediaAction.seek));
      expect(state.androidCompactActionIndices, [0, 1, 3]);
    });

    test('never reports a loading surah as playing', () {
      final state = MediaSessionMapper.buildPlaybackState(PlaybackState(
        isPlaying: false,
        isLoading: true,
        reciter: reciter,
      ));

      expect(state.playing, isFalse);
      expect(state.processingState, audio.AudioProcessingState.loading);
    });

    test('idle once recitation has stopped', () {
      final state =
          MediaSessionMapper.buildPlaybackState(const PlaybackState());

      expect(state.playing, isFalse);
      expect(state.processingState, audio.AudioProcessingState.idle);
    });
  });
}
