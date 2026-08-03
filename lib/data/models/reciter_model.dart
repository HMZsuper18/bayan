import 'package:hive/hive.dart';

part 'reciter_model.g.dart';

@HiveType(typeId: 2)
class ReciterModel extends HiveObject {
  @HiveField(0)
  final String id;
  @HiveField(1)
  final String name;
  @HiveField(2)
  final String arabicName;
  @HiveField(3)
  final String bio;
  @HiveField(4)
  final String imageAsset;
  @HiveField(5)
  final bool isClassical;
  @HiveField(6)
  final String audioBaseUrl;
  @HiveField(7)
  final String category;

  ReciterModel({
    required this.id,
    required this.name,
    required this.arabicName,
    required this.bio,
    required this.imageAsset,
    this.isClassical = false,
    this.audioBaseUrl = '',
    this.category = '',
  });

  factory ReciterModel.fromJson(Map<String, dynamic> json) {
    return ReciterModel(
      id: json['id'] as String,
      name: json['name'] as String,
      arabicName: json['arabicName'] as String,
      bio: json['bio'] as String,
      imageAsset: json['imageAsset'] as String,
      isClassical: json['isClassical'] as bool? ?? false,
      audioBaseUrl: json['audioBaseUrl'] as String? ?? '',
      category: json['category'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'arabicName': arabicName,
        'bio': bio,
        'imageAsset': imageAsset,
        'isClassical': isClassical,
        'audioBaseUrl': audioBaseUrl,
        'category': category,
      };
}