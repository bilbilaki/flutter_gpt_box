// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'file_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

FileModel _$FileModelFromJson(Map<String, dynamic> json) => FileModel(
  id: json['id'] as String,
  name: json['name'] as String,
  bytes: const Uint8ListBase64Converter().fromJson(json['bytes'] as String?),
  file: const FilePathConverter().fromJson(json['file'] as String?),
  filePath: json['filePath'] as String?,
  link: json['link'] == null
      ? null
      : LinkDetails.fromJson(json['link'] as Map<String, dynamic>),
  fileExtension: json['fileExtension'] as String? ?? "",
  includeExtension: json['includeExtension'] as bool? ?? true,
  mimeType: json['mimeType'] == null
      ? MimeType.other
      : const MimeTypeJsonConverter().fromJson(json['mimeType'] as String),
  customMimeType: json['customMimeType'] as String?,
);

Map<String, dynamic> _$FileModelToJson(FileModel instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'bytes': const Uint8ListBase64Converter().toJson(instance.bytes),
  'file': const FilePathConverter().toJson(instance.file),
  'filePath': instance.filePath,
  'link': instance.link?.toJson(),
  'fileExtension': instance.fileExtension,
  'includeExtension': instance.includeExtension,
  'mimeType': const MimeTypeJsonConverter().toJson(instance.mimeType),
  'customMimeType': instance.customMimeType,
};

LinkDetails _$LinkDetailsFromJson(Map<String, dynamic> json) => LinkDetails(
  link: json['link'] as String,
  headers: (json['headers'] as Map<String, dynamic>?)?.map(
    (k, e) => MapEntry(k, e as String),
  ),
  method: json['method'] as String?,
  body: json['body'],
);

Map<String, dynamic> _$LinkDetailsToJson(LinkDetails instance) =>
    <String, dynamic>{
      'link': instance.link,
      'headers': instance.headers,
      'method': instance.method,
      'body': instance.body,
    };
