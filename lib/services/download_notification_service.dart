import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../core/utils/notification_locale.dart';
import '../core/utils/reciter_utils.dart';
import '../data/database/hive_service.dart';
import '../data/database/settings_service.dart';
import '../data/models/reciter_model.dart';
import '../l10n/app_localizations.dart';
import 'reciter_store_service.dart';

/// Mirrors [ReciterStoreService] downloads into a system notification so the
/// progress stays visible — and the foreground service keeps the transfer
/// alive — while the app is backgrounded.
///
/// All copy is resolved here against the device locale and handed to Kotlin
/// already translated; the platform side holds no strings of its own.
class DownloadNotificationService {
  DownloadNotificationService._();
  static final DownloadNotificationService instance =
      DownloadNotificationService._();

  static const MethodChannel _channel =
      MethodChannel('com.hamzah.bayan/download_progress');
  static const Duration _hideDelay = Duration(seconds: 5);
  static const Duration _cancelHideDelay = Duration(seconds: 1);
  static const Duration _minPushInterval = Duration(milliseconds: 500);

  final ReciterStoreService _store = ReciterStoreService.instance;

  AppLocalizations? _l10n;
  List<ReciterModel> _reciters = const [];
  final Set<String> _active = {};
  final Map<String, double> _progress = {};
  String? _lastTitle;

  Timer? _hideTimer;
  DateTime _lastPush = DateTime.fromMillisecondsSinceEpoch(0);
  bool _initialized = false;

  /// Seed data is written *after* [init] runs, so the first lookup can come
  /// back empty on a fresh install. Re-read lazily until it resolves instead of
  /// caching the empty list forever and falling back to raw reciter ids.
  List<ReciterModel> get _recitersList {
    if (_reciters.isEmpty) _reciters = HiveService.getAllReciters();
    return _reciters;
  }

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    _reciters = HiveService.getAllReciters();
    await _loadLocalizations();

    _active.addAll(_store.activeDownloads);
    for (final id in _active) {
      _progress[id] = _store.getDownloadProgress(id);
    }

    // App-lifetime subscriptions: ReciterStoreService owns the controllers and
    // only closes them when the app itself shuts down.
    _store.activeStream.listen(_onActive);
    _store.progressStream.listen(_onProgress);

    if (!Platform.isAndroid) return;
    ui.PlatformDispatcher.instance.onLocaleChanged = () async {
      await _loadLocalizations();
      _push(force: true);
    };
    if (_active.isNotEmpty) _push(force: true);
  }

  Future<void> _loadLocalizations() async {
    final locale = resolveNotificationLocale(
      ui.PlatformDispatcher.instance.locale,
      AppLocalizations.supportedLocales,
      SettingsService.uiLanguage,
    );
    _l10n = await AppLocalizations.delegate.load(locale);
  }

  void _onActive(Set<String> ids) {
    _hideTimer?.cancel();
    _hideTimer = null;

    if (ids.isEmpty) {
      final completed = _active.isNotEmpty && _active.every(_isComplete);
      _active.clear();
      _progress.clear();
      if (completed) {
        _pushCompleted();
        _hideTimer = Timer(_hideDelay, _stop);
      } else {
        // Cancelled or abandoned: drop the notification without celebrating.
        _hideTimer = Timer(_cancelHideDelay, _stop);
      }
      return;
    }

    _active
      ..clear()
      ..addAll(ids);
    for (final id in ids) {
      _progress.putIfAbsent(id, () => _store.getDownloadProgress(id));
    }
    _push(force: true);
  }

  void _onProgress(DownloadProgress progress) {
    _progress[progress.reciterId] = progress.fraction;
    if (_active.contains(progress.reciterId)) _push();
  }

  bool _isComplete(String id) => (_progress[id] ?? 0.0) >= 0.999;

  /// Post the final "downloaded" state before the notification is dismissed.
  void _pushCompleted() {
    final l10n = _l10n;
    if (l10n == null) return;
    _send(
      channelName: l10n.downloadNotificationChannelName,
      channelDescription: l10n.downloadNotificationChannelDescription,
      title: _lastTitle ?? l10n.downloadNotificationChannelName,
      text: l10n.downloaded,
      progress: 100,
      indeterminate: false,
      force: true,
    );
  }

  void _push({bool force = false}) {
    final l10n = _l10n;
    if (l10n == null || _active.isEmpty) return;

    final ids = _active.toList(growable: false);
    var sum = 0.0;
    for (final id in ids) {
      sum += _progress[id] ?? 0.0;
    }
    final mean = sum / ids.length;
    final percent = (mean * 100).round();
    // One decimal keeps the text visibly moving even on a long, slow transfer;
    // the bar itself stays integral.
    final percentText = (mean * 100).toStringAsFixed(1);

    final String title;
    final String text;
    if (ids.length == 1) {
      title = _nameFor(ids.first, l10n);
      text = l10n.downloadNotificationProgress(percentText);
    } else {
      title = l10n.downloadNotificationMultiple(ids.length);
      final parts = <String>[];
      for (final id in ids) {
        final pct = ((_progress[id] ?? 0.0) * 100).toStringAsFixed(1);
        parts.add('${_nameFor(id, l10n)} $pct%');
      }
      text = parts.join(' • ');
    }

    _send(
      channelName: l10n.downloadNotificationChannelName,
      channelDescription: l10n.downloadNotificationChannelDescription,
      title: title,
      text: text,
      progress: percent,
      indeterminate: mean <= 0,
      force: force,
    );
  }

  void _send({
    required String channelName,
    required String channelDescription,
    required String title,
    required String text,
    required int progress,
    required bool indeterminate,
    required bool force,
  }) {
    if (!Platform.isAndroid) return;
    final now = DateTime.now();
    if (!force && now.difference(_lastPush) < _minPushInterval) return;
    _lastPush = now;
    _lastTitle = title;

    unawaited(_invokeUpdate(channelName, channelDescription, title, text,
        progress, indeterminate));
  }

  Future<void> _invokeUpdate(
    String channelName,
    String channelDescription,
    String title,
    String text,
    int progress,
    bool indeterminate,
  ) async {
    try {
      await _channel.invokeMethod<void>('update', <String, Object>{
        'channelName': channelName,
        'channelDescription': channelDescription,
        'title': title,
        'text': text,
        'progress': progress,
        'indeterminate': indeterminate,
      });
    } on PlatformException catch (e) {
      debugPrint('Download notification update failed: ${e.message}');
    } on MissingPluginException {
      // Platform side unavailable — nothing to show there.
    }
  }

  Future<void> _stop() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>('stop');
    } on PlatformException catch (e) {
      debugPrint('Download notification stop failed: ${e.message}');
    } on MissingPluginException {
      // Platform side unavailable.
    }
  }

  String _nameFor(String reciterId, AppLocalizations l10n) {
    for (final reciter in _recitersList) {
      if (reciter.id == reciterId) return reciterDisplayName(l10n, reciter);
    }
    return reciterId;
  }
}
