import 'package:hive/hive.dart';
import '../data/models/reciter_model.dart';
import '../data/database/hive_service.dart';

class DefaultReciterService {
  static const String _boxName = 'settings';
  static const String _defaultReciterIdKey = 'default_reciter_id';
  static const String _lastReciterIdKey = 'last_reciter_id';

  static Future<void> init() async {
    await Hive.openBox<String>(_boxName);
  }

  static String? getDefaultReciterId() {
    try {
      final box = Hive.box<String>(_boxName);
      return box.get(_defaultReciterIdKey);
    } catch (_) {
      return null;
    }
  }

  static ReciterModel? getDefaultReciter() {
    final id = getDefaultReciterId();
    if (id == null) return null;
    final reciter = HiveService.recitersBox.get(id);
    return reciter;
  }

  static Future<void> setDefaultReciterId(String reciterId) async {
    final box = Hive.box<String>(_boxName);
    await box.put(_defaultReciterIdKey, reciterId);
  }

  static Future<void> clearDefaultReciter() async {
    final box = Hive.box<String>(_boxName);
    await box.delete(_defaultReciterIdKey);
  }

  static bool isValidDefaultReciterAvailable() {
    return getDefaultReciter() != null;
  }

  static String? getLastReciterId() {
    try {
      final box = Hive.box<String>(_boxName);
      return box.get(_lastReciterIdKey);
    } catch (_) {
      return null;
    }
  }

  static (ReciterModel?, bool, String?) validateDefaultReciter() {
    // Fall back to the last used reciter so playback works as soon as any
    // reciter has been downloaded, without requiring an explicit selection.
    final id = getDefaultReciterId() ?? getLastReciterId();

    if (id == null) {
      return (
        null,
        false,
        'رجاءً اختر القارئ الافتراضي أولاً',
      );
    }

    final reciter = HiveService.recitersBox.get(id);
    if (reciter == null) {
      return (
        null,
        false,
        'القارئ المختار غير متوفر. يرجى تحميل القارئ الافتراضي أولاً.',
      );
    }

    return (reciter, true, null);
  }
}
