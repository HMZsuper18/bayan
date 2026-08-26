import 'dart:math';
import '../../data/models/prayer_time_model.dart';
import '../../data/database/settings_service.dart';

enum CalculationMethod {
  ummAlQura,
  muslimWorldLeague,
  egyptian,
  isna,
  karachi,
}

extension _CalculationMethodX on CalculationMethod {
  double get fajrAngle {
    switch (this) {
      case CalculationMethod.ummAlQura:
        return -18.5;
      case CalculationMethod.muslimWorldLeague:
        return -18.0;
      case CalculationMethod.egyptian:
        return -19.5;
      case CalculationMethod.isna:
        return -15.0;
      case CalculationMethod.karachi:
        return -18.0;
    }
  }

  int ishaMinutesAfterMaghrib(DateTime date) {
    switch (this) {
      case CalculationMethod.ummAlQura:
        final month = date.month;
        final day = date.day;
        if (month == 9 && day >= 1 && day <= 30) return 120;
        return 90;
      case CalculationMethod.muslimWorldLeague:
      case CalculationMethod.egyptian:
      case CalculationMethod.isna:
      case CalculationMethod.karachi:
        return -1;
    }
  }

  double? get ishaAngle {
    switch (this) {
      case CalculationMethod.ummAlQura:
        return null;
      case CalculationMethod.muslimWorldLeague:
        return -17.0;
      case CalculationMethod.egyptian:
        return -17.5;
      case CalculationMethod.isna:
        return -15.0;
      case CalculationMethod.karachi:
        return -18.0;
    }
  }
}

class PrayerTimeCalculator {
  PrayerTimeCalculator._();

  static List<PrayerTimeModel> getDefault() => calculate(
        latitude: SettingsService.latitude,
        longitude: SettingsService.longitude,
      );

  static List<PrayerTimeModel> calculate({
    required double latitude,
    required double longitude,
    DateTime? date,
    CalculationMethod method = CalculationMethod.ummAlQura,
  }) {
    final now = date ?? DateTime.now();
    final doy = _dayOfYear(now);
    final d = (2 * pi / 365) * (doy - 1);

    final declination = 0.006918 -
        0.399912 * cos(d) +
        0.070257 * sin(d) -
        0.006758 * cos(2 * d) +
        0.000907 * sin(2 * d) -
        0.002697 * cos(3 * d) +
        0.00148 * sin(3 * d);

    final eqOfTime = 229.18 *
        (0.000075 +
            0.001868 * cos(d) -
            0.032077 * sin(d) -
            0.014615 * cos(2 * d) -
            0.04089 * sin(2 * d));

    final timezoneOffset = now.timeZoneOffset.inHours;
    final stdMeridian = timezoneOffset * 15;
    final longCorrection = (longitude - stdMeridian) / 15.0;
    final solarNoon = 12.0 - longCorrection - eqOfTime / 60.0;
    final noon = DateTime(now.year, now.month, now.day)
        .add(Duration(minutes: (solarNoon * 60).round()));

    final latRad = latitude * pi / 180;
    final decRad = declination;

    double hourAngle(double altitude) {
      final cosH = (sin(altitude) - sin(latRad) * sin(decRad)) /
          (cos(latRad) * cos(decRad));
      if (cosH > 1 || cosH < -1) return 0;
      return acos(cosH);
    }

    int minutesFromAngle(double angle) =>
        (angle * 180 / pi * 4).round();

    final sunriseHA = hourAngle(-0.833 * pi / 180);
    final sunriseMinutes = minutesFromAngle(sunriseHA);

    final fajrHA = hourAngle(method.fajrAngle * pi / 180);
    final fajrMinutes = minutesFromAngle(fajrHA);

    final asrAltitude = atan(1.0 / (tan((latRad - decRad).abs()) + 1));
    final asrHA = hourAngle(asrAltitude);

    final maghribTime = noon.add(Duration(minutes: sunriseMinutes));

    DateTime ishaTime;
    final fixedOffset = method.ishaMinutesAfterMaghrib(now);
    if (fixedOffset > 0) {
      ishaTime = maghribTime.add(Duration(minutes: fixedOffset));
    } else {
      final ishaAngle = method.ishaAngle;
      if (ishaAngle != null) {
        final ishaHA = hourAngle(ishaAngle * pi / 180);
        ishaTime = noon.add(Duration(minutes: minutesFromAngle(ishaHA)));
      } else {
        ishaTime = maghribTime.add(const Duration(minutes: 90));
      }
    }

    return [
      PrayerTimeModel(
        name: 'Fajr',
        arabicName: 'الفجر',
        time: noon.subtract(Duration(minutes: fajrMinutes)),
      ),
      PrayerTimeModel(
        name: 'Sunrise',
        arabicName: 'الشروق',
        time: noon.subtract(Duration(minutes: sunriseMinutes)),
      ),
      PrayerTimeModel(
        name: 'Dhuhr',
        arabicName: 'الظهر',
        time: noon,
      ),
      PrayerTimeModel(
        name: 'Asr',
        arabicName: 'العصر',
        time: noon.add(Duration(minutes: minutesFromAngle(asrHA))),
      ),
      PrayerTimeModel(
        name: 'Maghrib',
        arabicName: 'المغرب',
        time: maghribTime,
      ),
      PrayerTimeModel(
        name: 'Isha',
        arabicName: 'العشاء',
        time: ishaTime,
      ),
    ];
  }

  static int _dayOfYear(DateTime date) {
    final start = DateTime(date.year, 1, 1);
    return date.difference(start).inDays + 1;
  }
}