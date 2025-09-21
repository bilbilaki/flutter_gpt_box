part of '../tool.dart';

/// Tool for managing persistent, interactive terminal sessions.
final class TfTerminal extends ToolFunc {
  static const instance = TfTerminal._();
  // Assume you have access to your service instance
  static final _manager = TerminalSessionManager.instance;

  const TfTerminal._()
      : super(
          name: 'interactiveTerminal',
          parametersSchema: const {
            'type': 'object',
            'properties': {
              'action': {
                'type': 'string',
                'description':
                    "The session operation: 'start', 'write', or 'close'.",
              },
              'sessionId': {
                'type': 'string',
                'description':
                    "The unique ID of the session. Required for 'write' and 'close' actions.",
              },
              'command': {
                'type': 'string',
                'description':
                    "The command to execute. For 'start', this is the shell (e.g., 'bash', 'tmux'). For 'write', it's the command to send to the running session.",
              },
              'timeoutMs': {
                'type': 'integer',
                'description': 'For the "write" action, this is the milliseconds to wait for output to stop before returning. Defaults to 500ms.',
              }
            },
            'required': ['action'],
          },
        );

  @override
  String get description => '''
Manages a persistent, interactive terminal session. Use this for commands that require interaction like 'sudo', 'bash', 'ssh', or 'tmux'.

**Workflow:**
1.  Call with `action: 'start'` to begin a session and get a `sessionId`.
2.  Use that `sessionId` in one or more calls with `action: 'write'` to send commands.
3.  When finished, call with `action: 'close'` and the `sessionId` to clean up.

**Example:**
- `interactiveTerminal(action: 'start', command: 'bash')` -> returns `sessionId: "abc-123"`
- `interactiveTerminal(action: 'write', sessionId: 'abc-123', command: 'ls -l')` -> returns the directory listing
- `interactiveTerminal(action: 'close', sessionId: 'abc-123')` -> returns "Session closed."
''';

  @override
  String get l10nName => "Interactive Terminal";

  @override
  Future<_Ret?> run(_CallResp call, _Map args, OnToolLog log) async {
    final action = args['action'] as String?;
    if (action == null) {
      return [ChatContent.text("Error: 'action' is required.")];
    }

    final sessionId = args['sessionId'] as String?;
    final command = args['command'] as String?;

    try {
      switch (action) {
        case 'start':
          log("Starting new interactive terminal session...");
          final newSessionId = await _manager.startSession(executable: command ?? 'bash');
          return [ChatContent.text('New session started with ID: $newSessionId')];

        case 'write':
          if (sessionId == null || command == null) {
            return [ChatContent.text("Error: 'sessionId' and 'command' are required for the 'write' action.")];
          }
          final timeout = args['timeoutMs'] as int? ?? 500;
          log("Writing to session '$sessionId': $command");
          final output = await _manager.writeToSession(sessionId, command, timeoutMs: timeout);
          return [ChatContent.text(output)];

        case 'close':
          if (sessionId == null) {
            return [ChatContent.text("Error: 'sessionId' is required for the 'close' action.")];
          }
          log("Closing session '$sessionId'...");
          _manager.closeSession(sessionId);
          return [ChatContent.text('Session $sessionId closed.')];

        default:
          return [ChatContent.text("Error: Unknown action '$action'.")];
      }
    } catch (e) {
      log('Interactive Terminal Error: $e');
      return [ChatContent.text('An error occurred: $e')];
    }
  }
}