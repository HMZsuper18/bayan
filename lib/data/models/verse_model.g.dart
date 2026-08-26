// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'verse_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class VerseModelAdapter extends TypeAdapter<VerseModel> {
  @override
  final int typeId = 1;

  @override
  VerseModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return VerseModel(
      id: fields[0] as int,
      surahId: fields[1] as int,
      verseNumber: fields[2] as int,
      text: fields[3] as String,
      textUthmani: fields[4] as String,
      juz: fields[5] as int,
      page: fields[6] as int,
      hizbQuarter: fields[7] as int,
    );
  }

  @override
  void write(BinaryWriter writer, VerseModel obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.surahId)
      ..writeByte(2)
      ..write(obj.verseNumber)
      ..writeByte(3)
      ..write(obj.text)
      ..writeByte(4)
      ..write(obj.textUthmani)
      ..writeByte(5)
      ..write(obj.juz)
      ..writeByte(6)
      ..write(obj.page)
      ..writeByte(7)
      ..write(obj.hizbQuarter);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VerseModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
