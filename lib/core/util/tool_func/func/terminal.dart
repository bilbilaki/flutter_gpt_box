part of '../tool.dart';

/// Tool for executing Linux shell commands.
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
                'description': 'The shell command to execute (e.g., "ls -la", "cat file.txt", "sudo apt update").',
              },
            },
            'required': ['command'],
          },
        );

  @override
  String get description => 'Execute Linux shell commands and return output. Supports all commands including sudo.';

  @override
  String get l10nName => "Terminal";

  @override
  Future<_Ret?> run(_CallResp call, _Map args, OnToolLog log) async {
    final command = args['command'] as String?;
    
    if (command == null || command.isEmpty) {
      return [ChatContent.text("Error: 'command' is required.")];
    }

    try {
      log("Executing: $command");
      
      // Execute command using bash -c to handle pipes, redirects, and complex syntax
      final result = await Process.run(
        'bash',
        ['-c', command],
        runInShell: true,
      );

      final output = StringBuffer();
      
      if (result.stdout.toString().isNotEmpty) {
        output.write(result.stdout);
      }
      
      if (result.stderr.toString().isNotEmpty) {
        if (output.isNotEmpty) output.write('\n');
        output.write('STDERR:\n${result.stderr}');
      }
      
      if (result.exitCode != 0) {
        output.write('\n[Exit code: ${result.exitCode}]');
      }

      return [ChatContent.text(output.isEmpty ? 'Command completed with no output.' : output.toString())];
    } catch (e) {
      log('Terminal Error: $e');
      return [ChatContent.text('Error executing command: $e')];
    }
  }
}