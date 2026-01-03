part of 'tool.dart';

typedef _Ret = List<ChatContent>;
typedef _CallResp = ChatCompletionMessageToolCall;
typedef _Map = Map<String, dynamic>;
typedef ToolConfirm = Future<bool> Function(ToolFunc func, String help);
typedef OnToolLog = void Function(String log);

/// Standardized tool error class for consistent LLM self-correction patterns.
///
/// Errors use the format: `[TOOL_ERROR] error_code: description. Suggestion: retry hint`
/// This allows LLMs to parse errors, understand the problem, and retry with corrected args.
class ToolError {
  final String code;
  final String description;
  final String? suggestion;

  const ToolError({
    required this.code,
    required this.description,
    this.suggestion,
  });

  /// Formats the error as a standardized message for the LLM.
  ///
  /// Example output:
  /// `[TOOL_ERROR] invalid_input: 'command' parameter is required. Suggestion: provide a valid shell command.`
  String toMessage() {
    final msg = '[TOOL_ERROR] $code: $description';
    return suggestion != null ? '$msg. Suggestion: $suggestion' : msg;
  }

  /// Common error factory constructors for reusable patterns
  factory ToolError.invalidInput(String param, {String? suggestion}) =>
      ToolError(
        code: 'invalid_input',
        description: 'Required parameter "$param" is missing or empty.',
        suggestion:
            suggestion ?? 'Verify all required parameters are provided.',
      );

  factory ToolError.notFound(String item, {String? suggestion}) => ToolError(
    code: 'not_found',
    description: '$item not found.',
    suggestion: suggestion ?? 'Verify the identifier or search term.',
  );

  factory ToolError.permissionDenied(String action, {String? suggestion}) =>
      ToolError(
        code: 'permission_denied',
        description: 'Permission denied for "$action".',
        suggestion: suggestion ?? 'Grant the required permission and retry.',
      );

  factory ToolError.invalidArgument(
    String param,
    String reason, {
    String? suggestion,
  }) => ToolError(
    code: 'invalid_argument',
    description: 'Invalid "$param": $reason.',
    suggestion: suggestion ?? 'Correct the parameter value and retry.',
  );

  factory ToolError.executionFailed(String reason, {String? suggestion}) =>
      ToolError(
        code: 'execution_failed',
        description: reason,
        suggestion: suggestion ?? 'Verify the inputs or try again later.',
      );
}

Future<Map<String, dynamic>> _parseMap(dynamic value) async {
  Future<_Map> tryDecodeJson(dynamic value) {
    return compute((_) {
      try {
        return json.decode(value);
      } catch (e) {
        return {};
      }
    }, null);
  }

  if (value is String) {
    final json = await tryDecodeJson(value);
    if (json.isNotEmpty) return json;
  }
  if (value is Map<String, dynamic>) return value;
  return {};
}
