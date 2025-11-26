part of '../tool.dart';

/// Node.js / TypeScript project builder tool.
///
/// Similar to [TfPythonProjectBuilder] / [TfGoProjectBuilder], but focused on
/// Node.js and TypeScript applications:
/// - Sandboxed workspace for Node/TS code
/// - Project scaffolding (HTTP API, TS app, or simple JS CLI) from:
///   - built-in templates, or
///   - a folder-tree schema + file contents
/// - File editor (write/read/list/mkdir/delete/tree)
/// - Project runner (npm / node / ts-node / arbitrary shell commands)
/// - Test runner (npm test / jest / vitest, via npm scripts)
/// - Node env setup (npm init, install deps)
/// - Export & reset workflow
///
/// Safety:
/// - All paths are sandboxed under the workspace root and sanitized (no `..` traversal).
final class TfNodeProjectBuilder extends ToolFunc {
  static const instance = TfNodeProjectBuilder._();

  const TfNodeProjectBuilder._()
      : super(
          name: 'nodeProjectBuilder',
          parametersSchema: const {
            'type': 'object',
            'properties': {
              'action': {
                'type': 'string',
                'description': '''
The operation to perform. Exactly one of:
- 'scaffoldProject'  : Initialize a new Node/TypeScript project in the workspace.
- 'setupPackage'     : Initialize package.json and optionally install dependencies/devDependencies.
- 'writeFile'        : Create or overwrite a file.
- 'readFile'         : Read a file's content.
- 'listDir'          : List files/directories.
- 'mkdirs'           : Create directories.
- 'deletePath'       : Delete a file or directory.
- 'showTree'         : Show directory tree structure.
- 'runCommand'       : Run an arbitrary shell / Node / npm command in the project workspace.
- 'runApp'           : Convenience helper to run/stop/status the dev server or app (e.g. "npm run dev", "node index.js").
- 'runTests'         : Run tests (e.g. "npm test").
- 'exportProject'    : Export the workspace to a user folder and optionally zip.
- 'resetWorkspace'   : Wipe the workspace and start fresh (destructive).
''',
              },

              // Common file/dir params
              'relPath': {
                'type': 'string',
                'description':
                    'Relative path inside the workspace (e.g., "index.ts", "src/app.ts", "tests/app.test.ts"). Used by writeFile/readFile/listDir/mkdirs/deletePath/showTree.',
              },
              'content': {
                'type': 'string',
                'description':
                    'File content for writeFile. UTF-8 text or base64 (see "encoding"). Use for JS/TS code, configs, etc.',
              },
              'encoding': {
                'type': 'string',
                'enum': ['utf8', 'base64'],
                'description':
                    'Encoding for writeFile/readFile content. Defaults to "utf8". Use "base64" for binary files.',
              },
              'recursive': {
                'type': 'boolean',
                'description':
                    'For listDir/deletePath/showTree: if true, include nested structure. Defaults to false for listDir/deletePath, true for showTree.',
              },

              // Scaffold-related
              'templateType': {
                'type': 'string',
                'description': '''
Template to use for scaffoldProject. Suggested values:
- 'node_express_ts_minimal' : Minimal Express HTTP API in TypeScript.
- 'node_ts_basic'          : Basic TypeScript app with ts-node / tsconfig.
- 'node_js_cli_basic'      : Simple Node CLI tool in plain JS.
If omitted but "projectSchema" is provided, the schema is used instead of a built-in template.
''',
              },
              'projectName': {
                'type': 'string',
                'description':
                    'Logical project name, used in scaffold template files (e.g., package.json name, README title). Optional; defaults to "my_node_app".',
              },

              /// Folder tree schema for custom project structure
              ///
              /// {
              ///   "name": "root",
              ///   "children": [
              ///     {"name": "index.ts", "type": "file", "content": "..."},
              ///     {
              ///       "name": "src",
              ///       "type": "dir",
              ///       "children": [
              ///         {"name": "app.ts", "type": "file", "content": "..."}
              ///       ]
              ///     }
              ///   ]
              /// }
              'projectSchema': {
                'type': 'object',
                'description':
                    'Optional folder tree schema for scaffoldProject. If provided, overrides templateType for structure/content. See description for schema shape.',
              },

              // Scaffold options
              'autoSetupPackage': {
                'type': 'boolean',
                'description':
                    'For scaffoldProject: if true (default), automatically calls setupPackage after scaffolding to install dependencies based on template (like setupModule in Go builder). Defaults to true.',
              },

              // Node package setup
              'initWithNpm': {
                'type': 'boolean',
                'description':
                    'For setupPackage: if true (default), runs "npm init -y" before installing dependencies.',
              },
              'dependencies': {
                'type': 'array',
                'items': {'type': 'string'},
                'description':
                    'For setupPackage: optional list of runtime dependencies to install via "npm install". Example: ["express", "cors"].',
              },
              'devDependencies': {
                'type': 'array',
                'items': {'type': 'string'},
                'description':
                    'For setupPackage: optional list of dev dependencies to install via "npm install -D". Example: ["typescript", "ts-node", "@types/node"].',
              },

              // Run / test actions
              'command': {
                'type': 'string',
                'description':
                    'For runCommand: the shell command to execute in the workspace (e.g., "npm run dev", "node index.js", "npm test").',
              },
              'timeoutMs': {
                'type': 'integer',
                'description':
                    'Optional timeout in milliseconds to wait for command output (default ~5000). Increase for long-running tasks.',
              },

              'appAction': {
                'type': 'string',
                'enum': ['start', 'stop', 'status'],
                'description':
                    'For runApp: whether to start, stop, or query status of the Node app helper (e.g., dev server).',
              },
              'appCommand': {
                'type': 'string',
                'description':
                    'Optional custom command for runApp "start" (e.g., "npm run dev", "node index.js"). If omitted, a default is guessed based on scaffold (prefers npm scripts).',
              },

              'testCommand': {
                'type': 'string',
                'description':
                    'Optional override for runTests (default "npm test" if package.json has a test script, else "npm run test" and similar fallbacks). Example: "npm run test:unit".',
              },

              // Export
              'includeZip': {
                'type': 'boolean',
                'description':
                    'For exportProject: if true (default), also create a ZIP archive of the exported project directory.',
              },
            },
            'required': ['action'],
          },
        );

  @override
  String get l10nName => 'Node / TypeScript Project Builder';

  @override
  String get description => '''
Use this tool to design, scaffold, edit, run, and test **Node.js / TypeScript projects** inside a sandboxed workspace. It mirrors the Python/Go builders, but specialized for Node/TS:

You can:
- **Scaffold** Node/TS HTTP APIs or CLI tools from a high-level folder tree schema or a simple template type.
- **Set up package.json** and optionally install dependencies/devDependencies.
- **Edit** files (create/overwrite, read, list, mkdir, delete).
- **Inspect** the project structure as a directory tree.
- **Run** Node/npm commands (`npm run dev`, `node index.js`, `npm test`, arbitrary shell).
- **Run tests** via npm test or a custom script.
- **Export** the finished project and optionally zip it.
- **Reset** the workspace to start a new project.

All operations are sandboxed under an internal workspace directory. Relative paths are sanitized to avoid `..` traversal.

---

### Key Actions (One Per Call)

1. **'scaffoldProject'** – Initialize a new Node/TS project
   - Use for: "Create an Express API in TypeScript", "Make a Node CLI", "Generate a Node project from this tree".
   - Parameters:
     - `templateType` *(optional)*: `"node_express_ts_minimal"`, `"node_ts_basic"`, `"node_js_cli_basic"`.
     - `projectName` *(optional)*: logical project name, default `"my_node_app"`.
     - `projectSchema` *(optional)*: folder tree schema; if present, overrides `templateType`.
     - `autoSetupPackage` *(optional)*: if true (default), automatically runs setupPackage after scaffolding to install deps. Like setupModule in Go builder.
   - Behavior:
     - Resets the workspace to a clean state.
     - If `projectSchema` is provided, recursively creates dirs/files as described.
     - Otherwise uses `templateType` to generate a starter:
       - `node_express_ts_minimal`: Express API with TypeScript, modern tooling (vitest, tsx), dev server with tsx watch.
       - `node_ts_basic`: plain TS app with TypeScript, vitest testing, modern tooling (tsx).
       - `node_js_cli_basic`: simple CLI in JS with modern Node setup (vitest).
     - If `autoSetupPackage` is true, automatically installs all dependencies and devDependencies for the template.

2. **'setupPackage'** – Initialize package.json and install deps
   - Parameters:
     - `initWithNpm` *(optional)*: if true (default), runs `npm init -y` first.
     - `dependencies` *(optional)*: list of runtime deps for `npm install`.
     - `devDependencies` *(optional)*: list of dev deps for `npm install -D`.
   - Behavior:
     - Optionally runs `npm init -y` if package.json does not exist or initWithNpm is true.
     - Installs listed dependencies/devDependencies.

3. **File/dir operations** – 'writeFile' / 'readFile' / 'listDir' / 'mkdirs' / 'deletePath' / 'showTree'
   - Same semantics as Python/Go builders:
     - `writeFile`: required `relPath`, `content`; optional `encoding`.
     - `readFile`: required `relPath`; optional `encoding`.
     - `listDir`: required `relPath`; optional `recursive`.
     - `mkdirs`: required `relPath`; optional `recursive` (default true).
     - `deletePath`: required `relPath`; optional `recursive` for directories.
     - `showTree`: optional `relPath` (default `"."`), optional `recursive` (default true).

4. **'runCommand'** – Run arbitrary shell command in workspace
   - Parameters:
     - `command`: e.g. `"npm run dev"`, `"node index.js"`, `"npm test"`.
     - `timeoutMs` *(optional)*: default ~5000ms.
   - Response includes exit code, stdout, stderr.

5. **'runApp'** – Helper to start/stop/status dev server or app
   - Parameters:
     - `appAction`: `"start"`, `"stop"`, `"status"`.
     - `appCommand` *(optional when starting)*: e.g. `"npm run dev"`, `"node index.js"`.
   - Behavior:
     - Manages a single persistent process for the app within the workspace.
     - Logs stdout/stderr to the tool log.
     - Returns simple status text to the model.

6. **'runTests'** – Run tests
   - Parameters:
     - `testCommand` *(optional)*: e.g. `"npm test"`, `"npm run test:unit"`.
   - Default behavior:
     - If `testCommand` is omitted, chooses a sensible default (prefers `npm test` when available).

7. **'exportProject'** – Export to a user-visible folder + optional zip
   - Parameters:
     - `includeZip` *(optional)*: default true.
   - Behavior:
     - Uses the same export helpers as the other builders.
     - Returns `exportDir` and `zipPath` (if created).

8. **'resetWorkspace'** – Wipe workspace
   - Destroys all files and re-creates a clean workspace under a temp directory.
   - Confirm with the user before using.

---

### Best Practices

- Plan routes/CLI behavior with the user, then **scaffold once**.
- Use `setupPackage` after scaffolding to initialize package.json/deps properly if the template doesn’t already.
- Use `runCommand` for one-shots (build, short test), and `runApp` for long-running dev servers.
- Prefer `runTests` over raw `runCommand` when the user just says "run the tests".
- Call `exportProject` before resetting if the project might be reused outside the app.
''';

  @override
  Future<_Ret?> run(_CallResp call, _Map args, OnToolLog log) async {
    final action = (args['action'] as String?)?.trim();
    if (action == null || action.isEmpty) {
      return [ChatContent.text("Error: 'action' is required for nodeProjectBuilder.")];
    }

    try {
      final ws = await _NodeWorkspace.ensure();
      log('[nodeProjectBuilder] workspaceRoot: ${ws.root.path}, action: $action');

      switch (action) {
        case 'scaffoldProject':
          return await _handleScaffold(ws, args, log);
        case 'setupPackage':
          return await _handleSetupPackage(ws, args, log);
        case 'writeFile':
          return await _handleWriteFile(ws, args, log);
        case 'readFile':
          return await _handleReadFile(ws, args, log);
        case 'listDir':
          return await _handleListDir(ws, args, log);
        case 'mkdirs':
          return await _handleMkdirs(ws, args, log);
        case 'deletePath':
          return await _handleDeletePath(ws, args, log);
        case 'showTree':
          return await _handleShowTree(ws, args, log);
        case 'runCommand':
          return await _handleRunCommand(ws, args, log);
        case 'runApp':
          return await _handleRunApp(ws, args, log);
        case 'runTests':
          return await _handleRunTests(ws, args, log);
        case 'exportProject':
          return await _handleExportProject(ws, args, log);
        case 'resetWorkspace':
          return await _handleResetWorkspace(ws, log);
        default:
          return [ChatContent.text("Error: Unknown action '$action'.")];
      }
    } catch (e, st) {
      log('[nodeProjectBuilder] Error: $e\n$st');
      return [
        ChatContent.text(
          'nodeProjectBuilder error performing action "$action": $e\nworkspaceRoot: ${(_NodeWorkspace._cur?.root.path ?? 'N/A')}',
        ),
      ];
    }
  }

  // === ACTION HANDLERS ===

  Future<_Ret?> _handleScaffold(
    _NodeWorkspace ws,
    _Map args,
    OnToolLog log,
  ) async {
    final templateType = (args['templateType'] as String?)?.trim().toLowerCase();
    final projectName = (args['projectName'] as String?)?.trim().isNotEmpty == true
        ? (args['projectName'] as String).trim()
        : 'my_node_app';
    final schema = args['projectSchema'] as Map<String, dynamic>?;
    final autoSetup = args['autoSetupPackage'] != false; // default true

    // Clean workspace
    await ws.reset();
    log('[nodeProjectBuilder] workspace reset before scaffold');

    if (schema != null) {
      await _materializeSchema(ws, schema, log, prefix: '');
      log('[nodeProjectBuilder] Scaffolded project from custom schema');
      return [
        ChatContent.text('scaffoldProject OK (custom projectSchema)'),
        ChatContent.text('workspaceRoot: ${ws.root.path}'),
      ];
    }

    switch (templateType) {
      case 'node_ts_basic':
        await _scaffoldNodeTsBasic(ws, projectName, log);
        break;
      case 'node_js_cli_basic':
        await _scaffoldNodeJsCliBasic(ws, projectName, log);
        break;
      case 'node_express_ts_minimal':
      default:
        await _scaffoldNodeExpressTsMinimal(ws, projectName, log);
        break;
    }

    final msgs = <ChatContent>[
      ChatContent.text('scaffoldProject OK (templateType: ${templateType ?? 'node_express_ts_minimal'})'),
      ChatContent.text('workspaceRoot: ${ws.root.path}'),
    ];

    // Auto-setup packages if requested (like setupModule in Go builder)
    if (autoSetup) {
      log('[nodeProjectBuilder] auto-running setupPackage for template');
      final setupRes = await _handleSetupPackage(ws, args, log);
      if (setupRes != null) {
        msgs.add(ChatContent.text('--- setupPackage (auto) ---'));
        msgs.addAll(setupRes.cast<ChatContent>());
      }
    }

    return msgs;
  }

  Future<_Ret?> _handleSetupPackage(
    _NodeWorkspace ws,
    _Map args,
    OnToolLog log,
  ) async {
    final initWithNpm = args['initWithNpm'] != false; // default true
    final deps = (args['dependencies'] as List?)?.cast<String>() ?? const <String>[];
    final devDeps = (args['devDependencies'] as List?)?.cast<String>() ?? const <String>[];

    // npm init -y if requested or if package.json is missing
    final pkgFile = ws.resolve('package.json');
    if (initWithNpm || !pkgFile.existsSync()) {
      log('[nodeProjectBuilder] setupPackage: npm init -y');
      final initRes = await _runShell(
        ws,
        'npm init -y',
        timeoutMs: 60000,
        log: log,
      );
      if (initRes.exitCode != 0) {
        return [
          ChatContent.text('setupPackage FAILED (npm init -y)'),
          ChatContent.text('workspaceRoot: ${ws.root.path}'),
          ChatContent.text(initRes.toDisplayString()),
        ];
      }
    }

    // Install dependencies
    _ShellResult? depsRes;
    if (deps.isNotEmpty) {
      final depCmd = 'npm install ${deps.join(' ')}';
      log('[nodeProjectBuilder] setupPackage: $depCmd');
      depsRes = await _runShell(
        ws,
        depCmd,
        timeoutMs: 600000,
        log: log,
      );
      if (depsRes.exitCode != 0) {
        return [
          ChatContent.text('setupPackage FAILED (dependencies)'),
          ChatContent.text('workspaceRoot: ${ws.root.path}'),
          ChatContent.text(depsRes.toDisplayString()),
        ];
      }
    }

    // Install devDependencies
    _ShellResult? devDepsRes;
    if (devDeps.isNotEmpty) {
      final devCmd = 'npm install -D ${devDeps.join(' ')}';
      log('[nodeProjectBuilder] setupPackage: $devCmd');
      devDepsRes = await _runShell(
        ws,
        devCmd,
        timeoutMs: 600000,
        log: log,
      );
      if (devDepsRes.exitCode != 0) {
        return [
          ChatContent.text('setupPackage FAILED (devDependencies)'),
          ChatContent.text('workspaceRoot: ${ws.root.path}'),
          ChatContent.text(devDepsRes.toDisplayString()),
        ];
      }
    }

    final msgs = <ChatContent>[
      ChatContent.text('setupPackage OK'),
      ChatContent.text('workspaceRoot: ${ws.root.path}'),
    ];
    if (depsRes != null) {
      msgs.add(ChatContent.text('dependencies install:\n${depsRes.toDisplayString()}'));
    }
    if (devDepsRes != null) {
      msgs.add(ChatContent.text('devDependencies install:\n${devDepsRes.toDisplayString()}'));
    }
    return msgs;
  }

  Future<_Ret?> _handleWriteFile(
    _NodeWorkspace ws,
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

    log("[nodeProjectBuilder] writeFile: '$relPath' ($encoding) OK");
    return [
      ChatContent.text('writeFile OK'),
      ChatContent.text('path: ${file.path}'),
      ChatContent.text('workspaceRoot: ${ws.root.path}'),
    ];
  }

  Future<_Ret?> _handleReadFile(
    _NodeWorkspace ws,
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

    log("[nodeProjectBuilder] readFile: '$relPath' ($encoding) OK");
    return [
      ChatContent.text('readFile OK'),
      ChatContent.text('workspaceRoot: ${ws.root.path}'),
      ChatContent.text(out),
    ];
  }

  Future<_Ret?> _handleListDir(
    _NodeWorkspace ws,
    _Map args,
    OnToolLog log,
  ) async {
    final relPath = _sanitizeRelPath(args['relPath'] as String? ?? '.');
    final recursive = args['recursive'] == true;
    final dir = ws.resolveDir(relPath!);

    if (!dir.existsSync()) {
      return [ChatContent.text("Error: Directory not found: '$relPath'")];
    }

    final items = <String>[];
    await for (final ent in dir.list(recursive: recursive, followLinks: false)) {
      final rp = ws.relative(ent.path);
      if (rp.isNotEmpty) items.add(rp);
    }
    items.sort();

    log("[nodeProjectBuilder] listDir: '$relPath' (recursive=$recursive) -> ${items.length} items");
    return [
      ChatContent.text('listDir OK'),
      ChatContent.text('workspaceRoot: ${ws.root.path}'),
      ChatContent.text(items.join('\n')),
    ];
  }

  Future<_Ret?> _handleMkdirs(
    _NodeWorkspace ws,
    _Map args,
    OnToolLog log,
  ) async {
    final relPath = _sanitizeRelPath(args['relPath'] as String?);
    final recursive = args['recursive'] != false;

    if (relPath == null || relPath.isEmpty) {
      return [ChatContent.text("Error: 'relPath' is required for mkdirs.")];
    }

    final dir = ws.resolveDir(relPath);
    await dir.create(recursive: recursive);
    log("[nodeProjectBuilder] mkdirs: '$relPath' (recursive=$recursive) OK");

    return [
      ChatContent.text('mkdirs OK'),
      ChatContent.text('path: ${dir.path}'),
      ChatContent.text('workspaceRoot: ${ws.root.path}'),
    ];
  }

  Future<_Ret?> _handleDeletePath(
    _NodeWorkspace ws,
    _Map args,
    OnToolLog log,
  ) async {
    final relPath = _sanitizeRelPath(args['relPath'] as String?);
    final recursive = args['recursive'] == true;

    if (relPath == null || relPath.isEmpty) {
      return [ChatContent.text("Error: 'relPath' is required for deletePath.")];
    }

    final file = ws.resolve(relPath);
    if (file.existsSync()) {
      await file.delete();
      log("[nodeProjectBuilder] deleteFile: '$relPath' OK");
    } else {
      final dir = ws.resolveDir(relPath);
      if (!dir.existsSync()) {
        return [ChatContent.text("Error: Path not found: '$relPath'")];
      }
      await dir.delete(recursive: recursive);
      log("[nodeProjectBuilder] deleteDir: '$relPath' (recursive=$recursive) OK");
    }

    return [
      ChatContent.text('deletePath OK'),
      ChatContent.text('workspaceRoot: ${ws.root.path}'),
    ];
  }

  Future<_Ret?> _handleShowTree(
    _NodeWorkspace ws,
    _Map args,
    OnToolLog log,
  ) async {
    final relPath = _sanitizeRelPath(args['relPath'] as String? ?? '.');
    final recursive = args['recursive'] != false;
    final dir = ws.resolveDir(relPath!);

    if (!dir.existsSync()) {
      return [ChatContent.text("Error: Directory not found: '$relPath'")];
    }

    final buf = StringBuffer();
    await _buildTree(ws, dir, buf, prefix: '', isRoot: true, recursive: recursive);
    final treeStr = buf.toString();
    log("[nodeProjectBuilder] showTree for '$relPath' (recursive=$recursive)\n$treeStr");

    return [
      ChatContent.text('showTree OK'),
      ChatContent.text('workspaceRoot: ${ws.root.path}'),
      ChatContent.text(treeStr),
    ];
  }

  Future<_Ret?> _handleRunCommand(
    _NodeWorkspace ws,
    _Map args,
    OnToolLog log,
  ) async {
    final command = (args['command'] as String?)?.trim();
    if (command == null || command.isEmpty) {
      return [ChatContent.text("Error: 'command' is required for runCommand.")];
    }
    final timeoutMs = args['timeoutMs'] as int? ?? 5000;

    log("[nodeProjectBuilder] runCommand: '$command' (timeoutMs=$timeoutMs)");

    final res = await _runShell(ws, command, timeoutMs: timeoutMs, log: log);

    return [
      ChatContent.text('runCommand OK'),
      ChatContent.text('workspaceRoot: ${ws.root.path}'),
      ChatContent.text(res.toDisplayString()),
    ];
  }

  Future<_Ret?> _handleRunApp(
    _NodeWorkspace ws,
    _Map args,
    OnToolLog log,
  ) async {
    final action = (args['appAction'] as String?)?.trim().toLowerCase();
    if (action == null || action.isEmpty) {
      return [ChatContent.text("Error: 'appAction' is required for runApp.")];
    }

    final appCommandRaw = (args['appCommand'] as String?)?.trim();
    final manager = _NodeAppManager.instance;

    switch (action) {
      case 'start':
        final guessed = await _guessDefaultRunCommand(ws, log);
        final cmd = appCommandRaw ?? guessed ?? 'npm run dev';
        final status = await manager.startIfNeeded(ws.root, cmd, log);
        return [
          ChatContent.text('runApp start OK'),
          ChatContent.text('workspaceRoot: ${ws.root.path}'),
          ChatContent.text('command: $cmd'),
          ChatContent.text('status: ${status.statusText}'),
        ];
      case 'status':
        final status = manager.status;
        return [
          ChatContent.text('runApp status'),
          ChatContent.text('workspaceRoot: ${ws.root.path}'),
          ChatContent.text('status: ${status.statusText}'),
        ];
      case 'stop':
        final stopped = await manager.stop(log);
        return [
          ChatContent.text('runApp stop ${stopped ? "OK" : "no running app"}'),
          ChatContent.text('workspaceRoot: ${ws.root.path}'),
        ];
      default:
        return [ChatContent.text("Error: Unknown appAction '$action'.")];
    }
  }

  Future<_Ret?> _handleRunTests(
    _NodeWorkspace ws,
    _Map args,
    OnToolLog log,
  ) async {
    final explicit = (args['testCommand'] as String?)?.trim();
    if (explicit != null && explicit.isNotEmpty) {
      return _handleRunCommand(
        ws,
        {'command': explicit, 'timeoutMs': args['timeoutMs']},
        log,
      );
    }

    // Default heuristics: prefer "npm test" if package.json has a test script.
    final pkg = ws.resolve('package.json');
    String command = 'npm test';
    if (!pkg.existsSync()) {
      // Fallback to "npm run test" anyway; it will fail clearly if no package.json.
      command = 'npm test';
    }

    log('[nodeProjectBuilder] runTests default command: $command');
    return _handleRunCommand(
      ws,
      {'command': command, 'timeoutMs': args['timeoutMs']},
      log,
    );
  }

  Future<_Ret?> _handleExportProject(
    _NodeWorkspace ws,
    _Map args,
    OnToolLog log,
  ) async {
    final includeZip = args['includeZip'] != false;

    final exportDir = await _Export.exportWorkspace(
      ws.root,
      log: log,
    );

    String? zipPath;
    if (includeZip) {
      zipPath = await _Export.zipDir(exportDir, log: log);
    }

    return [
      ChatContent.text('exportProject OK'),
      ChatContent.text('workspaceRoot: ${ws.root.path}'),
      ChatContent.text('exportDir: ${exportDir.path}'),
      if (zipPath != null) ChatContent.text('zipPath: $zipPath'),
    ];
  }

  Future<_Ret?> _handleResetWorkspace(
    _NodeWorkspace ws,
    OnToolLog log,
  ) async {
    await ws.reset();
    log('[nodeProjectBuilder] workspace reset');
    return [
      ChatContent.text('resetWorkspace OK'),
      ChatContent.text('workspaceRoot: ${ws.root.path}'),
    ];
  }

  // === HELPERS ===

  String? _sanitizeRelPath(String? rel) {
    if (rel == null) return null;
    var s = rel.replaceAll('\\', '/');
    while (s.startsWith('/')) s = s.substring(1);
    if (s.contains('..')) {
      s = s
          .split('/')
          .where((seg) => seg != '..' && seg.isNotEmpty)
          .join('/');
    }
    return s.trim();
  }

  Future<void> _materializeSchema(
    _NodeWorkspace ws,
    Map<String, dynamic> node,
    OnToolLog log, {
    required String prefix,
  }) async {
    final name = (node['name'] as String?) ?? '';
    final type = (node['type'] as String?) ?? 'file';
    final rel = prefix.isEmpty ? name : '$prefix/$name';

    if (type == 'dir' || type == 'directory' || node['children'] is List) {
      if (name.isNotEmpty) {
        final dir = ws.resolveDir(rel);
        await dir.create(recursive: true);
        log('[nodeProjectBuilder] schema mkdir: $rel');
      }
      final children = (node['children'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      for (final child in children) {
        await _materializeSchema(ws, child, log, prefix: rel);
      }
    } else {
      final file = ws.resolve(rel);
      await file.parent.create(recursive: true);
      final content = (node['content'] as String?) ?? '';
      await file.writeAsString(content, flush: true);
      log('[nodeProjectBuilder] schema write file: $rel');
    }
  }

  Future<void> _scaffoldNodeExpressTsMinimal(
    _NodeWorkspace ws,
    String projectName,
    OnToolLog log,
  ) async {
    // package.json with modern dev tooling
    final pkg = ws.resolve('package.json');
    await pkg.parent.create(recursive: true);
    await pkg.writeAsString('''{
  "name": "$projectName",
  "version": "1.0.0",
  "main": "dist/index.js",
  "type": "module",
  "scripts": {
    "dev": "tsx watch src/index.ts",
    "build": "tsc",
    "start": "node dist/index.js",
    "test": "vitest",
    "test:run": "vitest run"
  },
  "dependencies": {
    "express": "^4.18.2"
  },
  "devDependencies": {
    "@types/express": "^4.17.17",
    "@types/node": "^20.0.0",
    "typescript": "^5.0.0",
    "tsx": "^4.0.0",
    "vitest": "^1.0.0"
  }
}
''');

    // tsconfig.json
    final tsconfig = ws.resolve('tsconfig.json');
    await tsconfig.writeAsString('''{
  "compilerOptions": {
    "target": "ES2020",
    "module": "ESNext",
    "rootDir": "src",
    "outDir": "dist",
    "esModuleInterop": true,
    "strict": true,
    "moduleResolution": "bundler",
    "resolveJsonModule": true,
    "skipLibCheck": true,
    "declaration": true,
    "declarationMap": true,
    "sourceMap": true
  },
  "include": ["src"]
}
''');

    // vitest config
    final vitestConfig = ws.resolve('vitest.config.ts');
    await vitestConfig.writeAsString('''import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    environment: 'node',
    globals: true,
  },
});
''');

    final srcDir = ws.resolveDir('src');
    await srcDir.create(recursive: true);

    final indexTs = ws.resolve('src/index.ts');
    await indexTs.writeAsString('''import express, { Request, Response } from 'express';

const app = express();
const port = process.env.PORT || 3000;

app.get('/', (req: Request, res: Response) => {
  res.send('Hello from $projectName (Express + TypeScript)!');
});

app.get('/health', (req: Request, res: Response) => {
  res.json({ status: 'ok' });
});

app.listen(port, () => {
  console.log(`Server listening on port \${port}`);
});
''');

    // Test example
    final testsDir = ws.resolveDir('src/__tests__');
    await testsDir.create(recursive: true);
    final healthTest = ws.resolve('src/__tests__/health.test.ts');
    await healthTest.writeAsString('''import { describe, it, expect } from 'vitest';

describe('Health', () => {
  it('should pass', () => {
    expect(true).toBe(true);
  });
});
''');

    // Basic README
    final readme = ws.resolve('README.md');
    await readme.writeAsString('''# $projectName

Express + TypeScript app with modern tooling (tsx, vitest).

## Scripts

- \`npm run dev\` - start dev server with tsx watch
- \`npm run build\` - compile TypeScript to JavaScript
- \`npm start\` - run compiled app
- \`npm test\` - run tests with vitest (watch mode)
- \`npm run test:run\` - run tests once

## Dev Tools

- **tsx**: Modern TypeScript executor for development
- **vitest**: Modern test runner
- **TypeScript**: Static type checking
''');

    // .gitignore
    final gitignore = ws.resolve('.gitignore');
    await gitignore.writeAsString('''node_modules/
dist/
build/
.env
.env.local
.DS_Store
*.log
.vitest/
''');

    log('[nodeProjectBuilder] scaffolded node_express_ts_minimal "$projectName"');
  }

  Future<void> _scaffoldNodeTsBasic(
    _NodeWorkspace ws,
    String projectName,
    OnToolLog log,
  ) async {
    final pkg = ws.resolve('package.json');
    await pkg.parent.create(recursive: true);
    await pkg.writeAsString('''{
  "name": "$projectName",
  "version": "1.0.0",
  "main": "dist/index.js",
  "type": "module",
  "scripts": {
    "dev": "tsx src/index.ts",
    "build": "tsc",
    "start": "node dist/index.js",
    "test": "vitest",
    "test:run": "vitest run"
  },
  "devDependencies": {
    "@types/node": "^20.0.0",
    "typescript": "^5.0.0",
    "tsx": "^4.0.0",
    "vitest": "^1.0.0"
  }
}
''');

    final tsconfig = ws.resolve('tsconfig.json');
    await tsconfig.writeAsString('''{
  "compilerOptions": {
    "target": "ES2020",
    "module": "ESNext",
    "rootDir": "src",
    "outDir": "dist",
    "strict": true,
    "esModuleInterop": true,
    "moduleResolution": "bundler",
    "resolveJsonModule": true,
    "skipLibCheck": true,
    "declaration": true,
    "sourceMap": true
  },
  "include": ["src"]
}
''');

    // vitest config
    final vitestConfig = ws.resolve('vitest.config.ts');
    await vitestConfig.writeAsString('''import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    environment: 'node',
    globals: true,
  },
});
''');

    final srcDir = ws.resolveDir('src');
    await srcDir.create(recursive: true);

    final indexTs = ws.resolve('src/index.ts');
    await indexTs.writeAsString('''function main() {
  const name = process.argv[2] ?? 'world';
  console.log(`Hello, \${name} from $projectName (TypeScript)!`);
}

main();
''');

    // Test example
    final testsDir = ws.resolveDir('src/__tests__');
    await testsDir.create(recursive: true);
    final basicTest = ws.resolve('src/__tests__/basic.test.ts');
    await basicTest.writeAsString('''import { describe, it, expect } from 'vitest';

describe('Basic', () => {
  it('should pass', () => {
    expect(1 + 1).toBe(2);
  });
});
''');

    final readme = ws.resolve('README.md');
    await readme.writeAsString('''# $projectName

Basic TypeScript app with modern tooling (tsx, vitest).

## Scripts

- \`npm run dev\` - run with tsx
- \`npm run build\` - compile TypeScript
- \`npm start\` - run compiled app
- \`npm test\` - run tests with vitest (watch mode)
- \`npm run test:run\` - run tests once

## Dev Tools

- **tsx**: Modern TypeScript executor
- **vitest**: Modern test runner
- **TypeScript**: Static type checking
''');

    // .gitignore
    final gitignore = ws.resolve('.gitignore');
    await gitignore.writeAsString('''node_modules/
dist/
build/
.env
.env.local
.DS_Store
*.log
.vitest/
''');

    log('[nodeProjectBuilder] scaffolded node_ts_basic "$projectName"');
  }

  Future<void> _scaffoldNodeJsCliBasic(
    _NodeWorkspace ws,
    String projectName,
    OnToolLog log,
  ) async {
    final pkg = ws.resolve('package.json');
    await pkg.parent.create(recursive: true);
    await pkg.writeAsString('''{
  "name": "$projectName",
  "version": "1.0.0",
  "type": "module",
  "bin": {
    "$projectName": "bin/cli.js"
  },
  "scripts": {
    "start": "node bin/cli.js",
    "test": "vitest",
    "test:run": "vitest run"
  },
  "devDependencies": {
    "vitest": "^1.0.0"
  }
}
''');

    // vitest config
    final vitestConfig = ws.resolve('vitest.config.ts');
    await vitestConfig.writeAsString('''import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    environment: 'node',
    globals: true,
  },
});
''');

    final binDir = ws.resolveDir('bin');
    await binDir.create(recursive: true);

    final cliJs = ws.resolve('bin/cli.js');
    await cliJs.writeAsString('''#!/usr/bin/env node

function main() {
  const args = process.argv.slice(2);
  const name = args[0] || 'world';
  console.log(`Hello, \${name} from $projectName (Node CLI)!`);
}

main();
''');

    // Test example
    final testsDir = ws.resolveDir('test');
    await testsDir.create(recursive: true);
    final cliTest = ws.resolve('test/cli.test.js');
    await cliTest.writeAsString('''import { describe, it, expect } from 'vitest';

describe('CLI', () => {
  it('should pass basic test', () => {
    expect(true).toBe(true);
  });
});
''');

    final readme = ws.resolve('README.md');
    await readme.writeAsString('''# $projectName

Simple Node.js CLI with modern tooling.

## Usage

- \`npm start -- <name>\` - run CLI via npm
- After global install: \`$projectName <name>\`

## Development

- \`npm test\` - run tests with vitest (watch mode)
- \`npm run test:run\` - run tests once

## Modern Setup

- **ES Modules** (type: "module")
- **vitest** for testing
''');

    // .gitignore
    final gitignore = ws.resolve('.gitignore');
    await gitignore.writeAsString('''node_modules/
.env
.env.local
.DS_Store
*.log
.vitest/
''');

    log('[nodeProjectBuilder] scaffolded node_js_cli_basic "$projectName"');
  }

  Future<void> _buildTree(
    _NodeWorkspace ws,
    Directory dir,
    StringBuffer buf, {
    required String prefix,
    required bool isRoot,
    required bool recursive,
  }) async {
    final entries = await dir
        .list(followLinks: false)
        .where((ent) => ws.relative(ent.path).isNotEmpty)
        .toList();
    entries.sort((a, b) => a.path.compareTo(b.path));

    if (isRoot) {
      buf.writeln('.');
    }

    for (var i = 0; i < entries.length; i++) {
      final ent = entries[i];
      final isLast = i == entries.length - 1;
      final name = p.basename(ent.path);
      final connector = isLast ? '└── ' : '├── ';
      buf.writeln('$prefix$connector$name');

      if (ent is Directory && recursive) {
        final childPrefix = prefix + (isLast ? '    ' : '│   ');
        await _buildTree(ws, ent, buf,
            prefix: childPrefix, isRoot: false, recursive: recursive);
      }
    }
  }

  Future<_ShellResult> _runShell(
    _NodeWorkspace ws,
    String command, {
    required int timeoutMs,
    required OnToolLog log,
  }) async {
    final proc = await Process.start(
      Platform.isWindows ? 'cmd' : 'bash',
      Platform.isWindows ? ['/C', command] : ['-lc', command],
      workingDirectory: ws.root.path,
      runInShell: true,
    );

    final stdoutFuture = proc.stdout.transform(utf8.decoder).join();
    final stderrFuture = proc.stderr.transform(utf8.decoder).join();

    final code = await proc.exitCode.timeout(
      Duration(milliseconds: timeoutMs),
      onTimeout: () {
        proc.kill(ProcessSignal.sigterm);
        return -1;
      },
    );

    final out = await stdoutFuture;
    final err = await stderrFuture;

    log('[nodeProjectBuilder] shell "$command" exitCode=$code');
    return _ShellResult(exitCode: code, stdout: out, stderr: err);
  }

  Future<String?> _guessDefaultRunCommand(
    _NodeWorkspace ws,
    OnToolLog log,
  ) async {
    final pkgFile = ws.resolve('package.json');
    if (pkgFile.existsSync()) {
      // Very lightweight heuristic: prefer "npm run dev" if package.json mentions it.
      try {
        final pkgStr = await pkgFile.readAsString();
        if (pkgStr.contains('"dev"')) {
          const cmd = 'npm run dev';
          log('[nodeProjectBuilder] default run command guessed: $cmd');
          return cmd;
        }
        if (pkgStr.contains('"start"')) {
          const cmd = 'npm start';
          log('[nodeProjectBuilder] default run command guessed: $cmd');
          return cmd;
        }
      } catch (_) {
        // ignore JSON parse issues and fall through
      }
    }

    // Fallback to simple node entry
    if (ws.resolve('index.js').existsSync()) {
      const cmd = 'node index.js';
      log('[nodeProjectBuilder] default run command guessed: $cmd');
      return cmd;
    }
    if (ws.resolve('src/index.ts').existsSync()) {
      const cmd = 'npx ts-node src/index.ts';
      log('[nodeProjectBuilder] default run command guessed: $cmd');
      return cmd;
    }
    return null;
  }
}

/// Workspace for nodeProjectBuilder
class _NodeWorkspace {
  final Directory root;
  _NodeWorkspace._(this.root);

  static _NodeWorkspace? _cur;

  static Future<_NodeWorkspace> ensure() async {
    if (_cur != null) return _cur!;
    final d = await Directory.systemTemp.createTemp('node_ws_');
    _cur = _NodeWorkspace._(d);
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
    final d = await Directory.systemTemp.createTemp('node_ws_');
    _cur = _NodeWorkspace._(d);
  }
}

/// Simple manager for a single Node dev server / app process.
class _NodeAppManager {
  _NodeAppManager._();

  static final _NodeAppManager instance = _NodeAppManager._();

  Process? _proc;
  Directory? _cwd;
  String? _command;

  _NodeAppStatus get status => _NodeAppStatus(
        isRunning: _proc != null,
        command: _command,
        cwd: _cwd?.path,
      );

  Future<_NodeAppStatus> startIfNeeded(
    Directory cwd,
    String command,
    OnToolLog log,
  ) async {
    if (_proc != null) {
      log('[nodeProjectBuilder] app already running (cmd=$_command)');
      return status;
    }

    log('[nodeProjectBuilder] starting app: "$command" in ${cwd.path}');
    final proc = await Process.start(
      Platform.isWindows ? 'cmd' : 'bash',
      Platform.isWindows ? ['/C', command] : ['-lc', command],
      workingDirectory: cwd.path,
      runInShell: true,
    );
    _proc = proc;
    _cwd = cwd;
    _command = command;

    proc.stdout.transform(utf8.decoder).listen(
      (data) => log('[nodeApp stdout] $data'),
      onError: (e) => log('[nodeApp stdout error] $e'),
    );
    proc.stderr.transform(utf8.decoder).listen(
      (data) => log('[nodeApp stderr] $data'),
      onError: (e) => log('[nodeApp stderr error] $e'),
    );

    proc.exitCode.then((code) {
      log('[nodeProjectBuilder] app process exited with code $code');
      _proc = null;
      _cwd = null;
      _command = null;
    });

    return status;
  }

  Future<bool> stop(OnToolLog log) async {
    final proc = _proc;
    if (proc == null) return false;
    log('[nodeProjectBuilder] stopping app (pid=${proc.pid})');
    proc.kill(ProcessSignal.sigterm);
    _proc = null;
    _cwd = null;
    _command = null;
    return true;
  }
}

class _NodeAppStatus {
  final bool isRunning;
  final String? command;
  final String? cwd;

  _NodeAppStatus({
    required this.isRunning,
    this.command,
    this.cwd,
  });

  String get statusText {
    if (!isRunning) return 'stopped';
    return 'running (cmd="$command", cwd="$cwd")';
  }
}