// lib/services/terminal_session_manager.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:uuid/uuid.dart';

/// Represents an active, running terminal session.
class ActiveSession {
  final Process process;
  final Stream<String> output;
  late final StreamSubscription<String> _outputSub;
  final IOSink input;
  final StringBuffer _buffer = StringBuffer();

  ActiveSession(this.process)
      : input = process.stdin,
        output = process.stdout.transform(utf8.decoder) {
    // Also listen to stderr and merge it into the same stream/buffer
    process.stderr.transform(utf8.decoder).listen(_buffer.write);
    _outputSub = output.listen(_buffer.write);
  }

  /// Reads all output currently in the buffer and clears it.
  String readAndClear() {
    final content = _buffer.toString();
    _buffer.clear();
    return content;
  }

  void dispose() {
    _outputSub.cancel();
    process.kill();
  }
}

/// Manages multiple interactive terminal sessions.
class TerminalSessionManager {
  TerminalSessionManager._();
  static final instance = TerminalSessionManager._();
  final _uuid = Uuid();

  final Map<String, ActiveSession> _sessions = {};

  /// Starts a new terminal session and returns its unique ID.
  Future<String> startSession({String executable = 'bash', List<String> args = const []}) async {
    final process = await Process.start(executable, args);
    final sessionId = _uuid.v4();
    _sessions[sessionId] = ActiveSession(process);
    return sessionId;
  }

  /// Writes a command to a session and waits for a period of silence before returning output.
  Future<String> writeToSession(String sessionId, String command, {int timeoutMs = 500}) async {
    final session = _sessions[sessionId];
    if (session == null) {
      return 'Error: Session not found.';
    }

    // Clear any lingering output before sending the new command
    session.readAndClear();
    
    // Ensure the command has a newline to be executed
    session.input.add(utf8.encode('${command.trim()}\n'));

    // This is the tricky part: wait for output to stop arriving.
    final completer = Completer<String>();
    Timer? timer;

    final sub = session.process.stdout.transform(utf8.decoder).listen((_) {
      // Every time data arrives, reset the timeout timer.
      timer?.cancel();
      timer = Timer(Duration(milliseconds: timeoutMs), () {
        if (!completer.isCompleted) {
          completer.complete(session.readAndClear());
        }
      });
    });

    // Start the initial timer
    timer = Timer(Duration(milliseconds: timeoutMs), () {
        if (!completer.isCompleted) {
          completer.complete(session.readAndClear());
        }
    });

    // Clean up the listener after the future completes
    final result = await completer.future;
    await sub.cancel();
    return result;
  }

  /// Closes and cleans up a session.
  void closeSession(String sessionId) {
    final session = _sessions.remove(sessionId);
    session?.dispose();
  }
}