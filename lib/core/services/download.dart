// lib/services/file_downloader.dart

import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:gpt_box/data/model/app/download_task.dart';
import 'package:gpt_box/data/store/download.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shortid/shortid.dart';


/// Task update base class
abstract class TaskUpdate {}

/// Status update event (complete, paused, canceled, failed, running, queued)
class TaskStatusUpdate extends TaskUpdate {
  final String taskId;
  final TaskStatus status;
  final String? filePath;
  final String? error;

  TaskStatusUpdate({
    required this.taskId,
    required this.status,
    this.filePath,
    this.error,
  });

  @override
  String toString() =>
      'TaskStatusUpdate(taskId: $taskId, status: $status, filePath: $filePath, error: $error)';
}

/// Progress update event (0.0 - 1.0)
class TaskProgressUpdate extends TaskUpdate {
  final String taskId;
  final double progress;

  TaskProgressUpdate({
    required this.taskId,
    required this.progress,
  });

  @override
  String toString() => 'TaskProgressUpdate(taskId: $taskId, progress: $progress)';
}

final class FileDownloader {
  FileDownloader._internal();

  static final FileDownloader _instance = FileDownloader._internal();

  factory FileDownloader() => _instance;

  // Broadcast updates to UI / listeners
  final StreamController<TaskUpdate> _updates = StreamController<TaskUpdate>.broadcast();

  Stream<TaskUpdate> get updates => _updates.stream;

  // Simple in-memory queue + store backed
  final Queue<DownloadTask> _queue = Queue<DownloadTask>();

  // Active tasks map
  final Map<String, _ActiveTask> _active = {};

  // Limit concurrency for parallel downloads
  int concurrency = 3;

  bool _started = false;

  // Expose store instance
  final  _store = DownloadStore.instance;

  /// Start the downloader: restores any enqueued tasks from the store if necessary
  /// and mark it active so enqueued tasks will be processed.
  void start() {
    if (_started) return;
    _started = true;
    // restore any tasks from store if needed (fetchAll returns map)
    final all = _store.fetchAll();
    // enqueue those that are not running/completed (basic heuristic)
    for (final t in all.values) {
      // do not re-enqueue tasks already completed
      // here we only re-add to our queue so they will be processed
      _enqueueInternal(t);
    }
    _schedule();
  }

  /// Stop processing new queued tasks. Active tasks continue.
  void stop() {
    _started = false;
  }

  /// Shutdown and cancel all active tasks
  Future<void> shutdown({bool cancelActive = true}) async {
    _started = false;
    if (cancelActive) {
      final ids = _active.keys.toList();
      for (final id in ids) {
        cancel(id);
      }
    }
    await _updates.close();
  }

  /// Single-shot download. This does not enqueue the task into background queue,
  /// it runs immediately on caller's isolate and returns a DownloadResult.
  Future<DownloadResult> download(
    DownloadTask task, {
    void Function(double progress)? onProgress,
    void Function(TaskStatus status)? onStatus,
  }) async {
    final id = task.id.isEmpty ? shortid.generate() : task.id;
    final t = task.copyWith(id: id, createdAt: task.createdAt ?? DateTime.now());
    return _performDownloadSingle(
      t,
      onProgress: onProgress,
      onStatus: onStatus,
    );
  }

  /// Enqueue a task for background parallel processing.
  /// Returns true if successfully enqueued.
  Future<bool> enqueue(DownloadTask task) async {
    final id = task.id.isEmpty ? shortid.generate() : task.id;
    final t = task.copyWith(id: id, createdAt: task.createdAt ?? DateTime.now());

    // persist
    _store.put(t);

    final added = _enqueueInternal(t);
    if (added) _schedule();
    return added;
  }

  /// Enqueue a list of tasks for parallel processing.
  Future<void> enqueueAll(List<DownloadTask> tasks) async {
    for (final task in tasks) {
      await enqueue(task);
    }
  }

  /// Pause a task (best-effort). If task is active and allowPause is true it will
  /// be canceled and marked as paused; resuming will re-download from start.
  bool pause(String taskId) {
    final active = _active[taskId];
    if (active == null) return false;
    if (!active.task.allowPause) return false;
    active.paused = true;
    _signalCancelActive(active, statusAfterCancel: TaskStatus.paused);
    return true;
  }

  /// Resume a paused task (re-enqueue).
  Future<bool> resume(String taskId) async {
    final stored = _store.fetch(taskId);
    if (stored == null) return false;
    // mark as queued and re-enqueue
    _store.put(stored);
    _enqueueInternal(stored);
    _schedule();
    return true;
  }

  /// Cancel a task
  bool cancel(String taskId) {
    final active = _active[taskId];
    if (active != null) {
      active.canceled = true;
      _signalCancelActive(active, statusAfterCancel: TaskStatus.canceled);
      return true;
    } else {
      // If not active, remove from queue and store
      final removedFromQueue = _queue.remove((t) => t.id == taskId) > 0;
      final deleted = _store.delete(taskId);
      if (removedFromQueue || deleted) {
        _updates.add(TaskStatusUpdate(taskId: taskId, status: TaskStatus.canceled));
        return true;
      }
      return false;
    }
  }

  /// Internal enqueue helper (does not persist)
  bool _enqueueInternal(DownloadTask task) {
    // avoid duplicates in queue or active
    if (_active.containsKey(task.id)) return false;
    if (_queue.any((t) => t.id == task.id)) return false;
    _queue.add(task);
    _updates.add(TaskStatusUpdate(taskId: task.id, status: TaskStatus.queued));
    return true;
  }

  void _schedule() {
    if (!_started) return;
    while (_active.length < concurrency && _queue.isNotEmpty) {
      final next = _queue.removeFirst();
      _startBackgroundDownload(next);
    }
  }

  void _startBackgroundDownload(DownloadTask task) {
    final worker = _ActiveTask(task: task);
    _active[task.id] = worker;
    _updates.add(TaskStatusUpdate(taskId: task.id, status: TaskStatus.running));
    // Fire and forget
    unawaited(_backgroundDownloadWorker(worker).whenComplete(() {
      // cleanup if present
      _active.remove(task.id);
      // Trigger scheduling for remaining queued tasks
      _schedule();
    }));
  }

  Future<void> _backgroundDownloadWorker(_ActiveTask worker) async {
    final task = worker.task;
    try {
      final res = await _performDownloadSingle(
        task,
        onProgress: (p) {
          _updates.add(TaskProgressUpdate(taskId: task.id, progress: p));
        },
        onStatus: (status) {
          _updates.add(TaskStatusUpdate(taskId: task.id, status: status));
        },
        activeTracker: worker,
      );

      // Update store and emit final status
      if (res.status == TaskStatus.complete) {
        _store.put(task);
        _updates.add(TaskStatusUpdate(taskId: task.id, status: TaskStatus.complete, filePath: res.filePath));
      } else {
        _updates.add(TaskStatusUpdate(taskId: task.id, status: res.status, error: res.error));
      }
    } catch (e, st) {
      _updates.add(TaskStatusUpdate(taskId: task.id, status: TaskStatus.failed, error: e.toString()));
      // Nothing else, cleanup will be handled by caller
    }
  }

  /// Perform the actual download (used by both download() and background worker).
  /// If [activeTracker] is provided, it will be updated with cancellation hooks.
  Future<DownloadResult> _performDownloadSingle(
    DownloadTask task, {
    void Function(double progress)? onProgress,
    void Function(TaskStatus status)? onStatus,
    _ActiveTask? activeTracker,
  }) async {
    final maxRetries = task.retries;
    var attempt = 0;
    while (true) {
      attempt++;
      if (activeTracker?.canceled == true) {
        onStatus?.call(TaskStatus.canceled);
        return DownloadResult(status: TaskStatus.canceled, progress: 0.0, taskId: task.id);
      }

      final client = HttpClient();
      // attach client to active tracker for cancellation
      if (activeTracker != null) activeTracker.client = client;

      HttpClientRequest? request;
      HttpClientResponse? response;
      File? file;
      IOSink? sink;
      StreamSubscription<List<int>>? subscription;
      try {
        onStatus?.call(TaskStatus.running);

        // Build URI with query parameters
        final uri = _buildUri(task);

        request = await client.getUrl(uri);

        // add headers
        task.headers.forEach((k, v) {
          if (k.isNotEmpty) request!.headers.set(k, v);
        });

        // execute
        response = await request.close();

        if (response.statusCode >= 400) {
          throw HttpException('HTTP ${response.statusCode} for ${uri.toString()}');
        }

        // prepare file path
        final targetDir = await _getTargetDirectory(task.directory);
        await targetDir.create(recursive: true);
        final filename = task.filename.isNotEmpty ? task.filename : _filenameFromUri(uri);
        final filePath = p.join(targetDir.path, filename);
        file = File(filePath);
        sink = file.openWrite();

        final contentLength = response.contentLength;
        var downloaded = 0;
        final completer = Completer<void>();

        subscription = response.listen(
          (chunk) {
            if ((activeTracker?.canceled ?? false) || (activeTracker?.paused ?? false)) {
              // Cancel reading further
              subscription?.cancel();
              return;
            }
            downloaded += chunk.length;
            sink?.add(chunk);
            if (contentLength > 0) {
              final progress = (downloaded / contentLength).clamp(0.0, 1.0);
              onProgress?.call(progress);
              if (task.updates == Updates.statusAndProgress) {
                _updates.add(TaskProgressUpdate(taskId: task.id, progress: progress));
              }
            }
          },
          onError: (e) {
            if (!completer.isCompleted) completer.completeError(e);
          },
          onDone: () {
            if (!completer.isCompleted) completer.complete();
          },
          cancelOnError: true,
        );

        // store subscription & sink for cancellation
        if (activeTracker != null) {
          activeTracker.sub = subscription;
          activeTracker.sink = sink;
          activeTracker.file = file;
        }

        // Wait until done or canceled / paused
        try {
          await completer.future;
        } catch (e) {
          rethrow;
        } finally {
          // finalize sink
          try {
            await sink?.flush();
            await sink?.close();
          } catch (_) {}
        }

        if (activeTracker?.paused == true) {
          // mark paused
          onStatus?.call(TaskStatus.paused);
          _updates.add(TaskStatusUpdate(taskId: task.id, status: TaskStatus.paused));
          return DownloadResult(status: TaskStatus.paused, progress: 0.0, taskId: task.id);
        }

        if (activeTracker?.canceled == true) {
          // remove partial file
          try {
            await file?.delete();
          } catch (_) {}
          onStatus?.call(TaskStatus.canceled);
          _updates.add(TaskStatusUpdate(taskId: task.id, status: TaskStatus.canceled));
          return DownloadResult(status: TaskStatus.canceled, progress: 0.0, taskId: task.id);
        }

        // completed successfully
        onProgress?.call(1.0);
        onStatus?.call(TaskStatus.complete);
        return DownloadResult(status: TaskStatus.complete, progress: 1.0, filePath: file?.path, taskId: task.id);
      } catch (e) {
        // cleanup
        try {
          await subscription?.cancel();
        } catch (_) {}
        try {
          await sink?.close();
        } catch (_) {}
        try {
          await request?.flush();
        } catch (_) {}
        try {
          client.close(force: true);
        } catch (_) {}

        final isLastAttempt = attempt > maxRetries;
        if (activeTracker?.canceled == true) {
          onStatus?.call(TaskStatus.canceled);
          return DownloadResult(status: TaskStatus.canceled, progress: 0.0, error: e.toString(), taskId: task.id);
        } else if (activeTracker?.paused == true) {
          onStatus?.call(TaskStatus.paused);
          return DownloadResult(status: TaskStatus.paused, progress: 0.0, error: e.toString(), taskId: task.id);
        } else if (!isLastAttempt) {
          // retry
          await Future.delayed(const Duration(seconds: 1));
          continue;
        } else {
          onStatus?.call(TaskStatus.failed);
          return DownloadResult(status: TaskStatus.failed, progress: 0.0, error: e.toString(), taskId: task.id);
        }
      } finally {
        try {
          // ensure client is closed
          client.close(force: true);
        } catch (_) {}
      }
    } // end while
  }

  Uri _buildUri(DownloadTask task) {
    final base = Uri.parse(task.url);
    final mergedQuery = <String, String>{};
    mergedQuery.addAll(base.queryParameters);
    mergedQuery.addAll(task.urlQueryParameters);
    return base.replace(queryParameters: mergedQuery.isEmpty ? null : mergedQuery);
  }

  Future<Directory> _getTargetDirectory(String userSubdir) async {
   // Determine the base download directory per platform.
   late final Directory baseDir;
   if (Platform.isAndroid) {
     baseDir = Directory('/storage/emulated/0/Download');
   } else if (Platform.isLinux) {
     baseDir = Directory(p.join(Platform.environment['HOME']!, 'Downloads'));
   } else if (Platform.isWindows) {
     baseDir = Directory(p.join(Platform.environment['USERPROFILE']!, 'Downloads'));
   } else {
     final Directory? downloadsDir = await getDownloadsDirectory();
     baseDir = downloadsDir ?? await getApplicationDocumentsDirectory();
   }
  
   // App-specific subfolder structure.
   const String appFolderName = 'GPTBOX';
   const String downloadsSubFolderName = 'Downloads';
   String appDownloadsPath = p.join(
     baseDir.path,
     appFolderName,
     downloadsSubFolderName,
   );
  
   // Append user-provided subdirectory if any.
   if (userSubdir.isNotEmpty) {
     appDownloadsPath = p.join(appDownloadsPath, userSubdir);
   }
  
   return Directory(appDownloadsPath);
  }

  String _filenameFromUri(Uri uri) {
    final last = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : '';
    if (last.isEmpty) return 'file_${DateTime.now().millisecondsSinceEpoch}';
    return last;
  }

  void _signalCancelActive(_ActiveTask active, {required TaskStatus statusAfterCancel}) {
    active.canceled = true;
    // attempt to cancel the response subscription and close sink
    try {
      active.sub?.cancel();
    } catch (_) {}
    try {
      active.client?.close(force: true);
    } catch (_) {}
    try {
      active.sink?.close();
    } catch (_) {}
    // remove partial file
    try {
      if (active.file != null && active.file!.existsSync()) {
        active.file!.deleteSync();
      }
    } catch (_) {}
    _updates.add(TaskStatusUpdate(taskId: active.task.id, status: statusAfterCancel));
  }

  // For convenience when launching a Future without awaiting and still catching errors
  void unawaited(Future<void> f) {
    f.catchError((e, st) {
      // swallow
    });
  }
}

extension on void {
  operator >(int other) {}
}

/// Small helper to track active work so we can cancel / pause it.
class _ActiveTask {
  final DownloadTask task;
  HttpClient? client;
  StreamSubscription<List<int>>? sub;
  IOSink? sink;
  File? file;
  bool paused = false;
  bool canceled = false;

  _ActiveTask({required this.task});
}