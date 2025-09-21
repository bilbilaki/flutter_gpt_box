import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

Future<Directory> getTargetDirectory({
  required String folderUnderApp,
  String userSubdir = '',
  String appFolderName = 'GPTBOX',
  bool ensureExists = true,
}) async {
  // Determine the base download directory per platform.
  late final Directory baseDir;
  if (Platform.isAndroid) {
    baseDir = Directory('/storage/emulated/0/Download');
  } else if (Platform.isLinux) {
    baseDir = Directory(p.join(Platform.environment['HOME']!, 'Downloads'));
  } else if (Platform.isWindows) {
    baseDir = Directory(
      p.join(Platform.environment['USERPROFILE']!, 'Downloads'),
    );
  } else {
    final Directory? downloadsDir = await getDownloadsDirectory();
    baseDir = downloadsDir ?? await getApplicationDocumentsDirectory();
  }

  // Build: base/<appFolderName>/<folderUnderApp>/<userSubdir?>
  String targetPath = p.join(baseDir.path, appFolderName);
  if (folderUnderApp.isNotEmpty) {
    targetPath = p.join(targetPath, folderUnderApp);
  }
  if (userSubdir.isNotEmpty) {
    targetPath = p.join(targetPath, userSubdir);
  }

  final dir = Directory(targetPath);

  if (ensureExists && !await dir.exists()) {
    await dir.create(recursive: true);
  }

  return dir;
}
