import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../core/utils/azkar_time_logic.dart';
import '../../../../data/models/prayer_time_model.dart';

/// Drives the [AzkarWidget]: re-evaluates the time rules on an interval and
/// notifies listeners whenever the displayed type or the hourly-seeded content
/// changes. Fully offline — no network calls anywhere.
class AzkarController extends ChangeNotifier {
  AzkarController({List<PrayerTimeModel>? prayerTimes, bool autoRefresh = true})
      : _prayerTimes = prayerTimes {
    _refresh();
    if (autoRefresh) {
      _timer = Timer.periodic(refreshInterval, (_) => _refresh());
    }
  }

  /// Re-check granularity; the evening/morning windows are hour-aligned and
  /// the Friday window starts at Jumu'ah + 15 min, so once a minute is plenty.
  static const Duration refreshInterval = Duration(minutes: 1);

  Timer? _timer;
  List<PrayerTimeModel>? _prayerTimes;
  int _hourSeed = -1;
  AzkarWidgetType _type = AzkarWidgetType.general;
  AzkarItem _item = generalAzkar.first;

  AzkarWidgetType get type => _type;
  AzkarItem get item => _item;

  /// Prayer times used for the Friday (Surat Al-Kahf) rule. Assigning new
  /// times re-evaluates immediately (e.g. when the dashboard bloc loads them).
  List<PrayerTimeModel>? get prayerTimes => _prayerTimes;
  set prayerTimes(List<PrayerTimeModel>? times) {
    if (identical(times, _prayerTimes)) return;
    _prayerTimes = times;
    _refresh();
  }

  void _refresh() {
    final now = DateTime.now();
    final seed = azkarHourSeed(now);
    final newType = getAzkarType(now, prayerTimes: _prayerTimes);
    if (seed == _hourSeed && newType == _type) return;
    _hourSeed = seed;
    _type = newType;
    _item = getAzkarItem(newType, now);
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
