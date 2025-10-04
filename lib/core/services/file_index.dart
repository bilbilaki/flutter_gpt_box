// lib/services/file_index_service.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:gpt_box/data/model/app/file_model.dart';
import 'package:path/path.dart' as p;
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';
import 'package:file_saver/file_saver.dart' as fs;
import 'package:dio/dio.dart';

// Headless-friendly service (no Flutte.
class FileIndexService {
  FileIndexService._internal();
  static final FileIndexService instance = FileIndexService._internal();

  final Map<String, FileModel> _index = {}; // id -> FileModel (disk-backed or generated)
  final Map<String, Uint8List> _generatedFiles = {}; // id -> bytes for in-app generated files
  final Uuid _uuid = const Uuid();

  // Request permissions for Android (all files access) and generic storage.
  // For Android 11+ manageExternalStorage permission is requested via permission_handler.
  Future<bool> requestStoragePermissions() async {
    if (Platform.isAndroid) {
      final statusManage = await Permission.manageExternalStorage.status;
      if (!statusManage.isGranted) {
        final res = await Permission.manageExternalStorage.request();
        if (!res.isGranted) return false;
      }
      final statusStorage = await Permission.storage.status;
      if (!statusStorage.isGranted) {
        final res = await Permission.storage.request();
        if (!res.isGranted) return false;
      }
      return true;
    } else if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
      // Desktop: usually no permission prompt required for user directories.
      return true;
    } else {
      // Other platforms (web/iOS) - delegate to appropriate platform handlers if needed.
      return true;
    }
  }
  fs.MimeType toFileSaverMimeType(FileModel fileModel) {
 // If already correct type, return as is
 if (fileModel.fileExtension == '') return fs.MimeType.other;

 // Map your MimeType to file_saver's MimeType based on file extension
 switch (fileModel.fileExtension) {
 case 'aac':
 return fs.MimeType.aac;
 case 'apng':
 return fs.MimeType.apng;
 case 'asice':
 return fs.MimeType.asice;
 case 'asics':
 return fs.MimeType.asics;
 case 'avi':
 return fs.MimeType.avi;
 case 'avif':
 return fs.MimeType.avif;
 case 'bmp':
 return fs.MimeType.bmp;
 case 'csv':
 return fs.MimeType.csv;
 case 'epub':
 return fs.MimeType.epub;
 case 'gif':
 return fs.MimeType.gif;
 case 'heic':
 return fs.MimeType.heic;
 case 'heif':
 return fs.MimeType.heif;
 case 'jpeg':
 return fs.MimeType.jpeg;
 case 'json':
 return fs.MimeType.json;
 case 'md':
 return fs.MimeType.markdown;
 case 'xlsx':
 return fs.MimeType.microsoftExcel;
 case 'pptx':
 return fs.MimeType.microsoftPresentation;
 case 'docx':
 return fs.MimeType.microsoftWord;
 case 'mp3':
 return fs.MimeType.mp3;
 case 'mp4': // Handle mp4 for both audio and video/object
 return fs.MimeType.mp4Video;
 case 'mpeg':
 return fs.MimeType.mpeg;
 case 'odp':
 return fs.MimeType.openDocPresentation;
 case 'ods':
 return fs.MimeType.openDocSheets;
 case 'odt':
 return fs.MimeType.openDocText;
 case 'otf':
 return fs.MimeType.otf;
 case 'pdf':
 return fs.MimeType.pdf;
 case 'png':
 return fs.MimeType.png;
 case 'rar':
 return fs.MimeType.rar;
 case 'sql':
 return fs.MimeType.sql;
 case 'svg':
 return fs.MimeType.svg;
 case 'txt':
 return fs.MimeType.text;
 case 'ttf':
 return fs.MimeType.ttf;
 case 'webm':
 return fs.MimeType.webm;
 case 'webp':
 return fs.MimeType.webp;
 case 'xml':
 return fs.MimeType.xml;
 case 'yaml':
 return fs.MimeType.yaml;
 case 'zip':
 return fs.MimeType.zip;
 default:
 return fs.MimeType.other;
 }
 }

  // Generate temporary id
  String _generateId() => _uuid.v4();

  // Add a generated/in-memory file to index, returns assigned id.
  Future<String> addGeneratedFile({
    required String name,
    required Uint8List bytes,
    String fileExtension = '',
    bool includeExtension = true,
    MimeType mimeType = MimeType.other,
    String? customMimeType,
  }) async {
    final id = _generateId();
    final fm = FileModel(
      id: id,
      name: name,
      bytes: bytes,
      file: null,
      filePath: null,
      link: null,
      fileExtension: fileExtension,
      includeExtension: includeExtension,
      mimeType: mimeType,
      customMimeType: customMimeType,
    );
    _index[id] = fm;
    _generatedFiles[id] = bytes;
    return id;
  }

  // Internal helper to determine extension normalized (with leading dot and lowercase)
  String _normalizeExtension(String ext) {
    if (ext.isEmpty) return '';
    var e = ext.toLowerCase();
    if (!e.startsWith('.')) e = '.$e';
    return e;
  }

  // List files inside directory and subdirectories. If extensions is null => all files.
  // includeContent: try to read file content as UTF8 string and return contentLength & isText flag.
  // returns a list of lightweight maps for easy JSON serialization
  Future<List<Map<String, dynamic>>> listFiles(
    String directoryPath, {
    List<String>? extensions,
    bool includeContent = false,
  }) async {
    final dir = Directory(directoryPath);
    if (!await dir.exists()) return [];

    final normalizedExts = extensions
            ?.map((e) => _normalizeExtension(e.trim().toLowerCase()))
            .where((e) => e.isNotEmpty)
            .toSet() ??
        {};

    final List<Map<String, dynamic>> results = [];

    final stream = dir.list(recursive: true, followLinks: false);

    await for (final entity in stream) {
      if (entity is File) {
        final name = entity.uri.pathSegments.isNotEmpty ? entity.uri.pathSegments.last : entity.path;
        final fileExtension = name.contains('.') ? '.${name.split('.').last.toLowerCase()}' : '';
        if (normalizedExts.isNotEmpty && !normalizedExts.contains(fileExtension)) {
          continue;
        }

        final stat = await entity.stat();
        int size = stat.size;
        bool isText = false;
        int? contentLength;
        String? sampleContent;
        Uint8List? bytes;

        if (includeContent) {
          try {
            // Try reading as UTF8 text up to a limit to avoid huge memory usage
            final maxRead = 1024 * 64; // 64KB sample
            final opened = await entity.open();
            final readBytes = await opened.read(maxRead);
            await opened.close();
            bytes = readBytes;
            contentLength = readBytes.length;
            try {
              final decoded = utf8.decode(readBytes, allowMalformed: true);
              isText = true;
              sampleContent = decoded;
            } catch (_) {
              isText = false;
            }
          } catch (_) {
            // ignore read errors
          }
        }

        final id = _generateId();
        final fm = FileModel(
          id: id,
          name: name,
          bytes: includeContent ? bytes : null,
          file: entity,
          filePath: entity.path,
          link: null,
          fileExtension: fileExtension,
          includeExtension: true,
          mimeType: isText ? MimeType.text : MimeType.other,
        );

        _index[id] = fm;

        results.add({
          'id': id,
          'name': name,
          'path': entity.path,
          'extension': fileExtension,
          'size': size,
          'isText': isText,
          'contentLength': contentLength,
          'sampleContent': sampleContent,
        });
      }
    }

    return results;
  }

  // Return tree with ids. Node: { id, name, path, isDirectory, children: [...] }
  Future<Map<String, dynamic>?> getFileTree(String directoryPath) async {
    final dir = Directory(directoryPath);
    if (!await dir.exists()) return null;

    Future<Map<String, dynamic>> _build(Directory d) async {
      final name = d.uri.pathSegments.isNotEmpty ? d.uri.pathSegments.last : d.path;
      final nodeId = _generateId();
      final Map<String, dynamic> node = {
        'id': nodeId,
        'name': name,
        'path': d.path,
        'isDirectory': true,
        'children': <Map<String, dynamic>>[],
      };

      _index[nodeId] = FileModel(
        id: nodeId,
        name: name,
        bytes: null,
        file: null,
        filePath: d.path,
        link: null,
        fileExtension: '',
        includeExtension: true,
      );

      try {
        final children = d.listSync(recursive: false, followLinks: false)
          ..sort((a, b) => a.path.compareTo(b.path));
        for (final entity in children) {
          if (entity is Directory) {
            final childNode = await _build(entity);
            (node['children'] as List).add(childNode);
          } else if (entity is File) {
            final fname = entity.uri.pathSegments.isNotEmpty ? entity.uri.pathSegments.last : entity.path;
            final fext = fname.contains('.') ? '.${fname.split('.').last.toLowerCase()}' : '';
            final fid = _generateId();
            final stat = await entity.stat();
            final Map<String, dynamic> fileNode = {
              'id': fid,
              'name': fname,
              'path': entity.path,
              'isDirectory': false,
              'extension': fext,
              'size': stat.size,
            };

            _index[fid] = FileModel(
              id: fid,
              name: fname,
              bytes: null,
              file: entity,
              filePath: entity.path,
              link: null,
              fileExtension: fext,
              includeExtension: true,
            );

            (node['children'] as List).add(fileNode);
          }
        }
      } catch (_) {
        // ignore access errors
      }

      return node;
    }

    return await _build(dir);
  }

  // Given list of ids, return content bytes (reads from disk for disk-backed entries, returns stored bytes for generated).
  // Returns map id -> { bytes: Uint8List?, name, filePath, extension, size }
  Future<Map<String, Map<String, dynamic>>> getContentsByIds(List<String> ids, {bool returnAsStringIfText = true}) async {
    final Map<String, Map<String, dynamic>> results = {};
    for (final id in ids) {
      final model = _index[id];
      if (model == null) {
        results[id] = {'error': 'not_found'};
        continue;
      }

      if (model.bytes != null) {
        final bytes = model.bytes!;
        String? asString;
        if (returnAsStringIfText) {
          try {
            asString = utf8.decode(bytes);
          } catch (_) {
            asString = null;
          }
        }
        results[id] = {
          'id': id,
          'name': model.name,
          'filePath': model.filePath,
          'extension': model.fileExtension,
          'size': bytes.length,
          'bytes': bytes,
          'contentAsString': asString,
        };
      } else if (model.filePath != null) {
        try {
          final f = File(model.filePath!);
          if (await f.exists()) {
            final bytes = await f.readAsBytes();
            String? asString;
            if (returnAsStringIfText) {
              try {
                asString = utf8.decode(bytes);
              } catch (_) {
                asString = null;
              }
            }
            results[id] = {
              'id': id,
              'name': model.name,
              'filePath': model.filePath,
              'extension': model.fileExtension,
              'size': bytes.length,
              'bytes': bytes,
              'contentAsString': asString,
            };
          } else {
            results[id] = {'error': 'file_not_found'};
          }
        } catch (e) {
          results[id] = {'error': 'read_error', 'message': e.toString()};
        }
      } else if (model.link != null) {
        try {
          final dio = model.dioClient ?? Dio();
          final response = await dio.get<List<int>>(
            model.link!.link,
            options: Options(responseType: ResponseType.bytes, headers: model.link!.headers),
          );
          Uint8List bytes = Uint8List.fromList(response.data ?? []);
          if (model.transformDioResponse != null) {
            bytes = model.transformDioResponse!(bytes);
          }
          String? asString;
          if (returnAsStringIfText) {
            try {
              asString = utf8.decode(bytes);
            } catch (_) {
              asString = null;
            }
          }
          results[id] = {
            'id': id,
            'name': model.name,
            'filePath': model.filePath,
            'extension': model.fileExtension,
            'size': bytes.length,
            'bytes': bytes,
            'contentAsString': asString,
          };
        } catch (e) {
          results[id] = {'error': 'download_error', 'message': e.toString()};
        }
      } else {
        results[id] = {'error': 'no_source'};
      }
    }
    return results;
  }

  // Save a single FileModel using FileSaver.instance.saveFile (standard mode)
  Future<Map<String, dynamic>> saveFileUsingModel(FileModel model) async {
    try {
      // Prefer bytes if present, else file, else try link
      if (model.bytes != null) {
        final res = await fs.FileSaver.instance.saveFile(
          name: model.name,
          bytes: model.bytes,
          fileExtension: model.fileExtension.replaceFirst('.', ''),
          includeExtension: model.includeExtension,
          mimeType: toFileSaverMimeType(model),
          customMimeType: model.customMimeType,
        );
        return {'status': 'saved', 'result': res};
      } else if (model.filePath != null) {
        final f = File(model.filePath!);
        if (!await f.exists()) return {'status': 'error', 'message': 'file_not_found'};
        final bytes = await f.readAsBytes();
        final res = await fs.FileSaver.instance.saveFile(
          name: model.name,
          bytes: bytes,
          fileExtension: model.fileExtension.replaceFirst('.', ''),
          includeExtension: model.includeExtension,
          mimeType: toFileSaverMimeType(model),
          customMimeType: model.customMimeType,
        );
        return {'status': 'saved', 'result': res};
      } else if (model.link != null) {
        final dio = model.dioClient ?? Dio();
        final response = await dio.get<List<int>>(model.link!.link, options: Options(responseType: ResponseType.bytes, headers: model.link!.headers));
        Uint8List bytes = Uint8List.fromList(response.data ?? []);
        if (model.transformDioResponse != null) {
          bytes = model.transformDioResponse!(bytes);
        }
        final res = await fs.FileSaver.instance.saveFile(
          name: model.name,
          bytes: bytes,
          fileExtension: model.fileExtension.replaceFirst('.', ''),
          includeExtension: model.includeExtension,
          mimeType: toFileSaverMimeType(model),
          customMimeType: model.customMimeType,
        );
        return {'status': 'saved', 'result': res};
      } else {
        return {'status': 'error', 'message': 'no_data_to_save'};
      }
    } catch (e) {
      return {'status': 'error', 'message': e.toString()};
    }
  }

  // Save multiple by ids. If file is generated/in-memory (bytes present) it'll be saved.
  Future<List<Map<String, dynamic>>> saveFilesByIds(List<String> ids) async {
    final List<Map<String, dynamic>> out = [];
    for (final id in ids) {
      final model = _index[id];
      if (model == null) {
        out.add({'id': id, 'status': 'error', 'message': 'not_indexed'});
        continue;
      }
      final res = await saveFileUsingModel(model);
      out.add({'id': id, ...res});
    }
    return out;
  }

// NEW: Delete a single file and clean up index.
  Future<bool> deleteFile(String filePath) async {
    final fileToDelete = File(filePath);
    if (!await fileToDelete.exists()) {
      print("File not found: $filePath"); // Or use a logger if available
      return false;
    }
    try {
      await fileToDelete.delete();
      // Clean up index: Remove any entries matching this exact path
      final keysToRemove = _index.keys
          .where((id) => _index[id]?.filePath == filePath)
          .toList();
      for (final key in keysToRemove) {
        _index.remove(key);
        _generatedFiles.remove(key); // In case it's generated
      }
      print("File deleted: $filePath"); // Or log
      return true;
    } catch (e) {
      print("Error deleting file $filePath: $e");
      return false;
    }
  }

  // NEW: Delete a folder (recursive) and clean up index. Adapted from your example.
  Future<bool> deleteFolder(String folderPath, {bool recursive = true}) async {
    final dirToDelete = Directory(folderPath);
    if (!await dirToDelete.exists()) {
      print("Folder not found: $folderPath");
      return false;
    }
    try {
      await dirToDelete.delete(
        recursive: recursive,
      ); // Delete folder and all its contents
      // Clean up index: Remove any entries under this folder path
      final folderPrefix = folderPath.endsWith('/')
          ? folderPath
          : '$folderPath/';
      final keysToRemove = _index.keys.where((id) {
        final entryPath = _index[id]?.filePath ?? '';
        return entryPath == folderPath || entryPath.startsWith(folderPrefix);
      }).toList();
      for (final key in keysToRemove) {
        _index.remove(key);
        _generatedFiles.remove(key);
      }
      print("Folder deleted: $folderPath (recursive: $recursive)"); // Or log
      // Optional: Refresh parent index if desired (e.g., re-list parent dir)
      // await listFiles(p.dirname(folderPath), includeContent: false); // Uncomment if you want auto-refresh
      return true;
    } catch (e) {
      print("Error deleting folder $folderPath: $e");
      return false;
    }
  }
Future<bool> copyFile(
    String sourceFilePath,
    String destinationFilePath,
  ) async {
    try {
      final sourceFile = File(sourceFilePath);
      if (!await sourceFile.exists()) {
        print("Source file not found: $sourceFilePath");
        return false;
      }
      final destDir = Directory(p.dirname(destinationFilePath));
      if (!await destDir.exists()) {
        await destDir.create(recursive: true);
      }
      await sourceFile.copy(destinationFilePath);
      // Re-index destination to add the new copy
      await listFiles(p.dirname(destinationFilePath), includeContent: false);
      print("File copied: $sourceFilePath -> $destinationFilePath");
      return true;
    } catch (e) {
      print("Error copying file: $e");
      return false;
    }
  }

  // Copy a directory recursively and update index.
  Future<bool> copyDirectory(
    String sourceDirPath,
    String destinationDirPath,
  ) async {
    final sourceDir = Directory(sourceDirPath);
    if (!await sourceDir.exists()) {
      print("Source directory not found: $sourceDirPath");
      return false;
    }
    final destinationDir = Directory(destinationDirPath);
    try {
      if (!await destinationDir.exists()) {
        await destinationDir.create(recursive: true);
      }
      await for (final entity in sourceDir.list(recursive: false)) {
        final newPath = p.join(destinationDirPath, p.basename(entity.path));
        if (entity is File) {
          await copyFile(entity.path, newPath);
        } else if (entity is Directory) {
          await copyDirectory(entity.path, newPath);
        }
      }
      // Re-index destination
      await listFiles(p.dirname(destinationDirPath), includeContent: false);
      print("Directory copied: $sourceDirPath -> $destinationDirPath");
      return true;
    } catch (e) {
      print("Error copying directory: $e");
      return false;
    }
  }

  // Move a file (updates existing index entry's path).
  Future<bool> moveFile(
    String sourceFilePath,
    String destinationFilePath,
  ) async {
    try {
      final sourceFile = File(sourceFilePath);
      if (!await sourceFile.exists()) {
        print("Source file not found: $sourceFilePath");
        return false;
      }
      final destDir = Directory(p.dirname(destinationFilePath));
      if (!await destDir.exists()) {
        await destDir.create(recursive: true);
      }
      await sourceFile.rename(destinationFilePath);
      // Update index: Find and update path for matching entry
      final keysToUpdate = _index.keys
          .where((id) => _index[id]?.filePath == sourceFilePath)
          .toList();
      for (final key in keysToUpdate) {
        final model = _index[key]!;
        _index[key] = model.copyWith(filePath: destinationFilePath);
        if (model.file != null)
          model.file = File(destinationFilePath); // Update file ref if needed
      }
      // Re-index source and dest parents if different
      final sourceParent = p.dirname(sourceFilePath);
      final destParent = p.dirname(destinationFilePath);
      await listFiles(destParent, includeContent: false);
      if (sourceParent != destParent) {
        await listFiles(sourceParent, includeContent: false);
      }
      print("File moved: $sourceFilePath -> $destinationFilePath");
      return true;
    } catch (e) {
      print("Error moving file: $e");
      // Fallback copy+delete for cross-volume
      if (e is FileSystemException &&
          (e.osError?.errorCode == 18 || e.toString().contains('EXDEV'))) {
        if (await copyFile(sourceFilePath, destinationFilePath)) {
          return await deleteFile(sourceFilePath);
        }
      }
      return false;
    }
  }

  // Move a directory (updates index entries under the dir).
  Future<bool> moveDirectory(
    String sourceDirPath,
    String destinationDirPath,
  ) async {
    try {
      final sourceDir = Directory(sourceDirPath);
      if (!await sourceDir.exists()) {
        print("Source directory not found: $sourceDirPath");
        return false;
      }
      final destParentDir = Directory(p.dirname(destinationDirPath));
      if (!await destParentDir.exists()) {
        await destParentDir.create(recursive: true);
      }
      await sourceDir.rename(destinationDirPath);
      // Update index: Prefix-replace paths for all entries under source
      final sourcePrefix = sourceDirPath.endsWith('/')
          ? sourceDirPath
          : '$sourceDirPath/';
      final destPrefix = destinationDirPath.endsWith('/')
          ? destinationDirPath
          : '$destinationDirPath/';
      final keysToUpdate = _index.keys.where((id) {
        final entryPath = _index[id]?.filePath ?? '';
        return entryPath == sourceDirPath || entryPath.startsWith(sourcePrefix);
      }).toList();
      for (final key in keysToUpdate) {
        final model = _index[key]!;
        final oldPath = model.filePath ?? '';
        final newPath = oldPath.replaceFirst(sourcePrefix, destPrefix);
        _index[key] = model.copyWith(filePath: newPath);
        if (model.file != null) {
          model.file = File(newPath); // Update ref if applicable
        }
      }
      // Re-index parents if different
      final sourceParent = p.dirname(sourceDirPath);
      final destParent = p.dirname(destinationDirPath);
      await listFiles(destParent, includeContent: false);
      if (sourceParent != destParent) {
        await listFiles(sourceParent, includeContent: false);
      }
      print("Directory moved: $sourceDirPath -> $destinationDirPath");
      return true;
    } catch (e) {
      print("Error moving directory: $e");
      // Fallback copy+delete
      if (e is FileSystemException &&
          (e.osError?.errorCode == 18 || e.toString().contains('EXDEV'))) {
        if (await copyDirectory(sourceDirPath, destinationDirPath)) {
          return await deleteFolder(sourceDirPath, recursive: true);
        }
      }
      return false;
    }
  }
  // Clear index (useful for headless resets)
  void clearIndex() {
    _index.clear();
    _generatedFiles.clear();
  }

  // Get metadata for a single indexed file id
  Map<String, dynamic>? getMetadata(String id) {
    final model = _index[id];
    if (model == null) return null;
    return {
      'id': model.id,
      'name': model.name,
      'filePath': model.filePath,
      'extension': model.fileExtension,
      'hasBytes': model.bytes != null,
    };
  }

  // Helper: find by name substring under an indexed directory or across index
  List<Map<String, dynamic>> searchIndexedByName(String substring) {
    final List<Map<String, dynamic>> res = [];
    final q = substring.toLowerCase();
    _index.forEach((id, model) {
      if (model.name.toLowerCase().contains(q)) {
        res.add({
          'id': id,
          'name': model.name,
          'path': model.filePath,
          'extension': model.fileExtension,
        });
      }
    });
    return res;
  }

  // Optionally expose raw index (careful in production)
  Map<String, FileModel> get rawIndex => Map.unmodifiable(_index);
}
