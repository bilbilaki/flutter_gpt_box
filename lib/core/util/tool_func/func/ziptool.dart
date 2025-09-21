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
                  "The specific zip operation to perform. Must be one of: 'compress', 'extractAll', 'addFiles', 'extractFiles', 'renameEntry', 'moveEntries', 'removeEntries'.",
            },
            'zipPath': {
              'type': 'string',
              'description':
                  'The path to the ZIP archive file. Required for all actions except "compress".',
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
            'newEntryName': {
              'type': 'string',
              'description':
                  "The new name for a single entry within the zip. Required for the 'renameEntry' action. You must provide the full path if it's in a subdirectory.",
            },
            'destinationEntryDir': {
              'type': 'string',
              'description':
                  "The path to a destination directory *inside* the ZIP archive. Used with 'addFiles' and 'moveEntries' actions.",
            },
          },
          'required': ['action'],
        },
      );

  @override
  String get description => '''
A powerful tool to manage ZIP archives. It can create, extract, and modify zip files based on the specified 'action'.

**Actions and Required Parameters:**
1.-compress'**: Creates a new ZIP file from a folder.
 -   `sourcePath`: The folder to compress.
 -   `zipPath`: The path for the output ZIP file to be created.
 -   optional: `password`, `compressLevel`, `threadCount`, `showProgress` (bool)
2.-extractAll'**: Extracts the entire content of a ZIP file.
 -   `zipPath`: The ZIP file to extract.
 -   `destinationPath`: The folder where contents will be extracted.
 -   optional: `password`, `threadCount`, `showProgress` (bool)
3.-addFiles'**: Adds files from the disk into an existing ZIP file.
 -   `zipPath`: The target ZIP file.
 -   `sourceFilePaths`: A list of file/folder paths on disk to add.
 -   `destinationEntryDir` (optional): A folder inside the zip to place the new files.
 -   optional: `password`, `compressLevel`, `skipTopLevel`, `threadCount`, `showProgress` (bool)
4.-extractFiles'**: Extracts specific files or folders from a ZIP file.
 -   `zipPath`: The source ZIP file.
 -   `entryPaths`: A list of one or more files/folders inside the zip to extract.
 -   `destinationPath`: The folder on disk where files will be extracted.
 -    optional: `password`, `threadCount`, `showProgress` (bool)
5.-renameEntry'**: Renames a single file or folder inside a ZIP file.
 -   `zipPath`: The target ZIP file.
 -   `entryPaths`: A list containing the single, full path of the entry to rename.
 -   `newEntryName`: The new name for the entry.
 - optional: `password`
6.-moveEntries'**: Moves files or folders to a different directory inside the ZIP.
 -   `zipPath`: The target ZIP file.
 -   `entryPaths`: A list of entries to move.
 -   `destinationEntryDir`: The target directory inside the zip.
 -   `optional: `password`
7.-removeEntries'**: Deletes files or folders from inside the ZIP file.
 -   `zipPath`: The target ZIP file.
 -   `entryPaths`: A list of entries to delete.
 -   optional: `password`
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
          final source = args['sourcePath'] as String?;
          final zip = args['zipPath'] as String?;
          final password = args['password'] as String?;
          final compressLevel = (args['compressLevel'] as int?) ?? 5;
          final threadCount = (args['threadCount'] as int?) ?? 2;
          final showProgress = (args['showProgress'] as bool?) ?? false;

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
              showProgress: showProgress,
              log: log,
            );
            return [
              ChatContent.text('Successfully compressed folder: $source'),
            ];
          } catch (e) {
            log('Compression failed: $e');
            return [ChatContent.text('Compression error: $e')];
          }

        case 'extractAll':
          final zip = args['zipPath'] as String?;
          final dest = args['destinationPath'] as String?;
          final password = args['password'] as String?;
          final threadCount = (args['threadCount'] as int?) ?? 2;
          final showProgress = (args['showProgress'] as bool?) ?? false;

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
              showProgress: showProgress,
              log: log,
            );
            return [ChatContent.text('Successfully extracted archive: $zip')];
          } catch (e) {
            log('Extraction failed: $e');
            return [ChatContent.text('Extraction error: $e')];
          }

        case 'addFiles':
          final zipPath = args['zipPath'] as String?;
          final sources = (args['sourceFilePaths'] as List?)?.cast<String>();
          final destDir = args['destinationEntryDir'] as String? ?? "";
          final password = args['password'] as String?;
          final compressLevel = (args['compressLevel'] as int?) ?? 5;
          final skipTopLevel = (args['skipTopLevel'] as bool?) ?? false;
          final threadCount = (args['threadCount'] as int?) ?? 2;
          final showProgress = (args['showProgress'] as bool?) ?? false;

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
              showProgress: showProgress,
              log: log,
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

        case 'extractFiles':
          final zipPath = args['zipPath'] as String?;
          final entries = (args['entryPaths'] as List?)?.cast<String>();
          final dest = args['destinationPath'] as String?;
          final password = args['password'] as String?;
          final threadCount = (args['threadCount'] as int?) ?? 2;
          final showProgress = (args['showProgress'] as bool?) ?? false;

          if (zipPath == null ||
              entries == null ||
              entries.isEmpty ||
              dest == null) {
            return [
              ChatContent.text(
                "Error: 'zipPath', 'entryPaths', and 'destinationPath' are required for extractFiles action.",
              ),
            ];
          }

          log(
            'Extracting ${entries.length} entries from "$zipPath" to "$dest"',
          );
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
              showProgress: showProgress,
              log: log,
            );
            return [
              ChatContent.text(
                'Successfully extracted ${entries.length} entries.',
              ),
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

        case 'renameEntry':
          final zipPath = args['zipPath'] as String?;
          final entry = (args['entryPaths'] as List?)?.cast<String>();
          final newName = args['newEntryName'] as String?;
          final password = args['password'] as String?;

          if (zipPath == null ||
              entry == null ||
              entry.isEmpty ||
              newName == null) {
            return [
              ChatContent.text(
                "Error: 'zipPath', a single 'entryPaths' item, and 'newEntryName' are required for renameEntry action.",
              ),
            ];
          }

          final sourceEntry = entry.first;
          final newEntryPath = _computeRenamedEntryPath(sourceEntry, newName);

          log(
            'Renaming "$sourceEntry" to "$newEntryPath" in archive "$zipPath"',
          );
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

        case 'moveEntries':
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

          log(
            'Moving ${entries.length} entries to "$destDir" in archive "$zipPath"',
          );
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

        case 'removeEntries':
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
            return [
              ChatContent.text(
                'Successfully removed ${entries.length} entries.',
              ),
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

        default:
          return [ChatContent.text("Error: Unknown action '$action'.")];
      }
    } catch (e) {
      log('ZIP Manager Error: $e');
      return [
        ChatContent.text(
          'An error occurred while performing the zip operation: $e',
        ),
      ];
    }
  }

  /// Displays the progress of a [ZipTaskFuture] operation.
  ///
  /// This function sets up a periodic timer to log the progress, compress ratio,
  /// and currently processing file path. The timer is canceled when the future
  /// completes.
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

  /// Compresses a directory into a .zip file.
  ///
  /// Returns a [ZipTaskFuture] which completes when the operation is done.
  Future<void> compressFolderToZip({
    required String sourceDirPath,
    required String outputZipPath,
    String? password,
    int compressLevel = 5,
    int? threadCount,
    bool showProgress = false,
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

      if (showProgress) showZipProgress(future, log);

      await future;
      log("Compression completed successfully.");
    } catch (e, st) {
      log("Compression failed: $e\n$st");
      rethrow;
    }
  }

  /// Extracts all files from a .zip archive to a specified directory.
  Future<void> extractZipToFolder({
    required String sourceZipPath,
    required String outputDirPath,
    String? password,
    int? threadCount,
    bool showProgress = false,
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

      if (showProgress) showZipProgress(future, log);

      await future;
      log("Extraction completed successfully.");
    } catch (e, st) {
      log("Extraction failed: $e\n$st");
      rethrow;
    }
  }

  /// Opens a .zip file for operations.
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

  /// Closes a [ZipFile] instance.
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

  /// Gets a list of entries (files and directories) within a zip file.
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

  /// Reads the content of a file within a zip archive as a byte stream.
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

  /// Renames a file or directory within a zip archive.
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

  /// Moves one or more files or directories within a zip archive.
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

  /// Moves a single file or directory within a zip archive.
  Future<void> moveSingleZipEntry(
    ZipFile zipFile, {
    required String entryToMove,
    required String targetDirPath,
    required OnToolLog log,
  }) async {
    log("Moving '$entryToMove' to '$targetDirPath' in zip...");
    try {
      await zipFile.moveEntry(entryToMove, targetDirPath);
      log("Entry moved successfully.");
    } catch (e, st) {
      log("Failed to move entry: $e\n$st");
      rethrow;
    }
  }

  /// Deletes one or more files or directories from a zip archive.
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

  /// Deletes a single file or directory from a zip archive.
  Future<void> removeSingleZipEntry(
    ZipFile zipFile, {
    required String entryToRemove,
    required OnToolLog log,
  }) async {
    log("Removing '$entryToRemove' from zip...");
    try {
      await zipFile.removeEntry(entryToRemove);
      log("Entry removed successfully.");
    } catch (e, st) {
      log("Failed to remove entry: $e\n$st");
      rethrow;
    }
  }

  /// Adds files/directories from disk into an existing zip archive.
  Future<void> addFilesToZip({
    required ZipFile zipFile,
    required List<String> sourcesInDisk,
    String targetDirInZip = "",
    int compressLevel = 5,
    bool skipTopLevel = false,
    int? threadCount,
    bool showProgress = false,
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

      if (showProgress) {
        showZipProgress(future, log);
      }

      await future;
      log("Files/directories added successfully to zip.");
    } catch (e, st) {
      log("Add files operation failed: $e\n$st");
      rethrow;
    }
  }

  /// Extracts specific files/directories from a zip archive to disk.
  Future<void> extractFilesFromZip({
    required ZipFile zipFile,
    required List<String> sourcesInZip,
    required String outputDirPath,
    int? threadCount,
    bool showProgress = false,
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

      if (showProgress) showZipProgress(future, log);

      await future;
      log("Files/directories extracted from zip successfully.");
    } catch (e, st) {
      log("Failed to extract files from zip: $e\n$st");
      rethrow;
    }
  }

  /// Extracts a single file or directory from a zip archive to disk.
  Future<void> extractSingleFileFromZip({
    required ZipFile zipFile,
    required String sourceInZip,
    required String outputDirPath,
    int? threadCount,
    bool showProgress = false,
    required OnToolLog log,
  }) async {
    log("Extracting '$sourceInZip' from zip to '$outputDirPath'...");
    try {
      var future = zipFile.saveTo(
        sourceInZip,
        outputDirPath,
        threadCount: threadCount ?? 2,
      );

      if (showProgress) showZipProgress(future, log);

      await future;
      log("Single file/directory extracted from zip successfully.");
    } catch (e, st) {
      log("Failed to extract single file from zip: $e\n$st");
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
