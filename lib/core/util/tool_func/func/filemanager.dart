part of '../tool.dart';

// Needed imports in this file (or in tool.dart):
// import 'dart:convert';
// import 'dart:io';
// import 'dart:typed_data';
// import 'package:path/path.dart' as p;

// NEW imports (where you placed the refactor):
// import 'package:your_app/services/smart_fs/smart_file_index_service.dart';
// import 'package:your_app/services/smart_fs/providers.dart';
// import 'package:your_app/services/smart_fs/models.dart';

/// IMPORTANT NOTE ABOUT ANDROID (SAF)
/// - This tool currently accepts raw "path" strings (e.g. /storage/emulated/0/Download).
/// - On modern Android, direct access to arbitrary external paths is restricted (scoped storage).
/// - To reliably support user-visible folders on Android, you will need SAF (Storage Access Framework)
///   and your API must evolve from "path: string" to "locator/provider" semantics.
/// - Per your request: we will NOT implement SAF now; we keep path-based behavior and focus on syncing
///   the tool with the new indexing service. Use the AppSandboxProvider for guaranteed support.

final class TfFileManager extends ToolFunc {
  static const instance = TfFileManager._();

  const TfFileManager._()
    : super(
        name: 'filemanager',
        parametersSchema: const {
          'type': 'object',
          'properties': {
            'action': {
              'type': 'string',
              'description':
                  "The file operation to perform. Must be exactly one of: 'list' (list files in a directory), 'tree' (show directory structure), 'read' (read file contents), 'create' (create a new text file), or 'search' (find files by name). Use only one action per call to avoid conflicts.",
            },
            'path': {
              'type': 'string',
              'description':
                  "The directory path (for 'list' or 'tree') or full file path (for 'create', e.g., '/path/to/new_file.txt'). Always confirm paths with the user before using—use absolute paths where possible for accuracy.",
            },
            'content': {
              'type': 'string',
              'description':
                  "The text content to write into a new file. Required for the 'create' action. For multi-line content, use escaped newlines ('\\n') in the string.",
            },
            'fileIds': {
              'type': 'array',
              'items': {'type': 'string'},
              'description':
                  "An array of unique file IDs (obtained from previous 'list' or 'search' responses). Required for the 'read' action.",
            },
            'query': {
              'type': 'string',
              'description':
                  "The search term to find files by name or partial match. Required for the 'search' action.",
            },
            'extensions': {
              'type': 'array',
              'items': {'type': 'string'},
              'description':
                  "Optional array of file extensions to filter results (e.g., ['.txt', '.md']). Used with 'list'.",
            },
            'recursive': {
              'type': 'boolean',
              'description':
                  "Whether to delete recursively for folders (default: true).",
            },
            'sourcePath': {
              'type': 'string',
              'description': "The full source path (file or directory) to copy/move from.",
            },
            'destPath': {
              'type': 'string',
              'description':
                  "The full destination path (including filename for files, or dir for directories).",
            },
            'isDirectory': {
              'type': 'boolean',
              'description': "Set to true if source is a directory.",
            },
          },
          'required': ['action'],
        },
      );

  @override
  String get description => /* unchanged, keep your long description */ TfFileManager.instance.description;

  @override
  String get l10nName => "filemanager";

  // ---- New service wiring ----
  // We use app sandbox provider by default because it is reliable on Android.
  // If you still pass absolute external paths, it may fail on modern Android (scoped storage).
  SmartFileIndexService _makeService() {
    final sandbox = AppSandboxProvider();
    // Optional: you can register workspace provider later; not used by this tool yet.
    // final workspace = UserWorkspaceProvider();

    return SmartFileIndexService(
      providers: [sandbox /*, workspace*/],
    );
  }

  bool _looksLikeAbsolutePath(String input) {
    // Rough heuristic. Adjust for your environment if needed.
    if (input.startsWith('/')) return true; // unix-like
    if (RegExp(r'^[a-zA-Z]:\\').hasMatch(input)) return true; // windows
    return false;
  }

  String _normalizePathOrThrow(String? input, String fieldName) {
    if (input == null || input.trim().isEmpty) {
      throw ArgumentError('Missing required field: $fieldName');
    }
    final normalized = p.normalize(input.trim());
    // We keep allowing relative paths, but for safety you might require absolute.
    return normalized;
  }

  Set<String>? _parseExtensions(List<dynamic>? raw) {
    if (raw == null) return null;
    final exts = raw.cast<String>().map((e) => e.trim()).where((e) => e.isNotEmpty);
    final normalized = <String>{};
    for (final e in exts) {
      // accept ".txt" or "txt"
      final cleaned = e.startsWith('.') ? e.substring(1) : e;
      if (cleaned.isNotEmpty) normalized.add(cleaned.toLowerCase());
    }
    return normalized.isEmpty ? null : normalized;
  }

  @override
  Future<_Ret?> run(_CallResp call, _Map args, OnToolLog log) async {
    final action = args['action'] as String?;
    const allowedActions = [
      'list',
      'tree',
      'read',
      'create',
      'delete',
      'search',
      'copy',
      'move',
    ];

    if (action == null) {
      final error = ToolError.invalidInput(
        'action',
        suggestion: 'Provide one of: list, tree, read, create, delete, search, copy, move.',
      );
      log('FileManager Error: ${error.toMessage()}');
      return [ChatContent.text(error.toMessage())];
    }
    if (!allowedActions.contains(action)) {
      final error = ToolError.invalidArgument(
        'action',
        '"$action" is not supported',
        suggestion: 'Use one of: ${allowedActions.join(", ")}.',
      );
      log('FileManager Error: ${error.toMessage()}');
      return [ChatContent.text(error.toMessage())];
    }

    final service = _makeService();
    final sandbox = service.provider('app_sandbox');
    final sandboxRoot = await sandbox.getRootLocator();

    // Tool policy decision:
    // - If user passes a non-absolute path, treat it as relative to sandboxRoot.
    // - This gives you a consistent cross-platform behavior.
    String resolvePath(String userPath) {
      final normalized = p.normalize(userPath);
      if (_looksLikeAbsolutePath(normalized)) return normalized;
      return p.join(sandboxRoot, normalized);
    }

    try {
      log('Action received: $action');
      switch (action) {
        case 'list':
          final userPath = args['path'] as String?;
          if (userPath == null) {
            final error = ToolError.invalidInput('path', suggestion: 'Provide a directory path.');
            return [ChatContent.text(error.toMessage())];
          }
          final dirPath = resolvePath(userPath);
          final extensions = _parseExtensions(args['extensions'] as List?);

          log("Listing files in '$dirPath'...");

          // New: use provider + listAndIndex
          final files = await service.listAndIndex(
            sandbox,
            dirPath,
            extensions: extensions,
          );

          return [ChatContent.text(jsonEncode(files))];

        case 'tree':
          final userPath = args['path'] as String?;
          if (userPath == null) {
            final error = ToolError.invalidInput('path', suggestion: 'Provide a directory path.');
            return [ChatContent.text(error.toMessage())];
          }
          final dirPath = resolvePath(userPath);

          log("Generating file tree for '$dirPath'...");
          final tree = await service.tree(sandbox, dirPath);
          return [ChatContent.text(jsonEncode(tree))];

        case 'read':
          final ids = (args['fileIds'] as List?)?.cast<String>();
          if (ids == null || ids.isEmpty) {
            final error = ToolError.invalidInput(
              'fileIds',
              suggestion: 'Provide an array of file IDs from a previous list or search.',
            );
            return [ChatContent.text(error.toMessage())];
          }

          log("Reading content for IDs: ${ids.join(', ')}");

          final Map<String, dynamic> out = {};
          for (final id in ids) {
            try {
              final res = await service.readById(id, tryDecodeUtf8: true);
              if (res.text != null) {
                out[id] = {'content': res.text};
              } else {
                out[id] = {'content': '[Binary content of size ${res.bytes.length} bytes]'};
              }
            } catch (e) {
              out[id] = {'error': 'read_failed', 'message': e.toString()};
            }
          }

          return [ChatContent.text(jsonEncode(out))];

        case 'create':
          final userPath = args['path'] as String?;
          final content = args['content'] as String?;
          if (userPath == null || content == null) {
            final error = ToolError.invalidInput(
              userPath == null ? 'path' : 'content',
              suggestion: 'Provide both a file path and content string.',
            );
            return [ChatContent.text(error.toMessage())];
          }

          final fullPath = resolvePath(userPath);
          final parentDir = p.dirname(fullPath);
          final fileName = p.basename(fullPath);

          // Ensure fileName exists
          if (fileName.trim().isEmpty || fileName == '.' || fileName == '..') {
            final error = ToolError.invalidArgument(
              'path',
              'Invalid file path: "$userPath"',
              suggestion: 'Provide a full file path including a filename, e.g. "notes/todo.txt".',
            );
            return [ChatContent.text(error.toMessage())];
          }

          log("Creating file at '$fullPath'...");

          // Write via provider (sandbox-safe)
          final bytes = Uint8List.fromList(utf8.encode(content));
          final created = await sandbox.writeFile(
            parentDir,
            fileName: fileName,
            bytes: bytes,
            overwrite: true,
          );

          // Index the created file so it can be read by ID immediately
          final id = service.indexLocalEntity(provider: sandbox, entity: created);

          return [
            ChatContent.text(
              jsonEncode({
                'success': true,
                'path': created.locator,
                'fileId': id,
                'message': 'File created successfully.',
              }),
            ),
          ];

        case 'delete':
          final userPath = args['path'] as String?;
          if (userPath == null) {
            final error = ToolError.invalidInput('path', suggestion: 'Provide a directory or file path.');
            return [ChatContent.text(error.toMessage())];
          }
          final targetPath = resolvePath(userPath);
          final recursive = args['recursive'] as bool? ?? true;

          log("Deleting at '$targetPath' (recursive: $recursive)...");

          // Determine file/dir using dart:io for sandbox paths.
          final type = await FileSystemEntity.type(targetPath);
          final isDir = type == FileSystemEntityType.directory;

          try {
            await sandbox.deleteEntity(targetPath, recursive: isDir ? recursive : false);
            return [
              ChatContent.text(
                jsonEncode({
                  'success': true,
                  'deletedPath': targetPath,
                  'type': isDir ? 'folder' : 'file',
                  'recursive': recursive,
                  'message': 'Deletion successful. Consider listing the parent directory to confirm.',
                }),
              ),
            ];
          } catch (e) {
            return [
              ChatContent.text(
                jsonEncode({
                  'success': false,
                  'deletedPath': targetPath,
                  'message': 'Deletion failed: $e',
                }),
              ),
            ];
          }

        case 'search':
          final query = args['query'] as String?;
          // if (query == null || query.isEmpty) {
          //   final error = ToolError.invalidInput(
          //     'query',
          //     suggestion: 'Provide a search term (e.g., "report" or ".txt").',
          //   );
          //   return [ChatContent.text(error.toMessage())];
          // }
          log("Searching indexed items for '$query'...");

          // New: search is only within THIS service index (conversation lifetime).
          // If you need persistent/global search, you must persist the index or re-index known roots.
          // final q = query.toLowerCase();
          // final matches = <Map<String, dynamic>>[];
          // for (final entry in service) {
          //   final f = entry.value;
          //   if (f.name.toLowerCase().contains(q)) {
          //     matches.add({
          //       'id': entry.key,
          //       'name': f.name,
          //       'extension': f.extension,
          //       'locator': f.locator,
          //       'provider': f.providerName,
          //       'source': f.isRemote
          //           ? 'remote'
          //           : f.isGenerated
          //               ? 'generated'
          //               : 'local',
          //     });
          //   }
       //   }

          return [ChatContent.text(jsonEncode("todo implantion"))];

        case 'copy':
          final sourcePathRaw = args['sourcePath'] as String?;
          final destPathRaw = args['destPath'] as String?;
          if (sourcePathRaw == null || destPathRaw == null) {
            final error = ToolError.invalidInput(
              sourcePathRaw == null ? 'sourcePath' : 'destPath',
              suggestion: 'Provide both source and destination paths.',
            );
            return [ChatContent.text(error.toMessage())];
          }

          final sourcePath = resolvePath(sourcePathRaw);
          final destPath = resolvePath(destPathRaw);

          bool isDir = false;
          if (args['isDirectory'] != null) {
            isDir = args['isDirectory'] as bool;
          } else {
            final t = await FileSystemEntity.type(sourcePath);
            isDir = t == FileSystemEntityType.directory;
          }

          log("Copying ${isDir ? 'directory' : 'file'} from '$sourcePath' to '$destPath'...");

          final success = await _copyWithinSandbox(
            sandboxRoot: sandboxRoot,
            sourcePath: sourcePath,
            destPath: destPath,
            isDirectory: isDir,
          );

          return [
            ChatContent.text(
              jsonEncode({
                'success': success,
                'source': sourcePath,
                'dest': destPath,
                'type': isDir ? 'directory' : 'file',
                'message': success
                    ? 'Copy successful. Re-list destination to see new items.'
                    : 'Copy failed (invalid paths or permissions).',
              }),
            ),
          ];

        case 'move':
          final sourcePathRaw = args['sourcePath'] as String?;
          final destPathRaw = args['destPath'] as String?;
          if (sourcePathRaw == null || destPathRaw == null) {
            final error = ToolError.invalidInput(
              sourcePathRaw == null ? 'sourcePath' : 'destPath',
              suggestion: 'Provide both source and destination paths.',
            );
            return [ChatContent.text(error.toMessage())];
          }

          final sourcePath = resolvePath(sourcePathRaw);
          final destPath = resolvePath(destPathRaw);

          bool isDir = false;
          if (args['isDirectory'] != null) {
            isDir = args['isDirectory'] as bool;
          } else {
            final t = await FileSystemEntity.type(sourcePath);
            isDir = t == FileSystemEntityType.directory;
          }

          log("Moving ${isDir ? 'directory' : 'file'} from '$sourcePath' to '$destPath'...");

          final success = await _moveWithinSandbox(
            sandboxRoot: sandboxRoot,
            sourcePath: sourcePath,
            destPath: destPath,
            isDirectory: isDir,
          );

          return [
            ChatContent.text(
              jsonEncode({
                'success': success,
                'source': sourcePath,
                'dest': destPath,
                'type': isDir ? 'directory' : 'file',
                'message': success
                    ? 'Move successful. Re-list source/dest to confirm.'
                    : 'Move failed (invalid paths, cross-volume issues, or permissions).',
              }),
            ),
          ];

        default:
          final error = ToolError.invalidArgument(
            'action',
            '"$action" is not recognized',
            suggestion: 'Use one of: ${allowedActions.join(", ")}.',
          );
          return [ChatContent.text(error.toMessage())];
      }
    } catch (e) {
      final error = ToolError.executionFailed(
        'File operation failed: $e',
        suggestion: 'Verify the path, permissions, or file availability.',
      );
      log('File Manager Error: ${error.toMessage()}');
      return [ChatContent.text(error.toMessage())];
    }
  }
}

/// --- helpers for copy/move (sandbox path-based) ---
/// These are intentionally still dart:io because sandbox provider locator is a real path.
/// Later when SAF is added, these should become provider-level operations.
Future<bool> _copyWithinSandbox({
  required String sandboxRoot,
  required String sourcePath,
  required String destPath,
  required bool isDirectory,
}) async {
  try {
    if (isDirectory) {
      final src = Directory(sourcePath);
      if (!await src.exists()) return false;

      final dst = Directory(destPath);
      if (!await dst.exists()) await dst.create(recursive: true);

      await for (final entity in src.list(recursive: false, followLinks: false)) {
        final name = p.basename(entity.path);
        final childDest = p.join(destPath, name);

        if (entity is File) {
          await File(entity.path).copy(childDest);
        } else if (entity is Directory) {
          final ok = await _copyWithinSandbox(
            sandboxRoot: sandboxRoot,
            sourcePath: entity.path,
            destPath: childDest,
            isDirectory: true,
          );
          if (!ok) return false;
        }
      }
      return true;
    } else {
      final src = File(sourcePath);
      if (!await src.exists()) return false;

      await Directory(p.dirname(destPath)).create(recursive: true);
      await src.copy(destPath);
      return true;
    }
  } catch (_) {
    return false;
  }
}

Future<bool> _moveWithinSandbox({
  required String sandboxRoot,
  required String sourcePath,
  required String destPath,
  required bool isDirectory,
}) async {
  try {
    if (isDirectory) {
      final src = Directory(sourcePath);
      if (!await src.exists()) return false;

      await Directory(p.dirname(destPath)).create(recursive: true);
      await src.rename(destPath);
      return true;
    } else {
      final src = File(sourcePath);
      if (!await src.exists()) return false;

      await Directory(p.dirname(destPath)).create(recursive: true);
      await src.rename(destPath);
      return true;
    }
  } catch (_) {
    // For cross-volume move you'd do copy+delete; sandbox typically same volume.
    return false;
  }
}