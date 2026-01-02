 part of 'package:gpt_box/view/page/home/home.dart';


class ShellCall {
  final String callId;
  final Map<String, dynamic>
  action; // contains command, working_directory, env, timeout_ms
  ShellCall({required this.callId, required this.action});
}

class CodexLocalShellAgent {
  final ResponsesService svc;
  final String model; // e.g. "codex-mini-latest"
  final Duration defaultTimeout;
  final List<String>?
  allowListPrefixes; // simple allowlist for commands (e.g., ['ls','node','npm'])
  final List<String>? denyListPrefixes; // hard deny (e.g., ['rm','shutdown'])
  final String? workingDirectory;

  CodexLocalShellAgent({
    required this.svc,
    this.model = 'codex-mini-latest',
    this.defaultTimeout = const Duration(minutes: 10),
    this.allowListPrefixes,
    this.denyListPrefixes,
    this.workingDirectory,
  });

  bool _isAllowed(List<String> argv) {
    final cmd = argv.isNotEmpty ? argv.first : '';
    if (cmd.isEmpty) return false;
    if (denyListPrefixes != null) {
      for (final d in denyListPrefixes!) {
        if (cmd == d || cmd.startsWith('$d ')) return false;
      }
    }
    if (allowListPrefixes == null || allowListPrefixes!.isEmpty) return true;
    for (final a in allowListPrefixes!) {
      if (cmd == a || cmd.startsWith('$a ')) return true;
    }
    return false;
  }

  Future<DeepResponse> run(String userText) async {
    // 1) Initial create with tool enabled and inputs array
    final body = {
      'model': model,
      'tools': [LocalShellTool().toJson()],
      'inputs': [
        {
          'type': 'message',
          'role': 'user',
          'content': [
            {'type': 'text', 'text': userText},
          ],
        },
      ],
    };

    DeepResponse response = await svc.createRaw(body);

    while (true) {
      final calls = _extractShellCalls(response);
      if (calls.isEmpty) break;

      final call = calls.first;
      final argv = _readArgv(call.action['command']);
      final wd =
          (call.action['working_directory'] as String?) ??
          workingDirectory ??
          Directory.current.path;
      final envExtra =
          (call.action['env'] as Map?)?.map(
            (k, v) => MapEntry(k.toString(), v.toString()),
          ) ??
          {};
      final timeoutMs = call.action['timeout_ms'] is num
          ? (call.action['timeout_ms'] as num).toInt()
          : null;

      if (!_isAllowed(argv)) {
        final deniedOut = 'Command denied by policy: ${argv.join(' ')}';
        response = await _sendCallOutput(
          prevId: response.id!,
          callId: call.callId,
          output: deniedOut,
        );
        continue;
      }

      final out = await _exec(
        argv,
        wd: wd,
        envExtra: envExtra,
        timeout: timeoutMs,
      );
      response = await _sendCallOutput(
        prevId: response.id!,
        callId: call.callId,
        output: out,
      );
    }

    return response;
  }

  List<ShellCall> _extractShellCalls(DeepResponse resp) {
    final out = <ShellCall>[];
    for (final item in resp.outputItems) {
      if (item.type == 'local_shell_call' && item.raw['call_id'] is String) {
        final callId = item.raw['call_id'] as String;
        final action =
            (item.action ?? item.raw['action'] ?? {}) as Map<String, dynamic>;
        out.add(ShellCall(callId: callId, action: action));
      }
    }
    return out;
  }

  List<String> _readArgv(dynamic any) {
    if (any is List) {
      return any.map((e) => e.toString()).toList();
    } else if (any is String) {
      // naive split; prefer the server to send list
      return any.split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    }
    return const [];
  }

  Future<String> _exec(
    List<String> argv, {
    required String wd,
    Map<String, String>? envExtra,
    int? timeout,
  }) async {
    if (argv.isEmpty) return 'Empty command';
    final cmd = argv.first;
    final args = argv.skip(1).toList();
    final env = <String, String>{...Platform.environment, ...?envExtra};

    try {
      final res =
          await Process.run(
            cmd,
            args,
            workingDirectory: wd,
            environment: env,
            runInShell: false,
            stdoutEncoding: const Utf8Codec(),
            stderrEncoding: const Utf8Codec(),
          ).timeout(
            timeout != null ? Duration(milliseconds: timeout) : defaultTimeout,
          );

      final text =
          (res.stdout as String? ?? '') + (res.stderr as String? ?? '');
      return text.isEmpty ? '[no output]' : text;
    } catch (e) {
      return 'Exec error: $e';
    }
  }

  Future<DeepResponse> _sendCallOutput({
    required String prevId,
    required String callId,
    required String output,
  }) async {
    final body = {
      'model': model,
      'tools': [LocalShellTool().toJson()],
      'previous_response_id': prevId,
      'inputs': [
        {
          'type': 'local_shell_call_output',
          'call_id': callId,
          'output': output,
        },
      ],
    };
    return await svc.createRaw(body);
  }
}
