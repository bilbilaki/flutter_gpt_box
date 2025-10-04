part of '../tool.dart';

/// Tool for creating and manipulating ZIP archives.
final class TfZipManager extends ToolFunc {
  static const instance = TfZipManager._();

  const TfZipManager._()
    : super(
        name: 'zipmanager',
        parametersSchema: const {
          'type': 'object',
          'properties': {
            'action': {
              'type': 'string',
              'description':
                  "The specific zip operation to perform. Must be one of: 'compress', 'extractAll', 'addFiles', 'extractFiles', 'renameEntry', 'moveEntries', 'removeEntries', 'listEntries', or 'readEntryContent'.",
            },
            'zipPath': {
              'type': 'string',
              'description':
                  'The path to the ZIP archive file. Required for all actions.',
            },
            'sourcePath': {
              'type': 'string',
              'description':
                  'The path to a source folder on the disk. Required for the "compress" action.',
            },
            'destinationPath': {
              'type': 'string',
              'description':
                  'The path to a destination folder on the disk. Used with "extractAll" and "extractFiles" actions.',
            },
            'sourceFilePaths': {
              'type': 'array',
              'items': {'type': 'string'},
              'description':
                  'A list of paths to files or folders on the local disk to be added to the archive. Required for the "addFiles" action.',
            },

            'entryPaths': {
              'type': 'array',
              'items': {'type': 'string'},
              'description':
                  "A list of one or more paths to files or folders *inside* the ZIP archive. Used with 'extractFiles', 'moveEntries', and 'removeEntries' actions.",
            },
            'oldEntryPath': {
              'type': 'string',
              'description':
                  "The exact, full path of the single entry (file or folder) inside the ZIP archive to be renamed or read. Required for 'renameEntry' and 'readEntryContent'.",
            },
            'newEntryName': {
              'type': 'string',
              'description':
                  "The new name (excluding the parent path) for the single entry within the zip. Required for the 'renameEntry' action.",
            },
            'destinationEntryDir': {
              'type': 'string',
              'description':
                  "The path to a destination directory *inside* the ZIP archive. Used with 'addFiles' and 'moveEntries' actions.",
            },
            'path': {
              'type': 'string',
              'description':
                  "Used with 'listEntries' to specify the directory inside the zip to list. Use '.' for the root. Defaults to '.'",
            },
            'recursive': {
              'type': 'boolean',
              'description':
                  "Used with 'listEntries' to specify if subdirectory contents should also be listed. Defaults to true.",
            },
            'encoding': {
              'type': 'string',
              'enum': ['utf8', 'base64'],
              'description':
                  "Encoding for 'readEntryContent'. Defaults to 'utf8'. Use 'base64' for binary files.",
            },
          },
          'required': ['action'],
        },
      );

  @override
  String get description => '''
A powerful tool to manage ZIP archives. It can create, extract, modify, and inspect zip files based on the specified 'action'.

**Actions and Required Parameters:**
1. **'compress'**: Creates a new ZIP file from a folder. Required: `sourcePath`, `zipPath`.
2. **'extractAll'**: Extracts the entire content of a ZIP file. Required: `zipPath`, `destinationPath`.
3. **'addFiles'**: Adds files from the disk into an existing ZIP. Required: `zipPath`, `sourceFilePaths` (list).
4. **'extractFiles'**: Extracts specific files or folders from a ZIP. Required: `zipPath`, `entryPaths` (list), `destinationPath`.
5. **'renameEntry'**: Renames a single file or folder inside a ZIP. Required: `zipPath`, `oldEntryPath` (single path), `newEntryName`.
6. **'moveEntries'**: Moves files or folders to a different directory inside the ZIP. Required: `zipPath`, `entryPaths` (list), `destinationEntryDir`.
7. **'removeEntries'**: Deletes files or folders from inside the ZIP file. Required: `zipPath`, `entryPaths` (list).
8. **'listEntries' (NEW)**: Lists files and directories inside the ZIP. Required: `zipPath`. Optional: `path` (internal dir to list), `recursive`.
9. **'readEntryContent' (NEW)**: Reads the content of a single file inside the ZIP. Required: `zipPath`, `oldEntryPath` (the path of the file). Optional: `encoding`.

**Best Practices:**
- Use 'listEntries' first to verify file paths before attempting extraction or modification.
- Always use the full, internal path (e.g., `folder/file.txt`) when dealing with entries.
- Responses are simple text confirmations; detailed logs (e.g., entry lists, paths) are provided via tool logs for reference.
''';

  @override
  String get l10nName => "zipmanager";

  @override
  Future<_Ret?> run(_CallResp call, _Map args, OnToolLog log) async {
    final action = args['action'] as String?;
    if (action == null) {
      return [ChatContent.text("Error: 'action' parameter is required.")];
    }

    try {
      switch (action) {
        case 'compress':
          return await _handleCompress(args, log);
        case 'extractAll':
          return await _handleExtractAll(args, log);
        case 'addFiles':
          return await _handleAddFiles(args, log);
        case 'extractFiles':
          return await _handleExtractFiles(args, log);
        case 'renameEntry':
          return await _handleRenameEntry(args, log);
        case 'moveEntries':
          return await _handleMoveEntries(args, log);
        case 'removeEntries':
          return await _handleRemoveEntries(args, log);
        case 'listEntries':
          return await _handleListEntries(args, log);
        case 'readEntryContent':
          return await _handleReadEntryContent(args, log);
        default:
          return [ChatContent.text("Error: Unknown action '$action'.")];
      }
    } catch (e) {
      log('ZIP Manager Error during "$action": $e');
      return [
        ChatContent.text(
          'An error occurred while performing the zip operation: $e',
        ),
      ];
    }
  }

  // --- NEW HANDLERS (List and Read) ---

  Future<_Ret?> _handleListEntries(_Map args, OnToolLog log) async {
    final zipPath = args['zipPath'] as String?;
    final internalPath = (args['path'] as String?) ?? ".";
    final recursive = (args['recursive'] as bool?) ?? true;
    final password = args['password'] as String?;

    if (zipPath == null) {
      return [
        ChatContent.text("Error: 'zipPath' is required for listEntries."),
      ];
    }

    ZipFile? zipFile;
    try {
      zipFile = await openZipFileSafe(
        zipFilePath: zipPath,
        password: password,
        log: log,
      );
      final entries = getZipFileEntries(
        zipFile,
        path: internalPath,
        recursive: recursive,
        log: log,
      );

      log(
        "listEntries summary: Found ${entries.length} entries at '$internalPath' (recursive: $recursive).",
      );
      return [
        ChatContent.text(
          'listEntries OK: Found ${entries.length} entries in "$zipPath" at path "$internalPath". Check logs for details.',
        ),
      ];
    } finally {
      if (zipFile != null) closeZipFileSafe(zipFile, log: log);
    }
  }

  Future<_Ret?> _handleReadEntryContent(_Map args, OnToolLog log) async {
    final zipPath = args['zipPath'] as String?;
    final entryPath = args['oldEntryPath'] as String?;
    final encoding = (args['encoding'] as String?) ?? 'utf8';
    final password = args['password'] as String?;

    if (zipPath == null || entryPath == null) {
      return [
        ChatContent.text(
          "Error: 'zipPath' and 'oldEntryPath' are required for readEntryContent.",
        ),
      ];
    }

    ZipFile? zipFile;
    try {
      zipFile = await openZipFileSafe(
        zipFilePath: zipPath,
        password: password,
        log: log,
      );
      final stream = readZipFileContent(zipFile, entryPath, log);
      final bytes = await stream.fold<List<int>>(
        <int>[],
        (previous, element) => previous..addAll(element),
      );

      String content;
      if (encoding == 'base64') {
        content = base64Encode(bytes);
      } else {
        content = utf8.decode(bytes);
      }

      log(
        "readEntryContent: Retrieved content from '$entryPath' in '$zipPath' (${encoding} encoding, ${bytes.length} bytes).",
      );
      return [
        ChatContent.text('readEntryContent OK for "$entryPath"'),
        ChatContent.text(content),
      ];
    } finally {
      if (zipFile != null) closeZipFileSafe(zipFile, log: log);
    }
  }

  // --- MODIFIED HANDLERS (Text-Only Output & Parameter Refinement) ---

  Future<_Ret?> _handleCompress(_Map args, OnToolLog log) async {
    final source = args['sourcePath'] as String?;
    final zip = args['zipPath'] as String?;
    final password = args['password'] as String?;
    final compressLevel = (args['compressLevel'] as int?) ?? 5;
    final threadCount = (args['threadCount'] as int?) ?? 2;

    if (source == null || zip == null) {
      return [
        ChatContent.text(
          "Error: 'sourcePath' and 'zipPath' are required for compress action.",
        ),
      ];
    }

    log('Compressing folder "$source" to "$zip"');
    try {
      await compressFolderToZip(
        sourceDirPath: source,
        outputZipPath: zip,
        password: password,
        compressLevel: compressLevel,
        threadCount: threadCount,
        log: log,
      );
      log('Compression completed: Folder "$source" -> ZIP "$zip"');
      return [ChatContent.text('Successfully compressed folder: $source')];
    } catch (e) {
      log('Compression failed: $e');
      return [ChatContent.text('Compression error: $e')];
    }
  }

  Future<_Ret?> _handleExtractAll(_Map args, OnToolLog log) async {
    final zip = args['zipPath'] as String?;
    final dest = args['destinationPath'] as String?;
    final password = args['password'] as String?;
    final threadCount = (args['threadCount'] as int?) ?? 2;

    if (zip == null || dest == null) {
      return [
        ChatContent.text(
          "Error: 'zipPath' and 'destinationPath' are required for extractAll action.",
        ),
      ];
    }

    log('Extracting archive "$zip" to "$dest"');
    try {
      await extractZipToFolder(
        sourceZipPath: zip,
        outputDirPath: dest,
        password: password,
        threadCount: threadCount,
        log: log,
      );
      log('Extraction completed: ZIP "$zip" -> Folder "$dest"');
      return [ChatContent.text('Successfully extracted archive: $zip')];
    } catch (e) {
      log('Extraction failed: $e');
      return [ChatContent.text('Extraction error: $e')];
    }
  }

  Future<_Ret?> _handleAddFiles(_Map args, OnToolLog log) async {
    final zipPath = args['zipPath'] as String?;
    final sources = (args['sourceFilePaths'] as List?)?.cast<String>();
    final destDir = args['destinationEntryDir'] as String? ?? "";
    final password = args['password'] as String?;
    final compressLevel = (args['compressLevel'] as int?) ?? 5;
    final skipTopLevel = (args['skipTopLevel'] as bool?) ?? false;
    final threadCount = (args['threadCount'] as int?) ?? 2;

    if (zipPath == null || sources == null || sources.isEmpty) {
      return [
        ChatContent.text(
          "Error: 'zipPath' and 'sourceFilePaths' are required for addFiles action.",
        ),
      ];
    }

    log('Adding ${sources.length} files to "$zipPath"');
    ZipFile? zipFile;
    try {
      zipFile = await openZipFileSafe(
        zipFilePath: zipPath,
        password: password,
        log: log,
      );
      await addFilesToZip(
        zipFile: zipFile,
        sourcesInDisk: sources,
        targetDirInZip: destDir,
        compressLevel: compressLevel,
        skipTopLevel: skipTopLevel,
        threadCount: threadCount,
        log: log,
      );
      log(
        'Add files completed: ${sources.length} items added to ZIP "$zipPath"',
      );
      return [
        ChatContent.text(
          'Successfully added ${sources.length} files to the archive.',
        ),
      ];
    } catch (e) {
      log('Add files failed: $e');
      return [ChatContent.text('Add files error: $e')];
    } finally {
      if (zipFile != null) {
        try {
          closeZipFileSafe(zipFile, log: log);
        } catch (e) {
          log('Failed to close zip file after addFiles: $e');
        }
      }
    }
  }

  Future<_Ret?> _handleExtractFiles(_Map args, OnToolLog log) async {
    final zipPath = args['zipPath'] as String?;
    final entries = (args['entryPaths'] as List?)?.cast<String>();
    final dest = args['destinationPath'] as String?;
    final password = args['password'] as String?;
    final threadCount = (args['threadCount'] as int?) ?? 2;

    if (zipPath == null || entries == null || entries.isEmpty || dest == null) {
      return [
        ChatContent.text(
          "Error: 'zipPath', 'entryPaths', and 'destinationPath' are required for extractFiles action.",
        ),
      ];
    }

    log('Extracting ${entries.length} entries from "$zipPath" to "$dest"');
    ZipFile? zipFile;
    try {
      zipFile = await openZipFileSafe(
        zipFilePath: zipPath,
        password: password,
        log: log,
      );
      await extractFilesFromZip(
        zipFile: zipFile,
        sourcesInZip: entries,
        outputDirPath: dest,
        threadCount: threadCount,
        log: log,
      );
      log(
        'Extract files completed: ${entries.length} items from ZIP "$zipPath" -> "$dest"',
      );
      return [
        ChatContent.text('Successfully extracted ${entries.length} entries.'),
      ];
    } catch (e) {
      log('Extract files failed: $e');
      return [ChatContent.text('Extract files error: $e')];
    } finally {
      if (zipFile != null) {
        try {
          closeZipFileSafe(zipFile, log: log);
        } catch (e) {
          log('Failed to close zip file after extractFiles: $e');
        }
      }
    }
  }

  Future<_Ret?> _handleRenameEntry(_Map args, OnToolLog log) async {
    final zipPath = args['zipPath'] as String?;
    final sourceEntry = args['oldEntryPath'] as String?; // Refined parameter
    final newName = args['newEntryName'] as String?;
    final password = args['password'] as String?;

    if (zipPath == null || sourceEntry == null || newName == null) {
      return [
        ChatContent.text(
          "Error: 'zipPath', 'oldEntryPath', and 'newEntryName' are required for renameEntry action.",
        ),
      ];
    }

    // Use internal helper to correctly compute the final full path
    final newEntryPath = _computeRenamedEntryPath(sourceEntry, newName);

    log('Renaming "$sourceEntry" to "$newEntryPath" in archive "$zipPath"');
    ZipFile? zipFile;
    try {
      zipFile = await openZipFileSafe(
        zipFilePath: zipPath,
        password: password,
        log: log,
      );
      await renameZipEntry(
        zipFile,
        oldEntryPath: sourceEntry,
        newEntryPath: newEntryPath,
        log: log,
      );
      log(
        'Rename completed: "$sourceEntry" -> "$newEntryPath" in ZIP "$zipPath"',
      );
      return [ChatContent.text('Successfully renamed entry.')];
    } catch (e) {
      log('Rename entry failed: $e');
      return [ChatContent.text('Rename error: $e')];
    } finally {
      if (zipFile != null) {
        try {
          closeZipFileSafe(zipFile, log: log);
        } catch (e) {
          log('Failed to close zip file after renameEntry: $e');
        }
      }
    }
  }

  Future<_Ret?> _handleMoveEntries(_Map args, OnToolLog log) async {
    final zipPath = args['zipPath'] as String?;
    final entries = (args['entryPaths'] as List?)?.cast<String>();
    final destDir = args['destinationEntryDir'] as String?;
    final password = args['password'] as String?;

    if (zipPath == null ||
        entries == null ||
        entries.isEmpty ||
        destDir == null) {
      return [
        ChatContent.text(
          "Error: 'zipPath', 'entryPaths', and 'destinationEntryDir' are required for moveEntries action.",
        ),
      ];
    }

    log('Moving ${entries.length} entries to "$destDir" in archive "$zipPath"');
    ZipFile? zipFile;
    try {
      zipFile = await openZipFileSafe(
        zipFilePath: zipPath,
        password: password,
        log: log,
      );
      await moveZipEntries(
        zipFile,
        entriesToMove: entries,
        targetDirPath: destDir,
        log: log,
      );
      log(
        'Move entries completed: ${entries.length} items moved to "$destDir" in ZIP "$zipPath"',
      );
      return [
        ChatContent.text('Successfully moved ${entries.length} entries.'),
      ];
    } catch (e) {
      log('Move entries failed: $e');
      return [ChatContent.text('Move entries error: $e')];
    } finally {
      if (zipFile != null) {
        try {
          closeZipFileSafe(zipFile, log: log);
        } catch (e) {
          log('Failed to close zip file after moveEntries: $e');
        }
      }
    }
  }

  Future<_Ret?> _handleRemoveEntries(_Map args, OnToolLog log) async {
    final zipPath = args['zipPath'] as String?;
    final entries = (args['entryPaths'] as List?)?.cast<String>();
    final password = args['password'] as String?;

    if (zipPath == null || entries == null || entries.isEmpty) {
      return [
        ChatContent.text(
          "Error: 'zipPath' and 'entryPaths' are required for removeEntries action.",
        ),
      ];
    }

    log('Removing ${entries.length} entries from "$zipPath"');
    ZipFile? zipFile;
    try {
      zipFile = await openZipFileSafe(
        zipFilePath: zipPath,
        password: password,
        log: log,
      );
      await removeZipEntries(zipFile, entriesToRemove: entries, log: log);
      log(
        'Remove entries completed: ${entries.length} items removed from ZIP "$zipPath"',
      );
      return [
        ChatContent.text('Successfully removed ${entries.length} entries.'),
      ];
    } catch (e) {
      log('Remove entries failed: $e');
      return [ChatContent.text('Remove entries error: $e')];
    } finally {
      if (zipFile != null) {
        try {
          closeZipFileSafe(zipFile, log: log);
        } catch (e) {
          log('Failed to close zip file after removeEntries: $e');
        }
      }
    }
  }

  // --- Helper Methods (unchanged, excluding showProgress logic) ---

  void showZipProgress(ZipTaskFuture future, OnToolLog log) {
    var timer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      try {
        if (future.totalSize > 0 && future.processedSize >= 0) {
          var progress = future.processedSize / future.totalSize * 100;
          var compressRatio = future.processedSize > 0
              ? (future.compressedSize / future.processedSize * 100)
              : 0;
          var path = future.nowProcessingFilepath;
          log(
            "Progress: ${progress.toStringAsFixed(2)}%, Compress Ratio: ${compressRatio.toStringAsFixed(2)}%, Path: $path",
          );
        } else {
          log(
            "Progress: No files processed yet or total size is 0. Path: ${future.nowProcessingFilepath}",
          );
        }
      } catch (e) {
        log("Progress monitor error: $e");
      }
    });
    future.whenComplete(() {
      try {
        log("Operation finished.");
      } finally {
        timer.cancel();
      }
    });
  }

  Future<void> compressFolderToZip({
    required String sourceDirPath,
    required String outputZipPath,
    String? password,
    int compressLevel = 5,
    int? threadCount,
    required OnToolLog log,
  }) async {
    log("Starting compression of '$sourceDirPath' to '$outputZipPath'...");
    try {
      var future = NativeZip.zipDir(
        sourceDirPath,
        outputZipPath,
        password: password,
        compressLevel: compressLevel,
        threadCount: threadCount ?? 2,
      );

      // Internal progress logging (always on for tool logs, but not controlled by params)
      showZipProgress(future, log);

      await future;
      log("Compression completed successfully.");
    } catch (e, st) {
      log("Compression failed: $e\n$st");
      rethrow;
    }
  }

  Future<void> extractZipToFolder({
    required String sourceZipPath,
    required String outputDirPath,
    String? password,
    int? threadCount,
    required OnToolLog log,
  }) async {
    log("Starting extraction of '$sourceZipPath' to '$outputDirPath'...");
    try {
      var future = NativeZip.unzipToDir(
        sourceZipPath,
        outputDirPath,
        password: password,
        threadCount: threadCount ?? 2,
      );

      // Internal progress logging (always on for tool logs)
      showZipProgress(future, log);

      await future;
      log("Extraction completed successfully.");
    } catch (e, st) {
      log("Extraction failed: $e\n$st");
      rethrow;
    }
  }

  Future<ZipFile> openZipFileSafe({
    required String zipFilePath,
    String? password,
    required OnToolLog log,
  }) async {
    log("Opening zip file: '$zipFilePath'...");
    try {
      final zipFile = NativeZip.openZipFile(zipFilePath, password: password);
      log("Zip file opened successfully.");
      return zipFile;
    } catch (e, st) {
      log("Failed to open zip file: $e\n$st");
      rethrow;
    }
  }

  void closeZipFileSafe(ZipFile zipFile, {required OnToolLog log}) {
    log("Closing zip file...");
    try {
      zipFile.close();
      log("Zip file closed successfully.");
    } catch (e, st) {
      log("Failed to close zip file: $e\n$st");
      rethrow;
    }
  }

  List<ZipEntryInfo> getZipFileEntries(
    ZipFile zipFile, {
    String path = "",
    bool recursive = true,
    required OnToolLog log,
  }) {
    log("Getting entries from path '$path' (recursive: $recursive)...");
    try {
      final entries = zipFile.getEntries(path: path, recursive: recursive);
      log("Found ${entries.length} entries.");
      for (var e in entries) {
        log(
          " Entry: ${e.path}, Type: ${e.isDirectory ? 'Directory' : 'File'}, Size: ${e.originalSize} bytes",
        );
      }
      return entries;
    } catch (e, st) {
      log("Failed to get entries: $e\n$st");
      rethrow;
    }
  }

  Stream<List<int>> readZipFileContent(
    ZipFile zipFile,
    String entryPath,
    OnToolLog log,
  ) {
    log("Reading content of '$entryPath' from zip...");
    try {
      final stream = zipFile.openRead(entryPath);
      log("Successfully opened stream for '$entryPath'.");
      return stream;
    } catch (e, st) {
      log("Failed to open read stream for '$entryPath': $e\n$st");
      rethrow;
    }
  }

  Future<void> renameZipEntry(
    ZipFile zipFile, {
    required String oldEntryPath,
    required String newEntryPath,
    required OnToolLog log,
  }) async {
    log("Renaming '$oldEntryPath' to '$newEntryPath' in zip...");
    try {
      await zipFile.renameEntry(oldEntryPath, newEntryPath);
      log("Entry renamed successfully.");
    } catch (e, st) {
      log("Failed to rename entry: $e\n$st");
      rethrow;
    }
  }

  Future<void> moveZipEntries(
    ZipFile zipFile, {
    required List<String> entriesToMove,
    required String targetDirPath,
    required OnToolLog log,
  }) async {
    log("Moving ${entriesToMove.length} entries to '$targetDirPath' in zip...");
    try {
      await zipFile.moveEntries(entriesToMove, targetDirPath);
      log("Entries moved successfully.");
    } catch (e, st) {
      log("Failed to move entries: $e\n$st");
      rethrow;
    }
  }

  Future<void> removeZipEntries(
    ZipFile zipFile, {
    required List<String> entriesToRemove,
    required OnToolLog log,
  }) async {
    log("Removing ${entriesToRemove.length} entries from zip...");
    try {
      await zipFile.removeEntries(entriesToRemove);
      log("Entries removed successfully.");
    } catch (e, st) {
      log("Failed to remove entries: $e\n$st");
      rethrow;
    }
  }

  Future<void> addFilesToZip({
    required ZipFile zipFile,
    required List<String> sourcesInDisk,
    String targetDirInZip = "",
    int compressLevel = 5,
    bool skipTopLevel = false,
    int? threadCount,
    required OnToolLog log,
  }) async {
    log(
      "Adding ${sourcesInDisk.length} files/directories from disk to '$targetDirInZip' in zip...",
    );
    try {
      var future = zipFile.addFiles(
        sourcesInDisk,
        targetDirInZip,
        compressLevel: compressLevel,
        skipTopLevel: skipTopLevel,
        threadCount: threadCount ?? 2,
      );

      // Internal progress logging (always on for tool logs)
      showZipProgress(future, log);

      await future;
      log("Files/directories added successfully to zip.");
    } catch (e, st) {
      log("Add files operation failed: $e\n$st");
      rethrow;
    }
  }

  Future<void> extractFilesFromZip({
    required ZipFile zipFile,
    required List<String> sourcesInZip,
    required String outputDirPath,
    int? threadCount,
    required OnToolLog log,
  }) async {
    log(
      "Extracting ${sourcesInZip.length} files/directories from zip to '$outputDirPath'...",
    );
    try {
      var future = zipFile.saveFilesTo(
        sourcesInZip,
        outputDirPath,
        threadCount: threadCount ?? 2,
      );

      // Internal progress logging (always on for tool logs)
      showZipProgress(future, log);

      await future;
      log("Files/directories extracted from zip successfully.");
    } catch (e, st) {
      log("Failed to extract files from zip: $e\n$st");
      rethrow;
    }
  }

  String _computeRenamedEntryPath(String oldEntryPath, String newName) {
    if (oldEntryPath.endsWith('/')) {
      // directory
      final segments = oldEntryPath.split('/');
      // remove trailing empty and last folder name
      if (segments.isNotEmpty) segments.removeLast(); // removes trailing ''
      if (segments.isNotEmpty) segments.removeLast();
      final parent = segments.isNotEmpty ? segments.join('/') + '/' : '';
      return '$parent$newName/';
    } else {
      final idx = oldEntryPath.lastIndexOf('/');
      if (idx >= 0) {
        final parent = oldEntryPath.substring(0, idx + 1);
        return '$parent$newName';
      } else {
        return newName;
      }
    }
  }
}
