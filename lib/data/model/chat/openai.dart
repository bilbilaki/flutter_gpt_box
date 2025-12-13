import 'package:fl_lib/fl_lib.dart';
import 'package:gpt_box/data/model/chat/history/history.dart';

abstract final class OpenAIConvertor {
  static ChatHistory toChatHistory(Map session) {
    if (session['title'] is! String ||
        session['mapping'] is! Map<String, dynamic>) {
      throw ArgumentError(
        'Invalid session format: missing or invalid title/mapping',
      );
    }
    final title = session['title'] as String;
    final mapping = session['mapping'] as Map<String, dynamic>;
    final items = <ChatHistoryItem>[];

    try {
      Map<String, dynamic>? item =
          mapping.values.firstWhereOrNull(
                (e) => e is Map && e['parent'] == null,
              )
              as Map<String, dynamic>?;
      List<dynamic>? children = item?['children'] as List?;

      /// To avoid infinite loop
      var times = 0;
      while (children != null && children.isNotEmpty && times++ < 1000) {
        final nextId = children.firstOrNull;
        if (nextId == null || nextId is! String) break;

        item = mapping[nextId];
        children = item?['children'] as List?;

        final msg = item?['message'] as Map?;
        final roleStr = msg?['author']?['role'] as String?;
        final role = ChatRole.fromString(roleStr);
        if (role == null) continue;

        final content = msg?['content']?['parts'] as List?;
        if (content == null || content.isEmpty) continue;

        final contentStr = content.whereType<String>().join('\n');
        if (contentStr.isEmpty) continue;

        final createTimeValue = msg?['create_time'];
        if (createTimeValue is! double) continue;
        final createdTime = (createTimeValue * 1000).toInt();
        final time = DateTime.fromMillisecondsSinceEpoch(createdTime);

        items.add(
          ChatHistoryItem.single(role: role, raw: contentStr, createdAt: time),
        );
      }
    } catch (e) {
      // Log error or handle gracefully, for now just continue with partial items
    }

    return ChatHistory.noid(items: items, name: title);
  }
}
