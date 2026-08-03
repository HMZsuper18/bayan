class PrayerTimeModel {
  final String name;
  final String arabicName;
  final DateTime time;

  const PrayerTimeModel({
    required this.name,
    required this.arabicName,
    required this.time,
  });

  String get formattedTime {
    final hour = time.hour > 12 ? time.hour - 12 : time.hour;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }
}