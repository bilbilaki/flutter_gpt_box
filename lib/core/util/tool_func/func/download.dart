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

// ...existing code...
  @override
  Future<_Ret?> run(_CallResp call, _Map args, OnToolLog log) async {

   // Use the DownloadManagerService singleton directly (keeps tool in sync with provider changes)
   final svc = DownloadManagerService.I;
   await svc.init();
 
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
       // Look for the task in active items first, then history
       DownloadItem? findById(String id) {
         for (final it in svc.activeItems()) {
           if (it.taskId == id) return it;
         }
         for (final it in svc.history()) {
           if (it.taskId == id) return it;
         }
         return null;
       }

       final item = findById(taskId);
       if (item == null) {
         return [ChatContent.text('No download task found with ID: $taskId')];
       }
       return [ChatContent.text(_formatItem(item))];
       } else {
         log('Listing status for all tasks');

       final records = <DownloadItem>[
         ...svc.activeItems(),
         ...svc.history(),
       ];
       if (records.isEmpty) {
         return [
           ChatContent.text('There are no active or recent download tasks.'),
         ];
       }
       final statusList = records.map(_formatItem).join('\n---\n');
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


     final success = await svc.cancel(taskId);
     if (success) {
       return [
         ChatContent.text('Successfully signaled cancellation for task: $taskId'),
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

     final taskIds = <String>[];
     for (final taskData in batchTasks) {
       final taskUrl = taskData['url'] as String?;
       if (taskUrl == null) continue;
       final req = DownloadRequest(
         url: taskUrl,
         filename: taskData['filename'] as String? ?? '',
         userSubdir: taskData['subdir'] as String? ?? '',
       );
       final id = await svc.enqueueSingle(req);
       if (id != null) taskIds.add(id);
     }
     return [
       ChatContent.text(
         'Successfully enqueued ${taskIds.length} download tasks. Task IDs: ${taskIds.join(', ')}',
       ),
     ];
     }
     // 4. Add Single Task
     if (url != null && url.isNotEmpty) {

     final req = DownloadRequest(
       url: url,
       filename: args['filename'] as String? ?? '',
       userSubdir: args['subdir'] as String? ?? '',
     );
     final id = await svc.enqueueSingle(req);
     log('Enqueuing single download: $url. Task ID: $id');
     return [
       ChatContent.text(
         'Download task successfully added. Your Task ID is: ${id ?? 'unknown'}',
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
 

 String _formatItem(DownloadItem item) {
   final progressPercent = (item.progress! * 100).toStringAsFixed(1);
   final status = item.status!.name;
   final filename = item.filename!.isNotEmpty ? item.filename : 'N/A';
   var result = 'ID: ${item.taskId}\n';
   result += 'Status: $status\n';
   result += 'Filename: $filename\n';
   result += 'Progress: $progressPercent%';
   if (item.savedPath!.isNotEmpty) {
     result += '\nFile Path: ${item.savedPath}';
   }
   return result;
 }
}