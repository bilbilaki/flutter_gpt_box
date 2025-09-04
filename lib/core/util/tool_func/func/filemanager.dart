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
                    "The file operation to perform. Must be one of: 'list', 'tree', 'read', 'create', 'search'.",
              },
              'path': {
                'type': 'string',
                'description':
                    "The directory or full file path. Used for 'list', 'tree', and 'create' actions.",
              },
              'content': {
                'type': 'string',
                'description':
                    "The text content to write to a new file. Required for the 'create' action.",
              },
              'fileIds': {
                'type': 'array',
                'items': {'type': 'string'},
                'description':
                    "A list of file IDs (obtained from 'list' or 'search') to read. Required for the 'read' action.",
              },
              'query': {
                'type': 'string',
                'description':
                    "A search term to find indexed files by name. Required for the 'search' action.",
              },
              'extensions': {
                'type': 'array',
                'items': {'type': 'string'},
                'description':
                    "Optional list of file extensions to filter by (e.g., ['txt', 'md']). Used with 'list' action.",
              },
            },
            'required': ['action'],
          },
        );

  @override
  String get description => '''
Manages local files and directories. It allows you to discover, read, and create files.
All file operations return a temporary 'id' which can be used in other tools (like the pdfManager) to reference the file.

**Actions and Required Parameters:**
1.  **'list'**: Lists files in a directory.
    - `path`: The directory path to list.
    - `extensions` (optional): Filter by file extensions.
2.  **'tree'**: Shows a directory's structure as a tree.
    - `path`: The directory path to display.
3.  **'read'**: Reads the content of one or more files.
    - `fileIds`: A list of file IDs to read.
4.  **'create'**: Creates a new text file with specified content.
    - `path`: The full path for the new file (e.g., '/path/to/new_file.txt').
    - `content`: The text to write into the file.
5.  **'search'**: Searches for previously listed/indexed files by name.
    - `query`: The name or partial name of the file to search for.
''';

  @override
  String get l10nName => "filemanager";

  @override
  Future<_Ret?> run(_CallResp call, _Map args, OnToolLog log) async {
    final service = FileIndexService.instance;
    await service.requestStoragePermissions(); // Always ensure permissions

    final action = args['action'] as String?;
    if (action == null) {
      return [ChatContent.text("Error: 'action' is a required parameter for fileManager.")];
    }

    try {
      switch (action) {
        case 'list':
          final path = args['path'] as String?;
          if (path == null) return [ChatContent.text("Error: 'path' is required for the 'list' action.")];
          final extensions = (args['extensions'] as List?)?.cast<String>();
          log("Listing files in '$path'...");
          final files = await service.listFiles(path, extensions: extensions, includeContent: true);
          return [ChatContent.text(jsonEncode(files))];

        case 'tree':
           final path = args['path'] as String?;
           if (path == null) return [ChatContent.text("Error: 'path' is required for the 'tree' action.")];
           log("Generating file tree for '$path'...");
           final tree = await service.getFileTree(path);
           return [ChatContent.text(jsonEncode(tree ?? {'error': 'Directory not found or inaccessible.'}))];

        case 'read':
          final ids = (args['fileIds'] as List?)?.cast<String>();
          if (ids == null || ids.isEmpty) return [ChatContent.text("Error: 'fileIds' is required for the 'read' action.")];
          log("Reading content for IDs: ${ids.join(', ')}");
          final contents = await service.getContentsByIds(ids, returnAsStringIfText: true);
          // Return contentAsString directly if available, otherwise confirm binary content
          final result = contents.map((id, data) {
            if (data['contentAsString'] != null) {
              return MapEntry(id, {'content': data['contentAsString']});
            } else if (data['bytes'] != null) {
              return MapEntry(id, {'content': '[Binary content of size ${data['size']} bytes]'});
            }
            return MapEntry(id, data);
          });
          return [ChatContent.text(jsonEncode(result))];

        case 'create':
          final path = args['path'] as String?;
          final content = args['content'] as String?;
          if (path == null || content == null) return [ChatContent.text("Error: 'path' and 'content' are required for the 'create' action.")];
          
          final uri = Uri.file(path);
          final name = uri.pathSegments.last;
          final extension = name.contains('.') ? name.split('.').last : '';
          
          log("Creating file at '$path'...");
          final file = File(path);
          await file.parent.create(recursive: true);
          final bytes = utf8.encode(content);
          await file.writeAsBytes(bytes);
          
          final fileId = await service.addGeneratedFile(name: name, bytes: Uint8List.fromList(bytes), fileExtension: extension);
          return [ChatContent.text("Successfully created file. ID: $fileId")];

        case 'search':
          final query = args['query'] as String?;
          if (query == null) return [ChatContent.text("Error: 'query' is required for the 'search' action.")];
          log("Searching for files matching '$query'...");
          final results = service.searchIndexedByName(query);
          return [ChatContent.text(jsonEncode(results))];

        default:
          return [ChatContent.text("Error: Unknown action '$action'.")];
      }
    } catch (e) {
      log('File Manager Error: $e');
      return [ChatContent.text('An error occurred: $e')];
    }
  }
}