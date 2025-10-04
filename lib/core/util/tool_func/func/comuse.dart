part of '../tool.dart';

/// Simple tool for computer use tasks.
final class CompUseTool extends ToolFunc {
  static const instance = CompUseTool._();

  const CompUseTool._()
    : super(
        name: 'computer_use',
        parametersSchema: const {
          'type': 'object',
          'properties': {
            'task': {
              'type': 'string',
              'description':
                  'A simple string describing the computer task to perform (e.g., "Open the browser" or "Type hello world"). The tool will interpret and execute this via computer control services.',
            },
            // Optional parameters for context (e.g., image if needed for vision-based tasks)
            'imageBase64': {
              'type': 'string',
              'description':
                  'Optional: Base64-encoded image data for vision-assisted tasks (e.g., screenshot or user-provided image). Omit for text-only tasks.',
            },
          },
          'required': ['task'],
        },
      );

  @override
  String get description => '''
Use this simple tool to perform computer use tasks based on a natural language string description. 
This tool integrates with a computer control service to handle actions like moving the mouse, clicking, typing, scrolling, or taking screenshots.

**Key Usage**:
- Provide a "task" string describing what to do (e.g., "Click the start button" or "Type "hello" in the search bar").
- Optionally include "imageBase64" for vision-based tasks (e.g., identifying elements in a screenshot).
- The tool will parse the task and execute it step-by-step using the underlying service.
- Returns a JSON response with success status, executed actions, and any output (e.g., screenshot data URL).

**Best Practices**:
- Keep tasks simple and specific to avoid ambiguity.
- For complex sequences, chain multiple tool calls.
- Always confirm sensitive actions (e.g., "Are you sure you want to delete files?") before invoking.
- This tool is preview-only and may require user confirmation for safety.

Example: User says "Open Notepad and type hello". Call with {'task': 'Open Notepad and type hello'}.
''';

  @override
  String get l10nName => "Computer Use";

  @override
  Future<_Ret?> run(_CallResp call, _Map args, OnToolLog log) async {
    // Parse arguments
    final task = args['task'] as String?;
    final imageBase64 = args['imageBase64'] as String?;

    if (task == null || task.isEmpty) {
      return [
        ChatContent.text(
          'Error: A "task" string is required for computer use.',
        ),
      ];
    }

    log('Executing computer use task: $task');

    try {
      // Call the computer use service (integrating with startCompUse)
      final result = await startCompUse(task, imageBase64 ?? '');

      // Log the result and return a formatted response
      log('Computer use result: ${result.outputText}');
      return [
        ChatContent.text(
          'Task "$task" executed via computer use service. Result:${result.outputText} Check device for changes.',
        ),
      ];
    } catch (e) {
      log('Computer use error: $e');
      return [
        ChatContent.text(
          'Failed to execute computer task "$task". Error: $e. Ensure the service is initialized and permissions are granted.',
        ),
      ];
    }
  }
}
