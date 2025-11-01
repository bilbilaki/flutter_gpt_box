import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'models.dart';

class FileService {
  static String? _customOutputPath; // Stores custom output path if set

  static Future<String> get _localStoragePath async {
    // If a custom path is set, use it. Otherwise, use the app's document directory.
    if (_customOutputPath != null) {
      final dir = Directory(_customOutputPath!);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      return _customOutputPath!;
    }
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  static Future<void> setOutputPath(String? path) async {
    _customOutputPath = path;
  }

  static Future<String?> pickOutputDirectory() async {
    try {
      String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
      if (selectedDirectory != null) {
        _customOutputPath = selectedDirectory; // Store the selected path
        return selectedDirectory;
      }
      return null;
    } catch (e) {
      print("Error picking directory: $e");
      return null;
    }
  }

  static Future<File> _getFile(String filename) async {
    final path = await _localStoragePath;
    return File('$path/$filename');
  }

  static Future<void> saveObjectResponse(
    AIRequestObject object,
    String response,
  ) async {
    try {
      final file = await _getFile('object_${object.objectNumber}.json');
      final data = {
        'objectNumber': object.objectNumber,
        // 'content': object.content, // Removed as per request
        'aiResponse': response,
        'timestamp': DateTime.now().toIso8601String(),
      };
      await file.writeAsString(json.encode(data));
    } catch (e) {
      throw Exception('Failed to save object response: $e');
    }
  }

  static Future<void> saveCollectiveResponse(
    String name,
    String response,
  ) async {
    try {
      final file = await _getFile(
        '${name}_collective_responses.txt',
      ); // Changed to .txt
      await file.writeAsString(response);
    } catch (e) {
      throw Exception('Failed to save collective response: $e');
    }
  }

  // --- Template Management ---

  static Future<void> saveTemplate(
    String templateFileName,
    String content,
  ) async {
    try {
      final file = await _getFile(
        templateFileName,
      ); // Use provided filename directly
      final data = {
        'name': templateFileName
            .replaceFirst('template_', '')
            .replaceFirst('.json', ''),
        'content': content,
        'createdAt': DateTime.now().toIso8601String(),
      };
      await file.writeAsString(json.encode(data));
    } catch (e) {
      throw Exception('Failed to save template: $e');
    }
  }

  static Future<List<String>> getSavedTemplates() async {
    try {
      final path = await _localStoragePath;
      final directory = Directory(path);
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }
      final files = directory.listSync().whereType<File>().toList();

      final templates = <String>[];
      for (final file in files) {
        if (file.path.contains('template_') && file.path.endsWith('.json')) {
          // Extract filename without path and extension
          final fileName = file.uri.pathSegments.last;
          templates.add(fileName);
        }
      }
      return templates;
    } catch (e) {
      print('Error getting saved templates: $e');
      return [];
    }
  }

  static Future<String?> loadTemplate(String templateFileName) async {
    try {
      final file = await _getFile(templateFileName);
      if (await file.exists()) {
        final content = await file.readAsString();
        final data = json.decode(content);
        return data['content'];
      }
      return null;
    } catch (e) {
      print('Error loading template $templateFileName: $e');
      return null;
    }
  }

  static Future<String> getCurrentOutputPath() async {
    return _customOutputPath ?? await _localStoragePath;
  }
}
