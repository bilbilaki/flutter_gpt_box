part of '../tool.dart';

/// Python / Flask project builder tool.
///
/// Similar in spirit to [TfWebBuilder] but specialized for Python projects:
/// - Sandboxed workspace for Python code
/// - Flask project scaffolding from either:
///   - built‑in template types, or
///   - an explicit folder tree schema + file contents
/// - File editor (write/read/list/mkdir/delete/tree)
/// - Project runner (generic Python commands) and Flask dev server helper
/// - Test runner (pytest / unittest)
/// - Export & reset workflow
///
/// Safety:
/// - All paths are sandboxed under the workspace root and sanitized (no `..` traversal).
final class TfPythonProjectBuilder extends ToolFunc {
  static const instance = TfPythonProjectBuilder._();

  const TfPythonProjectBuilder._()
      : super(
          name: 'pythonProjectBuilder',
          parametersSchema: const {
            'type': 'object',
            'properties': {
              'action': {
                'type': 'string',
                'description': '''
The operation to perform. Exactly one of:
- 'scaffoldProject'  : Initialize a new Python/Flask project in the workspace.
- 'writeFile'        : Create or overwrite a file.
- 'readFile'         : Read a file's content.
- 'listDir'          : List files/directories.
- 'mkdirs'           : Create directories.
- 'deletePath'       : Delete a file or directory.
- 'showTree'         : Show directory tree structure.
- 'runCommand'       : Run arbitrary shell / Python command in the project workspace.
- 'runServer'        : Start or stop a Flask dev server helper session.
- 'runTests'         : Run tests (pytest or unittest).
- 'setupVenv'        : Create a Python virtual environment (.venv).
- 'installDeps'      : Install dependencies from requirements.txt into the virtual environment.
- 'exportProject'    : Export the workspace to a user folder and optionally zip.
- 'resetWorkspace'   : Wipe the workspace and start fresh (destructive).
''',
              },

              // Common file/dir params
              'relPath': {
                'type': 'string',
                'description':
                    'Relative path inside the workspace (e.g., "app.py", "src/utils/helpers.py", "tests/"). Used by writeFile/readFile/listDir/mkdirs/deletePath.',
              },
              'content': {
                'type': 'string',
                'description':
                    'File content for writeFile. UTF‑8 text or base64 (see "encoding"). Use for code, configs, etc.',
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

              // Scaffold‑related
              'templateType': {
                'type': 'string',
                'description': '''
Template to use for scaffoldProject. Suggested values:
- 'flask_minimal'   : Minimal Flask app with app.py, requirements.txt, basic structure.
- 'flask_blueprint' : Flask app with blueprints package structure.
If omitted but "projectSchema" is provided, the schema is used instead of a built‑in template.
''',
              },
              'projectName': {
                'type': 'string',
                'description':
                    'Logical project name, used in scaffold template files (e.g., package name, README title). Optional; defaults to "my_flask_app".',
              },

              /// Folder tree schema to build a custom project structure
              /// when using 'scaffoldProject'. This mirrors common
              /// "tree like" representations:
              ///
              /// {
              ///   "name": "root",
              ///   "children": [
              ///     {"name": "app.py", "type": "file", "content": "..."},
              ///     {
              ///       "name": "templates",
              ///       "type": "dir",
              ///       "children": [
              ///         {"name": "index.html", "type": "file", "content": "..."}
              ///       ]
              ///     }
              ///   ]
              /// }
              'projectSchema': {
                'type': 'object',
                'description':
                    'Optional folder tree schema for scaffoldProject. If provided, overrides templateType for structure/content. See tool description for schema shape.',
              },

              // Run / test actions
              'command': {
                'type': 'string',
                'description':
                    'For runCommand: the shell command to execute in the workspace (e.g., "python app.py", "pytest", "python -m unittest").',
              },
              'timeoutMs': {
                'type': 'integer',
                'description':
                    'Optional timeout in milliseconds to wait for command output (default ~5000). Increase for long‑running tasks.',
              },

              'serverAction': {
                'type': 'string',
                'enum': ['start', 'stop', 'status'],
                'description':
                    'For runServer: whether to start, stop or query status of the Flask dev server helper.',
              },
              'serverCommand': {
                'type': 'string',
                'description':
                    'Optional custom command for runServer "start" (e.g., "python app.py" or "flask run"). If omitted, a default Flask command is chosen based on scaffold.',
              },

              'testCommand': {
                'type': 'string',
                'description':
                    'Optional override for runTests (default tries "pytest" then "python -m unittest"). Example: "pytest -q tests/".',
              },

              // Virtual environment
              'venvPath': {
                'type': 'string',
                'description':
                    'Optional path for virtual environment (default ".venv"). Used by setupVenv and installDeps.',
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
  String get l10nName => 'Python Project Builder';

  @override
  String get description => '''
Use this tool to design, scaffold, edit, run, and test **Python (Flask) projects** inside a sandboxed workspace. It is conceptually similar to the "webbuilder" tool, but focused on Python/Flask instead of generic web assets.

You can:
- **Scaffold** a Flask project from a high‑level folder tree schema or a simple template type.
- **Edit** files (create/overwrite, read, list, mkdir, delete).
- **Inspect** the project structure as a directory tree.
- **Run** Python commands (e.g., `python app.py`, `flask run`, `pytest`).
- **Run tests** using pytest/unittest.
- **Export** the finished project to a user‑visible folder (optionally zipping it).
- **Reset** the workspace to start a new project.

All operations are sandboxed under an internal workspace directory. Relative paths are sanitized to avoid `..` traversal.

---

### Actions (Use Exactly One Per Call)

1. **'scaffoldProject'** – Initialize a new Python/Flask project
   - Use when the user says things like:
     - "Create a Flask project", "Make a REST API with Flask", or
     - "Here is a folder tree, generate a Flask project from it".
   - Parameters:
     - `templateType` *(optional)*: e.g. `"flask_minimal"` or `"flask_blueprint"`.
     - `projectName` *(optional)*: e.g. `"my_api"`.
     - `projectSchema` *(optional)*: object describing the folder tree and file contents. If present, it overrides `templateType` for structure and contents.
   - Behavior:
     - Resets the workspace (clean slate).
     - If `projectSchema` provided, recursively creates dirs/files accordingly.
     - Otherwise uses `templateType` to generate a reasonable Flask starter:
       - `flask_minimal`: `app.py`, `requirements.txt`, `/templates/`, `/static/`, etc.
       - `flask_blueprint`: app package with `__init__.py`, `routes.py`, `templates`, `static`, `tests`, etc.
   - Recommended flow:
     - Ask the user for endpoints/features first.
     - Use `scaffoldProject` once, then refine using `writeFile`.

2. **'writeFile'** – Create or overwrite a file
   - Required: `relPath`, `content`.
   - Optional: `encoding` (default "utf8"; "base64" for binary).
   - Example: write a `routes.py`, `models.py`, or `config.py`.
   - Best practice:
     - Include full file content each time to avoid diff‑merge ambiguity.
     - Use consistent formatting (PEP‑8 for Python).

3. **'readFile'** – Read a file's content
   - Required: `relPath`.
   - Optional: `encoding` ("utf8" or "base64").
   - Use to inspect or verify generated files before editing.

4. **'listDir'** – List files/directories
   - Required: `relPath` (e.g., `"."`, `"app"`, `"tests"`).
   - Optional: `recursive` (default `false`).
   - Returns a newline‑separated list of relative paths.

5. **'mkdirs'** – Create directories
   - Required: `relPath`.
   - Optional: `recursive` (default `true`).
   - Use to add new packages/modules (`"services/"`, `"blueprints/api/"`, etc).

6. **'deletePath'** – Delete a file or directory
   - Required: `relPath`.
   - Optional: `recursive` for directories (default `false`).
   - Always confirm with the user first; deletion is permanent.

7. **'showTree'** – Show directory tree
   - Optional: `relPath` (defaults to `"."`).
   - Optional: `recursive` (default `true`).
   - Output is a human‑readable tree suitable for reasoning about project structure.

8. **'runCommand'** – Run an arbitrary command in the workspace
   - Required: `command` (e.g., `"python app.py"`, `"pytest"`, `"python -m unittest"`).
   - Optional: `timeoutMs` (default ~5000).
   - Intended for one‑shot commands. For long‑lived sessions, prefer `runServer`.

9. **'runServer'** – Convenience helper for Flask dev server
   - Parameters:
     - `serverAction`: `"start"`, `"stop"`, or `"status"`.
     - `serverCommand` *(optional when starting)*: e.g. `"python app.py"` or `"flask run --host=0.0.0.0 --port=5000"`.
   - Behavior:
     - Uses an internal persistent session (via a terminal manager) bound to this workspace.
     - `"start"`: launches the server if not already running and returns basic output / PID info.
     - `"status"`: returns whether a server is running and last known info.
     - `"stop"`: attempts to terminate the running server process.

10. **'runTests'** – Run project tests
    - Optional: `testCommand` (e.g. `"pytest -q"`, `"python -m unittest"`).
    - If omitted, tool tries:
      1. `"pytest"` if a `tests/` folder or `pytest.ini` is present.
      2. Else `"python -m unittest"`.

11. **'setupVenv'** – Create a Python virtual environment
    - Optional: `venvPath` (default `".venv"`).
    - Behavior:
      - Runs `python -m venv <venvPath>` in the workspace.
      - Creates a fresh virtual environment for isolated dependency management.
      - Recommended before installing dependencies.

12. **'installDeps'** – Install dependencies from requirements.txt
    - Optional: `venvPath` (default `".venv"`).
    - Behavior:
      - Activates the virtual environment at `venvPath`.
      - Runs `pip install -r requirements.txt` to install project dependencies.
      - Requires `setupVenv` to be run first and `requirements.txt` to exist.

13. **'exportProject'** – Export the workspace to a user‑visible folder
    - Optional: `includeZip` (default `true`).
    - Behavior:
      - Copies workspace to a durable folder under something like `"GptBoxPythonApps"`.
      - Optionally creates a ZIP archive beside it.
      - Returns export path and ZIP path (if created).

14. **'resetWorkspace'** – Wipe workspace
    - No extra parameters.
    - Deletes all files in this tool's sandbox and starts fresh.
    - Confirm with user before using.

---

### Best Practices

- **One action per call**: Do not mix operations; chain multiple calls if needed.
- **Clarify project design first**: Before scaffolding, ask for routes, models, and folder preferences or a tree schema.
- **Prefer schema for complex structures**: Use `projectSchema` when the user provides or accepts a declarative tree; it makes the project easy to regenerate deterministically.
- **Avoid dangerous commands**: For `runCommand` / `runServer`, avoid destructive shell operations; focus on Python/Flask/test commands.
- **Export before reset**: If the project is important, use `exportProject` before `resetWorkspace`.
''';

  @override
  Future<_Ret?> run(_CallResp call, _Map args, OnToolLog log) async {
    final action = (args['action'] as String?)?.trim();
    if (action == null || action.isEmpty) {
      return [ChatContent.text("Error: 'action' is required for pythonProjectBuilder.")];
    }

    try {
      final ws = await _PyWorkspace.ensure();
      log('[pythonProjectBuilder] workspaceRoot: ${ws.root.path}, action: $action');

      switch (action) {
        case 'scaffoldProject':
          return await _handleScaffold(ws, args, log);

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

        case 'runServer':
          return await _handleRunServer(ws, args, log);

        case 'runTests':
          return await _handleRunTests(ws, args, log);

        case 'setupVenv':
          return await _handleSetupVenv(ws, args, log);

        case 'installDeps':
          return await _handleInstallDeps(ws, args, log);

        case 'exportProject':
          return await _handleExportProject(ws, args, log);

        case 'resetWorkspace':
          return await _handleResetWorkspace(ws, log);

        default:
          return [ChatContent.text("Error: Unknown action '$action'.")];
      }
    } catch (e, st) {
      log('[pythonProjectBuilder] Error: $e\n$st');
      return [
        ChatContent.text(
          'pythonProjectBuilder error performing action "$action": $e\nworkspaceRoot: ${(_PyWorkspace._cur?.root.path ?? 'N/A')}',
        ),
      ];
    }
  }

  // === ACTION HANDLERS ===

  Future<_Ret?> _handleScaffold(
    _PyWorkspace ws,
    _Map args,
    OnToolLog log,
  ) async {
    final templateType = (args['templateType'] as String?)?.trim().toLowerCase();
    final projectName = (args['projectName'] as String?)?.trim().isNotEmpty == true
        ? (args['projectName'] as String).trim()
        : 'my_flask_app';
    final schema = args['projectSchema'] as Map<String, dynamic>?;

    // Reset workspace first for clean project
    await ws.reset();
    log('[pythonProjectBuilder] workspace reset before scaffold');

    if (schema != null) {
      await _materializeSchema(ws, schema, log, prefix: '');
      log('[pythonProjectBuilder] Scaffolded project from custom schema');
      return [
        ChatContent.text('scaffoldProject OK (custom projectSchema)'),
        ChatContent.text('workspaceRoot: ${ws.root.path}'),
      ];
    }

    // Fallback to built‑in templates
    switch (templateType) {
      case 'flask_blueprint':
        await _scaffoldFlaskBlueprint(ws, projectName, log);
        break;
      case 'flask_minimal':
      default:
        await _scaffoldFlaskMinimal(ws, projectName, log);
        break;
    }

    return [
      ChatContent.text('scaffoldProject OK (templateType: ${templateType ?? 'flask_minimal'})'),
      ChatContent.text('workspaceRoot: ${ws.root.path}'),
    ];
  }

  Future<_Ret?> _handleWriteFile(
    _PyWorkspace ws,
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

    log("[pythonProjectBuilder] writeFile: '$relPath' ($encoding) OK");
    return [
      ChatContent.text('writeFile OK'),
      ChatContent.text('path: ${file.path}'),
      ChatContent.text('workspaceRoot: ${ws.root.path}'),
    ];
  }

  Future<_Ret?> _handleReadFile(
    _PyWorkspace ws,
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
    log("[pythonProjectBuilder] readFile: '$relPath' ($encoding) OK");
    return [
      ChatContent.text('readFile OK'),
      ChatContent.text('workspaceRoot: ${ws.root.path}'),
      ChatContent.text(out),
    ];
  }

  Future<_Ret?> _handleListDir(
    _PyWorkspace ws,
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
    log("[pythonProjectBuilder] listDir: '$relPath' (recursive=$recursive) -> ${items.length} items");
    return [
      ChatContent.text('listDir OK'),
      ChatContent.text('workspaceRoot: ${ws.root.path}'),
      ChatContent.text(items.join('\n')),
    ];
  }

  Future<_Ret?> _handleMkdirs(
    _PyWorkspace ws,
    _Map args,
    OnToolLog log,
  ) async {
    final relPath = _sanitizeRelPath(args['relPath'] as String?);
    final recursive = args['recursive'] != false; // default true
    if (relPath == null || relPath.isEmpty) {
      return [ChatContent.text("Error: 'relPath' is required for mkdirs.")];
    }
    final dir = ws.resolveDir(relPath);
    await dir.create(recursive: recursive);
    log("[pythonProjectBuilder] mkdirs: '$relPath' (recursive=$recursive) OK");
    return [
      ChatContent.text('mkdirs OK'),
      ChatContent.text('path: ${dir.path}'),
      ChatContent.text('workspaceRoot: ${ws.root.path}'),
    ];
  }

  Future<_Ret?> _handleDeletePath(
    _PyWorkspace ws,
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
      log("[pythonProjectBuilder] deleteFile: '$relPath' OK");
    } else {
      final dir = ws.resolveDir(relPath);
      if (!dir.existsSync()) {
        return [ChatContent.text("Error: Path not found: '$relPath'")];
      }
      await dir.delete(recursive: recursive);
      log("[pythonProjectBuilder] deleteDir: '$relPath' (recursive=$recursive) OK");
    }

    return [
      ChatContent.text('deletePath OK'),
      ChatContent.text('workspaceRoot: ${ws.root.path}'),
    ];
  }

  Future<_Ret?> _handleShowTree(
    _PyWorkspace ws,
    _Map args,
    OnToolLog log,
  ) async {
    final relPath = _sanitizeRelPath(args['relPath'] as String? ?? '.');
    final recursive = args['recursive'] != false; // default true
    final dir = ws.resolveDir(relPath!);
    if (!dir.existsSync()) {
      return [ChatContent.text("Error: Directory not found: '$relPath'")];
    }

    final buffer = StringBuffer();
    await _buildTree(ws, dir, buffer, prefix: '', isRoot: true, recursive: recursive);
    final treeStr = buffer.toString();
    log("[pythonProjectBuilder] showTree for '$relPath' (recursive=$recursive)\n$treeStr");
    return [
      ChatContent.text('showTree OK'),
      ChatContent.text('workspaceRoot: ${ws.root.path}'),
      ChatContent.text(treeStr),
    ];
  }

  Future<_Ret?> _handleRunCommand(
    _PyWorkspace ws,
    _Map args,
    OnToolLog log,
  ) async {
    final command = (args['command'] as String?)?.trim();
    if (command == null || command.isEmpty) {
      return [ChatContent.text("Error: 'command' is required for runCommand.")];
    }
    final timeoutMs = args['timeoutMs'] as int? ?? 5000;

    log("[pythonProjectBuilder] runCommand: '$command' (timeoutMs=$timeoutMs)");

    final proc = await Process.start(
      Platform.isWindows ? 'cmd' : 'bash',
      Platform.isWindows ? ['/C', command] : ['-lc', command],
      workingDirectory: ws.root.path,
      runInShell: true,
    );

    final stdoutFuture = proc.stdout.transform(utf8.decoder).join();
    final stderrFuture = proc.stderr.transform(utf8.decoder).join();

    // Simple timeout handling
    final exitCode = await proc.exitCode.timeout(
      Duration(milliseconds: timeoutMs),
      onTimeout: () {
        proc.kill(ProcessSignal.sigterm);
        return -1;
      },
    );

    final out = await stdoutFuture;
    final err = await stderrFuture;

    final result = StringBuffer();
    result.writeln('exitCode: $exitCode');
    if (out.trim().isNotEmpty) {
      result.writeln('stdout:\n$out');
    }
    if (err.trim().isNotEmpty) {
      result.writeln('stderr:\n$err');
    }

    log("[pythonProjectBuilder] runCommand done (exitCode=$exitCode)");
    return [
      ChatContent.text('runCommand OK'),
      ChatContent.text('workspaceRoot: ${ws.root.path}'),
      ChatContent.text(result.toString()),
    ];
  }

  Future<_Ret?> _handleRunServer(
    _PyWorkspace ws,
    _Map args,
    OnToolLog log,
  ) async {
    final action = (args['serverAction'] as String?)?.trim().toLowerCase();
    if (action == null || action.isEmpty) {
      return [ChatContent.text("Error: 'serverAction' is required for runServer.")];
    }

    final serverCommandRaw = (args['serverCommand'] as String?)?.trim();
    final server = _PyServerManager.instance;

    switch (action) {
      case 'start':
        final cmd = serverCommandRaw ??
            await _guessDefaultServerCommand(ws, log) ??
            'python app.py';
        final info = await server.startIfNeeded(ws.root, cmd, log);
        return [
          ChatContent.text('runServer start OK'),
          ChatContent.text('workspaceRoot: ${ws.root.path}'),
          ChatContent.text('command: $cmd'),
          ChatContent.text('status: ${info.statusText}'),
        ];

      case 'status':
        final info = server.status;
        return [
          ChatContent.text('runServer status'),
          ChatContent.text('workspaceRoot: ${ws.root.path}'),
          ChatContent.text('status: ${info.statusText}'),
        ];

      case 'stop':
        final stopped = await server.stop(log);
        return [
          ChatContent.text('runServer stop ${stopped ? "OK" : "no running server"}'),
          ChatContent.text('workspaceRoot: ${ws.root.path}'),
        ];

      default:
        return [ChatContent.text("Error: Unknown serverAction '$action'.")];
    }
  }

  Future<_Ret?> _handleRunTests(
    _PyWorkspace ws,
    _Map args,
    OnToolLog log,
  ) async {
    final explicit = (args['testCommand'] as String?)?.trim();
    if (explicit != null && explicit.isNotEmpty) {
      // Just run that command
      return _handleRunCommand(ws, {'command': explicit, 'timeoutMs': args['timeoutMs']}, log);
    }

    // Heuristic: prefer pytest if tests folder or pytest.ini exists
    final hasTestsDir = ws.resolveDir('tests').existsSync();
    final hasPytestIni = ws.resolve('pytest.ini').existsSync();
    final command = (hasTestsDir || hasPytestIni) ? 'pytest' : 'python -m unittest';

    log('[pythonProjectBuilder] runTests auto command: $command');
    return _handleRunCommand(ws, {'command': command, 'timeoutMs': args['timeoutMs']}, log);
  }

  Future<_Ret?> _handleSetupVenv(
    _PyWorkspace ws,
    _Map args,
    OnToolLog log,
  ) async {
    final venvPath = (args['venvPath'] as String?)?.trim() ?? '.venv';
    final sanitized = _sanitizeRelPath(venvPath);
    if (sanitized == null || sanitized.isEmpty) {
      return [ChatContent.text("Error: Invalid venvPath.")];
    }

    final venvDir = ws.resolveDir(sanitized);
    if (venvDir.existsSync()) {
      return [ChatContent.text("Error: Virtual environment already exists at '$sanitized'. Delete it first or use a different path.")];
    }

    final command = 'python -m venv $sanitized';
    log('[pythonProjectBuilder] setupVenv: $command');

    final proc = await Process.start(
      Platform.isWindows ? 'cmd' : 'bash',
      Platform.isWindows ? ['/C', command] : ['-lc', command],
      workingDirectory: ws.root.path,
      runInShell: true,
    );

    final stdoutFuture = proc.stdout.transform(utf8.decoder).join();
    final stderrFuture = proc.stderr.transform(utf8.decoder).join();
    final exitCode = await proc.exitCode;
    final out = await stdoutFuture;
    final err = await stderrFuture;

    if (exitCode != 0) {
      log('[pythonProjectBuilder] setupVenv failed (exitCode=$exitCode)');
      return [
        ChatContent.text('setupVenv FAILED'),
        ChatContent.text('workspaceRoot: ${ws.root.path}'),
        ChatContent.text('exitCode: $exitCode'),
        if (err.trim().isNotEmpty) ChatContent.text('stderr:\n$err'),
      ];
    }

    log('[pythonProjectBuilder] setupVenv OK');
    return [
      ChatContent.text('setupVenv OK'),
      ChatContent.text('workspaceRoot: ${ws.root.path}'),
      ChatContent.text('venvPath: $sanitized'),
      if (out.trim().isNotEmpty) ChatContent.text('output:\n$out'),
    ];
  }

  Future<_Ret?> _handleInstallDeps(
    _PyWorkspace ws,
    _Map args,
    OnToolLog log,
  ) async {
    final venvPath = (args['venvPath'] as String?)?.trim() ?? '.venv';
    final sanitized = _sanitizeRelPath(venvPath);
    if (sanitized == null || sanitized.isEmpty) {
      return [ChatContent.text("Error: Invalid venvPath.")];
    }

    final venvDir = ws.resolveDir(sanitized);
    if (!venvDir.existsSync()) {
      return [ChatContent.text("Error: Virtual environment not found at '$sanitized'. Run setupVenv first.")];
    }

    final requirementsFile = ws.resolve('requirements.txt');
    if (!requirementsFile.existsSync()) {
      return [ChatContent.text("Error: requirements.txt not found in workspace.")];
    }

    // Construct activation + pip install command
    final String command;
    if (Platform.isWindows) {
      command = '$sanitized\\Scripts\\activate.bat && pip install -r requirements.txt';
    } else {
      command = 'source $sanitized/bin/activate && pip install -r requirements.txt';
    }

    log('[pythonProjectBuilder] installDeps: $command');

    final proc = await Process.start(
      Platform.isWindows ? 'cmd' : 'bash',
      Platform.isWindows ? ['/C', command] : ['-lc', command],
      workingDirectory: ws.root.path,
      runInShell: true,
    );

    final stdoutFuture = proc.stdout.transform(utf8.decoder).join();
    final stderrFuture = proc.stderr.transform(utf8.decoder).join();
    final exitCode = await proc.exitCode;
    final out = await stdoutFuture;
    final err = await stderrFuture;

    if (exitCode != 0) {
      log('[pythonProjectBuilder] installDeps failed (exitCode=$exitCode)');
      return [
        ChatContent.text('installDeps FAILED'),
        ChatContent.text('workspaceRoot: ${ws.root.path}'),
        ChatContent.text('exitCode: $exitCode'),
        if (err.trim().isNotEmpty) ChatContent.text('stderr:\n$err'),
      ];
    }

    log('[pythonProjectBuilder] installDeps OK');
    return [
      ChatContent.text('installDeps OK'),
      ChatContent.text('workspaceRoot: ${ws.root.path}'),
      ChatContent.text('venvPath: $sanitized'),
      if (out.trim().isNotEmpty) ChatContent.text('output:\n$out'),
    ];
  }

  Future<_Ret?> _handleExportProject(
    _PyWorkspace ws,
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
    _PyWorkspace ws,
    OnToolLog log,
  ) async {
    await ws.reset();
    log('[pythonProjectBuilder] workspace reset');
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
      s = s.split('/').where((seg) => seg != '..' && seg.isNotEmpty).join('/');
    }
    return s.trim();
  }

  Future<void> _materializeSchema(
    _PyWorkspace ws,
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
        log('[pythonProjectBuilder] schema mkdir: $rel');
      }
      final children = (node['children'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      for (final child in children) {
        await _materializeSchema(ws, child, log, prefix: rel);
      }
    } else {
      // file node
      final file = ws.resolve(rel);
      await file.parent.create(recursive: true);
      final content = (node['content'] as String?) ?? '';
      await file.writeAsString(content, flush: true);
      log('[pythonProjectBuilder] schema write file: $rel');
    }
  }

  Future<void> _scaffoldFlaskMinimal(
    _PyWorkspace ws,
    String projectName,
    OnToolLog log,
  ) async {
    final appPy = ws.resolve('app.py');
    await appPy.parent.create(recursive: true);
    await appPy.writeAsString('''
from flask import Flask, jsonify

app = Flask(__name__)

@app.route("/")
def index():
    return "Hello from $projectName!"

@app.route("/health")
def health():
    return jsonify(status="ok")

if __name__ == "__main__":
    app.run(debug=True)
''');

    final req = ws.resolve('requirements.txt');
    await req.writeAsString('''
flask>=2.0.0
''');

    final templateDir = ws.resolveDir('templates');
    await templateDir.create(recursive: true);
    final indexHtml = ws.resolve('templates/index.html');
    await indexHtml.writeAsString('''
<!doctype html>
<html>
  <head><title>$projectName</title></head>
  <body>
    <h1>Hello from $projectName</h1>
  </body>
</html>
''');

    final staticDir = ws.resolveDir('static');
    await staticDir.create(recursive: true);

    log('[pythonProjectBuilder] scaffolded flask_minimal project "$projectName"');
  }

  Future<void> _scaffoldFlaskBlueprint(
    _PyWorkspace ws,
    String projectName,
    OnToolLog log,
  ) async {
    final pkgDir = ws.resolveDir(projectName);
    await pkgDir.create(recursive: true);

    final initPy = ws.resolve('$projectName/__init__.py');
    await initPy.writeAsString('''
from flask import Flask
from .routes import bp as main_bp

def create_app():
    app = Flask(__name__)
    app.register_blueprint(main_bp)
    return app
''');

    final routesPy = ws.resolve('$projectName/routes.py');
    await routesPy.writeAsString('''
from flask import Blueprint, jsonify

bp = Blueprint("main", __name__)

@bp.route("/")
def index():
    return "Hello from $projectName (blueprint)!"

@bp.route("/health")
def health():
    return jsonify(status="ok")
''');

    final wsgiPy = ws.resolve('wsgi.py');
    await wsgiPy.writeAsString('''
from $projectName import create_app

app = create_app()

if __name__ == "__main__":
    app.run(debug=True)
''');

    final req = ws.resolve('requirements.txt');
    await req.writeAsString('''
flask>=2.0.0
''');

    final templatesDir = ws.resolveDir('$projectName/templates');
    await templatesDir.create(recursive: true);
    final indexHtml = ws.resolve('$projectName/templates/index.html');
    await indexHtml.writeAsString('''
<!doctype html>
<html>
  <head><title>$projectName Blueprint App</title></head>
  <body>
    <h1>Hello from $projectName (blueprint)</h1>
  </body>
</html>
''');

    final testsDir = ws.resolveDir('tests');
    await testsDir.create(recursive: true);
    final testBasic = ws.resolve('tests/test_basic.py');
    await testBasic.writeAsString('''
from $projectName import create_app

def test_health():
    app = create_app()
    client = app.test_client()
    resp = client.get("/health")
    assert resp.status_code == 200
''');

    log('[pythonProjectBuilder] scaffolded flask_blueprint project "$projectName"');
  }

  Future<void> _buildTree(
    _PyWorkspace ws,
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

  Future<String?> _guessDefaultServerCommand(
    _PyWorkspace ws,
    OnToolLog log,
  ) async {
    final appPy = ws.resolve('app.py');
    if (appPy.existsSync()) {
      log('[pythonProjectBuilder] default server command guessed: python app.py');
      return 'python app.py';
    }
    final wsgiPy = ws.resolve('wsgi.py');
    if (wsgiPy.existsSync()) {
      log('[pythonProjectBuilder] default server command guessed: python wsgi.py');
      return 'python wsgi.py';
    }
    return null;
  }
}

/// Workspace for pythonProjectBuilder
class _PyWorkspace {
  final Directory root;
  _PyWorkspace._(this.root);

  static _PyWorkspace? _cur;

  static Future<_PyWorkspace> ensure() async {
    if (_cur != null) return _cur!;
    final d = await Directory.systemTemp.createTemp('py_ws_');
    _cur = _PyWorkspace._(d);
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
    final d = await Directory.systemTemp.createTemp('py_ws_');
    _cur = _PyWorkspace._(d);
  }
}

/// Simple manager for a single Flask dev server process per app session.
class _PyServerManager {
  _PyServerManager._();

  static final _PyServerManager instance = _PyServerManager._();

  Process? _proc;
  Directory? _cwd;
  String? _command;

  _ServerStatus get status => _ServerStatus(
        isRunning: _proc != null,
        command: _command,
        cwd: _cwd?.path,
      );

  Future<_ServerStatus> startIfNeeded(
    Directory cwd,
    String command,
    OnToolLog log,
  ) async {
    if (_proc != null) {
      log('[pythonProjectBuilder] server already running (cmd=$_command)');
      return status;
    }

    log('[pythonProjectBuilder] starting server: "$command" in ${cwd.path}');
    final proc = await Process.start(
      Platform.isWindows ? 'cmd' : 'bash',
      Platform.isWindows ? ['/C', command] : ['-lc', command],
      workingDirectory: cwd.path,
      runInShell: true,
    );
    _proc = proc;
    _cwd = cwd;
    _command = command;

    // Consume stdout/stderr to avoid blocking; log lightweight lines.
    proc.stdout.transform(utf8.decoder).listen(
      (data) => log('[pyServer stdout] $data'),
      onError: (e) => log('[pyServer stdout error] $e'),
    );
    proc.stderr.transform(utf8.decoder).listen(
      (data) => log('[pyServer stderr] $data'),
      onError: (e) => log('[pyServer stderr error] $e'),
    );

    proc.exitCode.then((code) {
      log('[pythonProjectBuilder] server process exited with code $code');
      _proc = null;
      _cwd = null;
      _command = null;
    });

    return status;
  }

  Future<bool> stop(OnToolLog log) async {
    final proc = _proc;
    if (proc == null) return false;
    log('[pythonProjectBuilder] stopping server (pid=${proc.pid})');
    proc.kill(ProcessSignal.sigterm);
    _proc = null;
    _cwd = null;
    _command = null;
    return true;
  }
}

class _ServerStatus {
  final bool isRunning;
  final String? command;
  final String? cwd;

  _ServerStatus({
    required this.isRunning,
    this.command,
    this.cwd,
  });

  String get statusText {
    if (!isRunning) return 'stopped';
    return 'running (cmd="$command", cwd="$cwd")';
  }
}