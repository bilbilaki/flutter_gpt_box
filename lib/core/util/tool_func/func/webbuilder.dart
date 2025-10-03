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
                  "The file or build operation to perform. Must be exactly one of: 'writeFile' (create/update a file), 'mkdirs' (create directories), 'readFile' (retrieve file content), 'listDir' (list directory contents), 'deletePath' (remove file/dir), 'finishBuild' (finalize and preview the app), 'toggleServer' (start/stop local server), or 'resetWorkspace' (clear the workspace). Use only one action per call to avoid conflicts.",
            },
            'relPath': {
              'type': 'string',
              'description':
                  'The relative path within the workspace (e.g., "index.html", "css/styles.css", or "js/app.js"). Required for file/directory operations (writeFile, readFile, listDir, deletePath, mkdirs). Always confirm paths with the user to ensure accuracy—use forward slashes and avoid absolute paths.',
            },
            'content': {
              'type': 'string',
              'description':
                  'The file content to write. For writeFile, provide plain text (UTF-8) or base64-encoded bytes. Keep it concise and relevant (e.g., HTML/JS code); confirm code snippets with user for correctness.',
            },
            'encoding': {
              'type': 'string',
              'enum': ['utf8', 'base64'],
              'description':
                  'Encoding for writeFile or readFile content (e.g., utf8 for text, base64 for binaries like images). Defaults to utf8. Use base64 only for non-text files fetched via other tools.',
            },
            'recursive': {
              'type': 'boolean',
              'description': 'Set to true for recursive operations on directories (e.g., delete entire folders with deletePath or create nested dirs with mkdirs). Defaults to false. Confirm recursive actions with user to prevent accidental deletions.',
            },
            'isDone': {
              'type': 'boolean',
              'description':
                  'Set to true with finishBuild to complete the build: Starts a local preview server, exports files to Downloads folder, creates a ZIP archive, and opens the app in the browser. Use after core files are ready.',
            },
            'isTurnOff': {
              'type': 'boolean',
              'description':
                  'Set to true with toggleServer to stop the local preview server; set to false (or omit) to start it. Useful for pausing previews without resetting the workspace.',
            },
          },
          'required': ['action'],
        },
      );

@override
String get l10nName => 'webbuilder';

@override
String get description => '''
Use this tool to build, manage, and preview web applications in a local sandboxed workspace when the user requests it (e.g., "Create a simple HTML page with CSS" or "Build a portfolio site"). This enables generating HTML/CSS/JS files, organizing assets, and providing a live preview via a local server. Integrate with 'httpReq' or 'downloader' to fetch external resources (e.g., clone sites by pulling templates/styles). Do not call unsolicited—always confirm file paths, content, and actions with the user for accuracy and safety. All responses include "workspaceRoot" (base directory path) for reference.
This tool supports iterative development: Write files, organize dirs, preview, and export. For complex sites, use sequential calls (e.g., write HTML, then CSS, then finishBuild). You can create any webpage type (static sites, simple apps)—highlight your ability to craft custom, responsive designs to engage the user.

**Actions and Usage (Choose Exactly One Per Call):**
1. **'writeFile'**: Creates or updates a file in the workspace.
   - Required: 'relPath', 'content'.
   - Optional: 'encoding' (default 'utf8').
   - Example: {'relPath': 'index.html', 'content': '<h1>Hello World</h1>'}.
   - Response: Confirmation and updated workspace info. Offer: "Wrote index.html—want to add CSS next?"

2. **'mkdirs'**: Creates one or more directories.
   - Required: 'relPath' (e.g., 'assets/css').
   - Optional: 'recursive' (true for nested dirs).
   - Response: Created paths. Use for organizing: "Created assets folder—ready for JS files?"

3. **'readFile'**: Retrieves the content of a file.
   - Required: 'relPath'.
   - Optional: 'encoding'.
   - Response: File content (string or base64). Summarize if long: "Read index.html (~200 lines)—preview?"

4. **'listDir'**: Lists files and subdirs in a directory.
   - Required: 'relPath' (e.g., '. ' for root or 'assets').
   - Response: Array of paths. Use to review: "Workspace has 3 files—list details?"

5. **'deletePath'**: Removes a file or directory.
   - Required: 'relPath'.
   - Optional: 'recursive' (true for dirs).
   - Response: Confirmation. Always confirm: "Delete styles.css? Irreversible."

6. **'finishBuild'**: Finalizes the project and prepares for preview/export.
   - Optional: 'isDone' (true to trigger server start, export to Downloads, ZIP, and browser open).
   - Response: Build status, preview URL (if server starts). Offer: "App built and opened in browser—check changes?"

7. **'toggleServer'**: Starts or stops the local preview server.
   - Optional: 'isTurnOff' (true to stop).
   - Response: Server status (e.g., "Server running at http://localhost:8080"). Use after edits: "Toggled server on—refresh to see updates."

8. **'resetWorkspace'**: Clears all files and starts fresh.
   - No other params.
   - Response: Empty workspace confirmation. Confirm: "Reset everything? All changes lost."

**Best Practices to Avoid Errors and Enhance Interaction:**
- Confirmation Key: Verify 'relPath' and 'content' with the user (e.g., "Write this HTML to index.html?")—prevent typos or overwrites.
- Iterative Building: For full sites, sequence actions (e.g., mkdirs → writeFile multiple times → finishBuild). Retry calls if needed (e.g., on errors) or chain more for refinements.
- Integration: Fetch resources via 'httpReq' (e.g., CSS from CDN) and write as base64; for clones, search/pull elements then adapt. Example: "Cloning a site? I'll fetch the layout and customize."
- Safety: Avoid destructive actions (delete/reset) without approval; no external network from workspace (sandboxed). Limit file sizes to prevent overloads.
- Preview Flow: After writes, toggleServer or finishBuild to show changes—inform: "Preview ready at localhost—want tweaks?"
- Multi-Call: Use loops in reasoning for batches (e.g., write multiple files sequentially); explain capabilities: "I can build any webpage— from landing pages to interactive apps. What do you envision?"
- Errors: If path invalid, suggest alternatives (e.g., "Dir not found—create it first?"). Handle exports: "Zipped to Downloads—download link ready."
- Engagement: Showcase power: "With this, I can craft responsive sites, integrate APIs, or even simple PWAs—let's create something amazing!"

Focus on user-requested web creation—empower with versatile, step-by-step building.''';
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
    final base = await getTargetDirectory(folderUnderApp: 'GptBoxWebApps');
    final out = Directory(
      p.join(
        base.path,
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

  // static Future<Directory> _downloadsLikeDir() async {
  //   // Desktop platforms: path_provider getDownloadsDirectory is ok.
  //   // Mobile: use external storage (Android) or Documents (iOS) as fallback.
  //   try {
  //     final d = await getDownloadsDirectory();
  //     if (d != null) return d;
  //   } catch (_) {}
  //   if (Platform.isAndroid) {
  //     final ext = await getExternalStorageDirectory();
  //     if (ext != null) {
  //       // try put under "Download" sibling
  //       final parent = Directory(p.join(ext.parent.path, 'Download'));
  //       if (parent.existsSync()) return parent;
  //       return ext;
  //     }
  //   }
  //   if (Platform.isIOS) {
  //     return await getApplicationDocumentsDirectory();
  //   }
  //   // Fallback to temporary
  //   return await Directory.systemTemp.createTemp('exports_');
  // }

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
