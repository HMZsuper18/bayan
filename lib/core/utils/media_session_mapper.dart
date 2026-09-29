import 'package:audio_service/audio_service.dart' as audio;

import '../../services/audio_playback_service.dart';

/// Pure helpers deciding what gets published to the system media session.
///
/// Kept free of widget/stateful dependencies so the throttling rules can be
/// unit tested: Android projects the playback position forward between
/// broadcasts, so updates must only be pushed when something really changed.
class MediaSessionMapper {
  MediaSessionMapper._();

  static const List<audio.MediaControl> controls = [
    audio.MediaControl.skipToPrevious,
    audio.MediaControl.pause,
    audio.MediaControl.play,
    audio.MediaControl.skipToNext,
    audio.MediaControl.stop,
  ];

  /// prev / play-pause / next in Android's compact (collapsed) view.
  static const List<int> compactActionIndices = [0, 1, 3];

  static const Set<audio.MediaAction> systemActions = {
    audio.MediaAction.seek,
    audio.MediaAction.seekForward,
    audio.MediaAction.seekBackward,
  };

  static audio.AudioProcessingState processingState({
    required bool isEmpty,
    required bool isLoading,
  }) {
    // Loading wins: a first surah is still "empty" (no reciter attached yet)
    // while it prepares its audio.
    if (isLoading) return audio.AudioProcessingState.loading;
    if (isEmpty) return audio.AudioProcessingState.idle;
    return audio.AudioProcessingState.ready;
  }

  /// Whether the current recitation state is worth sending to the system.
  static bool shouldBroadcast({
    required PlaybackState current,
    PlaybackState? previous,
    required Duration lastBroadcastPosition,
    required DateTime lastBroadcastAt,
    DateTime? now,
  }) {
    final clock = now ?? DateTime.now();

    // Nothing has ever played — don't wake the media session up at start-up.
    if (current.isEmpty && previous == null) return false;

    // The very first surah is still loading, so there is no reciter (and
    // therefore no media item) to show yet: broadcasting now would flash a
    // metadata-less notification.
    if (current.isEmpty && current.isLoading) return false;

    if (previous == null) return true;
    if (current.isEmpty != previous.isEmpty) return true;
    if (current.isPlaying != previous.isPlaying) return true;
    if (current.isLoading != previous.isLoading) return true;
    if (current.duration != previous.duration) return true;

    // A seek (or an edited position) shows up as a jump relative to the last
    // broadcast position; steady progress does not.
    if ((current.position - lastBroadcastPosition).abs() >
        const Duration(seconds: 1)) {
      return true;
    }

    // Periodic correction so drift between us and the system stays invisible.
    return clock.difference(lastBroadcastAt) > const Duration(seconds: 15);
  }

  static audio.PlaybackState buildPlaybackState(PlaybackState state) {
    return audio.PlaybackState(
      controls: controls,
      androidCompactActionIndices: compactActionIndices,
      systemActions: systemActions,
      processingState: processingState(
        isEmpty: state.isEmpty,
        isLoading: state.isLoading,
      ),
      playing: state.isPlaying && !state.isLoading,
      updatePosition: state.position,
      bufferedPosition: state.position,
      speed: 1.0,
    );
  }
}
