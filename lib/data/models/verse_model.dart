import 'package:hive/hive.dart';

part 'verse_model.g.dart';

@HiveType(typeId: 1)
class VerseModel extends HiveObject {
  @HiveField(0)
  final int id;
  @HiveField(1)
  final int surahId;
  @HiveField(2)
  final int verseNumber;
  @HiveField(3)
  final String text;
  @HiveField(4)
  final String textUthmani;
  @HiveField(5)
  final int juz;
  @HiveField(6)
  final int page;
  @HiveField(7)
  final int hizbQuarter;

  VerseModel({
    required this.id,
    required this.surahId,
    required this.verseNumber,
    required this.text,
    required this.textUthmani,
    required this.juz,
    required this.page,
    required this.hizbQuarter,
  });

  factory VerseModel.fromJson(Map<String, dynamic> json) {
    return VerseModel(
      id: json['id'] as int,
      surahId: json['surahId'] as int,
      verseNumber: json['verseNumber'] as int,
      text: json['text'] as String,
      textUthmani: json['textUthmani'] as String? ?? json['text'] as String,
      juz: json['juz'] as int,
      page: json['page'] as int,
      hizbQuarter: json['hizbQuarter'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'surahId': surahId,
        'verseNumber': verseNumber,
        'text': text,
        'textUthmani': textUthmani,
        'juz': juz,
        'page': page,
        'hizbQuarter': hizbQuarter,
      };
}