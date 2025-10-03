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
                  "The text content to write into a new file. Required for the 'create' action. Keep content concise and inform the user if the file is created successfully.",
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
   - Response: Content for each file, keyed by 'fileId'. For multi-file reads, summarize or offer excerpts to avoid overwhelming the user.
   - Best Practice: If the user wants multiple files, call sequentially (e.g., one ID at a time) for targeted control; confirm: "Which file should I read first?"

4. **'create'**: Creates a new plain text file with provided content.
   - Required: 'path' (full path including filename, e.g., '/Notes/my_note.txt') and 'content'.
   - Response: Confirmation and new 'fileId'. Inform the user (e.g., "File created at [path]—want to read it back?").
   - Note: Overwrites if the file exists; always ask the user to confirm the path to avoid accidents.

5. **'search'**: Finds previously indexed or listed files by name.
   - Required: 'query' (e.g., 'invoice' for partial match).
   - Response: Matching files with names and 'fileId's. No path needed—searches across indexed areas.
   - Tip: Run 'list' first to index directories if search yields no results; use returned 'fileId's for 'read'.

**Best Practices to Avoid Errors and Confusion:**
- Start with 'list' or 'search' to get 'fileId's—never assume IDs.
- Handle multi-file scenarios: For reading or listing many items, use multiple tool calls to manage responses (e.g., read one file, then ask user for next).
- Security: Only operate on user-confirmed paths (e.g., avoid system folders). If an action fails (e.g., invalid path), inform the user and suggest alternatives.
- Integration: Pass 'fileId's to other tools promptly; they are temporary, so use them in the same conversation.
- Proactively Offer: After listing, suggest next steps (e.g., "Found files—should I read the report.pdf?").

Focus on user requests—do not perform unsolicited file operations.''';

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