import 'dart:io';
import 'package:path/path.dart' as path;

import '../../util/utils.dart';

class WebBuilders {
  final String prjName;
  final String projectPrompt;
  WebBuilders({required this.prjName, required this.projectPrompt});

  String currentDir = '';

  void init() {
    currentProjectDir();
  }

  Future<bool> ensureWebBuildersDirectory() async {
    try {
      // Get the target directory
      final targetDir = await getTargetDirectory(folderUnderApp: "");

      // Create the WebBuilders folder path
      final webBuildersPath = path.join(targetDir.path, 'WebBuilders');
      final webBuildersDir = Directory(webBuildersPath);

      // Check if folder exists, create if it doesn't
      if (!await webBuildersDir.exists()) {
        await webBuildersDir.create(recursive: true);
      }
      final webBuildersPathCurrentProject = path.join(
        webBuildersDir.path,
        prjName,
      );
      final webBuildersDirCurrentProject = Directory(
        webBuildersPathCurrentProject,
      );
      if (!await webBuildersDirCurrentProject.exists()) {
        await webBuildersDirCurrentProject.create(recursive: true);
      }
      currentDir = webBuildersDirCurrentProject.path;
      return true;
    } catch (e) {
      print('Error ensuring WebBuilders directory: $e');
      return false;
    }
  }

  Future<String?> currentProjectDir() async {
    final r = await ensureWebBuildersDirectory();
    if (r) {
      final targetDir = await getTargetDirectory(folderUnderApp: "WebBuilders");
      final webBuildersPathCurrentProject = path.join(targetDir.path, prjName);
      return webBuildersPathCurrentProject;
    } else {
      final targetDir = await getTargetDirectory(folderUnderApp: "");

      // Create the WebBuilders folder path
      final webBuildersPath = path.join(targetDir.path, 'WebBuilders');
      final webBuildersDir = Directory(webBuildersPath);

      // Check if folder exists, create if it doesn't
      if (!await webBuildersDir.exists()) {
        await webBuildersDir.create(recursive: true);
      }
      final webBuildersPathCurrentProject = path.join(
        webBuildersDir.path,
        '$prjName-${DateTime.now()}',
      );
      final webBuildersDirCurrentProject = Directory(
        webBuildersPathCurrentProject,
      );
      if (!await webBuildersDirCurrentProject.exists()) {
        await webBuildersDirCurrentProject.create(recursive: true);
      }
      currentDir = webBuildersDirCurrentProject.path;

      return webBuildersDirCurrentProject.path;
    }
  }
}
