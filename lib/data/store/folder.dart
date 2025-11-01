import 'package:fl_lib/fl_lib.dart';
import 'package:gpt_box/data/model/chat/folder.dart';

class FolderStore extends HiveStore {
  FolderStore._() : super('folders');

  static final instance = FolderStore._();

  Map<String, ChatFolder> fetchAll() {
    final map = <String, ChatFolder>{};
    var errCount = 0;
    for (final key in box.keys) {
      final item = box.get(key);
      if (item != null) {
        if (item is ChatFolder) {
          map[key] = item;
        } else if (item is Map) {
          try {
            map[key] = ChatFolder.fromJson(item.cast<String, dynamic>());
          } catch (e) {
            errCount++;
          }
        }
      }
    }
    if (errCount > 0) Loggers.app.warning('Init folders: $errCount error(s)');
    return map;
  }

  void put(ChatFolder folder) {
    box.put(folder.id, folder);
  }

  void delete(String id) {
    box.delete(id);
  }
}
