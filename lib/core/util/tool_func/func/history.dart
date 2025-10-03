part of '../tool.dart';

final class TfHistory extends ToolFunc {
  static const instance = TfHistory._();

const TfHistory._()
    : super(
        name: 'history',
        parametersSchema: const {
          'type': 'object',
          'properties': {
            'keywords': {
              'type': 'array',
              'items': {'type': 'string'},
              'description': '''
An array of keywords to filter chat history (e.g., ['project', 'meeting']). If empty (or omitted), retrieves all chats limited by 'count'. Use keywords from the user's request to narrow results—confirm relevance with the user if ambiguous.''',
            },
            'onlyTitles': {
              'type': 'boolean',
              'description':
                  'Set to true to retrieve only chat titles for quick overview and selection. Defaults to false for full chat details. Use this initially to let the user choose before loading full contexts.',
            },
            'count': {
              'type': 'integer',
              'description': '''
The maximum number of chat results to retrieve (default: 3). Only increase or set to -1 (for all chats) if the user explicitly requests more (e.g., "load recent 10 chats" or "all chats"). For large counts, offer summaries or ask the user to select specifics to avoid overwhelming the response.''',
            },
          },
          // Note: 'keywords' and 'onlyTitles' are optional; 'count' has sensible defaults
        },
      );

  @override
  String get description => '''
Use this tool to search and retrieve chat history when the user explicitly requests it (e.g., "Load my previous chats about the project" or "Show recent conversations"). Do not call unsolicited—always base keywords or count on the user's input.
The tool searches indexed chat history and returns matching chats (or all if no keywords). Responses include titles and optional full content, with unique IDs for loading as context in other tools. Use returned data to help the user select and load relevant chats.

**Usage Steps (Invoke Only When User Requests History):**
1. **Search with Keywords**:
   - Provide 'keywords' array (e.g., from user's query like "meeting notes").
   - Optional: Set 'onlyTitles' to true for a list of titles first—present to user (e.g., "Here are matching chats: 1. Project Update, 2. Team Meeting. Which one to load?").
   - If no keywords, it defaults to recent chats.

2. **Control Result Count**:
   - Use 'count' to limit (e.g., 5 for "recent 5 chats"). Set to -1 only for "all chats".
   - For multi-chat results: Summarize or list with options; if many, suggest refining keywords or loading one at a time to focus.

3. **Loading Full Contexts**:
   - After getting titles, ask the user to select (e.g., by title or ID), then use the full response (with 'onlyTitles' false) to incorporate as context.
   - Response Format: Array of chats with titles, dates, IDs, and content (if not titles-only). Store IDs for reference.

**Best Practices to Avoid Errors and Enhance Interaction:**
- Confirm user's intent: Before calling, verify keywords/count (e.g., "Do you mean chats with 'project'? How many?").
- Handle Multi-Results: If results exceed 3-5, proactively offer choices (e.g., "Found 10 chats—want the top 3 or search narrower?") and use sequential calls if loading multiple.
- Defaults: Rely on them unless specified—don't assume large loads.
- Privacy: Only load history the user requests; inform if no matches (e.g., "No chats found—try different keywords?").
- Integration: Use retrieved content to continue the conversation naturally (e.g., "Based on your previous chat...").

Focus on user-driven history access—respect conversation flow.''';

  @override
  String get l10nName => l10n.history;

  @override
  String? get l10nTip => l10n.historyToolTip;

  @override
  bool get defaultEnabled => false;

  @override
  String help(_CallResp call, _Map args) {
    final keywords = args['keywords'] as List? ?? [];
    return l10n.historyToolHelp(keywords);
  }

  @override
  Future<_Ret?> run(_CallResp call, _Map args, OnToolLog log) async {
    final keywords_ = args['keywords'] as List?;
    if (keywords_ == null) return null;

    final keywords = <String>[];
    for (final e in keywords_) {
      if (e is String) keywords.add(e);
    }
    final count = args['count'] as int? ?? 3;
    final prop = Stores.history;
    final chats = prop.take(count, keywords);
    final onlyTitles = args['onlyTitles'] as bool? ?? false;
    return chats
        .map((e) => ChatContent.text(
            onlyTitles ? e.name ?? l10n.untitled : e.toMarkdown))
        .toList();
  }
}
