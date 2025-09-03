// lib/src/tool/func/terminal.dart
part of '../tool.dart';

final class TfTerminal extends ToolFunc {
  static const instance = TfTerminal._();
  const TfTerminal._()
    : super(
        name: 'terminal',
        parametersSchema: const {
          'type': 'object',
          'properties': {
            'command': {
              'type': 'string',
              'description': 'The command to execute (required).',
            },
            'args': {
              'type': 'array',
              'items': {'type': 'string'},
              'description': 'Arguments list for the command.',
            },
            'cwd': {
              'type': 'string',
              'description': 'Working directory for the command.',
            },
            'useShell': {
              'type': 'boolean',
              'description':
                  'Run command in shell. Useful for builtin shell commands.',
            },
            'truncateSize': {
              'type': 'integer',
              'description':
                  'If user wants to save tokens, set it to the max size of the combined output returned.',
            },
          },
          'required': ['command'],
        },
      );

  @override
  String get description => '''
Execute a shell command and stream live output back via tool logs.
Only call this function if the user explicitly asks to run terminal commands.
The command output will be returned as the final tool result as well.''';

  @override
  String get l10nName => "terminal";

  String _terminalHelpFallback(String? command) =>
      command == null || command.isEmpty
      ? 'Execute a shell command'
      : 'Execute the shell command: $command';

  // And update the help(...) override to use the fallback if needed:
  @override
  String help(_CallResp call, _Map args) {
    final cmd = args['command'] as String?;
    // Use l10n.terminalHelp if present, otherwise fallback
    try {
      return L10n().terminalHelp(cmd ?? '<?>');
    } catch (_) {
      return _terminalHelpFallback(cmd);
    }
  }

  // ...existing code...
  @override
  Future<_Ret?> run(_CallResp call, _Map args, OnToolLog log) async {
    final command = args['command'] as String?;
    if (command == null) return [ChatContent.text('')];

    final argsList =
        (args['args'] as List?)?.whereType<String>().toList() ?? <String>[];
    final cwd = args['cwd'] as String?;
    final useShell = args['useShell'] as bool? ?? false;
    final truncateSize = args['truncateSize'] as int?;

    log(
      'Terminal -> $command ${argsList.join(' ')} ${cwd != null ? '(cwd: $cwd)' : ''}',
    );

    final buffer = StringBuffer();

    try {
      // Start a process so we can stream stdout/stderr
      final proc = await Process.start(
        command,
        argsList,
        runInShell: useShell,
        workingDirectory: cwd,
      );

      final stdoutSub = proc.stdout.transform(utf8.decoder).listen((data) {
        buffer.write(data);
        log(data);
        if (truncateSize != null && buffer.length > truncateSize) {
          final truncated = buffer.toString().substring(0, truncateSize);
          buffer
            ..clear()
            ..write(truncated);
        }
      });

      final stderrSub = proc.stderr.transform(utf8.decoder).listen((data) {
        buffer.write('\nERROR: $data');
        log('ERROR: $data');
        if (truncateSize != null && buffer.length > truncateSize) {
          final truncated = buffer.toString().substring(0, truncateSize);
          buffer
            ..clear()
            ..write(truncated);
        }
      });

      final exitCode = await proc.exitCode;
      await stdoutSub.cancel();
      await stderrSub.cancel();

      log('Terminal -> Process exited with code: $exitCode');
      var finalOutput = buffer.toString();
      if (truncateSize != null && finalOutput.length > truncateSize) {
        finalOutput =
            '${finalOutput.substring(0, truncateSize)}\n...[truncated]';
      }

      return [ChatContent.text(finalOutput)];
    } catch (e, st) {
      final errMsg = 'Terminal -> failure: $e\n$st';
      log(errMsg);
      // Always return something so the caller/client can send the tool response
      return [ChatContent.text(errMsg)];
    }
  }
}
// ...existing code...// File: lib/src/tool/func/terminal.dart
// Small defensive fallback if l10n.terminalHelp is somehow not available at runtime.
// Add this helper near the top of the file (below imports) or inside the class as a private method.
// File: lib/data/res/l10n.dart
// Add the Terminal related localization strings & helper to your existing L10n class.
// Insert these members into the class that provides the `l10n` instance (commonly named `L10n`, `AppL10n`, or similar).

// Example insertion into the existing L10n class:
class L10n {
  // ... existing members ...

  // Simple name for the terminal tool
  String get terminal => 'Terminal';

  // Tooltip/short description used in UI where needed
  String get terminalToolTip =>
      'Run shell commands on the host system (for advanced users).';

  // Helper used by TfTerminal.help to build a contextual help string
  String terminalHelp(String command) => 'Execute the shell command: $command';

  // Optionally add message used when terminal output is added to memory/history
  String terminalOutputLabel(String cmd) => 'Output of: $cmd';

  // ... existing members ...
}
