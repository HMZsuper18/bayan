import 'dart:math';

/// Calculates the Qiblah bearing (direction from current GPS location to the Kaaba).
class QiblahCalculator {
  QiblahCalculator._();

  static const double _kaabaLat = 21.4225;
  static const double _kaabaLng = 39.8262;

  /// Returns the Qiblah bearing in degrees (0–360) from [lat], [lng] to the Kaaba.
  static double calculate(double lat, double lng) {
    final dLon = (_kaabaLng - lng) * pi / 180;
    final lat1 = lat * pi / 180;
    final lat2 = _kaabaLat * pi / 180;

    final y = sin(dLon) * cos(lat2);
    final x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon);
    final bearing = atan2(y, x) * 180 / pi;
    return (bearing + 360) % 360;
  }

  /// Returns a human-readable direction label from [lat], [lng].
  /// E.g. "NE", "SSE", "W" depending on the bearing.
  static String directionLabel(double lat, double lng) {
    final bearing = calculate(lat, lng);
    return bearingToCardinal(bearing);
  }

  static String bearingToCardinal(double bearing) {
    const labels = ['N', 'NNE', 'NE', 'ENE', 'E', 'ESE', 'SE', 'SSE',
        'S', 'SSW', 'SW', 'WSW', 'W', 'WNW', 'NW', 'NNW'];
    final idx = ((bearing / 22.5) + 0.5).floor() % 16;
    return labels[idx];
  }
}
