import 'dart:async';
import 'package:flutter/services.dart';
import '../core/utils/prayer_time_calculator.dart';
import '../data/database/settings_service.dart';

/// Schedules and cancels adhan (prayer time) notifications on Android
/// via a MethodChannel to native AlarmManager. No sound — visual only.
class AdhanNotificationService {
  AdhanNotificationService._();
  static final AdhanNotificationService instance = AdhanNotificationService._();

  static const _channel = MethodChannel('com.hamzah.bayan/adhan_notifications');
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  /// Schedules notifications for the given prayer times.
  /// [prayerTimes] is a list of maps with keys: name, hour, minute.
  /// Each prayer gets a notification at its time and optionally a reminder
  /// [reminderMinutes] before.
  Future<void> scheduleNotifications({
    required List<Map<String, dynamic>> prayerTimes,
    int reminderMinutes = 10,
  }) async {
    if (!adhanEnabled) return;
    try {
      await _channel.invokeMethod('scheduleNotifications', {
        'prayerTimes': prayerTimes,
        'reminderMinutes': reminderMinutes,
        'enabled': true,
      });
    } on PlatformException catch (e) {
      // Silently fail on unsupported platforms
      if (e.code != 'MissingPluginException') {
        rethrow;
      }
    }
  }

  /// Cancels all scheduled adhan notifications.
  Future<void> cancelAll() async {
    try {
      await _channel.invokeMethod('cancelAll');
    } on PlatformException catch (e) {
      if (e.code != 'MissingPluginException') {
        rethrow;
      }
    }
  }

  /// Reschedules notifications (call after prayer times update).
  Future<void> reschedule({
    required List<Map<String, dynamic>> prayerTimes,
    int reminderMinutes = 10,
  }) async {
    await cancelAll();
    await scheduleNotifications(
      prayerTimes: prayerTimes,
      reminderMinutes: reminderMinutes,
    );
  }

  /// Reschedules notifications from stored settings (e.g. on app startup
  /// or after device reboot). Uses the full Flutter prayer time calculator.
  Future<void> rescheduleFromSettings() async {
    if (!adhanEnabled) return;
    try {
      final lat = SettingsService.latitude;
      final lng = SettingsService.longitude;
      final saved = SettingsService.prayerCalculationMethod;
      final method = saved == 'auto'
          ? PrayerTimeCalculator.detectMethod(lat, lng)
          : PrayerTimeCalculator.methodFromKey(saved);
      final times = PrayerTimeCalculator.calculate(
        latitude: lat,
        longitude: lng,
        method: method,
      );
      final prayerData = times
          .where((t) => t.name != 'Sunrise')
          .map((t) => {
                'name': t.name.toLowerCase(),
                'hour': t.time.hour,
                'minute': t.time.minute,
              })
          .toList();
      await scheduleNotifications(
        prayerTimes: prayerData,
        reminderMinutes: reminderMinutes,
      );
    } on PlatformException catch (e) {
      if (e.code != 'MissingPluginException') {
        rethrow;
      }
    }
  }

  /// Handles calls from native side (e.g., notification tapped).
  Future<dynamic> _handleMethodCall(MethodCall call) async {
    // Native may notify us when a notification fires — no action needed
    // for now since we're visual-only.
  }

  static bool get adhanEnabled =>
      SettingsService.adhanEnabled;

  static set adhanEnabled(bool value) =>
      SettingsService.adhanEnabled = value;

  static int get reminderMinutes =>
      SettingsService.adhanReminderMinutes;

  static set reminderMinutes(int value) =>
      SettingsService.adhanReminderMinutes = value;
}
