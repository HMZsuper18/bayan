class HijriDate {
  HijriDate._();

  /// Converts a Gregorian [year], [month], [day] to Hijri
  /// `[year, month, day]` using the Kuwaiti algorithm.
  static List<int> fromGregorian(int year, int month, int day) {
    final jd = _gregorianToJulian(year, month, day);
    final l = jd - 1948440 + 10632;
    final n = ((l - 1) / 10631).floor();
    final remainder = l - 10631 * n + 354;
    final j = ((10985 - remainder) / 5316).floor() *
            ((50 * remainder) / 17719).floor() +
        (remainder / 5670).floor() *
            ((43 * remainder) / 15238).floor();
    final l2 = j +
        ((30 - j) / 15).floor() * ((17719 * j) / 50).floor() +
        (j / 16).floor() * ((15238 * j) / 43).floor() +
        29;
    final hm = ((24 * l2) / 709).floor();
    final hd = l2 - ((709 * hm) / 24).floor();
    final hy = 30 * n + j - 30;
    return [hy, hm, hd];
  }

  static int _gregorianToJulian(int y, int m, int d) {
    final a = ((14 - m) / 12).floor();
    final yy = y + 4800 - a;
    final mm = m + 12 * a - 3;
    return d +
        ((153 * mm + 2) / 5).floor() +
        365 * yy +
        (yy / 4).floor() -
        (yy / 100).floor() +
        (yy / 400).floor() -
        32045;
  }
}
