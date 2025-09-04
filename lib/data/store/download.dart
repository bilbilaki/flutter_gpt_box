// lib/data/store/download/download_store.dart

import 'package:fl_lib/fl_lib.dart';
import 'package:gpt_box/data/model/app/download_task.dart';

final class DownloadStore extends HiveStore {
  DownloadStore._() : super('downloads');

  static final instance = DownloadStore._();

  /// Fetch a DownloadTask by id. If not found returns null.
  DownloadTask? fetch(String id) {
    final val = box.get(id);
    if (val == null) return null;
    if (val is DownloadTask) return val;
    if (val is Map) {
      try {
        return DownloadTask.fromJson(Map<String, dynamic>.from(val));
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  void put(DownloadTask task) {
    box.put(task.id, task);
  }

  bool delete(String id) {
    if (!box.containsKey(id)) return false;
    box.delete(id);
    return true;
  }

  Map<String, DownloadTask> fetchAll() {
    final map = <String, DownloadTask>{};
    var errCount = 0;
    for (final key in box.keys) {
      final item = box.get(key);
      if (item != null) {
        if (item is DownloadTask) {
          map[key] = item;
        } else if (item is Map) {
          try {
            map[key] = DownloadTask.fromJson(Map<String, dynamic>.from(item));
          } catch (e) {
            errCount++;
          }
        }
      }
    }
    if (errCount > 0) {
      Loggers.app.warning('fetchAll downloads: $errCount error(s)');
    }
    return map;
  }
}