import 'dart:typed_data';

enum FsEntityType { file, directory }

class FsEntityInfo {
  final String id;
  final FsEntityType type;
  final String name;

  /// A platform-specific locator.
  /// - Desktop: absolute path
  /// - Android SAF: could be a URI-like string or internal token
  final String locator;

  final int? size;
  final DateTime? modified;

  /// Convenience extension (lowercase, without dot). Empty if none.
  final String extension;

  const FsEntityInfo({
    required this.id,
    required this.type,
    required this.name,
    required this.locator,
    required this.extension,
    this.size,
    this.modified,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'name': name,
        'locator': locator,
        'extension': extension,
        'size': size,
        'modified': modified?.toIso8601String(),
      };
}

class FsReadResult {
  final Uint8List bytes;
  final String? text; // optionally decoded
  const FsReadResult(this.bytes, {this.text});
}

String extFromName(String name) {
  final idx = name.lastIndexOf('.');
  if (idx <= 0 || idx == name.length - 1) return '';
  return name.substring(idx + 1).toLowerCase();
}