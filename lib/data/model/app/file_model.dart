// lib/models/file_model.dart
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:json_annotation/json_annotation.dart';
import 'package:dio/dio.dart';

part 'file_model.g.dart';

@JsonSerializable(explicitToJson: true)
class FileModel {
  final String id; // newly added id field (temporary/service id)
  final String name;

  @Uint8ListBase64Converter()
  final Uint8List? bytes;

  @FilePathConverter()
  late final File? file;

  final String? filePath;

  final LinkDetails? link;

  final String fileExtension;

  final bool includeExtension;

  @MimeTypeJsonConverter()
  final MimeType mimeType;

  final String? customMimeType;

  @JsonKey(ignore: true)
  final Dio? dioClient;

  @JsonKey(ignore: true)
  final Uint8List Function(Uint8List)? transformDioResponse;

   FileModel({
    required this.id,
    required this.name,
    this.bytes,
    this.file,
    this.filePath,
    this.link,
    this.fileExtension = "",
    this.includeExtension = true,
    this.mimeType = MimeType.other,
    this.customMimeType,
    this.dioClient,
    this.transformDioResponse,
  });

  // NEW: copyWith method for immutable updates (e.g., changing path during moves)
  FileModel copyWith({
    String? id,
    String? name,
    Uint8List? bytes,
    File? file,
    String? filePath,
    LinkDetails? link,
    String? fileExtension,
    bool? includeExtension,
    MimeType? mimeType,
    String? customMimeType,
    Dio? dioClient,
    Uint8List Function(Uint8List)? transformDioResponse,
  }) {
    return FileModel(
      id: id ?? this.id,
      name: name ?? this.name,
      bytes: bytes ?? this.bytes,
      file: file ?? this.file,
      filePath: filePath ?? this.filePath,
      link: link ?? this.link,
      fileExtension: fileExtension ?? this.fileExtension,
      includeExtension: includeExtension ?? this.includeExtension,
      mimeType: mimeType ?? this.mimeType,
      customMimeType: customMimeType ?? this.customMimeType,
      dioClient: dioClient ?? this.dioClient,
      transformDioResponse: transformDioResponse ?? this.transformDioResponse,
    );
  }

  factory FileModel.fromJson(Map<String, dynamic> json) =>
      _$FileModelFromJson(json);
  Map<String, dynamic> toJson() => _$FileModelToJson(this);
}

/* ---------- Converters ---------- */

class Uint8ListBase64Converter implements JsonConverter<Uint8List?, String?> {
  const Uint8ListBase64Converter();

  @override
  Uint8List? fromJson(String? json) {
    if (json == null) return null;
    return base64Decode(json);
  }

  @override
  String? toJson(Uint8List? object) {
    if (object == null) return null;
    return base64Encode(object);
  }
}

class FilePathConverter implements JsonConverter<File?, String?> {
  const FilePathConverter();

  @override
  File? fromJson(String? json) {
    if (json == null) return null;
    return File(json);
  }

  @override
  String? toJson(File? object) {
    return object?.path;
  }
}

class MimeTypeJsonConverter implements JsonConverter<MimeType, String> {
  const MimeTypeJsonConverter();

  @override
  MimeType fromJson(String json) {
    return MimeTypeExtension.fromJson(json);
  }

  @override
  String toJson(MimeType object) {
    return object.name;
  }
}

/* ---------- MimeType enum ---------- */

enum MimeType {
  other,
  image,
  video,
  audio,
  application,
  text,
  pdf,
  doc,
  excel,
  powerpoint,
  csv,
  zip,
  custom,
}

extension MimeTypeExtension on MimeType {
  static MimeType fromJson(String value) {
    try {
      return MimeType.values.firstWhere((e) => e.name == value);
    } catch (_) {
      return MimeType.other;
    }
  }
}

/* ---------- LinkDetails (example) ---------- */

@JsonSerializable()
class LinkDetails {
  final String link;
  final Map<String, String>? headers;
  final String? method;
  final dynamic body;

  LinkDetails({required this.link, this.headers, this.method, this.body});

  factory LinkDetails.fromJson(Map<String, dynamic> json) =>
      _$LinkDetailsFromJson(json);
  Map<String, dynamic> toJson() => _$LinkDetailsToJson(this);
}
