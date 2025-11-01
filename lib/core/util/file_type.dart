
import 'package:path/path.dart' as p;

enum AppFileType {
  image,
  audio,
  directdoc,
  undirectdoc,
}

AppFileType getAppFileType(String filePath) {
  final ext = p.extension(filePath).toLowerCase();

  const imageExtensions = [
    '.png',
    '.jpg',
    '.jpeg',
    '.webp',
    '.gif',
    '.bmp',
    '.heic',
    '.heif'
  ];
  const audioExtensions = [
    '.wav',
    '.mp3',
    '.m4a',
    '.aac',
    '.flac',
    '.ogg',
    '.oga',
    '.webm'
  ];
  const directDocExtensions = ['.txt', '.csv', '.md'];

  if (imageExtensions.contains(ext)) {
    return AppFileType.image;
  } else if (audioExtensions.contains(ext)) {
    return AppFileType.audio;
  } else if (directDocExtensions.contains(ext)) {
    return AppFileType.directdoc;
  } else {
    return AppFileType.undirectdoc;
  }
}
