// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'folder.dart';

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
