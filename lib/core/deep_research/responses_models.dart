/// Deep Research request object (Responses API).
class DeepResearchRequest {
  final String
  model; // e.g. "o3-deep-research" | "o4-mini-deep-research" | "gpt-4.1"
  final String input; // user input
  final String? instructions; // system/instructions
  final bool background; // background mode for long tasks
  final Map<String, dynamic>? reasoning; // e.g. { "summary": "auto" }
  final int? maxToolCalls; // constrain cost/latency
  final List<ResponseTool>
  tools; // web_search_preview, file_search, mcp, code_interpreter
  final Map<String, dynamic>?
  extra; // passthrough for future fields (webhooks etc.)

  DeepResearchRequest({
    required this.model,
    required this.input,
    this.instructions,
    this.background = false,
    this.reasoning,
    this.maxToolCalls,
    this.tools = const [],
    this.extra,
  });

  Map<String, dynamic> toJson({bool stream = false}) {
    final body = <String, dynamic>{
      'model': model,
      'input': input,
      if (instructions != null) 'instructions': instructions,
      if (reasoning != null) 'reasoning': reasoning,
      if (maxToolCalls != null) 'max_tool_calls': maxToolCalls,
      if (tools.isNotEmpty) 'tools': tools.map((t) => t.toJson()).toList(),
      if (stream) 'stream': true,
      // background can coexist with tools; streaming and background are typically exclusive
      if (background) 'background': true,
      if (extra != null) ...extra!,
    };
    return body;
  }
}

/// Base class for tools
abstract class ResponseTool {
  String get type;
  Map<String, dynamic> toJson();
}

/// Web search preview tool (builtin)
class WebSearchPreviewTool extends ResponseTool {
  @override
  String get type => 'web_search_preview';
  @override
  Map<String, dynamic> toJson() => {'type': type};
}

/// File search over vector stores
class FileSearchTool extends ResponseTool {
  final List<String> vectorStoreIds;
  FileSearchTool({required this.vectorStoreIds});
  @override
  String get type => 'file_search';
  @override
  Map<String, dynamic> toJson() => {
    'type': type,
    'vector_store_ids': vectorStoreIds,
  };
}

/// Code interpreter
class CodeInterpreterTool extends ResponseTool {
  /// container = {"type":"auto"} or explicitly provisioned
  final Map<String, dynamic> container;
  CodeInterpreterTool({this.container = const {'type': 'auto'}});
  @override
  String get type => 'code_interpreter';
  @override
  Map<String, dynamic> toJson() => {'type': type, 'container': container};
}

/// Remote MCP server for Deep Research
class McpTool extends ResponseTool {
  final String serverLabel; // developer label
  final String serverUrl; // http(s) endpoint
  final String requireApproval; // "never" for deep research
  McpTool({
    required this.serverLabel,
    required this.serverUrl,
    this.requireApproval = 'never',
  });
  @override
  String get type => 'mcp';
  @override
  Map<String, dynamic> toJson() => {
    'type': type,
    'server_label': serverLabel,
    'server_url': serverUrl,
    'require_approval': requireApproval,
  };
}

/// Minimal deep response structure we care about (id, status, output_text, outputs)
class DeepResponse {
  final String? id;
  final String? status; // e.g. "in_progress", "completed", "failed"
  final String outputText; // concatenated human-readable answer (best-effort)
  final List<OutputItem>
  outputItems; // web_search_call, code_interpreter_call, mcp_tool_call, file_search_call, message
  final Map<String, dynamic> raw;

  DeepResponse({
    required this.id,
    required this.status,
    required this.outputText,
    required this.outputItems,
    required this.raw,
  });

  factory DeepResponse.fromJson(Map<String, dynamic> json) {
    final items = OutputItem.parseList(json['output']);
    final text = extractOutputText(json, items);
    return DeepResponse(
      id: json['id']?.toString(),
      status: json['status']?.toString(),
      outputText: text,
      outputItems: items,
      raw: json,
    );
  }

  static String extractOutputText(
    Map<String, dynamic> json,
    List<OutputItem> items,
  ) {
    // If server already provides output_text
    final ot = json['output_text'];
    if (ot is String && ot.isNotEmpty) return ot;

    // Otherwise try to aggregate message items text content
    final buf = StringBuffer();
    for (final item in items) {
      if (item.type == 'message') {
        final content = item.content;
        if (content is List) {
          for (final c in content) {
            // expect {type: 'output_text'|'text', text: '...'}
            if (c is Map) {
              final text = c['text'];
              if (text is String && text.isNotEmpty) {
                buf.write(text);
                if (!text.endsWith('\n')) buf.write('\n');
              }
            }
          }
        }
      }
    }
    return buf.toString().trim();
  }
}

/// Output item base: we keep the type and content minimally typed to avoid tight coupling
class OutputItem {
  final String type;
  final Map<String, dynamic>? action; // for web_search_call etc.
  final dynamic content; // for message, it's a List of content objects
  final String? status; // tool call status ("completed")
  final Map<String, dynamic> raw;

  OutputItem({
    required this.type,
    this.action,
    this.content,
    this.status,
    required this.raw,
  });

  factory OutputItem.fromJson(Map<String, dynamic> json) {
    return OutputItem(
      type: json['type']?.toString() ?? '',
      action: json['action'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(json['action'])
          : null,
      content: json['content'],
      status: json['status']?.toString(),
      raw: json,
    );
  }

  static List<OutputItem> parseList(dynamic any) {
    if (any is List) {
      return any
          .whereType<Map>()
          .map((m) => OutputItem.fromJson(Map<String, dynamic>.from(m)))
          .toList();
    }
    return const [];
  }
}

/// Streaming chunk for /responses stream
class DeepResponseChunk {
  final String? id;
  final String? status;
  final String? deltaText; // text delta for display
  final Map<String, dynamic>?
  outputItem; // raw item if the server streams items
  final Map<String, dynamic> raw;

  DeepResponseChunk({
    this.id,
    this.status,
    this.deltaText,
    this.outputItem,
    required this.raw,
  });

  factory DeepResponseChunk.fromJson(Map<String, dynamic> json) {
    // There is no universal schema for chunks; we best-effort map common fields
    String? delta;
    // Some servers use { "type": "message.delta", "delta": "..." }
    if (json.containsKey('delta')) {
      final d = json['delta'];
      if (d is String) delta = d;
      if (d is Map && d['text'] is String) delta = d['text'];
    } else if (json['type']?.toString().contains('message') == true) {
      // sometimes: { "type":"message", "content":[{"type":"output_text","text":"..."}] }
      final content = json['content'];
      if (content is List && content.isNotEmpty) {
        final c0 = content.first;
        if (c0 is Map && c0['text'] is String) delta = c0['text'];
      }
    }
    return DeepResponseChunk(
      id: json['id']?.toString(),
      status: json['status']?.toString(),
      deltaText: delta,
      outputItem: json['output_item'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(json['output_item'])
          : null,
      raw: json,
    );
  }
}
