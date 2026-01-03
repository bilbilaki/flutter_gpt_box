 part of 'package:gpt_box/view/page/home/home.dart';
class ResponseFunctionCall {
  final String callId;
  final String name;
  final String argumentsJson;

  ResponseFunctionCall({
    required this.callId,
    required this.name,
    required this.argumentsJson,
  });
}
ResponseFunctionCall? _tryParseFunctionCall(Map<String, dynamic> raw) {
  // Common pattern: chunk.raw['output_item'] or raw itself contains tool call info
  final item = (raw['output_item'] is Map<String, dynamic>)
      ? Map<String, dynamic>.from(raw['output_item'])
      : null;

  final map = item ?? raw;

  // Look for function call structures
  final type = map['type']?.toString();
  if (type == null) return null;

  if (type.contains('function_call') || type == 'function_call') {
    final callId = map['id']?.toString() ?? map['call_id']?.toString();
    final name = map['name']?.toString();
    final args = map['arguments'];

    if (callId != null && name != null) {
      return ResponseFunctionCall(
        callId: callId,
        name: name,
        argumentsJson: args is String ? args : jsonEncode(args ?? {}),
      );
    }
  }

  return null;
}
