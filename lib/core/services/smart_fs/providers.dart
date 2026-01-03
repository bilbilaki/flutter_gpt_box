import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import 'models.dart';

abstract class StorageProvider {
  String get name;

  /// A stable root locator representing the provider root.
  /// - Desktop providers: a directory path
  /// - Android SAF provider: a directory URI/token
  Future<String> getRootLocator();

  /// List direct children (non-recursive).
  Future<List<FsEntityInfo>> list(String directoryLocator);

  /// Recursive tree (optional convenience).
  Future<Map<String, dynamic>> tree(String directoryLocator);

  Future<FsReadResult> readFile(String fileLocator, {bool tryDecodeUtf8 = true});

  Future<FsEntityInfo> writeFile(
    String directoryLocator, {
    required String fileName,
    required Uint8List bytes,
    bool overwrite = true,
  });

  Future<void> deleteEntity(String locator, {bool recursive = false});

  Future<FsEntityInfo> createDirectory(String parentLocator, String name);

  /// Move/rename inside same provider. Cross-provider moves should be done via copy+delete in the service layer.
  Future<FsEntityInfo> move(String sourceLocator, String destDirectoryLocator,
      {String? newName});
}

final _uuid = Uuid();

/// ------------------------
/// App sandbox provider
/// ------------------------
class AppSandboxProvider implements StorageProvider {
  @override
  String get name => 'app_sandbox';

  Directory? _root;

  Future<Directory> _ensureRoot() async {
    _root ??= await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(_root!.path, 'workspace'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  @override
  Future<String> getRootLocator() async => (await _ensureRoot()).path;

  @override
  Future<List<FsEntityInfo>> list(String directoryLocator) async {
    final dir = Directory(directoryLocator);
    if (!await dir.exists()) return [];

    final out = <FsEntityInfo>[];
    await for (final e in dir.list(followLinks: false)) {
      final stat = await e.stat();
      final base = p.basename(e.path);

      if (e is Directory) {
        out.add(FsEntityInfo(
          id: _uuid.v4(),
          type: FsEntityType.directory,
          name: base,
          locator: e.path,
          extension: '',
          size: null,
          modified: stat.modified,
        ));
      } else if (e is File) {
        out.add(FsEntityInfo(
          id: _uuid.v4(),
          type: FsEntityType.file,
          name: base,
          locator: e.path,
          extension: extFromName(base),
          size: stat.size,
          modified: stat.modified,
        ));
      }
    }

    out.sort((a, b) {
      if (a.type != b.type) return a.type == FsEntityType.directory ? -1 : 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return out;
  }

  @override
  Future<Map<String, dynamic>> tree(String directoryLocator) async {
    Future<Map<String, dynamic>> build(Directory d) async {
      final children = <Map<String, dynamic>>[];
      final list = await d.list(followLinks: false).toList();
      list.sort((a, b) => a.path.compareTo(b.path));

      for (final e in list) {
        if (e is Directory) {
          children.add(await build(e));
        } else if (e is File) {
          final stat = await e.stat();
          children.add({
            'id': _uuid.v4(),
            'type': 'file',
            'name': p.basename(e.path),
            'locator': e.path,
            'extension': extFromName(p.basename(e.path)),
            'size': stat.size,
            'modified': stat.modified.toIso8601String(),
          });
        }
      }

      return {
        'id': _uuid.v4(),
        'type': 'directory',
        'name': p.basename(d.path),
        'locator': d.path,
        'children': children,
      };
    }

    final dir = Directory(directoryLocator);
    if (!await dir.exists()) {
      return {
        'id': _uuid.v4(),
        'type': 'directory',
        'name': p.basename(directoryLocator),
        'locator': directoryLocator,
        'children': <dynamic>[],
      };
    }
    return build(dir);
  }

  @override
  Future<FsReadResult> readFile(String fileLocator,
      {bool tryDecodeUtf8 = true}) async {
    final f = File(fileLocator);
    final bytes = await f.readAsBytes();
    if (!tryDecodeUtf8) return FsReadResult(bytes);
    String? text;
    try {
      text = String.fromCharCodes(bytes); // fast-ish; not strict UTF8
    } catch (_) {}
    return FsReadResult(bytes, text: text);
  }

  @override
  Future<FsEntityInfo> writeFile(
    String directoryLocator, {
    required String fileName,
    required Uint8List bytes,
    bool overwrite = true,
  }) async {
    final dir = Directory(directoryLocator);
    if (!await dir.exists()) await dir.create(recursive: true);

    final targetPath = p.join(directoryLocator, fileName);
    final file = File(targetPath);

    if (!overwrite && await file.exists()) {
      throw FileSystemException('File already exists', targetPath);
    }

    await file.writeAsBytes(bytes, flush: true);
    final stat = await file.stat();

    return FsEntityInfo(
      id: _uuid.v4(),
      type: FsEntityType.file,
      name: fileName,
      locator: targetPath,
      extension: extFromName(fileName),
      size: stat.size,
      modified: stat.modified,
    );
  }

  @override
  Future<void> deleteEntity(String locator, {bool recursive = false}) async {
    final f = File(locator);
    if (await f.exists()) {
      await f.delete();
      return;
    }
    final d = Directory(locator);
    if (await d.exists()) {
      await d.delete(recursive: recursive);
      return;
    }
  }

  @override
  Future<FsEntityInfo> createDirectory(String parentLocator, String name) async {
    final dirPath = p.join(parentLocator, name);
    final dir = Directory(dirPath);
    if (!await dir.exists()) await dir.create(recursive: true);
    return FsEntityInfo(
      id: _uuid.v4(),
      type: FsEntityType.directory,
      name: name,
      locator: dir.path,
      extension: '',
    );
  }

  @override
  Future<FsEntityInfo> move(String sourceLocator, String destDirectoryLocator,
      {String? newName}) async {
    final srcFile = File(sourceLocator);
    final srcDir = Directory(sourceLocator);
    final name = newName ?? p.basename(sourceLocator);
    final dest = p.join(destDirectoryLocator, name);

    if (await srcFile.exists()) {
      final moved = await srcFile.rename(dest);
      final stat = await moved.stat();
      return FsEntityInfo(
        id: _uuid.v4(),
        type: FsEntityType.file,
        name: p.basename(moved.path),
        locator: moved.path,
        extension: extFromName(p.basename(moved.path)),
        size: stat.size,
        modified: stat.modified,
      );
    }
    if (await srcDir.exists()) {
      final moved = await srcDir.rename(dest);
      return FsEntityInfo(
        id: _uuid.v4(),
        type: FsEntityType.directory,
        name: p.basename(moved.path),
        locator: moved.path,
        extension: '',
      );
    }

    throw FileSystemException('Source not found', sourceLocator);
  }
}

/// ------------------------
/// User workspace provider
/// - Desktop: normal directory path chosen by user (optional)
/// - Android: SAF directory chosen by user
/// ------------------------
class UserWorkspaceProvider implements StorageProvider {
  @override
  String get name => 'user_workspace';

  String? _rootLocator;

  /// Call this from UI flow to pick a folder.
  /// On Android this uses SAF and works with scoped storage.
  /// On desktop it returns a normal path.
  Future<String?> pickWorkspaceDirectory() async {
    final path = await getDirectoryPath(confirmButtonText: 'Use this folder');
    if (path == null) return null;
    _rootLocator = path;
    return path;
  }

  /// In production you should persist this value and restore it on next launch.
  void restoreRootLocator(String locator) {
    _rootLocator = locator;
  }

  @override
  Future<String> getRootLocator() async {
    if (_rootLocator == null) {
      throw StateError(
          'Workspace not selected. Call pickWorkspaceDirectory() first.');
    }
    return _rootLocator!;
  }

  bool get _isDesktop =>
      Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  @override
  Future<List<FsEntityInfo>> list(String directoryLocator) async {
    // file_selector directoryLocator is a path on desktop.
    // On Android, getDirectoryPath returns a path-like string managed by plugin
    // (internals vary). The key point: we should use XFile abstractions when possible.
    //
    // Unfortunately, file_selector does not currently provide full directory listing
    // APIs for SAF uniformly. So for Android SAF, the recommended approach is:
    // - keep files inside app sandbox, OR
    // - use a dedicated SAF plugin that exposes DocumentFile APIs (e.g. shared_storage / saf)
    //
    // To still deliver a working modern solution:
    // - Desktop: list via dart:io
    // - Android: treat workspace as app-sandbox OR only write/export via save dialogs.
    //
    // If you want full Android SAF directory listing, tell me which SAF plugin you want to use
    // and I’ll adapt this provider accordingly.

    if (!_isDesktop) {
      throw UnsupportedError(
        'Listing user workspace on Android requires a SAF-capable directory API. '
        'Use AppSandboxProvider for full features, and use file_selector for export/import.',
      );
    }

    final dir = Directory(directoryLocator);
    if (!await dir.exists()) return [];
    final out = <FsEntityInfo>[];

    await for (final e in dir.list(followLinks: false)) {
      final stat = await e.stat();
      final base = p.basename(e.path);

      if (e is Directory) {
        out.add(FsEntityInfo(
          id: _uuid.v4(),
          type: FsEntityType.directory,
          name: base,
          locator: e.path,
          extension: '',
          modified: stat.modified,
        ));
      } else if (e is File) {
        out.add(FsEntityInfo(
          id: _uuid.v4(),
          type: FsEntityType.file,
          name: base,
          locator: e.path,
          extension: extFromName(base),
          size: stat.size,
          modified: stat.modified,
        ));
      }
    }

    out.sort((a, b) {
      if (a.type != b.type) return a.type == FsEntityType.directory ? -1 : 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return out;
  }

  @override
  Future<Map<String, dynamic>> tree(String directoryLocator) async {
    if (!_isDesktop) {
      throw UnsupportedError(
        'Tree on Android requires SAF directory APIs. Use AppSandboxProvider.',
      );
    }
    // Delegate to AppSandboxProvider-style logic for desktop
    final sandbox = AppSandboxProvider();
    return sandbox.tree(directoryLocator);
  }

  @override
  Future<FsReadResult> readFile(String fileLocator,
      {bool tryDecodeUtf8 = true}) async {
    if (_isDesktop) {
      final bytes = await File(fileLocator).readAsBytes();
      String? text;
      if (tryDecodeUtf8) {
        try {
          text = String.fromCharCodes(bytes);
        } catch (_) {}
      }
      return FsReadResult(bytes, text: text);
    }

    // On Android, reading arbitrary user-workspace file requires SAF file handle.
    // file_selector gives XFile for openFile, not arbitrary path.
    throw UnsupportedError(
      'Reading by locator on Android workspace is not supported without SAF file handles.',
    );
  }

  @override
  Future<FsEntityInfo> writeFile(
    String directoryLocator, {
    required String fileName,
    required Uint8List bytes,
    bool overwrite = true,
  }) async {
    if (!_isDesktop) {
      throw UnsupportedError(
        'Writing into a chosen folder on Android requires SAF document APIs. '
        'Use export via getSaveLocation()/XFile instead.',
      );
    }
    final dir = Directory(directoryLocator);
    if (!await dir.exists()) await dir.create(recursive: true);

    final target = p.join(directoryLocator, fileName);
    final f = File(target);
    if (!overwrite && await f.exists()) {
      throw FileSystemException('File already exists', target);
    }
    await f.writeAsBytes(bytes, flush: true);
    final stat = await f.stat();
    return FsEntityInfo(
      id: _uuid.v4(),
      type: FsEntityType.file,
      name: fileName,
      locator: target,
      extension: extFromName(fileName),
      size: stat.size,
      modified: stat.modified,
    );
  }

  @override
  Future<void> deleteEntity(String locator, {bool recursive = false}) async {
    if (!_isDesktop) {
      throw UnsupportedError(
          'Delete on Android workspace requires SAF document APIs.');
    }
    final app = AppSandboxProvider();
    await app.deleteEntity(locator, recursive: recursive);
  }

  @override
  Future<FsEntityInfo> createDirectory(String parentLocator, String name) async {
    if (!_isDesktop) {
      throw UnsupportedError(
          'Create directory on Android workspace requires SAF document APIs.');
    }
    final app = AppSandboxProvider();
    return app.createDirectory(parentLocator, name);
  }

  @override
  Future<FsEntityInfo> move(String sourceLocator, String destDirectoryLocator,
      {String? newName}) async {
    if (!_isDesktop) {
      throw UnsupportedError('Move on Android workspace requires SAF APIs.');
    }
    final app = AppSandboxProvider();
    return app.move(sourceLocator, destDirectoryLocator, newName: newName);
  }
}