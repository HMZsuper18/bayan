import 'package:flutter/services.dart';
import '../data/database/settings_service.dart';

class AppIconService {
  AppIconService._();
  static final AppIconService instance = AppIconService._();
  static const _channel = MethodChannel('com.hamzah.bayan/app_icon');

  static const variants = ['Classic', 'Emerald', 'Midnight', 'Gold', 'Royal'];

  Future<void> init() async {
    try {
      await _channel.invokeMethod('switchIcon', {'variant': currentVariant});
    } on MissingPluginException {
    } on PlatformException {
    }
  }

  /// Returns true only when the icon actually changed on a device with a
  /// MIUI/HyperOS dock (whose icon cache may need a guided refresh).
  Future<bool> switchIcon(String variant) async {
    try {
      final needsDockHelp =
          await _channel.invokeMethod<bool>('switchIcon', {'variant': variant}) ??
              false;
      SettingsService.appIconVariant = variant;
      return needsDockHelp;
    } on MissingPluginException {
      SettingsService.appIconVariant = variant;
      return false;
    } on PlatformException catch (e) {
      if (e.code != 'MissingPluginException') rethrow;
      return false;
    }
  }

  /// Disables the previous alias after the UI is ready and relaunches if
  /// the running component was the one switched away from.
  Future<void> finalizeSwitch() async {
    try {
      await _channel.invokeMethod('finalizeIconSwitch');
    } on MissingPluginException {
    } on PlatformException {
    }
  }

  Future<void> openLauncherSettings() async {
    try {
      await _channel.invokeMethod('openLauncherSettings');
    } on MissingPluginException {
    } on PlatformException {
    }
  }

  String get currentVariant => SettingsService.appIconVariant;
}
