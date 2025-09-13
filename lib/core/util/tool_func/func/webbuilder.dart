part of '../tool.dart';

/// Web app builder tool
///
/// Allows the model to:
/// - write files into a temporary "workspace"
/// - manage directories (mkdirs / delete)
/// - read/list paths for inspection
/// - when finished: start a local preview server, export to Downloads, create a zip, open browser
/// - stop the server on demand
///
/// Safety:
/// - All paths are sandboxed under the workspace root and sanitized (no `..` traversal).
final class TfWebBuilder extends ToolFunc {
  static const instance = TfWebBuilder._();

  const TfWebBuilder._()
    : super(
        name: 'webbuilder',
        parametersSchema: const {
          'type': 'object',
          'properties': {
            'action': {
              'type': 'string',
              'description':
                  "Action to perform. One of: 'writeFile','mkdirs','readFile','listDir','deletePath','finishBuild','toggleServer','resetWorkspace'.",
            },
            'relPath': {
              'type': 'string',
              'description':
                  'Relative path under the workspace (e.g., "index.html", "assets/css/app.css"). Required for file ops.',
            },
            'content': {
              'type': 'string',
              'description':
                  'File content. If encoding=base64, provide base64 of the raw bytes; if utf8, plain text.',
            },
            'encoding': {
              'type': 'string',
              'enum': ['utf8', 'base64'],
              'description':
                  'Content encoding for writeFile/readFile. Defaults to utf8.',
            },
            'recursive': {
              'type': 'boolean',
              'description': 'For deletePath and mkdirs: apply recursively.',
            },
            'isDone': {
              'type': 'boolean',
              'description':
                  'If true with action=finishBuild, app will start local preview server, export to Downloads, zip, and open browser.',
            },
            'isTurnOff': {
              'type': 'boolean',
              'description':
                  'If true with action=toggleServer, the local preview server will be stopped.',
            },
          },
          'required': ['action'],
        },
      );

  @override
  String get l10nName => 'webbuilder';

  @override
  String get description => '''
A tool to generate and preview web apps locally:
- writeFile: write files (HTML/CSS/JS/assets) into a sandboxed workspace.
- mkdirs, readFile, listDir, deletePath: manage files/dirs.
- finishBuild: start a local HTTP server to preview, export sources to Downloads, create a zip, and open the browser.
- toggleServer: stop (or start) the server.
- resetWorkspace: wipe and recreate an empty workspace.
Return values always include "workspaceRoot".''';

  @override
  Future<_Ret?> run(_CallResp call, _Map args, OnToolLog log) async {
    final action = (args['action'] as String?)?.trim().toLowerCase();
    if (action == null || action.isEmpty) {
      return [ChatContent.text("Error: 'action' is required.")];
    }

    try {
      final ws = await _WebWorkspace.ensure();
      log('[webbuilder] workspaceRoot: ${ws.root.path}');

      switch (action) {
        case 'writefile':
          return await _handleWriteFile(ws, args, log);

        case 'mkdirs':
          return await _handleMkdirs(ws, args, log);

        case 'readfile':
          return await _handleReadFile(ws, args, log);

        case 'listdir':
          return await _handleListDir(ws, args, log);

        case 'deletepath':
          return await _handleDeletePath(ws, args, log);

        case 'finishbuild':
          return await _handleFinishBuild(ws, args, log);

        case 'toggleserver':
          return await _handleToggleServer(ws, args, log);

        case 'resetworkspace':
          return await _handleResetWorkspace(ws, log);

        default:
          return [ChatContent.text("Error: Unknown action '$action'.")];
      }
    } catch (e, st) {
      log('[webbuilder] Error: $e\n$st');
      return [ChatContent.text('WebBuilder error: $e')];
    }
  }

  Future<_Ret?> _handleWriteFile(
    _WebWorkspace ws,
    _Map args,
    OnToolLog log,
  ) async {
    final relPath = _sanitizeRelPath(args['relPath'] as String?);
    final content = args['content'] as String?;
    final encoding = ((args['encoding'] as String?) ?? 'utf8').toLowerCase();

    if (relPath == null || relPath.isEmpty) {
      return [ChatContent.text("Error: 'relPath' is required for writeFile.")];
    }
    if (content == null) {
      return [ChatContent.text("Error: 'content' is required for writeFile.")];
    }

    final file = ws.resolve(relPath);
    await file.parent.create(recursive: true);

    if (encoding == 'base64') {
      final bytes = base64Decode(content);
      await file.writeAsBytes(bytes, flush: true);
    } else {
      await file.writeAsString(content, flush: true);
    }

    log("[webbuilder] writeFile: '$relPath' (${encoding}) OK");
    return [
      ChatContent.text('writeFile OK'),
      ChatContent.text('workspaceRoot: ${ws.root.path}'),
      ChatContent.text('path: ${file.path}'),
    ];
  }

  Future<_Ret?> _handleMkdirs(
    _WebWorkspace ws,
    _Map args,
    OnToolLog log,
  ) async {
    final relPath = _sanitizeRelPath(args['relPath'] as String?);
    final recursive = args['recursive'] == true;
    if (relPath == null || relPath.isEmpty) {
      return [ChatContent.text("Error: 'relPath' is required for mkdirs.")];
    }
    final dir = ws.resolveDir(relPath);
    await dir.create(recursive: recursive);
    log("[webbuilder] mkdirs: '$relPath' (recursive=$recursive) OK");
    return [
      ChatContent.text('mkdirs OK'),
      ChatContent.text('workspaceRoot: ${ws.root.path}'),
      ChatContent.text('path: ${dir.path}'),
    ];
  }

  Future<_Ret?> _handleReadFile(
    _WebWorkspace ws,
    _Map args,
    OnToolLog log,
  ) async {
    final relPath = _sanitizeRelPath(args['relPath'] as String?);
    final encoding = ((args['encoding'] as String?) ?? 'utf8').toLowerCase();
    if (relPath == null || relPath.isEmpty) {
      return [ChatContent.text("Error: 'relPath' is required for readFile.")];
    }
    final file = ws.resolve(relPath);
    if (!file.existsSync()) {
      return [ChatContent.text("Error: File not found: '$relPath'")];
    }
    String out;
    if (encoding == 'base64') {
      final bytes = await file.readAsBytes();
      out = base64Encode(bytes);
    } else {
      out = await file.readAsString();
    }
    log("[webbuilder] readFile: '$relPath' OK (${encoding})");
    return [
      ChatContent.text('readFile OK'),
      ChatContent.text('workspaceRoot: ${ws.root.path}'),
      ChatContent.text(out),
    ];
  }

  Future<_Ret?> _handleListDir(
    _WebWorkspace ws,
    _Map args,
    OnToolLog log,
  ) async {
    final relPath = _sanitizeRelPath(args['relPath'] as String? ?? '.');
    final dir = ws.resolveDir(relPath!);
    if (!dir.existsSync()) {
      return [ChatContent.text("Error: Directory not found: '$relPath'")];
    }
    final items = <String>[];
    await for (final ent in dir.list(recursive: true, followLinks: false)) {
      final rp = ws.relative(ent.path);
      if (rp.isNotEmpty) items.add(rp);
    }
    items.sort();
    log("[webbuilder] listDir: '$relPath' -> ${items.length} items");
    return [
      ChatContent.text('listDir OK'),
      ChatContent.text('workspaceRoot: ${ws.root.path}'),
      ChatContent.text(items.join('\n')),
    ];
  }

  Future<_Ret?> _handleDeletePath(
    _WebWorkspace ws,
    _Map args,
    OnToolLog log,
  ) async {
    final relPath = _sanitizeRelPath(args['relPath'] as String?);
    final recursive = args['recursive'] == true;
    if (relPath == null || relPath.isEmpty) {
      return [ChatContent.text("Error: 'relPath' is required for deletePath.")];
    }
    final file = ws.resolve(relPath);
    if (!file.existsSync()) {
      final dir = ws.resolveDir(relPath);
      if (!dir.existsSync()) {
        return [ChatContent.text("Error: Path not found: '$relPath'")];
      }
      await dir.delete(recursive: recursive);
      log("[webbuilder] deleteDir: '$relPath' (recursive=$recursive) OK");
    } else {
      await file.delete();
      log("[webbuilder] deleteFile: '$relPath' OK");
    }
    return [
      ChatContent.text('deletePath OK'),
      ChatContent.text('workspaceRoot: ${ws.root.path}'),
    ];
  }

  Future<_Ret?> _handleFinishBuild(
    _WebWorkspace ws,
    _Map args,
    OnToolLog log,
  ) async {
    final isDone = args['isDone'] == true;
    if (!isDone) {
      return [ChatContent.text("finishBuild ignored because 'isDone' != true")];
    }

    // 1) start local preview server
    final srv = await _WebPreviewServer.instance.start(root: ws.root);
    log('[webbuilder] server started: ${srv.url}');

    // 2) export to Downloads and zip it
    final exportDir = await _Export.exportWorkspace(ws.root, log: log);
    final zipPath = await _Export.zipDir(exportDir, log: log);

    // 3) open browser
    try {
      final uri = Uri.parse(srv.url);
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      log('[webbuilder] open browser failed: $e');
    }

    return [
      ChatContent.text('finishBuild OK'),
      ChatContent.text('workspaceRoot: ${ws.root.path}'),
      ChatContent.text('previewUrl: ${srv.url}'),
      ChatContent.text('exportDir: ${exportDir.path}'),
      ChatContent.text('zipPath: $zipPath'),
    ];
  }

  Future<_Ret?> _handleToggleServer(
    _WebWorkspace ws,
    _Map args,
    OnToolLog log,
  ) async {
    final turnOff = args['isTurnOff'] == true;
    final srv = _WebPreviewServer.instance;
    if (turnOff) {
      await srv.stop();
      log('[webbuilder] server stopped');
      return [
        ChatContent.text('toggleServer OK'),
        ChatContent.text('previewUrl:'),
      ];
    } else {
      final started = await srv.start(root: ws.root);
      log('[webbuilder] server started: ${started.url}');
      try {
        await launchUrl(
          Uri.parse(started.url),
          mode: LaunchMode.externalApplication,
        );
      } catch (_) {}
      return [
        ChatContent.text('toggleServer OK'),
        ChatContent.text('previewUrl: ${started.url}'),
      ];
    }
  }

  Future<_Ret?> _handleResetWorkspace(_WebWorkspace ws, OnToolLog log) async {
    await ws.reset();
    log('[webbuilder] workspace reset');
    return [ChatContent.text('resetWorkspace OK')];
  }

  String? _sanitizeRelPath(String? rel) {
    if (rel == null) return null;
    // Normalize separators and strip leading slashes
    var s = rel.replaceAll('\\', '/');
    while (s.startsWith('/')) s = s.substring(1);
    // Deny traversal
    if (s.contains('..')) {
      // strip any traversal attempts
      s = s.split('/').where((seg) => seg != '..' && seg.isNotEmpty).join('/');
    }
    return s.trim();
  }
}

/// Workspace manager
class _WebWorkspace {
  final Directory root;
  _WebWorkspace._(this.root);

  static _WebWorkspace? _cur;

  static Future<_WebWorkspace> ensure() async {
    if (_cur != null) return _cur!;
    final d = await Directory.systemTemp.createTemp('web_ws_');
    _cur = _WebWorkspace._(d);
    return _cur!;
  }

  File resolve(String rel) => File(p.join(root.path, rel));
  Directory resolveDir(String rel) => Directory(p.join(root.path, rel));
  String relative(String absPath) {
    final rp = p.relative(absPath, from: root.path);
    if (rp == '.') return '';
    return rp.replaceAll('\\', '/');
  }

  Future<void> reset() async {
    try {
      if (root.existsSync()) await root.delete(recursive: true);
    } catch (_) {}
    final d = await Directory.systemTemp.createTemp('web_ws_');
    _cur = _WebWorkspace._(d);
  }
}

/// Local static server with shelf
class _WebPreviewServer {
  _WebPreviewServer._();

  static final _WebPreviewServer instance = _WebPreviewServer._();
  HttpServer? _server;
  Directory? _servedRoot;

  String get url {
    final s = _server;
    if (s == null) return '';
    final host = s.address.isLoopback ? 'localhost' : s.address.host;
    return 'http://$host:${s.port}/';
  }

  Future<_WebPreviewServer> start({required Directory root, int? port}) async {
    // If already serving same root, return
    if (_server != null && _servedRoot?.path == root.path) return this;

    await stop();

    final handler = const Pipeline()
        .addMiddleware(logRequests())
        .addHandler(
          createStaticHandler(
            root.path,
            defaultDocument: 'index.html',
            listDirectories: true,
          ),
        );

    // Pick a free port (or provided)
    final bindAddress = InternetAddress.loopbackIPv4;
    final srv = await io.serve(handler, bindAddress, port ?? 0);
    _server = srv;
    _servedRoot = root;
    return this;
  }

  Future<void> stop() async {
    try {
      await _server?.close(force: true);
    } catch (_) {}
    _server = null;
    _servedRoot = null;
  }
}

/// Export helpers: copy to Downloads-like dir and zip
class _Export {
  static Future<Directory> exportWorkspace(
    Directory wsRoot, {
    required OnToolLog log,
  }) async {
    final base = await _downloadsLikeDir();
    final out = Directory(
      p.join(
        base.path,
        'GptBoxWebApps',
        'web_${DateTime.now().millisecondsSinceEpoch}',
      ),
    );
    await out.create(recursive: true);
    await _copyDir(wsRoot, out);
    log('[webbuilder] exported to: ${out.path}');
    return out;
  }

  static Future<String> zipDir(Directory dir, {required OnToolLog log}) async {
    // Use NativeZip if available in your app (already used elsewhere)
    final zipOut = p.join(dir.parent.path, '${p.basename(dir.path)}.zip');
    try {
      final future = NativeZip.zipDir(dir.path, zipOut, threadCount: 2);
      await future;
      log('[webbuilder] zip created: $zipOut');
      return zipOut;
    } catch (e) {
      log('[webbuilder] zip failed: $e');
      rethrow;
    }
  }

  static Future<Directory> _downloadsLikeDir() async {
    // Desktop platforms: path_provider getDownloadsDirectory is ok.
    // Mobile: use external storage (Android) or Documents (iOS) as fallback.
    try {
      final d = await getDownloadsDirectory();
      if (d != null) return d;
    } catch (_) {}
    if (Platform.isAndroid) {
      final ext = await getExternalStorageDirectory();
      if (ext != null) {
        // try put under "Download" sibling
        final parent = Directory(p.join(ext.parent.path, 'Download'));
        if (parent.existsSync()) return parent;
        return ext;
      }
    }
    if (Platform.isIOS) {
      return await getApplicationDocumentsDirectory();
    }
    // Fallback to temporary
    return await Directory.systemTemp.createTemp('exports_');
  }

  static Future<void> _copyDir(Directory src, Directory dst) async {
    await for (final ent in src.list(recursive: true, followLinks: false)) {
      final rel = p.relative(ent.path, from: src.path);
      final target = p.join(dst.path, rel);
      if (ent is Directory) {
        await Directory(target).create(recursive: true);
      } else if (ent is File) {
        await File(target).parent.create(recursive: true);
        await ent.copy(target);
      }
    }
  }
}
