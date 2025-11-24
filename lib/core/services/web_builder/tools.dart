import 'dart:io';

/// Creates multiple empty files in batch under a specified directory.
/// 
/// [baseDirectoryPath] - The base directory path where files will be created
/// [fileNames] - List of file names to create as empty files
/// 
/// Returns a list of created File objects on success
Future<List<File>> createEmptyFilesBatch(
  String baseDirectoryPath,
  List<String> fileNames,
) async {
  try {
    // Ensure base directory exists
    final baseDir = Directory(baseDirectoryPath);
    if (!await baseDir.exists()) {
      await baseDir.create(recursive: true);
    }

    // Create all files in parallel for performance
    final fileFutures = fileNames.map((fileName) async {
      final filePath = '${baseDir.path}${Platform.pathSeparator}$fileName';
      final file = File(filePath);
      
      // Check if file already exists to avoid overwriting
      if (!await file.exists()) {
        await file.create(recursive: true);
      }
      return file;
    }).toList();

    // Wait for all file creation operations to complete
    final createdFiles = await Future.wait(fileFutures);
    return createdFiles;
  } catch (e) {
    throw Exception('Failed to create files: $e');
  }
}

/// Writes or appends content to multiple files in batch.
/// 
/// [baseDirectoryPath] - The base directory path where files are located
/// [fileNames] - List of file names to write/append content to
/// [content] - The content to write or append to all files
/// [isAppend] - If true, appends content; if false, replaces file content (default: false)
/// 
/// Returns a list of modified File objects on success
Future<List<File>> writeContentToFilesBatch(
  String baseDirectoryPath,
  List<String> fileNames,
  String content, {
  bool isAppend = false,
}) async {
  try {
    final baseDir = Directory(baseDirectoryPath);
    if (!await baseDir.exists()) {
      await baseDir.create(recursive: true);
    }

    // Write content to all files in parallel
    final fileFutures = fileNames.map((fileName) async {
      final filePath = '${baseDir.path}${Platform.pathSeparator}$fileName';
      final file = File(filePath);
      
      // Create file if it doesn't exist
      if (!await file.exists()) {
        await file.create(recursive: true);
      }
      
      // Write or append based on isAppend flag
      if (isAppend) {
        await file.writeAsString(content, mode: FileMode.append);
      } else {
        await file.writeAsString(content, mode: FileMode.write);
      }
      
      return file;
    }).toList();

    final modifiedFiles = await Future.wait(fileFutures);
    return modifiedFiles;
  } catch (e) {
    throw Exception('Failed to write content to files: $e');
  }
}

/// Generates a directory tree structure up to a specified depth.
/// 
/// [directoryPath] - The root directory path to start traversing from
/// [depth] - Maximum depth to traverse (0 means only root directory)
/// 
/// Returns a formatted string representation of the directory tree
Future<String> getDirectoryTree(
  String directoryPath, {
  int depth = 3,
}) async {
  try {
    final baseDir = Directory(directoryPath);
    if (!await baseDir.exists()) {
      throw Exception('Directory does not exist: $directoryPath');
    }

    final buffer = StringBuffer();
    buffer.writeln(baseDir.path);
    
    await _buildTree(baseDir, buffer, depth, '', true);
    
    return buffer.toString();
  } catch (e) {
    throw Exception('Failed to generate directory tree: $e');
  }
}

/// Recursively builds the directory tree structure.
Future<void> _buildTree(
  Directory dir,
  StringBuffer buffer,
  int remainingDepth,
  String prefix,
  bool isLast,
) async {
  if (remainingDepth < 0) return;

  try {
    final entities = await dir.list().toList();
    
    // Sort entities: directories first, then files
    entities.sort((a, b) {
      final aIsDir = a is Directory ? 1 : 0;
      final bIsDir = b is Directory ? 1 : 0;
      return bIsDir.compareTo(aIsDir);
    });

    for (int i = 0; i < entities.length; i++) {
      final entity = entities[i];
      final isLastEntity = i == entities.length - 1;
      final connector = isLastEntity ? '└── ' : '├── ';
      final entityName = entity.path.split(Platform.pathSeparator).last;

      buffer.writeln('$prefix$connector$entityName');

      if (entity is Directory && remainingDepth > 0) {
        final extension = isLastEntity ? '    ' : '│   ';
        await _buildTree(
          entity,
          buffer,
          remainingDepth - 1,
          prefix + extension,
          isLastEntity,
        );
      }
    }
  } catch (e) {
    // Handle permission errors gracefully
    buffer.writeln('$prefix[Error accessing directory]');
  }
}



