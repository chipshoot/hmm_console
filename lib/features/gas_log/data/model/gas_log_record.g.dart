// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'gas_log_record.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class GasLogRecordAdapter extends TypeAdapter<GasLogRecord> {
  @override
  final int typeId = 0;

  @override
  GasLogRecord read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return GasLogRecord(
      id: fields[0] as String,
      odometer: fields[1] as String,
      distance: fields[2] as double,
      gas: fields[3] as double,
      price: fields[4] as double,
      date: fields[5] as DateTime,
      gasStation: fields[6] as String?,
      comment: fields[7] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, GasLogRecord obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.odometer)
      ..writeByte(2)
      ..write(obj.distance)
      ..writeByte(3)
      ..write(obj.gas)
      ..writeByte(4)
      ..write(obj.price)
      ..writeByte(5)
      ..write(obj.date)
      ..writeByte(6)
      ..write(obj.gasStation)
      ..writeByte(7)
      ..write(obj.comment);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GasLogRecordAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
