import 'package:path/path.dart' as p;

enum AppFileType { image, audio, directdoc, undirectdoc, reversefiletotext }

AppFileType getAppFileType(
  String filePath, {
  bool convertingfiletotextmessagebeforesending = false,
}) {
  final ext = p.extension(filePath).toLowerCase();

// ===== IMAGE EXTENSIONS =====
const imageExtensions = [
  '.png', '.jpg', '.jpeg', '.webp', '.gif', '.bmp', '.heic', '.heif',
  // additional common image formats
  '.tiff', '.tif', '.svg', '.svgz', '.ico', '.cur',
  '.dng', '.cr2', '.nef', '.orf', '.raf', '.arw',    // camera raw
  '.psd', '.xcf', '.ai', '.eps',                    // layered / vector
  '.raw', '.ppm', '.pgm', '.pbm', '.pnm',
  '.jp2', '.j2k', '.jpf', '.jpx',                   // JPEG 2000
  '.jxr', '.hdr', '.exr',                           // HDR / OpenEXR
  '.avif', '.apng', '.mng',                         // modern / animated
  '.icns', '.xbm', '.xpm', '.wbmp',
];

// ===== AUDIO EXTENSIONS =====
const audioExtensions = [
  '.wav', '.mp3', '.m4a', '.aac', '.flac', '.ogg', '.oga', '.webm',
  // additional audio formats
  '.opus', '.wma', '.alac', '.aiff', '.au', '.snd',
  '.mid', '.midi', '.mp2', '.ra', '.ram',            // legacy / streaming
  '.ac3', '.dts', '.eac3',                           // surround / Dolby
  '.mka', '.m4r', '.caf',                            // Matroska / Apple
  '.3gp',                                            // (usually video, but audio only variant)
];

// ===== TEXT / CODE EXTENSIONS =====
// Originally: ['.txt', '.csv', '.md']
// Expanded to cover programming languages and other plain‑text formats
const textExtensions = [
  '.txt', '.csv', '.md',
  // programming languages (alphabetical)
  '.asm', '.awk', '.bash', '.bat', '.c', '.cbl', '.cc', '.cfm', '.clj',
  '.cmake', '.cpp', '.cs', '.css', '.cxx', '.d', '.dart', '.elm', '.erl',
  '.ex', '.exs', '.f', '.f90', '.f95', '.fish', '.for', '.fs', '.fsx',
  '.go', '.groovy', '.h', '.hpp', '.hs', '.htm', '.html', '.hxx',
  '.ini', '.java', '.jl', '.js', '.json', '.jsx', '.kt', '.kts',
  '.less', '.lisp', '.log', '.lua', '.m', '.make', '.ml', '.mli',
  '.nim', '.nix', '.pas', '.php', '.pl', '.pm', '.ps1', '.psm1',
  '.py', '.r', '.rb', '.rs', '.rst', '.sass', '.scala', '.scm',
  '.scss', '.sh', '.sml', '.sql', '.sty', '.swift', '.tcl',
  '.tex', '.toml', '.ts', '.tsx', '.twig', '.vbs', '.vim',
  '.xhtml', '.xml', '.yaml', '.yml', '.zsh',
  // other text‑based formats
  '.conf', '.cfg', '.env', '.gitignore', '.gradle', '.ini',
  '.lock', '.log', '.mak', '.mk', '.plist', '.properties',
  '.rc', '.reg', '.tex', '.textile', '.tsv', '.url',
  // note: .docx, .xlsx, etc. are binary (ZIP containers) and are NOT plain text
];

  if (imageExtensions.contains(ext)) {
    return AppFileType.image;
  } else if (audioExtensions.contains(ext)) {
    return AppFileType.audio;
  } else if (textExtensions.contains(ext)) {
    return AppFileType.directdoc;
  } else if (convertingfiletotextmessagebeforesending) {
    return AppFileType.reversefiletotext;
  } else {
    return AppFileType.undirectdoc;
  }
}
