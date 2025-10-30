// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'folder.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ChatFolderAdapter extends TypeAdapter<ChatFolder> {
  @override
  final typeId = 20;

  @override
  ChatFolder read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ChatFolder(
      id: fields[0] as String,
      name: fields[1] as String,
      colorIndicator: fields[2] as String?,
      isExpanded: fields[3] as bool?,
    );
  }

  @override
  void write(BinaryWriter writer, ChatFolder obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.colorIndicator)
      ..writeByte(3)
      ..write(obj.isExpanded);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChatFolderAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ChatFolder _$ChatFolderFromJson(Map<String, dynamic> json) => ChatFolder(
  id: json['id'] as String,
  name: json['name'] as String,
  colorIndicator: json['colorIndicator'] as String?,
  isExpanded: json['isExpanded'] as bool?,
);

Map<String, dynamic> _$ChatFolderToJson(ChatFolder instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      if (instance.colorIndicator case final value?) 'colorIndicator': value,
      if (instance.isExpanded case final value?) 'isExpanded': value,
    };
