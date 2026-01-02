/// Generic Responses API request for our use-cases.
 part of 'package:gpt_box/view/page/home/home.dart';
class FunctionTool extends ResponseTool {
  @override
  String get type => 'function';

  final String name;
  final String? description;
  final Map<String, dynamic>? parameters;

  FunctionTool({
    required this.name,
    this.description,
    this.parameters,
  });

  @override
  Map<String, dynamic> toJson() => {
    'type': type,
    'name': name,
    if (description != null) 'description': description,
    if (parameters != null) 'parameters': parameters,
  };
}

class ResponsesRequest {
  final String model;
  final String? input; // simple string input (typical)
  final List<dynamic>?
  inputs; // advanced inputs array (for local_shell and others)
  final bool? background;
  final String? previousResponseId;

  final Map<String, dynamic>?
  reasoning; // e.g., {"effort":"low"} or {"summary":"auto"}
  final List<ResponseTool> tools;
  final String? toolChoice; // "auto" | "none" | specific
  final List<String>? include; // e.g., ["web_search_call.action.sources"]
  final Map<String, dynamic>? extra; // passthrough

  ResponsesRequest({
    required this.model,
    this.input,
    this.inputs,
    this.background,
    this.reasoning,
   required this.previousResponseId,
    this.tools = const [],
    this.toolChoice,
    this.include,
    this.extra,
  });

  Map<String, dynamic> toJson({
    bool stream = false,
    bool dropBackgroundIfStreaming = true,
  }) {
    final body = <String, dynamic>{
      'model': model,
      if (previousResponseId != null) 'previous_response_id': previousResponseId,

      if (input != null) 'input': input,
      if (inputs != null) 'inputs': inputs,
      if (background == true) 'background': true,
      if (reasoning != null) 'reasoning': reasoning,
      if (tools.isNotEmpty) 'tools': tools.map((t) => t.toJson()).toList(),
      if (toolChoice != null) 'tool_choice': toolChoice,
      if (include != null && include!.isNotEmpty) 'include': include,
      if (stream) 'stream': true,
    };
    if (extra != null) body.addAll(extra!);

    if (stream && dropBackgroundIfStreaming == true) {
      body.remove('background'); // streaming + background are not compatible
    }
    return body;
  }
}

/// Base tool
abstract class ResponseTool {
  String get type;
  Map<String, dynamic> toJson();
}

/// Web search (new tool)
class WebSearchTool extends ResponseTool {
  @override
  String get type => 'web_search';
  final WebSearchFilters? filters;
  final WebSearchUserLocation? userLocation;

  WebSearchTool({this.filters, this.userLocation});

  @override
  Map<String, dynamic> toJson() => {
    'type': type,
    if (filters != null) 'filters': filters!.toJson(),
    if (userLocation != null) 'user_location': userLocation!.toJson(),
  };
}

/// Legacy web_search_preview with context control
class WebSearchPreviewTool extends ResponseTool {
  @override
  String get type => 'web_search_preview';
  final String? searchContextSize; // "low" | "medium" | "high"
  WebSearchPreviewTool({this.searchContextSize});
  @override
  Map<String, dynamic> toJson() => {
    'type': type,
    if (searchContextSize != null) 'search_context_size': searchContextSize,
  };
}

class WebSearchFilters {
  final List<String>? allowedDomains; // up to 20
  WebSearchFilters({this.allowedDomains});
  Map<String, dynamic> toJson() => {
    if (allowedDomains != null) 'allowed_domains': allowedDomains,
  };
}

class WebSearchUserLocation {
  final String? type; // "approximate"
  final String? country; // ISO code
  final String? city;
  final String? region;
  final String? timezone; // IANA
  WebSearchUserLocation({
    this.type = 'approximate',
    this.country,
    this.city,
    this.region,
    this.timezone,
  });
  Map<String, dynamic> toJson() => {
    if (type != null) 'type': type,
    if (country != null) 'country': country,
    if (city != null) 'city': city,
    if (region != null) 'region': region,
    if (timezone != null) 'timezone': timezone,
  };
}

/// Local shell tool for Codex loop
class LocalShellTool extends ResponseTool {
  @override
  String get type => 'local_shell';
  @override
  Map<String, dynamic> toJson() => {'type': type};
}

/// Minimal deep/response structure
class DeepResponse {
  final String? id;
  final String? status; // "in_progress", "completed", "failed"
  final String outputText;
  final List<OutputItem> outputItems;
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
    final ot = json['output_text'];
    if (ot is String && ot.isNotEmpty) return ot;
    final buf = StringBuffer();
    for (final item in items) {
      if (item.type == 'message') {
        final content = item.content;
        if (content is List) {
          for (final c in content) {
            if (c is Map && c['text'] is String) {
              buf.write(c['text']);
              if (!c['text'].toString().endsWith('\n')) buf.write('\n');
            }
          }
        }
      }
    }
    return buf.toString().trim();
  }
}

/// Output item (tool calls, messages, etc.)
class OutputItem {
  final String type;
  final Map<String, dynamic>? action;
  final dynamic content;
  final String? status;
  final String? role;
  final Map<String, dynamic> raw;

  OutputItem({
    required this.type,
    this.action,
    this.content,
    this.status,
    this.role,
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
      role: json['role']?.toString(),
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

/// Streaming chunk
class DeepResponseChunk {
  final String? id;
  final String? status;
  final String? deltaText;
  final Map<String, dynamic>? outputItem;
  final Map<String, dynamic> raw;
  DeepResponseChunk({
    this.id,
    this.status,
    this.deltaText,
    this.outputItem,
    required this.raw,
  });

  factory DeepResponseChunk.fromJson(Map<String, dynamic> json) {
    // Responses SSE events are not consistent about where the response id lives.
    // Prefer the top-level `id`, then fall back to nested `response.id` or `response_id`.
    String? respId = json['id']?.toString();
    final responseObj = json['response'];
    if (respId == null && responseObj is Map && responseObj['id'] != null) {
      respId = responseObj['id']?.toString();
    }
    respId ??= json['response_id']?.toString();

    String? delta;
    if (json.containsKey('delta')) {
      final d = json['delta'];
      if (d is String) delta = d;
      if (d is Map && d['text'] is String) delta = d['text'];
    } else if (json['type']?.toString().contains('message') == true) {
      final content = json['content'];
      if (content is List && content.isNotEmpty) {
        final c0 = content.first;
        if (c0 is Map && c0['text'] is String) delta = c0['text'];
      }
    }
    return DeepResponseChunk(
      id: respId,
      status: json['status']?.toString(),
      deltaText: delta,
      outputItem: json['output_item'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(json['output_item'])
          : null,
      raw: json,
    );
  }
}

/// Helpers to extract citations from a message item content array.
class UrlCitation {
  final String url;
  final String? title;
  final int? startIndex;
  final int? endIndex;
  UrlCitation({required this.url, this.title, this.startIndex, this.endIndex});

  static List<UrlCitation> fromMessageContent(dynamic content) {
    final out = <UrlCitation>[];
    if (content is List) {
      for (final c in content) {
        if (c is Map && c['annotations'] is List) {
          for (final a in (c['annotations'] as List)) {
            if (a is Map && a['type'] == 'url_citation' && a['url'] is String) {
              out.add(
                UrlCitation(
                  url: a['url'],
                  title: a['title']?.toString(),
                  startIndex: a['start_index'] is int
                      ? a['start_index'] as int
                      : null,
                  endIndex: a['end_index'] is int
                      ? a['end_index'] as int
                      : null,
                ),
              );
            }
          }
        }
      }
    }
    return out;
  }
}
