import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../data/database/hive_service.dart';
import '../data/models/reciter_model.dart';
import 'audio_playback_service.dart';
import 'recitations_widget_service.dart';

/// Handles play/pause/cancel commands from the home-screen widget over
/// [WidgetControlsReceiver]'s channel. Registered at the top of `main()` so a
/// headless engine booted by the receiver can act without any Activity.
class WidgetControlHandler {
  WidgetControlHandler._();

  static const MethodChannel channel = MethodChannel(
    'com.hamzah.bayan/widget_controls',
  );

  static final Completer<void> _ready = Completer<void>();

  /// Completes once Hive/settings are initialized and actions are safe to run.
  static Future<void> get ready => _ready.future;

  static void markReady() {
    if (!_ready.isCompleted) _ready.complete();
  }

  static void register() {
    channel.setMethodCallHandler(_handle);
  }

  static Future<void> _handle(MethodCall call) async {
    // Ack as soon as the action is accepted — the receiver's reply must not
    // wait for ExoPlayer setup/widget sync (that can take seconds on a cold
    // engine and would look like a dropped command).
    await ready.timeout(const Duration(seconds: 6));
    switch (call.method) {
      case 'toggle':
        unawaited(
          AudioPlaybackService.instance.togglePlayPause().catchError((
            Object e,
            StackTrace s,
          ) {
            debugPrint('widget toggle failed: $e');
          }),
        );
      case 'stop':
        unawaited(
          AudioPlaybackService.instance.stop().catchError((
            Object e,
            StackTrace s,
          ) {
            debugPrint('widget stop failed: $e');
          }),
        );
      case 'play':
        unawaited(
          playReciter(call.arguments as String).catchError((
            Object e,
            StackTrace s,
          ) {
            debugPrint('widget play failed: $e');
          }),
        );
      default:
        throw MissingPluginException('Unknown method ${call.method}');
    }
  }

  /// Same behavior as tapping a reciter chip: play this reciter from the
  /// beginning, or resume/pause when it is already the current one.
  static Future<void> playReciter(String reciterId) async {
    ReciterModel? reciter;
    for (final r in HiveService.getAllReciters()) {
      if (r.id == reciterId) {
        reciter = r;
        break;
      }
    }
    if (reciter == null) return;
    final audio = AudioPlaybackService.instance;
    if (audio.currentState.reciter?.id == reciterId) {
      await audio.togglePlayPause();
    } else {
      await audio.playAllSurahs(reciter: reciter, startSurahId: 1);
      await RecitationsWidgetService.update(
        lastPlayedReciterId: reciter.id,
        lastPlayedReciterName: reciter.arabicName,
      );
    }
  }
}
