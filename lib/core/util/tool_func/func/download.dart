part of '../tool.dart';

/// Tool for managing file downloads.
final class TfDownloader extends ToolFunc {
  static const instance = TfDownloader._();

  const TfDownloader._()
    : super(
        name: 'downloader',
        parametersSchema: const {
          'type': 'object',
          'properties': {
            // Action flags
            'checkStatus': {
              'type': 'boolean',
              'description':
                  'Set to true to check download status. If taskId is also provided, checks a specific task; otherwise, lists all tasks.',
            },
            'cancelTask': {
              'type': 'boolean',
              'description':
                  'Set to true to cancel a download. The "taskId" parameter is required for this action.',
            },
            // Parameters for adding a single task
            'url': {
              'type': 'string',
              'description':
                  'The URL of the file to download for a single task.',
            },
            'filename': {
              'type': 'string',
              'description':
                  'Optional. The desired filename for the download. If not provided, a name will be inferred from the URL.',
            },
            'subdir': {
              'type': 'string',
              'description':
                  'Optional. The desired of subdirectory user want to file saved to that.in default files saved at Download Folder/GPTBOX/Download',
            },
            // Parameters for adding multiple tasks
            'batchTasks': {
              'type': 'array',
              'description':
                  "An array of download tasks to be added in a batch. Each item in the array should be an object with a 'url' and an optional 'filename'.",
              'items': {
                'type': 'object',
                'properties': {
                  'url': {'type': 'string'},
                  'filename': {'type': 'string'},
                },
                'required': ['url'],
              },
            },
            // Identifier for status/cancel actions
            'taskId': {
              'type': 'string',
              'description':
                  'The unique ID of a download task. Used when checking status or canceling a specific task.',
            },
          },
        },
      );

  @override
  String get description => '''
Manages file downloads. This single tool can perform multiple actions:
1.  **Add a new download**: Provide the 'url' and optional 'filename'.
2.  **Add multiple downloads**: Provide a 'batchTasks' list.
3.  **Check status**: Set 'checkStatus' to true. Provide 'taskId' for a specific task, or omit it to see all tasks.
4.  **Cancel a download**: Set 'cancelTask' to true and provide the 'taskId'.
The tool will return a task ID when a new download is started, which you can use for later status checks or cancellations.''';

  @override
  String get l10nName => "Downloader";

  @override
  Future<_Ret?> run(_CallResp call, _Map args, OnToolLog log) async {
    // Ensure the provider is started and tracking tasks
    final downloader = DownloadProvider.instance;
    downloader.start();
    // This ensures the provider is listening to updates. It's safe to call multiple times.
    downloader.trackTasks();

    // --- Parse Arguments ---
    final checkStatus = args['checkStatus'] as bool? ?? false;
    final cancelTask = args['cancelTask'] as bool? ?? false;
    final taskId = args['taskId'] as String?;
    final url = args['url'] as String?;
    final batchTasks = (args['batchTasks'] as List?)
        ?.cast<Map<String, dynamic>>();

    // --- Action Logic ---

    // 1. Check Status
    if (checkStatus) {
      if (taskId != null) {
        log('Checking status for task: $taskId');
        final record = downloader.snapshotRecordForId(taskId);
        if (record == null) {
          return [ChatContent.text('No download task found with ID: $taskId')];
        }
        return [ChatContent.text(_formatRecord(record))];
      } else {
        log('Listing status for all tasks');
        final records = downloader.snapshotRecords();
        if (records.isEmpty) {
          return [
            ChatContent.text('There are no active or recent download tasks.'),
          ];
        }
        final statusList = records.map(_formatRecord).join('\n---\n');
        return [ChatContent.text(statusList)];
      }
    }

    // 2. Cancel Task
    if (cancelTask) {
      if (taskId == null || taskId.isEmpty) {
        return [
          ChatContent.text('Error: A "taskId" is required to cancel a task.'),
        ];
      }
      log('Attempting to cancel task: $taskId');
      final success = downloader.cancel(taskId);
      if (success) {
        return [
          ChatContent.text(
            'Successfully signaled cancellation for task: $taskId',
          ),
        ];
      } else {
        return [
          ChatContent.text(
            'Failed to cancel task: $taskId. It may not exist or may have already completed.',
          ),
        ];
      }
    }

    // 3. Add Batch Tasks
    if (batchTasks != null && batchTasks.isNotEmpty) {
      log('Enqueuing ${batchTasks.length} batch download tasks.');
      final tasks = <DownloadTask>[];
      final taskIds = <String>[];

      for (final taskData in batchTasks) {
        final taskUrl = taskData['url'] as String?;
        if (taskUrl != null) {
          final id = shortid.generate();
          taskIds.add(id);
          tasks.add(
            DownloadTask(
              id: id,
              url: taskUrl,
              filename: taskData['filename'] as String? ?? '',
              createdAt: DateTime.now(),
            ),
          );
        }
      }

      await downloader.enqueueAll(tasks);
      return [
        ChatContent.text(
          'Successfully enqueued ${tasks.length} download tasks. Task IDs: ${taskIds.join(', ')}',
        ),
      ];
    }
    // 4. Add Single Task
    if (url != null && url.isNotEmpty) {
      final tasks = <DownloadTask>[];
      final taskIds = <String>[];
      final id = shortid.generate();
      taskIds.add(id);
      tasks.add(
        DownloadTask(
          id: id,
          url: url,
          filename: args['filename'] as String? ?? '',
          createdAt: DateTime.now(),
          directory: args['subdir']??'', 
        ),
      );
      log('Enqueuing single download: $url. Task ID: ${taskIds.first}');
      await downloader.enqueue(tasks.first);
      return [
        ChatContent.text(
          'Download task successfully added. Your Task ID is: ${taskIds.first}',
        ),
      ];
    }

    // Fallback: If no valid action was specified
    return [
      ChatContent.text(
        'Invalid downloader arguments. Please specify a valid action (add, check status, or cancel a task).',
      ),
    ];
  }

  String _formatRecord(DownloadRecord record) {
    final progressPercent = (record.progress * 100).toStringAsFixed(1);
    final status = record.status.toString().split('.').last;
    final filename = record.task?.filename.isNotEmpty == true
        ? record.task!.filename
        : 'N/A';
    var result = 'ID: ${record.taskId}\n';
    result += 'Status: $status\n';
    result += 'Filename: $filename\n';
    result += 'Progress: $progressPercent%';
    if (record.status == TaskStatus.complete && record.subDirPath != null) {
      result += '\nFile Path: ${record.subDirPath}';
    }
    if (record.status == TaskStatus.failed && record.error != null) {
      result += '\nError: ${record.error}';
    }
    return result;
  }
}
