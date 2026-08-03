// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reciter_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ReciterModelAdapter extends TypeAdapter<ReciterModel> {
  @override
  final int typeId = 2;

  @override
  ReciterModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ReciterModel(
      id: fields[0] as String,
      name: fields[1] as String,
      arabicName: fields[2] as String,
      bio: fields[3] as String,
      imageAsset: fields[4] as String,
      isClassical: fields[5] as bool,
      audioBaseUrl: fields[6] as String? ?? '',
      category: fields[7] as String? ?? '',
    );
  }

  @override
  void write(BinaryWriter writer, ReciterModel obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.arabicName)
      ..writeByte(3)
      ..write(obj.bio)
      ..writeByte(4)
      ..write(obj.imageAsset)
      ..writeByte(5)
      ..write(obj.isClassical)
      ..writeByte(6)
      ..write(obj.audioBaseUrl)
      ..writeByte(7)
      ..write(obj.category);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReciterModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}