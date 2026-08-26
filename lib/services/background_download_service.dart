import 'dart:async';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:bayan/data/models/reciter_model.dart';
import 'package:bayan/services/reciter_store_service.dart';

@pragma('vm:entry-point')
void backgroundServiceOnStart(ServiceInstance service) async {
  if (service is AndroidServiceInstance) {
    service.setAsForegroundService();
  }

  service.on('stopService').listen((_) {
    service.stopSelf();
  });

  service.on('pause').listen((event) {
    final reciterId = event?['reciterId'] as String?;
    if (reciterId != null) {
      ReciterStoreService.instance.pauseDownload(reciterId);
    }
  });

  service.on('resume').listen((event) {
    final reciterId = event?['reciterId'] as String?;
    if (reciterId != null) {
      ReciterStoreService.instance.resumeDownload(reciterId);
    }
  });

  service.on('cancel').listen((event) {
    final reciterId = event?['reciterId'] as String?;
    if (reciterId != null) {
      ReciterStoreService.instance.cancelDownload(reciterId);
    }
  });
}

@pragma('vm:entry-point')
bool backgroundServiceOnIosBackground(ServiceInstance service) {
  return true;
}

@pragma('vm:entry-point')
class BackgroundDownloadService {
  BackgroundDownloadService._();
  static final BackgroundDownloadService instance = BackgroundDownloadService._();

  final FlutterBackgroundService _service = FlutterBackgroundService();
  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  final ReciterStoreService _reciterService = ReciterStoreService.instance;

  static const int _notificationId = 2001;
  static const String _channelId = 'bayan_download_channel';

  bool _initialized = false;
  StreamSubscription<DownloadProgress>? _progressSub;
  StreamSubscription<Map<String, String>>? _statusSub;
  StreamSubscription<Set<String>>? _activeSub;

  final Map<String, String> _reciterNames = {};

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    await _initializeNotifications();

    await _service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: backgroundServiceOnStart,
        autoStart: false,
        isForegroundMode: true,
        notificationChannelId: _channelId,
        initialNotificationTitle: 'بيان',
        initialNotificationContent: 'Bayan Quran App',
        foregroundServiceNotificationId: _notificationId,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: backgroundServiceOnStart,
        onBackground: backgroundServiceOnIosBackground,
      ),
    );

    _listenToDownloads();
  }

  Future<void> _initializeNotifications() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);
    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationAction,
    );

    final androidPlugin = _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          _channelId,
          'Reciter Downloads',
          description: 'Shows download progress for reciters',
          importance: Importance.low,
          enableVibration: false,
          playSound: false,
        ),
      );
    }
  }

  void _listenToDownloads() {
    _progressSub?.cancel();
    _statusSub?.cancel();
    _activeSub?.cancel();

    _progressSub = _reciterService.progressStream.listen((progress) {
      _updateNotification(
        reciterId: progress.reciterId,
        progress: (progress.fraction * 100).round(),
        status: 'Downloading... ${(progress.fraction * 100).round()}%',
      );
    });

    _statusSub = _reciterService.statusStream.listen((status) {
      status.forEach((id, message) {
        if (id.isEmpty) return;
        final isPaused = message.toLowerCase().contains('paused');
        final isComplete = message.toLowerCase().contains('complete');
        final progress = _reciterService.getDownloadProgress(id);

        _updateNotification(
          reciterId: id,
          progress: (progress * 100).round(),
          status: message,
          isPaused: isPaused,
        );

        if (isComplete || message.contains('Partial')) {
          _scheduleAutoHide();
        }
      });
    });

    _activeSub = _reciterService.activeStream.listen((active) {
      if (active.isEmpty) {
        _scheduleAutoHide();
      }
    });
  }

  Timer? _autoHideTimer;
  void _scheduleAutoHide() {
    _autoHideTimer?.cancel();
    _autoHideTimer = Timer(const Duration(seconds: 5), () async {
      final active = _reciterService.activeDownloads;
      if (active.isEmpty) {
        await _hideNotification();
        await stopService();
      }
    });
  }

  Future<void> startService() async {
    if (!await _service.isRunning()) {
      await _service.startService();
    }
  }

  Future<void> stopService() async {
    if (await _service.isRunning()) {
      _service.invoke('stopService');
    }
  }

  Future<void> startDownload(ReciterModel reciter) async {
    _reciterNames[reciter.id] = reciter.name;
    await startService();
    _updateNotification(
      reciterId: reciter.id,
      progress: 0,
      status: 'Starting download...',
    );
  }

  void _onNotificationAction(NotificationResponse response) {
    final actionId = response.actionId;
    if (actionId == null) return;

    final parts = actionId.split('|');
    if (parts.length < 2) return;

    final action = parts[0];
    final reciterId = parts[1];

    switch (action) {
      case 'pause_resume':
        if (_reciterService.isPaused(reciterId)) {
          _reciterService.resumeDownload(reciterId);
        } else {
          _reciterService.pauseDownload(reciterId);
        }
        break;
      case 'cancel':
        _reciterService.cancelDownload(reciterId);
        _reciterNames.remove(reciterId);
        break;
    }
  }

  void _updateNotification({
    required String reciterId,
    required int progress,
    required String status,
    bool isPaused = false,
  }) {
    final name = _reciterNames[reciterId] ?? reciterId;
    final active = _reciterService.activeDownloads;
    final otherCount = active.length - 1;

    final String title;
    final String body;
    if (otherCount > 0) {
      title = 'Bayan - Downloading ($otherCount more)';
    } else {
      title = 'Bayan - Downloading';
    }
    body = '$name\n$status';

    _showNotification(
      title: title,
      body: body,
      ongoing: true,
      reciterId: reciterId,
      isPaused: isPaused,
    );
  }

  Future<void> _showNotification({
    required String title,
    required String body,
    required bool ongoing,
    required String reciterId,
    bool isPaused = false,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      _channelId,
      'Reciter Downloads',
      channelDescription: 'Shows download progress for reciters',
      importance: Importance.low,
      priority: Priority.low,
      ongoing: ongoing,
      showWhen: false,
      actions: [
        AndroidNotificationAction(
          'pause_resume|$reciterId',
          isPaused ? 'Continue' : 'Pause',
          cancelNotification: false,
        ),
        AndroidNotificationAction(
          'cancel|$reciterId',
          'Cancel',
          cancelNotification: true,
        ),
      ],
    );

    final details = NotificationDetails(android: androidDetails);

    await _notifications.show(
      _notificationId,
      title,
      body,
      details,
    );
  }

  Future<void> _hideNotification() async {
    await _notifications.cancel(_notificationId);
  }

  void dispose() {
    _autoHideTimer?.cancel();
    _progressSub?.cancel();
    _statusSub?.cancel();
    _activeSub?.cancel();
  }
}
