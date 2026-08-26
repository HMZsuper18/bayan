import 'package:hive/hive.dart';

part 'surah_model.g.dart';

@HiveType(typeId: 0)
class SurahModel extends HiveObject {
  @HiveField(0)
  final int id;
  @HiveField(1)
  final String name;
  @HiveField(2)
  final String englishName;
  @HiveField(3)
  final String revelationType;
  @HiveField(4)
  final int versesCount;
  @HiveField(5)
  final int pageStart;
  @HiveField(6)
  final int pageEnd;

  SurahModel({
    required this.id,
    required this.name,
    required this.englishName,
    required this.revelationType,
    required this.versesCount,
    required this.pageStart,
    required this.pageEnd,
  });

  factory SurahModel.fromJson(Map<String, dynamic> json) {
    return SurahModel(
      id: json['id'] as int,
      name: json['name'] as String,
      englishName: json['englishName'] as String,
      revelationType: json['revelationType'] as String,
      versesCount: json['versesCount'] as int,
      pageStart: json['pageStart'] as int,
      pageEnd: json['pageEnd'] as int,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'englishName': englishName,
        'revelationType': revelationType,
        'versesCount': versesCount,
        'pageStart': pageStart,
        'pageEnd': pageEnd,
      };
}