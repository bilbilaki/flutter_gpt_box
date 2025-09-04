
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:gpt_box/core/services/download.dart';
import 'package:gpt_box/data/model/app/download_task.dart';
import 'package:gpt_box/data/store/download.dart';

class TaskNotification {
  final String titleTemplate;
  final String bodyTemplate;

  const TaskNotification(this.titleTemplate, this.bodyTemplate);

  String _interpolate(String template, DownloadTask task, {String? subDirPath}) {
    return template
        .replaceAll('{filename}', task.filename)
        .replaceAll('{url}', task.url)
        .replaceAll('{taskId}', task.id)
        .replaceAll('{subDirPath}', subDirPath ?? '');
  }

  String titleFor(DownloadTask task, {String? subDirPath}) =>
      _interpolate(titleTemplate, task, subDirPath: subDirPath);

  String bodyFor(DownloadTask task, {String? subDirPath}) =>
      _interpolate(bodyTemplate, task, subDirPath: subDirPath);
}

class DownloadRecord {
  final String taskId;
  TaskStatus status;
  double progress;
  int? expectedFileSize;
  String? subDirPath;
  String? error;
  final DownloadTask? task;
  DateTime updatedAt;

  DownloadRecord({
    required this.taskId,
    this.status = TaskStatus.queued,
    this.progress = 0.0,
    this.expectedFileSize,
    this.subDirPath,
    this.error,
    this.task,
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.now();

  void updateStatus(TaskStatus s, {String? subDirPath, String? error}) {
    status = s;
    this.subDirPath = subDirPath ?? this.subDirPath;
    this.error = error ?? this.error;
    updatedAt = DateTime.now();
  }

  void updateProgress(double p) {
    progress = p;
    updatedAt = DateTime.now();
  }
}

/// Minimal database-like bridge returned by trackTasks().
class DownloadDatabaseBridge {
  final Future<List<DownloadRecord>> Function() allRecords;
  final Future<DownloadRecord?> Function(String id) recordForId;

  DownloadDatabaseBridge({
    required this.allRecords,
    required this.recordForId,
  });
}

/// Provider / bridge between FileDownloader service and UI / other classes.
///
/// Usage example (tracking):
///
/// // activate tracking at the start of your app
/// final db = await DownloadProvider.instance.trackTasks();
///
/// // somewhere else: enqueue a download (does not complete immediately)
/// final task = DownloadTask(
///   url: 'https://google.com',
///   filename: 'testfile.txt',
/// );
/// final successfullyEnqueued = await DownloadProvider.instance.enqueue(task);
///
/// // query the tracking database, returning a record for each task
/// final records = await db.allRecords();
/// for (final record in records) {
///   print('Task ${record.taskId} status is ${record.status}');
///   if (record.status == TaskStatus.running) {
///     print('-- progress ${record.progress * 100}%');
///     print('-- file size ${record.expectedFileSize ?? 'unknown'} bytes');
///   }
/// }
///
/// // or get record for specific task
/// final record = await db.recordForId(task.id);
///
/// Usage example (notification):
///
/// FileDownloaderProvider().configureNotification(
///   running: TaskNotification('Downloading', 'file: {filename}'),
///   complete: TaskNotification('Download finished', 'file: {filename}'),
///   progressBar: true,
/// );
class DownloadProvider extends ChangeNotifier {
  DownloadProvider._internal() {
    _downloader = FileDownloader();
  }

  static final DownloadProvider instance = DownloadProvider._internal();

  late final FileDownloader _downloader;
  StreamSubscription<TaskUpdate>? _sub;
  final Map<String, DownloadRecord> _records = {};
  bool _trackingActive = false;

  // Notification templates (local only; you must integrate with platform
  // notification plugin if you want real system notifications).
  TaskNotification? _runningNotification;
  TaskNotification? _completeNotification;
  bool _progressBarEnabled = false;

  Stream<TaskUpdate> get updates => _downloader.updates;

  /// Start the downloader service (restores store and schedules background work).
  void start() {
    _downloader.start();
  }

  /// Stop accepting new queued tasks from scheduler.
  void stop() {
    _downloader.stop();
  }

  /// Shutdown downloader and cancel active tasks optionally.
  Future<void> shutdown({bool cancelActive = true}) async {
    await _downloader.shutdown(cancelActive: cancelActive);
    await _sub?.cancel();
    _trackingActive = false;
  }

  /// Direct single-shot download (awaits completion).
  Future<DownloadResult> download(
    DownloadTask task, {
    void Function(double progress)? onProgress,
    void Function(TaskStatus status)? onStatus,
  }) =>
      _downloader.download(task, onProgress: onProgress, onStatus: onStatus);

  /// Enqueue a task for background processing.
  Future<bool> enqueue(DownloadTask task) => _downloader.enqueue(task);

  /// Enqueue many tasks for background processing.
  Future<void> enqueueAll(List<DownloadTask> tasks) => _downloader.enqueueAll(tasks);

  /// Pause a running task (best-effort).
  bool pause(String taskId) => _downloader.pause(taskId);

  /// Resume a paused task (re-enqueue).
  Future<bool> resume(String taskId) => _downloader.resume(taskId);

  /// Cancel a task.
  bool cancel(String taskId) => _downloader.cancel(taskId);

  /// Configure simple notifications for state transitions.
  ///
  /// Note: This implementation only stores templates and will call the internal
  /// [_showNotification] method when updates occur. To display actual OS
  /// notifications integrate the call to your platform notification plugin
  /// inside [_showNotification].
  void configureNotification({
    TaskNotification? running,
    TaskNotification? complete,
    bool progressBar = false,
  }) {
    _runningNotification = running;
    _completeNotification = complete;
    _progressBarEnabled = progressBar;
  }

  /// Begin tracking background tasks and return a small database-like bridge.
  ///
  /// The provider will keep an internal map of DownloadRecord entries and update
  /// them as events come in. Callers can use the returned bridge to query
  /// records by id or get a snapshot of all records.
  Future<DownloadDatabaseBridge> trackTasks() async {
    if (!_trackingActive) {
      _downloader.start();
      // Prime with persisted tasks in store (if any)
      final store = DownloadStore.instance;
      final persisted = store.fetchAll();
      for (final entry in persisted.entries) {
        final dt = entry.value;
        _records[dt.id] = DownloadRecord(
          taskId: dt.id,
          status: TaskStatus.queued,
          progress: 0.0,
          expectedFileSize: null,
          subDirPath: null,
          error: null,
          task: dt,
        );
      }

      _sub = _downloader.updates.listen((update) {
        if (update is TaskStatusUpdate) {
          final id = update.taskId;
          final record = _records[id] ?? DownloadRecord(taskId: id, task: store.fetch(id));
          record.updateStatus(update.status, subDirPath: update.filePath, error: update.error);
          _records[id] = record;
          _handleNotificationForStatus(record);
          notifyListeners();
        } else if (update is TaskProgressUpdate) {
          final id = update.taskId;
          final record = _records[id] ?? DownloadRecord(taskId: id, task: store.fetch(id));
          record.updateProgress(update.progress);
          _records[id] = record;
          notifyListeners();
        }
      }, onError: (e) {
        // swallow or log as desired
      });
      _trackingActive = true;
    }

    return DownloadDatabaseBridge(
      allRecords: () async => _records.values.toList(growable: false),
      recordForId: (String id) async => _records[id],
    );
  }

  /// Return current snapshot of records (synchronous).
  List<DownloadRecord> snapshotRecords() => _records.values.toList(growable: false);

  DownloadRecord? snapshotRecordForId(String id) => _records[id];

  void _handleNotificationForStatus(DownloadRecord record) {
    final task = record.task;
    if (task == null) return;

    switch (record.status) {
      case TaskStatus.running:
        if (_runningNotification != null) {
          _showNotification(
            title: _runningNotification!.titleFor(task, subDirPath: record.subDirPath),
            body: _runningNotification!.bodyFor(task, subDirPath: record.subDirPath),
            progress: _progressBarEnabled ? record.progress : null,
          );
        }
        break;
      case TaskStatus.complete:
        if (_completeNotification != null) {
          _showNotification(
            title: _completeNotification!.titleFor(task, subDirPath: record.subDirPath),
            body: _completeNotification!.bodyFor(task, subDirPath: record.subDirPath),
            progress: null,
          );
        }
        break;
      default:
        // no-op for other statuses by default
        break;
    }
  }

  /// Replace this with your platform notification plugin integration.
  /// This method is intentionally synchronous and minimal so consumers can
  /// decide how to surface notifications.
  void _showNotification({required String title, required String body, double? progress}) {
    // Example: integrate with flutter_local_notifications or other plugin.
    // For now we just print to console so devs can see it during debugging.
    // Remove or replace with real notification code in production.
    if (kDebugMode) {
      if (progress != null) {
        // progress 0.0 - 1.0
        debugPrint('[DownloadProvider Notification] $title - $body (${(progress * 100).toStringAsFixed(1)}%)');
      } else {
        debugPrint('[DownloadProvider Notification] $title - $body');
      }
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}