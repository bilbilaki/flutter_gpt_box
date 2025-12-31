import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'models.dart';

class ToolsHandler {
  final String rootPath;

  ToolsHandler(this.rootPath);

  // Define the JSON Schema for the AI
  List<Tool> getToolDefinitions() {
    return [
      Tool(function: {
        "name": "list_files",
        "description": "Returns a recursive list of all file paths in the workspace. Use this first to find where files are.",
        "parameters": {
          "type": "object",
          "properties": {}, // No params needed, scans root
        }
      }),
      Tool(function: {
        "name": "read_file",
        "description": "Reads a file and returns content with line numbers (e.g. '1 | code').",
        "parameters": {
          "type": "object",
          "properties": {"path": {"type": "string"}},
          "required": ["path"]
        }
      }),
      Tool(function: {
        "name": "patch_file",
        "description": "Edits a file using line-based patches. Syntax: 'N--' (delete), 'N++ content' (replace), '0++' (prepend), '00++' (append).",
        "parameters": {
          "type": "object",
          "properties": {
            "path": {"type": "string"},
            "patch": {"type": "string", "description": "The patch string e.g. '26++ new code'"}
          },
          "required": ["path", "patch"]
        }
      }),
    ];
  }

  Future<String> execute(String name, Map<String, dynamic> args) async {
    try {
      switch (name) {
        case "list_files":
          return await _listFiles();
        case "read_file":
          return await _readFileWithLines(args['path']);
        case "patch_file":
          return await _applyFilePatch(args['path'], args['patch']);
        default:
          return "Error: Unknown tool $name";
      }
    } catch (e) {
      return "Error executing $name: $e";
    }
  }

  // --- Implementations ---

  Future<String> _listFiles() async {
    final dir = Directory(rootPath);
    if (!await dir.exists()) return "Error: Workspace not found.";
    
    List<String> paths = [];
    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is File) {
        // Skip .git
        if (entity.path.contains(p.separator + '.git' + p.separator)) continue;
        
        // Return relative path for AI clarity
        String relative = p.relative(entity.path, from: rootPath);
        paths.add(relative);
      }
    }
    return paths.join("\n");
  }

  Future<String> _readFileWithLines(String relPath) async {
    final file = File(p.join(rootPath, relPath));
    if (!await file.exists()) return "Error: File $relPath does not exist.";
    
    final lines = await file.readAsLines();
    final buffer = StringBuffer();
    for (var i = 0; i < lines.length; i++) {
      buffer.writeln("${i + 1} | ${lines[i]}");
    }
    return buffer.toString();
  }

  // Exact port of your Go ApplyFilePatch logic
  Future<String> _applyFilePatch(String relPath, String patchContent) async {
    final file = File(p.join(rootPath, relPath));
    if (!await file.exists()) return "Error: File not found.";

    List<String> originalLines = await file.readAsLines();
    
    // Regex: (\d+|00) followed by (++|--) then optional content
    final re = RegExp(r'^(\d+|00)(\+\+|--)\s?(.*)$');
    
    // Map of Target -> Operation
    final Map<String, _Op> ops = {};

    final patchLines = const LineSplitter().convert(patchContent);
    for (var line in patchLines) {
      if (line.trim().isEmpty) continue;
      final match = re.firstMatch(line);
      if (match == null) continue;

      String target = match.group(1)!;
      String operator = match.group(2)!;
      String text = match.group(3) ?? "";

      ops[target] = _Op(operator == "--" ? "delete" : "replace", text);
    }

    List<String> newLines = [];

    // 0++ (Prepend)
    if (ops.containsKey("0") && ops["0"]!.type != "delete") {
      newLines.add(ops["0"]!.content);
    }

    // Process Original
    for (var i = 0; i < originalLines.length; i++) {
      String lineNum = (i + 1).toString();
      if (ops.containsKey(lineNum)) {
        if (ops[lineNum]!.type == "replace") {
          newLines.add(ops[lineNum]!.content);
        }
        // if delete, do nothing (skip)
      } else {
        newLines.add(originalLines[i]);
      }
    }

    // 00++ (Append)
    if (ops.containsKey("00") && ops["00"]!.type != "delete") {
      newLines.add(ops["00"]!.content);
    }

    // Write back
    String finalContent = newLines.join("\n");
    if (finalContent.isNotEmpty && !finalContent.endsWith("\n")) {
      finalContent += "\n";
    }
    await file.writeAsString(finalContent);

    return "Successfully patched $relPath.";
  }
}

class _Op {
  final String type;
  final String content;
  _Op(this.type, this.content);
}