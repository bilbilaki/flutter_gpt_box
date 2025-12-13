part of '../tool.dart';

/// Go project builder tool.
///
/// Similar to TfPythonProjectBuilder / TfWebBuilder, but focused on Go apps:
/// - Sandboxed workspace for Go code
/// - Project scaffolding (simple HTTP API or CLI) from:
///   - built-in templates, or
///   - a folder-tree schema + file contents
/// - File editor (write/read/list/mkdir/delete/tree)
/// - Project runner (go run / arbitrary go commands)
/// - Test runner (go test ./...)
/// - go env setup (go mod init, optional go get)
/// - Export & reset workflow
///
/// Safety:
/// - All paths are sandboxed under the workspace root and sanitized (no `..` traversal).
final class TfGoProjectBuilder extends ToolFunc {
  static const instance = TfGoProjectBuilder._();

  const TfGoProjectBuilder._()
    : super(
        name: 'goProjectBuilder',
        parametersSchema: const {
          'type': 'object',
          'properties': {
            'action': {
              'type': 'string',
              'description': '''
The operation to perform. Exactly one of:
- 'scaffoldProject'  : Initialize a new Go project in the workspace.
- 'setupModule'      : Initialize go.mod and optionally run "go get ./...".
- 'writeFile'        : Create or overwrite a file.
- 'readFile'         : Read a file's content.
- 'listDir'          : List files/directories.
- 'mkdirs'           : Create directories.
- 'deletePath'       : Delete a file or directory.
- 'showTree'         : Show directory tree structure.
- 'runCommand'       : Run an arbitrary shell / Go command in the project workspace.
- 'runApp'           : Convenience helper to run/stop/status the Go app (e.g. "go run .").
- 'runTests'         : Run tests (e.g. "go test ./...").
- 'exportProject'    : Export the workspace to a user folder and optionally zip.
- 'resetWorkspace'   : Wipe the workspace and start fresh (destructive).
''',
            },

            // Common file/dir params
            'relPath': {
              'type': 'string',
              'description':
                  'Relative path inside the workspace (e.g., "main.go", "cmd/api/main.go", "internal/handler/handler.go"). Used by writeFile/readFile/listDir/mkdirs/deletePath/showTree.',
            },
            'content': {
              'type': 'string',
              'description':
                  'File content for writeFile. UTF-8 text or base64 (see "encoding"). Use for Go code, configs, etc.',
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
- 'go_http_minimal' : Minimal Go HTTP server with net/http.
- 'go_api_clean'    : Slightly structured HTTP API (cmd/, internal/).
- 'go_cli_basic'    : Simple CLI tool with main.go and basic flags.
If omitted but "projectSchema" is provided, the schema is used instead of a built-in template.
''',
            },
            'moduleName': {
              'type': 'string',
              'description':
                  'Go module path to use for go.mod (e.g., "github.com/user/app"). If omitted, a simple name like "example.com/app" is used.',
            },

            /// Folder tree schema for custom project structure
            ///
            /// {
            ///   "name": "root",
            ///   "children": [
            ///     {"name": "main.go", "type": "file", "content": "..."},
            ///     {
            ///       "name": "cmd",
            ///       "type": "dir",
            ///       "children": [
            ///         {"name": "api", "type": "dir", "children": [...]}
            ///       ]
            ///     }
            ///   ]
            /// }
            'projectSchema': {
              'type': 'object',
              'description':
                  'Optional folder tree schema for scaffoldProject. If provided, overrides templateType for structure/content. See description for schema shape.',
            },

            // Go module setup
            'runGoGet': {
              'type': 'boolean',
              'description':
                  'For setupModule: if true, runs "go get ./..." after "go mod init" to fetch dependencies (may be slower). Default false.',
            },

            // Run / test actions
            'command': {
              'type': 'string',
              'description':
                  'For runCommand: the shell command to execute in the workspace (e.g., "go run .", "go build ./...", "go test ./...").',
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
                  'For runApp: whether to start, stop, or query status of the Go app helper.',
            },
            'appCommand': {
              'type': 'string',
              'description':
                  'Optional custom command for runApp "start" (e.g., "go run .", "go run ./cmd/api"). If omitted, a default is guessed based on scaffold.',
            },

            'testCommand': {
              'type': 'string',
              'description':
                  'Optional override for runTests (default "go test ./..."). Example: "go test ./internal/...".',
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
  String get l10nName => 'Go Project Builder';

  @override
  String get description => '''
Use this tool to design, scaffold, edit, run, and test **Go applications** inside a sandboxed workspace. It mirrors the Python/Flask builder, but specialized for Go:

You can:
- **Scaffold** Go HTTP APIs or CLI tools from a high-level folder tree schema or a template type.
- **Set up go.mod** and optionally run `go get ./...` to fetch dependencies.
- **Edit** files (create/overwrite, read, list, mkdir, delete).
- **Inspect** the project structure as a directory tree.
- **Run** Go commands (`go run`, `go build`, `go test`, arbitrary shell).
- **Run tests** (default `go test ./...`).
- **Export** the finished project and optionally zip it.
- **Reset** the workspace to start a new project.

All operations are sandboxed under an internal workspace directory. Relative paths are sanitized to avoid `..` traversal.

---

### Key Actions (One Per Call)

1. **'scaffoldProject'** – Initialize a new Go project
   - Use for: "Create a Go HTTP API", "Make a Go CLI", "Generate a Go project from this tree".
   - Parameters:
     - `templateType` *(optional)*: `"go_http_minimal"`, `"go_api_clean"`, `"go_cli_basic"`.
     - `moduleName` *(optional)*: go module path, used later by `setupModule`.
     - `projectSchema` *(optional)*: a folder tree schema. If present, overrides `templateType`.
   - Behavior:
     - Resets the workspace to a clean state.
     - If `projectSchema` is provided, recursively creates dirs/files as described.
     - Otherwise uses `templateType` to generate a reasonable starter:
       - `go_http_minimal`: `main.go` with net/http, simple routes.
       - `go_api_clean`: `cmd/api/main.go`, `internal/handlers`, etc.
       - `go_cli_basic`: `main.go` with basic flag parsing.

2. **'setupModule'** – Initialize go.mod and optionally fetch deps
   - Parameters:
     - `moduleName` *(optional)*: e.g. `"github.com/user/app"`. If omitted, a simple placeholder is derived from the workspace root name.
     - `runGoGet` *(optional)*: if true, runs `go get ./...` afterward.
   - Behavior:
     - Runs `go mod init <module>` in the workspace.
     - Optional `go get ./...` to download dependencies.

3. **'writeFile' / 'readFile' / 'listDir' / 'mkdirs' / 'deletePath' / 'showTree'**
   - Same semantics as the Python/Web builders:
     - `writeFile`: required `relPath`, `content`; optional `encoding`.
     - `readFile`: required `relPath`; optional `encoding`.
     - `listDir`: required `relPath`; optional `recursive`.
     - `mkdirs`: required `relPath`; optional `recursive` (default true).
     - `deletePath`: required `relPath`; optional `recursive` for directories.
     - `showTree`: optional `relPath` (default `"."`), optional `recursive` (default true).
   - Use these for iterative editing and inspection.

4. **'runCommand'** – Run any shell/Go command in the workspace
   - Parameters:
     - `command`: e.g. `"go run ."`, `"go build ./cmd/api"`, `"go test ./..."`.
     - `timeoutMs` *(optional)*: how long to wait for completion before killing (default ~5000ms).
   - Response includes exit code, stdout, and stderr.

5. **'runApp'** – Helper to start/stop/status the Go app
   - Parameters:
     - `appAction`: `"start"`, `"stop"`, `"status"`.
     - `appCommand` *(optional when starting)*: e.g. `"go run ."`, `"go run ./cmd/api"`.
   - Behavior:
     - Manages a single persistent process for the app within the workspace.
     - Logs stdout/stderr to the tool log.
     - Returns simple status text to the model.

6. **'runTests'** – Run tests
   - Parameters:
     - `testCommand` *(optional)*: e.g. `"go test ./internal/..."`.
   - Default behavior:
     - If `testCommand` is omitted, runs `"go test ./..."` from the workspace.

7. **'exportProject'** – Export to a user-visible folder + optional zip
   - Parameters:
     - `includeZip` *(optional)*: default true.
   - Behavior:
     - Uses the same export helpers as webbuilder (`GptBoxGoApps`-like folder).
     - Returns `exportDir` and `zipPath` (if created).

8. **'resetWorkspace'** – Wipe workspace
   - Destroys all files and re-creates a clean workspace under a temp directory.
   - Confirm with the user before using.

---

### Best Practices

- Plan structure/routes/CLI flags with the user, then **scaffold once**.
- Use `setupModule` after scaffolding to initialize `go.mod` properly.
- Use `runCommand` for one-shots (build, short test), and `runApp` for a long-running dev server.
- Prefer `runTests` over raw `runCommand` when the user just says "run the tests".
- Call `exportProject` before resetting if the project might be reused outside the app.
''';

  @override
  Future<_Ret?> run(_CallResp call, _Map args, OnToolLog log) async {
    final action = (args['action'] as String?)?.trim();
    if (action == null || action.isEmpty) {
      return [
        ChatContent.text("Error: 'action' is required for goProjectBuilder."),
      ];
    }

    try {
      final ws = await _GoWorkspace.ensure();
      log('[goProjectBuilder] workspaceRoot: ${ws.root.path}, action: $action');

      switch (action) {
        case 'scaffoldProject':
          return await _handleScaffold(ws, args, log);
        case 'setupModule':
          return await _handleSetupModule(ws, args, log);
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
      log('[goProjectBuilder] Error: $e\n$st');
      return [
        ChatContent.text(
          'goProjectBuilder error performing action "$action": $e\nworkspaceRoot: ${(_GoWorkspace._cur?.root.path ?? 'N/A')}',
        ),
      ];
    }
  }

  // === ACTION HANDLERS ===

  Future<_Ret?> _handleScaffold(
    _GoWorkspace ws,
    _Map args,
    OnToolLog log,
  ) async {
    final templateType = (args['templateType'] as String?)
        ?.trim()
        .toLowerCase();
    final moduleName = (args['moduleName'] as String?)?.trim();
    final schema = args['projectSchema'] as Map<String, dynamic>?;

    // Clean workspace
    await ws.reset();
    log('[goProjectBuilder] workspace reset before scaffold');

    if (schema != null) {
      await _materializeSchema(ws, schema, log, prefix: '');
      log('[goProjectBuilder] Scaffolded project from custom schema');
      return [
        ChatContent.text('scaffoldProject OK (custom projectSchema)'),
        ChatContent.text('workspaceRoot: ${ws.root.path}'),
      ];
    }

    switch (templateType) {
      case 'go_api_clean':
        await _scaffoldGoApiClean(ws, moduleName, log);
        break;
      case 'go_cli_basic':
        await _scaffoldGoCli(ws, moduleName, log);
        break;
      case 'go_http_minimal':
      default:
        await _scaffoldGoHttpMinimal(ws, moduleName, log);
        break;
    }

    return [
      ChatContent.text(
        'scaffoldProject OK (templateType: ${templateType ?? 'go_http_minimal'})',
      ),
      ChatContent.text('workspaceRoot: ${ws.root.path}'),
    ];
  }

  Future<_Ret?> _handleSetupModule(
    _GoWorkspace ws,
    _Map args,
    OnToolLog log,
  ) async {
    var moduleName = (args['moduleName'] as String?)?.trim();
    final runGoGet = args['runGoGet'] == true;

    if (moduleName == null || moduleName.isEmpty) {
      // fallback: simple placeholder from folder name
      moduleName = 'example.com/${p.basename(ws.root.path)}';
    }

    // go mod init
    log('[goProjectBuilder] setupModule: go mod init $moduleName');
    final initRes = await _runShell(
      ws,
      'go mod init $moduleName',
      timeoutMs: 10000,
      log: log,
    );

    if (initRes.exitCode != 0) {
      return [
        ChatContent.text('setupModule FAILED (go mod init)'),
        ChatContent.text('workspaceRoot: ${ws.root.path}'),
        ChatContent.text(initRes.toDisplayString()),
      ];
    }

    if (runGoGet) {
      log('[goProjectBuilder] setupModule: go get ./...');
      final getRes = await _runShell(
        ws,
        'go get ./...',
        timeoutMs: 60000,
        log: log,
      );
      return [
        ChatContent.text('setupModule OK (go mod init + go get ./...)'),
        ChatContent.text('workspaceRoot: ${ws.root.path}'),
        ChatContent.text(getRes.toDisplayString()),
      ];
    }

    return [
      ChatContent.text('setupModule OK (go mod init only)'),
      ChatContent.text('workspaceRoot: ${ws.root.path}'),
      ChatContent.text(initRes.toDisplayString()),
    ];
  }

  Future<_Ret?> _handleWriteFile(
    _GoWorkspace ws,
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

    log("[goProjectBuilder] writeFile: '$relPath' ($encoding) OK");
    return [
      ChatContent.text('writeFile OK'),
      ChatContent.text('path: ${file.path}'),
      ChatContent.text('workspaceRoot: ${ws.root.path}'),
    ];
  }

  Future<_Ret?> _handleReadFile(
    _GoWorkspace ws,
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

    log("[goProjectBuilder] readFile: '$relPath' ($encoding) OK");
    return [
      ChatContent.text('readFile OK'),
      ChatContent.text('workspaceRoot: ${ws.root.path}'),
      ChatContent.text(out),
    ];
  }

  Future<_Ret?> _handleListDir(
    _GoWorkspace ws,
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
    await for (final ent in dir.list(
      recursive: recursive,
      followLinks: false,
    )) {
      final rp = ws.relative(ent.path);
      if (rp.isNotEmpty) items.add(rp);
    }
    items.sort();

    log(
      "[goProjectBuilder] listDir: '$relPath' (recursive=$recursive) -> ${items.length} items",
    );
    return [
      ChatContent.text('listDir OK'),
      ChatContent.text('workspaceRoot: ${ws.root.path}'),
      ChatContent.text(items.join('\n')),
    ];
  }

  Future<_Ret?> _handleMkdirs(_GoWorkspace ws, _Map args, OnToolLog log) async {
    final relPath = _sanitizeRelPath(args['relPath'] as String?);
    final recursive = args['recursive'] != false;

    if (relPath == null || relPath.isEmpty) {
      return [ChatContent.text("Error: 'relPath' is required for mkdirs.")];
    }

    final dir = ws.resolveDir(relPath);
    await dir.create(recursive: recursive);
    log("[goProjectBuilder] mkdirs: '$relPath' (recursive=$recursive) OK");

    return [
      ChatContent.text('mkdirs OK'),
      ChatContent.text('path: ${dir.path}'),
      ChatContent.text('workspaceRoot: ${ws.root.path}'),
    ];
  }

  Future<_Ret?> _handleDeletePath(
    _GoWorkspace ws,
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
      log("[goProjectBuilder] deleteFile: '$relPath' OK");
    } else {
      final dir = ws.resolveDir(relPath);
      if (!dir.existsSync()) {
        return [ChatContent.text("Error: Path not found: '$relPath'")];
      }
      await dir.delete(recursive: recursive);
      log("[goProjectBuilder] deleteDir: '$relPath' (recursive=$recursive) OK");
    }

    return [
      ChatContent.text('deletePath OK'),
      ChatContent.text('workspaceRoot: ${ws.root.path}'),
    ];
  }

  Future<_Ret?> _handleShowTree(
    _GoWorkspace ws,
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
    await _buildTree(
      ws,
      dir,
      buf,
      prefix: '',
      isRoot: true,
      recursive: recursive,
    );
    final treeStr = buf.toString();
    log(
      "[goProjectBuilder] showTree for '$relPath' (recursive=$recursive)\n$treeStr",
    );

    return [
      ChatContent.text('showTree OK'),
      ChatContent.text('workspaceRoot: ${ws.root.path}'),
      ChatContent.text(treeStr),
    ];
  }

  Future<_Ret?> _handleRunCommand(
    _GoWorkspace ws,
    _Map args,
    OnToolLog log,
  ) async {
    final command = (args['command'] as String?)?.trim();
    if (command == null || command.isEmpty) {
      return [ChatContent.text("Error: 'command' is required for runCommand.")];
    }
    final timeoutMs = args['timeoutMs'] as int? ?? 5000;

    log("[goProjectBuilder] runCommand: '$command' (timeoutMs=$timeoutMs)");

    final res = await _runShell(ws, command, timeoutMs: timeoutMs, log: log);

    return [
      ChatContent.text('runCommand OK'),
      ChatContent.text('workspaceRoot: ${ws.root.path}'),
      ChatContent.text(res.toDisplayString()),
    ];
  }

  Future<_Ret?> _handleRunApp(_GoWorkspace ws, _Map args, OnToolLog log) async {
    final action = (args['appAction'] as String?)?.trim().toLowerCase();
    if (action == null || action.isEmpty) {
      return [ChatContent.text("Error: 'appAction' is required for runApp.")];
    }

    final appCommandRaw = (args['appCommand'] as String?)?.trim();
    final manager = _GoAppManager.instance;

    switch (action) {
      case 'start':
        final guessed = await _guessDefaultRunCommand(ws, log);
        final cmd = appCommandRaw ?? guessed ?? 'go run .';
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
    _GoWorkspace ws,
    _Map args,
    OnToolLog log,
  ) async {
    final explicit = (args['testCommand'] as String?)?.trim();
    if (explicit != null && explicit.isNotEmpty) {
      return _handleRunCommand(ws, {
        'command': explicit,
        'timeoutMs': args['timeoutMs'],
      }, log);
    }

    // Default
    final command = 'go test ./...';
    log('[goProjectBuilder] runTests default command: $command');
    return _handleRunCommand(ws, {
      'command': command,
      'timeoutMs': args['timeoutMs'],
    }, log);
  }

  Future<_Ret?> _handleExportProject(
    _GoWorkspace ws,
    _Map args,
    OnToolLog log,
  ) async {
    final includeZip = args['includeZip'] != false;

    final exportDir = await _Export.exportWorkspace(ws.root, log: log);

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

  Future<_Ret?> _handleResetWorkspace(_GoWorkspace ws, OnToolLog log) async {
    await ws.reset();
    log('[goProjectBuilder] workspace reset');
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
    _GoWorkspace ws,
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
        log('[goProjectBuilder] schema mkdir: $rel');
      }
      final children =
          (node['children'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      for (final child in children) {
        await _materializeSchema(ws, child, log, prefix: rel);
      }
    } else {
      final file = ws.resolve(rel);
      await file.parent.create(recursive: true);
      final content = (node['content'] as String?) ?? '';
      await file.writeAsString(content, flush: true);
      log('[goProjectBuilder] schema write file: $rel');
    }
  }

  Future<void> _scaffoldGoHttpMinimal(
    _GoWorkspace ws,
    String? moduleName,
    OnToolLog log,
  ) async {
    final mainGo = ws.resolve('main.go');
    await mainGo.parent.create(recursive: true);
    await mainGo.writeAsString('''
package main

import (
    "fmt"
    "log"
    "net/http"
)

func main() {
    mux := http.NewServeMux()

    mux.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
        fmt.Fprintln(w, "Hello from Go HTTP minimal app!")
    })

    mux.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
        w.Header().Set("Content-Type", "application/json")
        fmt.Fprint(w, `{"status":"ok"}`)
    })

    addr := ":8080"
    log.Printf("Starting server on %s...", addr)
    if err := http.ListenAndServe(addr, mux); err != nil {
        log.Fatalf("server error: %v", err)
    }
}
''');

    log('[goProjectBuilder] scaffolded go_http_minimal (module=$moduleName)');
  }

  Future<void> _scaffoldGoApiClean(
    _GoWorkspace ws,
    String? moduleName,
    OnToolLog log,
  ) async {
    final cmdApiDir = ws.resolveDir('cmd/api');
    await cmdApiDir.create(recursive: true);

    final mainGo = ws.resolve('cmd/api/main.go');
    await mainGo.writeAsString('''
package main

import (
    "log"
    "net/http"

    "${moduleName ?? "example.com/app"}/internal/handlers"
)

func main() {
    mux := http.NewServeMux()
    mux.HandleFunc("/", handlers.Home)
    mux.HandleFunc("/health", handlers.Health)

    addr := ":8080"
    log.Printf("Starting API on %s...", addr)
    if err := http.ListenAndServe(addr, mux); err != nil {
        log.Fatalf("server error: %v", err)
    }
}
''');

    final handlersDir = ws.resolveDir('internal/handlers');
    await handlersDir.create(recursive: true);

    final handlersGo = ws.resolve('internal/handlers/handlers.go');
    await handlersGo.writeAsString('''
package handlers

import (
    "fmt"
    "net/http"
)

func Home(w http.ResponseWriter, r *http.Request) {
    fmt.Fprintln(w, "Hello from Go clean API!")
}

func Health(w http.ResponseWriter, r *http.Request) {
    w.Header().Set("Content-Type", "application/json")
    fmt.Fprint(w, `{"status":"ok"}`)
}
''');

    log('[goProjectBuilder] scaffolded go_api_clean (module=$moduleName)');
  }

  Future<void> _scaffoldGoCli(
    _GoWorkspace ws,
    String? moduleName,
    OnToolLog log,
  ) async {
    final mainGo = ws.resolve('main.go');
    await mainGo.parent.create(recursive: true);
    await mainGo.writeAsString('''
package main

import (
    "flag"
    "fmt"
    "os"
)

func main() {
    name := flag.String("name", "world", "name to greet")
    flag.Parse()

    fmt.Fprintf(os.Stdout, "Hello, %s!\\n", *name)
}
''');

    log('[goProjectBuilder] scaffolded go_cli_basic (module=$moduleName)');
  }

  Future<void> _buildTree(
    _GoWorkspace ws,
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
        await _buildTree(
          ws,
          ent,
          buf,
          prefix: childPrefix,
          isRoot: false,
          recursive: recursive,
        );
      }
    }
  }

  Future<_ShellResult> _runShell(
    _GoWorkspace ws,
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

    log('[goProjectBuilder] shell "$command" exitCode=$code');
    return _ShellResult(exitCode: code, stdout: out, stderr: err);
  }

  Future<String?> _guessDefaultRunCommand(
    _GoWorkspace ws,
    OnToolLog log,
  ) async {
    // prefer cmd/api/main.go
    if (ws.resolve('cmd/api/main.go').existsSync()) {
      final cmd = 'go run ./cmd/api';
      log('[goProjectBuilder] default run command guessed: $cmd');
      return cmd;
    }
    if (ws.resolve('main.go').existsSync()) {
      const cmd = 'go run .';
      log('[goProjectBuilder] default run command guessed: $cmd');
      return cmd;
    }
    return null;
  }
}

/// Workspace for goProjectBuilder
class _GoWorkspace {
  final Directory root;
  _GoWorkspace._(this.root);

  static _GoWorkspace? _cur;

  static Future<_GoWorkspace> ensure() async {
    if (_cur != null) return _cur!;
    final d = await Directory.systemTemp.createTemp('go_ws_');
    _cur = _GoWorkspace._(d);
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
    final d = await Directory.systemTemp.createTemp('go_ws_');
    _cur = _GoWorkspace._(d);
  }
}

class _ShellResult {
  final int exitCode;
  final String stdout;
  final String stderr;

  _ShellResult({
    required this.exitCode,
    required this.stdout,
    required this.stderr,
  });

  String toDisplayString() {
    final buf = StringBuffer();
    buf.writeln('exitCode: $exitCode');
    if (stdout.trim().isNotEmpty) {
      buf.writeln('stdout:');
      buf.writeln(stdout);
    }
    if (stderr.trim().isNotEmpty) {
      buf.writeln('stderr:');
      buf.writeln(stderr);
    }
    return buf.toString();
  }
}

/// Simple manager for a single Go app process.
class _GoAppManager {
  _GoAppManager._();

  static final _GoAppManager instance = _GoAppManager._();

  Process? _proc;
  Directory? _cwd;
  String? _command;

  _GoAppStatus get status => _GoAppStatus(
    isRunning: _proc != null,
    command: _command,
    cwd: _cwd?.path,
  );

  Future<_GoAppStatus> startIfNeeded(
    Directory cwd,
    String command,
    OnToolLog log,
  ) async {
    if (_proc != null) {
      log('[goProjectBuilder] app already running (cmd=$_command)');
      return status;
    }

    log('[goProjectBuilder] starting app: "$command" in ${cwd.path}');
    final proc = await Process.start(
      Platform.isWindows ? 'cmd' : 'bash',
      Platform.isWindows ? ['/C', command] : ['-lc', command],
      workingDirectory: cwd.path,
      runInShell: true,
    );
    _proc = proc;
    _cwd = cwd;
    _command = command;

    proc.stdout
        .transform(utf8.decoder)
        .listen(
          (data) => log('[goApp stdout] $data'),
          onError: (e) => log('[goApp stdout error] $e'),
        );
    proc.stderr
        .transform(utf8.decoder)
        .listen(
          (data) => log('[goApp stderr] $data'),
          onError: (e) => log('[goApp stderr error] $e'),
        );

    proc.exitCode.then((code) {
      log('[goProjectBuilder] app process exited with code $code');
      _proc = null;
      _cwd = null;
      _command = null;
    });

    return status;
  }

  Future<bool> stop(OnToolLog log) async {
    final proc = _proc;
    if (proc == null) return false;
    log('[goProjectBuilder] stopping app (pid=${proc.pid})');
    proc.kill(ProcessSignal.sigterm);
    _proc = null;
    _cwd = null;
    _command = null;
    return true;
  }
}

class _GoAppStatus {
  final bool isRunning;
  final String? command;
  final String? cwd;

  _GoAppStatus({required this.isRunning, this.command, this.cwd});

  String get statusText {
    if (!isRunning) return 'stopped';
    return 'running (cmd="$command", cwd="$cwd")';
  }
}
