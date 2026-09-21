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

  Future<void> switchIcon(String variant) async {
    try {
      await _channel.invokeMethod('switchIcon', {'variant': variant});
      SettingsService.appIconVariant = variant;
    } on MissingPluginException {
      SettingsService.appIconVariant = variant;
    } on PlatformException catch (e) {
      if (e.code != 'MissingPluginException') rethrow;
    }
  }

  String get currentVariant => SettingsService.appIconVariant;
}
