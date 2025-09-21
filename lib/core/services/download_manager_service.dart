import 'dart:async';
import 'dart:io';
import 'package:background_downloader/background_downloader.dart' show DownloadTask, Batch, FileDownloader, TaskNotification, Task, TaskUpdate, TaskProgressUpdate, TaskStatusUpdate, BaseDirectory, Updates, TaskStatus, SharedStorage;
import 'package:collection/collection.dart';
import 'package:gpt_box/core/util/utils.dart';
import 'package:gpt_box/data/model/download.dart' hide DownloadItemAdapter;
import 'package:hive_ce/hive.dart';
import 'notification_service.dart';

/// DownloadManagerService
/// - Singleton. Call init() once at app startup.
/// - Wraps background_downloader lifecycle, events, pause/resume/cancel.
/// - Stores history in Hive (DownloadItem box) and also uses the built-in
///   downloader DB for real-time stats.
/// - On Android, moves completed files to SharedStorage.downloads (optional).
class DownloadManagerService {
  DownloadManagerService._();
  static final DownloadManagerService I = DownloadManagerService._();

  final FileDownloader _downloader = FileDownloader();
  late final StreamSubscription _updatesSub;

  // In-memory active items (by taskId) for fast UI updates
  final Map<String, DownloadItem> _active = {};

  // Hive box for history
  Box<DownloadItem>? historyBox;

  // Defaults
  String _defaultAppFolderName = 'GPTBOX';
  String _defaultFolderUnderApp = 'Downloads';
  String _defaultUserSubdir = '';

  // Whether to also show desktop progress via flutter_local_notifications
  bool _desktopProgressNotifications = true;

  bool _initialized = false;

  Future<void> init({
    String appFolderName = 'GPTBOX',
    String folderUnderApp = 'Downloads',
    String userSubdir = '',
    bool desktopProgressNotifications = true,
    bool configureNativeNotificationsOnAndroid = true,
  }) async {
    if (_initialized) return;

    _defaultAppFolderName = appFolderName;
    _defaultFolderUnderApp = folderUnderApp;
    _defaultUserSubdir = userSubdir;
    _desktopProgressNotifications = desktopProgressNotifications;

    // Notifications: desktop via flutter_local_notifications; Android uses native
    await NotificationService.I.init();

    // Initialize Hive box for history
    historyBox = await Hive.openBox<DownloadItem>('download_history');

    // Optionally configure native notifications for Android via background_downloader
    if (Platform.isAndroid && configureNativeNotificationsOnAndroid) {
      _downloader.configureNotification(
        running: const TaskNotification('Downloading', 'file: {filename}'),
        complete: const TaskNotification(
          'Download finished',
          'file: {filename}',
        ),
        error: const TaskNotification('Error', '{filename}'),
        canceled: const TaskNotification('Canceled', '{filename}'),
        paused: const TaskNotification('Paused', '{filename}'),
        progressBar: true,
        tapOpensFile: true,
      );
    }

    // Start downloader with DB tracking, resume, reschedule killed tasks
    await _downloader.start(
      doTrackTasks: true,
    //  doResume: true,
      doRescheduleKilledTasks: true,
    );

    // Subscribe to updates stream (status + progress)
    _updatesSub = _downloader.updates.listen(_onUpdate);

    _initialized = true;
  }

  void dispose() {
    _updatesSub.cancel();
  }

  // region Public API

  /// Single download request -> enqueues and returns taskId
  Future<String?> enqueueSingle(DownloadRequest req) async {
    final task = await _buildTask(req);
    final enq = await _downloader.enqueue(task);
    return enq ? task.taskId : null;
  }

  /// Batch enqueue (true parallel downloads without waiting)
  Future<List<bool>> enqueueMany(List<DownloadRequest> requests) async {
    final tasks = <Task>[];
    for (final req in requests) {
      final t = await _buildTask(req);
      tasks.add(t);
    }
    final numEnqueued = await _downloader.enqueueAll(tasks);
    return numEnqueued;
  }

  /// Download a batch and wait till all finish
  Future<Batch> downloadBatchAndWait(List<DownloadRequest> requests) async {
    final tasks = <DownloadTask>[];
    for (final req in requests) {
      final t = (await _buildTask(req)) as DownloadTask;
      tasks.add(t);
    }
    return _downloader.downloadBatch(
      tasks,
      batchProgressCallback: (succeeded, failed) async {
        // Optional: desktop notification showing overall batch progress
        if (_desktopProgressNotifications &&
            (Platform.isWindows || Platform.isLinux)) {
          final pct = ((succeeded + failed) / tasks.length * 100).round();
          await NotificationService.I.showOrUpdateProgress(
            id: _notifIdForGroup(tasks.first.group),
            title: 'Batch downloading',
            body: '$succeeded of ${tasks.length}',
            progressPercent: pct,
          );
        }
      },
    );
  }
  /// Pause a task
  Future<bool> pause(String taskId) async {
    final record = await _downloader.database.recordForId(taskId);
    if (record?.task is DownloadTask) {
      return _downloader.pause(record!.task as DownloadTask);
    }
    return false;
  }

  /// Resume a task
  Future<bool> resume(String taskId) async{
        final record = await _downloader.database.recordForId(taskId);
    if (record?.task is DownloadTask) {
      return _downloader.resume(record!.task as DownloadTask);
    }
    return false;
  }
  

  /// Cancel a task
  Future<bool> cancel(String taskId) => _downloader.cancelTaskWithId(taskId);

  /// Cancel all tasks in optional group
  Future<void> cancelAll({String? group}) async {
    if (group == null) {
      await _downloader.cancelAll();
    } else {
      final tasks = await _downloader.allTasks(group: group, allGroups: false);
      await _downloader.cancelAll();
    }
  }

  /// Returns a snapshot of active items
  List<DownloadItem> activeItems() =>
      _active.values.sortedBy<DateTime>((e) => e.createdAt!).toList();

  /// Returns persistent history
  List<DownloadItem> history() =>
      historyBox?.values.sortedBy<DateTime>((e) => e.createdAt!).toList() ?? const [];

  /// Clear all history (does not delete files)
  Future<void> clearHistory() async => historyBox?.clear();

  /// Open file by taskId (if path is known)
  Future<bool> openFileByTaskId(String taskId) async {
    final rec = await _downloader.database.recordForId(taskId);
    if (rec?.task is DownloadTask) {
      final task = rec!.task as DownloadTask;
      final ok = await _downloader.openFile(task: task);
      return ok;
    }
    // Try our cached path
    final it =
        _active[taskId] ??
        historyBox?.values.firstWhereOrNull((e) => e.taskId == taskId);
    if (it != null && it.savedPath!.isNotEmpty) {
      final ok = await _downloader.openFile(filePath: it.savedPath);
      return ok;
    }
    return false;
  }

  /// Configure default download directory base (affects subsequent tasks)
  void setDefaultFolder({
    String? appFolderName,
    String? folderUnderApp,
    String? userSubdir,
  }) {
    if (appFolderName != null) _defaultAppFolderName = appFolderName;
    if (folderUnderApp != null) _defaultFolderUnderApp = folderUnderApp;
    if (userSubdir != null) _defaultUserSubdir = userSubdir;
  }

  // endregion

  // region Internals

  int _notifIdForTask(String taskId) => taskId.hashCode;
  int _notifIdForGroup(String group) => group.hashCode;

  Future<Task> _buildTask(DownloadRequest req) async {
    // Determine target directory and filename
    final directory = await getTargetDirectory(
      appFolderName: _defaultAppFolderName,
      folderUnderApp: req.folderUnderApp.isNotEmpty
          ? req.folderUnderApp
          : _defaultFolderUnderApp,
      userSubdir: req.userSubdir.isNotEmpty
          ? req.userSubdir
          : _defaultUserSubdir,
      ensureExists: true,
    );

    final effectiveFilename = req.filename?.trim().isNotEmpty == true
        ? req.filename!
        : _inferFilenameFromUrl(req.url);

    // Platform-specific baseDirectory handling
    // - Desktop: write directly to absolute folder using BaseDirectory.root
    // - Android: write to app support, then (optionally) move to SharedStorage downloads after completion
    if (Platform.isWindows || Platform.isLinux) {
      return DownloadTask(
        url: req.url,
        urlQueryParameters: req.urlQueryParameters,
        headers: req.headers,
        filename: effectiveFilename,
        baseDirectory: BaseDirectory.root,
        directory: directory.path, // absolute
        updates: Updates.statusAndProgress,
        allowPause: req.allowPause,
        requiresWiFi: req.requiresWiFi,
        group: req.group,
        displayName: req.displayName,
        metaData: req.metaData,
        retries: 3,
        priority: 5,
      );
    } else if (Platform.isAndroid) {
      // Use app support; we'll move to shared storage on completion
      final appSupport = getTargetDirectory(folderUnderApp: "Downloads");
      return DownloadTask(
        url: req.url,
        urlQueryParameters: req.urlQueryParameters,
        headers: req.headers,
        filename: effectiveFilename,
        baseDirectory: BaseDirectory.applicationSupport,
        directory: 'downloads/tmp', // temp staging
        updates: Updates.statusAndProgress,
        allowPause: req.allowPause,
        requiresWiFi: req.requiresWiFi,
        group: req.group,
        displayName: req.displayName,
        metaData: _encodeMeta(req, directory.path),
        retries: 3,
        priority: 5,
      );
    } else {
      // Fallback: app documents
      return DownloadTask(
        url: req.url,
        urlQueryParameters: req.urlQueryParameters,
        headers: req.headers,
        filename: effectiveFilename,
        baseDirectory: BaseDirectory.applicationDocuments,
        directory: 'Downloads',
        updates: Updates.statusAndProgress,
        allowPause: req.allowPause,
        requiresWiFi: req.requiresWiFi,
        group: req.group,
        displayName: req.displayName,
        metaData: req.metaData,
        retries: 3,
        priority: 5,
      );
    }
  }

  String _inferFilenameFromUrl(String url) {
    final uri = Uri.parse(url);
    final last = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : 'file';
    return last.isEmpty ? 'file' : last;
  }

  String _encodeMeta(DownloadRequest req, String destAbsDir) {
    // encode extra info we need later (Android move, openAfterComplete, dest dir)
    final meta = {
      'meta': req.metaData,
      'displayName': req.displayName,
      'openAfterComplete': req.openAfterComplete,
      'moveToSharedDownloads': req.moveToSharedDownloads,
      'desiredDestDir': destAbsDir,
    };
    return meta.toString();
  }

  Map<String, dynamic> _decodeMeta(Task task) {
    try {
      // We encoded a map using toString; try to parse naïvely
      final s = task.metaData ?? '{}';
      final map = <String, dynamic>{};
      final body = s.substring(1, s.length - 1); // remove {}
      for (final part in body.split(',')) {
        final kv = part.split(':');
        if (kv.length >= 2) {
          map[kv[0].trim()] = kv.sublist(1).join(':').trim();
        }
      }
      return map;
    } catch (_) {
      return {};
    }
  }

  Future<void> _onUpdate(TaskUpdate update) async {
    switch (update) {
      case TaskProgressUpdate():
        final t = update.task;
        _touchActive(
          t,
          status: DownloadUiStatus.running,
          progress: update.progress,
        );
        _updateTelemetry(
          t.taskId,
          expected: update.hasExpectedFileSize ? update.expectedFileSize : null,
          speedBps: update.hasNetworkSpeed ? update.networkSpeed : null,
          eta: update.hasTimeRemaining ? update.timeRemaining : null,
        );

        // Desktop progress notification
        if (_desktopProgressNotifications &&
            (Platform.isLinux || Platform.isWindows)) {
          final pct = (update.progress * 100).clamp(0, 100).round();
          await NotificationService.I.showOrUpdateProgress(
            id: _notifIdForTask(t.taskId),
            title: 'Downloading',
            body: t.filename,
            progressPercent: pct,
          );
        }
        break;

      case TaskStatusUpdate():
        await _handleStatus(update);
        break;
    }
  }

  Future<void> _handleStatus(TaskStatusUpdate su) async {
    final task = su.task;
    final uiStatus = mapTaskStatus(su.status);

    // Update memory model
    final item = _touchActive(
      task,
      status: uiStatus,
      progress: _statusToProgress(uiStatus),
    );

    if (su.status == TaskStatus.complete) {
      String? finalPath;

      // On Android, move to shared storage if requested
      if (Platform.isAndroid) {
        final meta = _decodeMeta(task);
        final move =
            (meta['moveToSharedDownloads']?.toString() ?? 'true') == 'true';
        final desiredDestDir = meta['desiredDestDir']?.toString() ?? '';
        if (move) {
          finalPath = await FileDownloader().moveToSharedStorage(
            task as DownloadTask,
            SharedStorage.downloads,
            directory: _relativeSubdir(desiredDestDir),
          );
        }
      }

      // Determine saved path if not moved
      final record = await _downloader.database.recordForId(task.taskId);
      final saved = task.directory;
      finalPath ??= saved ?? '';

      // Persist in history
      final hist = DownloadItem(
        taskId: task.taskId,
        url: (task as DownloadTask).url,
        filename: task.filename,
        savedPath: finalPath ?? '',
        status: DownloadUiStatus.complete,
        progress: 1.0,
        expectedFileSize: null,
        networkSpeedBytesPerSec: null,
        timeRemainingSeconds: 0,
        group: task.group,
        openAfterComplete: _readOpenAfterComplete(task),
        createdAt: DateTime.now(), // Best effort
        finishedAt: DateTime.now(),
        displayName: task.displayName ?? '',
        metaData: task.metaData ?? '',
      );
      await historyBox?.put(task.taskId, hist);

      // Desktop summary notification
      if (Platform.isLinux || Platform.isWindows) {
        await NotificationService.I.showSummary(
          id: _notifIdForTask(task.taskId),
          title: 'Download finished',
          body: task.filename,
          payload: finalPath,
        );
      }

      // Auto-open if desired (supported across platforms via background_downloader)
      if (_readOpenAfterComplete(task)) {
        unawaited(_downloader.openFile(task: task));
      }

      // Remove from active after completion
      _active.remove(task.taskId);
    } else if (su.status.isFinalState && su.status != TaskStatus.complete) {
      // Persist failed/canceled/notFound
      final saved = task.directory;
      final hist = DownloadItem(
        taskId: task.taskId,
        url: (task as DownloadTask).url,
        filename: task.filename,
        savedPath: saved ?? '',
        status: mapTaskStatus(su.status),
        progress: _statusToProgress(mapTaskStatus(su.status)),
        expectedFileSize: null,
        networkSpeedBytesPerSec: null,
        timeRemainingSeconds: null,
        group: task.group,
        openAfterComplete: _readOpenAfterComplete(task),
        createdAt: DateTime.now(),
        finishedAt: DateTime.now(),
        displayName: task.displayName ?? '',
        metaData: task.metaData ?? '',
      );
      await historyBox?.put(task.taskId, hist);

      if (Platform.isLinux || Platform.isWindows) {
        await NotificationService.I.showSummary(
          id: _notifIdForTask(task.taskId),
          title: 'Download ${su.status.name}',
          body: task.filename,
        );
      }

      _active.remove(task.taskId);
    }
  }

  bool _readOpenAfterComplete(Task task) {
    if (Platform.isAndroid) {
      final meta = _decodeMeta(task);
      return (meta['openAfterComplete']?.toString() ?? 'false') == 'true';
    }
    return (task.metaData ?? '').contains('openAfterComplete=true');
  }

  String _relativeSubdir(String absolutePath) {
    // For Android shared storage, we can pass a subdirectory like "GPTBOX/Downloads/user123"
    // If you pass an absolute path previously for desktop, here we try to preserve the tail
    // after the public Downloads folder name.
    final parts = absolutePath.split(Platform.pathSeparator);
    final idx = parts.lastIndexWhere((e) => e.toLowerCase() == 'downloads');
    if (idx >= 0 && idx + 1 < parts.length) {
      return parts.sublist(idx + 1).join('/');
    }
    // Fallback to app folder structure
    return '$_defaultAppFolderName/$_defaultFolderUnderApp/$_defaultUserSubdir'
        .replaceAll('//', '/');
  }

  DownloadItem _touchActive(
    Task task, {
    required DownloadUiStatus status,
    required double progress,
  }) {
    final existing = _active[task.taskId];
    final updated = DownloadItem(
      taskId: task.taskId,
      url: (task as DownloadTask).url,
      filename: task.filename,
      savedPath: existing?.savedPath ?? '',
      status: status,
      progress: progress,
      expectedFileSize: existing?.expectedFileSize,
      networkSpeedBytesPerSec: existing?.networkSpeedBytesPerSec,
      timeRemainingSeconds: existing?.timeRemainingSeconds,
      group: task.group,
      openAfterComplete: _readOpenAfterComplete(task),
      createdAt: existing?.createdAt ?? DateTime.now(),
      finishedAt: existing?.finishedAt,
      displayName: task.displayName ?? '',
      metaData: task.metaData ?? '',
    );
    _active[task.taskId] = updated;
    return updated;
  }

  void _updateTelemetry(
    String taskId, {
    int? expected,
    double? speedBps,
    Duration? eta,
  }) {
    final it = _active[taskId];
    if (it == null) return;
    _active[taskId] = DownloadItem(
      taskId: it.taskId,
      url: it.url,
      filename: it.filename,
      savedPath: it.savedPath,
      status: it.status,
      progress: it.progress,
      expectedFileSize: expected ?? it.expectedFileSize,
      networkSpeedBytesPerSec: speedBps ?? it.networkSpeedBytesPerSec,
      timeRemainingSeconds: eta?.inSeconds ?? it.timeRemainingSeconds,
      group: it.group,
      openAfterComplete: it.openAfterComplete,
      createdAt: it.createdAt,
      finishedAt: it.finishedAt,
      displayName: it.displayName,
      metaData: it.metaData,
    );
  }

  double _statusToProgress(DownloadUiStatus s) {
    switch (s) {
      case DownloadUiStatus.running:
      case DownloadUiStatus.enqueued:
        return 0.0;
      case DownloadUiStatus.complete:
        return 1.0;
      case DownloadUiStatus.canceled:
        return -2.0;
      case DownloadUiStatus.failed:
        return -1.0;
      case DownloadUiStatus.notFound:
        return -3.0;
      case DownloadUiStatus.waitingToRetry:
        return -4.0;
      case DownloadUiStatus.paused:
        return -5.0;
    }
  }

  // endregion
}
