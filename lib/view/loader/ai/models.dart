// TODO Implement this library.
class Message {
  String role;
  String content;
  List<ToolCall>? toolCalls;
  String? toolCallId;

  Message({
    required this.role, 
    this.content = "", 
    this.toolCalls, 
    this.toolCallId
  });

  Map<String, dynamic> toJson() => {
    'role': role,
    'content': content, // API expects content even if null/empty for some roles
    if (toolCalls != null) 'tool_calls': toolCalls!.map((e) => e.toJson()).toList(),
    if (toolCallId != null) 'tool_call_id': toolCallId,
  };
}

class ToolCall {
  String id;
  String type;
  FunctionCall function;

  ToolCall({required this.id, required this.type, required this.function});

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'function': function.toJson(),
  };
}

class FunctionCall {
  String name;
  String arguments;

  FunctionCall({required this.name, required this.arguments});

  Map<String, dynamic> toJson() => {'name': name, 'arguments': arguments};
}

class Tool {
  final String type;
  final Map<String, dynamic> function;
  Tool({this.type = "function", required this.function});
  Map<String, dynamic> toJson() => {'type': type, 'function': function};
}