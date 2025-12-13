part of '../tool.dart';

/// Tool for interacting with the local file system.
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
                  "The text content to write into a new file. Required for the 'create' action. For multi-line content (e.g., code snippets or formatted text), use escaped newlines ('\\n') in the string—e.g., 'Line 1\\nLine 2'—which the backend will convert to actual line breaks on disk. Avoid double-escaping (e.g., '\\\\n') to prevent literal '\\n' in the file. Other escapes like '\\t' for tabs or '\\\"' for quotes should also be used as needed. Keep content concise (under 10KB if possible) and inform the user if the file is created successfully. After creation, consider using 'read' to verify the content was written correctly (no visible escapes).",
            },
            'fileIds': {
              'type': 'array',
              'items': {'type': 'string'},
              'description':
                  "An array of unique file IDs (obtained from previous 'list' or 'search' responses). Required for the 'read' action. For multiple files, provide all relevant IDs; if reading many, consider calling sequentially for better control.",
            },
            'query': {
              'type': 'string',
              'description':
                  "The search term (e.g., 'report' or '.txt') to find files by name or partial match. Required for the 'search' action. Results include file IDs for further use (e.g., reading).",
            },
            'extensions': {
              'type': 'array',
              'items': {'type': 'string'},
              'description':
                  "Optional array of file extensions to filter results (e.g., ['.txt', '.md']). Primarily used with the 'list' action to narrow down files; omit for all types.",
            },
            'recursive': {
              // NEW: For 'delete' on folders
              'type': 'boolean',
              'description':
                  "Whether to delete recursively for folders (default: true). Required only for 'delete' on directories—set to false for non-recursive (delete empty folder only).",
            },
            'sourcePath': {
              'type': 'string',
              'description':
                  "The full source path (file or directory) to copy/move from. Use absolute paths; confirm with user.",
            },
            'destPath': {
              'type': 'string',
              'description':
                  "The full destination path (including filename for files, or dir for directories). Destination parent dir will be created if needed.",
            },
            'isDirectory': {
              'type': 'boolean',
              'description':
                  "Set to true if source is a directory (auto-detected if possible, but specify for clarity). For move/copy actions.",
            },
          },
          'required': ['action'],
        },
      );

  @override
  String get description => '''
Use this tool to manage local files and directories when the user requests discovering, reading, or creating files (e.g., "List files in my downloads" or "Create a note with this text").
This tool supports safe, read-only and create operations only—no deletions or modifications to existing files. All responses include temporary 'fileId's for each file, which you can store and use in other tools (e.g., pdfManager for PDFs). Always confirm file paths and actions with the user to prevent errors.

**Actions and Usage (Choose Exactly One Per Call):**
1. **'list'**: Lists files in a specified directory.
   - Required: 'path' (e.g., '/Downloads/GPTBOX').
   - Optional: 'extensions' to filter (e.g., ['.pdf', '.txt']).
   - Response: Array of files with names, sizes, and 'fileId's. Offer to the user: "Here are the files—want me to read one?"
   - Tip: Use this first to discover files before reading or searching.

2. **'tree'**: Displays a hierarchical view of a directory's structure.
   - Required: 'path' (e.g., '/Documents').
   - Response: Tree-formatted output showing subdirectories and files.
   - Useful for overview; follow up with 'list' for details on a subfolder.

3. **'read'**: Retrieves the content of one or more files.
   - Required: 'fileIds' (array from 'list' or 'search').
   - Response: Content for each file, keyed by 'fileId'. For multi-file reads, summarize or offer excerpts to avoid overwhelming the user. Note: Read-back content may show escaped newlines ('\\n') in logs or responses, but the original file uses actual line breaks—use this to verify creations.
   - Best Practice: If the user wants multiple files, call sequentially (e.g., one ID at a time) for targeted control; confirm: "Which file should I read first?"

4. **'create'**: Creates a new plain text file with provided content.
   - Required: 'path' (full path including filename, e.g., '/Notes/my_note.txt') and 'content'.
   - Response: Confirmation and new 'fileId'. Inform the user (e.g., "File created at [path]—want to read it back?").
   - Content Handling: Pass multi-line content (e.g., Python code) as a single escaped string—use '\\n' for line breaks (e.g., 'def main():\\n    print(\\\"Hello, World!\\\")\\n'). The backend (using UTF-8 encoding) will automatically convert '\\n' to real newlines and handle other escapes (e.g., quotes, tabs) on disk, ensuring the file is properly formatted (no literal '\\n' visible). For code files, include appropriate indentation with spaces or '\\t'. If the content is binary or non-UTF-8, consider alternatives outside this tool. Overwrites if the file exists; always ask the user to confirm the path to avoid accidents. After creation, use 'read' on the new 'fileId' to confirm the content (e.g., check for proper line breaks vs. escapes).

5. **'delete'**: Deletes a file or folder at the specified path. Deletions are permanent—always confirm with the user before using this action!
   - Required: 'path' (full path to file or folder, e.g., '/Notes/my_note.txt' or '/Documents/old_folder/').
   - Optional: 'recursive' (boolean, default true—for folders only; false deletes only if empty).
   - Response: Confirmation of success/failure (e.g., {'success': true, 'deletedPath': '/path/to/item', 'removedIds': ['id1', 'id2']}). If indexed, includes removed 'fileId's. Suggest re-listing the parent directory afterward.
   - Best Practice: Determine if path is a file or folder via 'list' first; warn user about recursive deletion (e.g., "This will delete the folder and all contents—confirm?"). Do not use on system paths.

6. **'search'**: Finds previously indexed or listed files by name.
   - Required: 'query' (e.g., 'invoice' for partial match).
   - Response: Matching files with names and 'fileId's. No path needed—searches across indexed areas.
   - Tip: Run 'list' first to index directories if search yields no results; use returned 'fileId's for 'read'.

7. **'copy'**: Copies a file or directory to a new location (non-destructive; original remains).
   - Required: 'sourcePath' (e.g., '/Documents/file.txt' or '/Documents/folder/'), 'destPath' (e.g., '/Backup/file_copy.txt').
   - Optional: 'isDirectory' (boolean; auto-detects if omitted).
   - Response: {'success': bool, 'type': 'file/directory', 'message': str}. Original index updated; suggest 'list' on dest parent.

8. **'move'**: Moves a file or directory (renames/moves; original removed).
   - Required: 'sourcePath', 'destPath' (as in copy).
   - Optional: 'isDirectory'.
   - Response: Similar to copy. Index paths updated automatically.

**Best Practices to Avoid Errors and Confusion:**
- Start with 'list' or 'search' to get 'fileId's—never assume IDs.
- Handle multi-file scenarios: For reading or listing many items, use multiple tool calls to manage responses (e.g., read one file, then ask user for next).
- Security: Only operate on user-confirmed paths (e.g., avoid system folders). If an action fails (e.g., invalid path), inform the user and suggest alternatives. For 'delete', double-confirm to prevent data loss.
- Content-Specific Tips for 'create' and 'read': Always use single-escaped strings ('\\n' for newlines) when passing content—double-escaping ('\\\\n') will result in literal '\\n' in the file, causing formatting errors (e.g., in code). Test multi-line content by reading back immediately after creation to verify (e.g., if the file shows actual indentation/line breaks in a text editor or 'cat' command, it's correct). For code or structured text, preserve indentation with spaces after '\\n'. Limit content size to prevent timeouts; for large files, suggest user-side creation.
- After 'delete', re-run 'list' on the parent path to refresh the view and confirm removal.
- Integration: Pass 'fileId's to other tools promptly; they are temporary, so use them in the same conversation.
- Proactively Offer: After listing, suggest next steps (e.g., "Found files—should I read the report.pdf?"). For creations, always follow up: "File created—shall I verify its content?" For deletions: "Item deleted—want to list the parent directory?"
Focus on user requests—do not perform unsolicited file operations.''';

  @override
  String get l10nName => "filemanager";

  @override
  Future<_Ret?> run(_CallResp call, _Map args, OnToolLog log) async {
    // Import 'package:path/path.dart' as p; at the top of the file if not already imported
    String? normalizePath(String? path) =>
        path == null ? null : p.normalize(path);
    final service = FileIndexService.instance;
    await service.requestStoragePermissions(); // Always ensure permissions

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
        suggestion:
            'Provide one of: list, tree, read, create, delete, search, copy, move.',
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

    try {
      log('Action received: $action');
      switch (action) {
        case 'list':
          final path = normalizePath(args['path'] as String?);
          if (path == null) {
            final error = ToolError.invalidInput(
              'path',
              suggestion: 'Provide a directory path.',
            );
            return [ChatContent.text(error.toMessage())];
          }
          final extensions = (args['extensions'] as List?)?.cast<String>();
          log("Listing files in '$path'...");
          final files = await service.listFiles(
            path,
            extensions: extensions,
            includeContent: true,
          );
          return [ChatContent.text(jsonEncode(files))];

        case 'tree':
          final path = normalizePath(args['path'] as String?);
          if (path == null) {
            final error = ToolError.invalidInput(
              'path',
              suggestion: 'Provide a directory path.',
            );
            return [ChatContent.text(error.toMessage())];
          }
          log("Generating file tree for '$path'...");
          final tree = await service.getFileTree(path);
          if (tree == null) {
            final error = ToolError.notFound(
              'Directory "$path"',
              suggestion: 'Verify the path exists and is accessible.',
            );
            return [ChatContent.text(error.toMessage())];
          }
          return [ChatContent.text(jsonEncode(tree))];

        case 'read':
          final ids = (args['fileIds'] as List?)?.cast<String>();
          if (ids == null || ids.isEmpty) {
            final error = ToolError.invalidInput(
              'fileIds',
              suggestion:
                  'Provide an array of file IDs from a previous list or search.',
            );
            return [ChatContent.text(error.toMessage())];
          }
          log("Reading content for IDs: ${ids.join(', ')}");
          final contents = await service.getContentsByIds(
            ids,
            returnAsStringIfText: true,
          );
          final result = contents.map((id, data) {
            if (data['contentAsString'] != null) {
              return MapEntry(id, {'content': data['contentAsString']});
            } else if (data['bytes'] != null) {
              return MapEntry(id, {
                'content': '[Binary content of size ${data['size']} bytes]',
              });
            }
            return MapEntry(id, data);
          });
          return [ChatContent.text(jsonEncode(result))];

        case 'copy':
          final sourcePath = normalizePath(args['sourcePath'] as String?);
          final destPath = normalizePath(args['destPath'] as String?);
          bool isDir = false;
          if (args['isDirectory'] != null) {
            isDir = args['isDirectory'] as bool;
          } else if (sourcePath != null) {
            final type = await FileSystemEntity.type(sourcePath);
            isDir = type == FileSystemEntityType.directory;
          }
          if (sourcePath == null || destPath == null) {
            final error = ToolError.invalidInput(
              sourcePath == null ? 'sourcePath' : 'destPath',
              suggestion: 'Provide both source and destination paths.',
            );
            return [ChatContent.text(error.toMessage())];
          }
          log(
            "Copying ${isDir ? 'directory' : 'file'} from '$sourcePath' to '$destPath'...",
          );
          final success = isDir
              ? await service.copyDirectory(sourcePath, destPath)
              : await service.copyFile(sourcePath, destPath);
          final msg = success
              ? 'Copy successful. Re-list destination to see new items.'
              : 'Copy failed (e.g., invalid paths or permissions).';
          return [
            ChatContent.text(
              jsonEncode({
                'success': success,
                'source': sourcePath,
                'dest': destPath,
                'type': isDir ? 'directory' : 'file',
                'message': msg,
              }),
            ),
          ];

        case 'move':
          final sourcePath = normalizePath(args['sourcePath'] as String?);
          final destPath = normalizePath(args['destPath'] as String?);
          bool isDir = false;
          if (args['isDirectory'] != null) {
            isDir = args['isDirectory'] as bool;
          } else if (sourcePath != null) {
            final type = await FileSystemEntity.type(sourcePath);
            isDir = type == FileSystemEntityType.directory;
          }
          if (sourcePath == null || destPath == null) {
            final error = ToolError.invalidInput(
              sourcePath == null ? 'sourcePath' : 'destPath',
              suggestion: 'Provide both source and destination paths.',
            );
            return [ChatContent.text(error.toMessage())];
          }
          log(
            "Moving ${isDir ? 'directory' : 'file'} from '$sourcePath' to '$destPath'...",
          );
          final success = isDir
              ? await service.moveDirectory(sourcePath, destPath)
              : await service.moveFile(sourcePath, destPath);
          final msg = success
              ? 'Move successful. Re-list source/dest to confirm.'
              : 'Move failed (e.g., invalid paths, cross-volume issues, or permissions).';
          return [
            ChatContent.text(
              jsonEncode({
                'success': success,
                'source': sourcePath,
                'dest': destPath,
                'type': isDir ? 'directory' : 'file',
                'message': msg,
              }),
            ),
          ];

        case 'create':
          final path = normalizePath(args['path'] as String?);
          final content = args['content'] as String?;
          if (path == null || content == null) {
            final error = ToolError.invalidInput(
              path == null ? 'path' : 'content',
              suggestion: 'Provide both a file path and content string.',
            );
            return [ChatContent.text(error.toMessage())];
          }

          final uri = Uri.file(path);
          final name = uri.pathSegments.last;
          final extension = name.contains('.') ? name.split('.').last : '';

          final file = File(path);
          if (await file.exists()) {
            log("Warning: File at '$path' will be overwritten.");
          }
          log("Creating file at '$path'...");
          await file.parent.create(recursive: true);
          final bytes = utf8.encode(content);
          await file.writeAsBytes(bytes);

          final fileId = await service.addGeneratedFile(
            name: name,
            bytes: Uint8List.fromList(bytes),
            fileExtension: extension,
          );
          return [ChatContent.text("Successfully created file. ID: $fileId")];

        case 'delete':
          final path = normalizePath(args['path'] as String?);
          if (path == null) {
            final error = ToolError.invalidInput(
              'path',
              suggestion: 'Provide a directory or file path.',
            );
            return [ChatContent.text(error.toMessage())];
          }
          final recursive =
              args['recursive'] as bool? ?? true; // Default to true for folders

          log("Deleting at 'path' (recursive: recursive)...");

          // Determine if file or folder (accurate check)
          final type = await FileSystemEntity.type(path);
          final isDir = type == FileSystemEntityType.directory;
          bool success;
          List<String> removedIds = [];

          if (isDir) {
            success = await service.deleteFolder(path, recursive: recursive);
            // Collect removed IDs (already handled in service, but re-scan for response)
            removedIds = service.rawIndex.keys.where((id) {
              final entryPath = service.rawIndex[id]?.filePath ?? '';
              final folderPrefix = path.endsWith('/') ? path : '$path/';
              return entryPath.startsWith(folderPrefix);
            }).toList();
          } else {
            success = await service.deleteFile(path);
            // Collect removed ID
            removedIds = service.rawIndex.keys
                .where((id) => service.rawIndex[id]?.filePath == path)
                .toList();
          }

          if (success) {
            return [
              ChatContent.text(
                jsonEncode({
                  'success': true,
                  'deletedPath': path,
                  'type': isDir ? 'folder' : 'file',
                  'recursive': recursive,
                  'removedIds': removedIds,
                  'message':
                      'Deletion successful. Consider listing the parent directory to confirm.',
                }),
              ),
            ];
          } else {
            return [
              ChatContent.text(
                jsonEncode({
                  'success': false,
                  'deletedPath': path,
                  'message':
                      'Deletion failed (e.g., not found, permissions, or non-empty folder with recursive=false).',
                }),
              ),
            ];
          }

        case 'search':
          final query = args['query'] as String?;
          if (query == null || query.isEmpty) {
            final error = ToolError.invalidInput(
              'query',
              suggestion: 'Provide a search term (e.g., "report" or ".txt").',
            );
            return [ChatContent.text(error.toMessage())];
          }
          log("Searching for files matching '$query'...");
          final results = service.searchIndexedByName(query);
          return [ChatContent.text(jsonEncode(results))];

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
