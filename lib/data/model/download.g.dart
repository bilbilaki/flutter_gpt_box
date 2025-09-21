// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'download.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class DownloadItemAdapter extends TypeAdapter<DownloadItem> {
  @override
  final typeId = 112;

  @override
  DownloadItem read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DownloadItem(
      taskId: fields[0] as String,
      url: fields[1] as String,
      filename: fields[2] as String,
      savedPath: fields[3] as String,
      status: fields[4] as DownloadUiStatus,
      progress: (fields[5] as num).toDouble(),
      expectedFileSize: (fields[6] as num?)?.toInt(),
      networkSpeedBytesPerSec: (fields[7] as num?)?.toDouble(),
      timeRemainingSeconds: (fields[8] as num?)?.toInt(),
      group: fields[9] as String,
      openAfterComplete: fields[10] as bool,
      createdAt: fields[11] as DateTime,
      finishedAt: fields[12] as DateTime?,
      displayName: fields[13] as String,
      metaData: fields[14] as String,
    );
  }

  @override
  void write(BinaryWriter writer, DownloadItem obj) {
    writer
      ..writeByte(15)
      ..writeByte(0)
      ..write(obj.taskId)
      ..writeByte(1)
      ..write(obj.url)
      ..writeByte(2)
      ..write(obj.filename)
      ..writeByte(3)
      ..write(obj.savedPath)
      ..writeByte(4)
      ..write(obj.status)
      ..writeByte(5)
      ..write(obj.progress)
      ..writeByte(6)
      ..write(obj.expectedFileSize)
      ..writeByte(7)
      ..write(obj.networkSpeedBytesPerSec)
      ..writeByte(8)
      ..write(obj.timeRemainingSeconds)
      ..writeByte(9)
      ..write(obj.group)
      ..writeByte(10)
      ..write(obj.openAfterComplete)
      ..writeByte(11)
      ..write(obj.createdAt)
      ..writeByte(12)
      ..write(obj.finishedAt)
      ..writeByte(13)
      ..write(obj.displayName)
      ..writeByte(14)
      ..write(obj.metaData);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DownloadItemAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
