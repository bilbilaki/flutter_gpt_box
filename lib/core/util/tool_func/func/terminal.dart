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
                  "The session operation to perform. Must be exactly one of: 'start' (initialize a new terminal session), 'write' (send a command to an active session), or 'close' (end and clean up a session). Use only one action per call.",
            },
            'sessionId': {
              'type': 'string',
              'description':
                  "The unique ID of an existing session (returned from a 'start' action response). Required for 'write' and 'close' actions. Store and reference it from previous responses—do not fabricate IDs.",
            },
            'command': {
              'type': 'string',
              'description':
                  "The shell or command to execute. For 'start', specify the initial shell (e.g., 'bash' or 'tmux'); for 'write', provide the command to run in the session (e.g., 'ls -l' or 'sudo apt update'). Always confirm commands with the user, especially interactive or risky ones (e.g., sudo).",
            },
            'timeoutMs': {
              'type': 'integer',
              'description': 'Optional wait time (in milliseconds) for output after a write command before returning (e.g., 5000 for long-running tasks). Defaults to 500ms. Increase only if the user expects delayed output (e.g., "Wait up to 10 seconds"); use to balance responsiveness.',
            }
          },
          'required': ['action'],
        },
      );

@override
String get description => '''
Use this tool to manage interactive terminal sessions when the user explicitly requests shell access or command execution (e.g., "Run ls in a bash terminal" or "Execute sudo update"). Ideal for persistent, stateful commands like sudo (which needs password interaction) or multi-step scripting (e.g., ssh sessions). Do not call unsolicited—always confirm commands and risks with the user to ensure safety and consent. Sessions are isolated per call; the tool returns output immediately for 'write' and a 'sessionId' for 'start'.
This tool enables a workflow of starting a session, sending commands, and closing—use sequentially for multi-command interactions. Focus on non-destructive commands; warn for potentially harmful ones.

**Usage Workflow (Sequential Calls Required):**
1. **'start'**: Initialize a new terminal session.
   - Required: 'command' (e.g., 'bash' for standard shell).
   - Response: 'sessionId' (e.g., "abc-123") and initial prompt. Offer: "Terminal session started with bash. What command to run first?"
   - Tip: Choose shell based on user need (e.g., 'tmux' for persistent multiplexing); confirm: "Start a bash session?"

2. **'write'**: Send a command to an active session and get output.
   - Required: 'sessionId', 'command' (e.g., 'pwd' or 'git status').
   - Optional: 'timeoutMs' for waiting (e.g., 3000ms for installs).
   - Response: Command output, errors, and updated prompt. Handle interactively: If output prompts (e.g., sudo password), inform user (e.g., "Sudo needs input—provide in next command?").
   - Example: After start, write 'ls -l' → returns directory listing. For multi-steps: Chain writes (e.g., 'cd /dir', then 'ls').

3. **'close'**: Terminate the session cleanly.
   - Required: 'sessionId'.
   - Response: Confirmation (e.g., "Session closed."). Always close after use to free resources; offer: "Session complete—close now or run one more command?"

**Example Sequence:**
- Call 1: {'action': 'start', 'command': 'bash'} → "Session ID: abc-123"
- Call 2: {'action': 'write', 'sessionId': 'abc-123', 'command': 'ls -l'} → "file1.txt\nfile2.pdf"
- Call 3: {'action': 'close', 'sessionId': 'abc-123'} → "Session closed."

**Best Practices to Avoid Errors and Enhance Safety:**
- Confirmation Critical: Verify every 'command' with the user (e.g., "Run 'rm file.txt'? This deletes—confirm.")—especially for sudo, rm, or network commands.
- Security: No root/sudo without explicit user approval; avoid commands accessing sensitive data. If interactive (e.g., password prompts), pause and ask: "Session prompts for sudo—enter password in next write?"
- Session Management: Store 'sessionId' across calls in your reasoning; start new only if no active one. Close promptly after tasks to prevent resource leaks.
- Output Handling: For long outputs, summarize (e.g., "Listed 50 files—key ones: ..."); if timeout, suggest increasing 'timeoutMs' or breaking commands.
- Multi-Command: Use sequential 'write' calls for workflows (e.g., install then test); inform progress: "Running update... Output ready."
- Errors: If invalid 'sessionId' or command fails, inform (e.g., "Command errored—try again?") and suggest debugging (').
- Limits: Keep sessions short; no persistent state across conversations unless user requests.
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