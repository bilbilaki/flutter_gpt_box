part of '../tool.dart';

final class TfMemory extends ToolFunc {
  static const instance = TfMemory._();

  const TfMemory._()
    : super(
        name: 'memory',
        parametersSchema: const {
          'type': 'object',
          'properties': {
            'memory': {
              'type': 'string',
              'description':
                  'The text or information to store persistently in the database (e.g., "User\'s favorite color is blue" or "Key project deadline: Dec 15"). Keep it concise and relevant. Always confirm the exact details with the user before storing to ensure accuracy and consent.',
            },
          },
          // Note: Only one memory item per call; for multiple, invoke sequentially
        },
      );

  @override
  String get description => '''
Use this tool to store user-specified information persistently when they explicitly request it (e.g., "Remember that my API key is abc123" or "Memorize this note for later"). Do not call unsolicited—only save what the user wants to recall later in conversations. The tool persists the memory in a database, making it available across sessions for reference (e.g., to inform future responses like "Based on your memorized preference...").
Responses confirm storage (e.g., "Saved successfully") with a unique ID if needed for retrieval. Use memorized info ethically to enhance personalization without over-relying on it.


Focus on user-driven persistence—enhance conversations without intruding.''';
  @override
  String get l10nName => l10n.memory;

  @override
  String help(_CallResp call, _Map args) {
    return l10n.memoryTip(args['memory'] as String? ?? '<?>');
  }

  @override
  Future<_Ret?> run(_CallResp call, _Map args, OnToolLog log) async {
    final memory = args['memory'] as String?;
    if (memory == null) return null;

    final prop = Stores.mcp.memories;
    final memories = prop.get();
    prop.set(memories..add(memory));
    await Future.delayed(Durations.medium1);
    return [ChatContent.text(l10n.memoryAdded(memory))];
  }
}
