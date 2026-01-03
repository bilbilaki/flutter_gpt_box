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
            // Action flags (use exactly one action per call for clarity)
            'checkStatus': {
              'type': 'boolean',
              'description':
                  'Set to true to check the status of download tasks. If "taskId" is provided, it checks that specific task; otherwise, it lists all active/completed tasks. Use this after starting a download to monitor progress (e.g., offer to the user: "Would you like to check the download status?").',
            },
            'cancelTask': {
              'type': 'boolean',
              'description':
                  'Set to true to cancel a specific download task. Requires "taskId". Confirm with the user before canceling (e.g., "Do you want to stop this download?").',
            },
            'installApk': {
              // NEW: APK Installation Action
              'type': 'boolean',
              'description':
                  'Set to true to install an APK file (Android only). Requires "apkPath" (full path to the APK). Use this after downloading an APK and confirming with the user (e.g., "The APK is ready—do you want to install it?"). Warn the user about security risks from untrusted sources.',
            },
            // Parameters for adding a single download task
            'url': {
              'type': 'string',
              'description':
                  'The full URL of the file to download (e.g., "https://example.com/file.zip"). Verify the URL is valid and accessible before calling. Use for single-file downloads.',
            },
            'filename': {
              'type': 'string',
              'description':
                  'Optional: The desired name for the downloaded file (e.g., "myfile.zip"). If omitted, the tool infers it from the URL.',
            },
            'subdir': {
              'type': 'string',
              'description':
                  'Optional: The subdirectory within the default download folder (e.g., "MyDownloads/Subfolder") where the file should be saved. By default, files are saved to "Download Folder/GPTBOX/Download".',
            },
            // Parameters for adding multiple download tasks (batch)
            'batchTasks': {
              'type': 'array',
              'description':
                  'An array of download tasks for batch processing (e.g., multiple files at once). Each item must include a "url"; "filename" is optional. Ideal for 2-5 files; for more or per-file control, call the tool multiple times sequentially. Returns an array of task IDs for status tracking.',
              'items': {
                'type': 'object',
                'properties': {
                  'url': {
                    'type': 'string',
                    'description': 'The full URL of the file to download.',
                  },
                  'filename': {
                    'type': 'string',
                    'description':
                        'Optional: The desired filename for this file.',
                  },
                },
                'required': ['url'],
              },
            },
            // Identifier for status/cancel actions
            'taskId': {
              'type': 'string',
              'description':
                  'The unique ID of a download task (returned by the tool after starting a download). Use this for checking status or canceling a specific task. Store and reference it from previous responses.',
            },
            'apkPath': {
              // NEW: For APK Installation
              'type': 'string',
              'description':
                  'The full local path to the APK file to install (e.g., "/sdcard/Download/app.apk"). Required when "installApk" is true. Get this from the "savedPath" in a download status response.',
            },
          },
          // Note: Exactly one action or download parameter set should be used per call to avoid conflicts
        },
      );

  @override
  String get description => '''
Use this tool to manage file downloads when the user requests downloading one or more files (e.g., "Download this image" or "Get these PDFs for me").
This versatile tool supports five main actions in a single call—choose one per invocation for best results:

1. **Start a Single Download**:
   - Provide "url" (required), optional "filename" and "subdir".
   - The tool returns a "taskId" immediately. Save this ID and offer to check status (e.g., "I've started downloading the file. Want me to check its progress?").
   - Example: User says "Download https://example.com/report.pdf as report.pdf".

2. **Start Multiple Downloads (Batch)**:
   - Provide "batchTasks" as an array of objects with "url" (and optional "filename").
   - Returns an array of "taskId"s for each file.
   - Best for small batches (2-5 files). For larger sets or individual tracking, call the tool multiple times (once per file or small group) to get per-task status easily.
   - Example: User provides multiple URLs; confirm with them before batching.

3. **Check Download Status**:
   - Set "checkStatus" to true.
   - Optionally provide "taskId" for a specific task; omit for all tasks.
   - The response includes progress (e.g., percentage, completed/failed), file path if done, and updated "taskId".
   - Always offer this to the user proactively after starting a download (e.g., "Download started—should I check the status now?"). Re-check periodically if the download is long-running.
   - **APK-Specific Flow**: If the download is an APK (e.g., URL ends with .apk), after it completes (status shows "completed" and a "savedPath"), ask the user: "The APK [filename] has downloaded to [savedPath]. Do you want me to install it now? (Note: Only install from trusted sources to avoid security risks.)" If yes, use "installApk: true" with the "apkPath" from the saved path.
   - Tip: If no "taskId" is available, ask the user for details or list all tasks.

4. **Cancel a Download**:
   - Set "cancelTask" to true and provide "taskId".
   - Returns confirmation. Always confirm intent with the user first.

5. **Install APK (Android Only)**:
   - Set "installApk" to true and provide "apkPath" (full path from a completed download).
   - Triggers installation via the system package installer. Returns success/failure status.
   - **Important**: Only use after user confirmation (e.g., "Yes, install the APK"). Warn about risks: APKs from untrusted sources can contain malware. This action fails on non-Android platforms.
   - Example: After APK download completes, confirm with user, then call with {'installApk': true, 'apkPath': '/sdcard/Download/app.apk'}.

**Best Practices to Avoid Errors**:
- Always confirm URLs and details with the user before invoking—do not assume or generate them.
- Handle responses: Use returned "taskId"(s) for follow-ups. If a download fails, inform the user and suggest retrying.
- For multi-file requests: If the user wants status per file, use multiple tool calls instead of a large batch.
- APK Handling: Detect APK requests (e.g., by URL extension or user mention of "app" or "APK"). Download first, check status, ask for install permission, then install only if confirmed. Never auto-install.
- Security: Only download from trusted URLs; warn the user about potential risks, especially for APKs.

This tool does not support uploading or other file ops—focus on downloads (and APK installs on Android) only.
''';

  @override
  String get l10nName => "Downloader";

  @override
  Future<_Ret?> run(_CallResp call, _Map args, OnToolLog log) async {
    // Use the DownloadManagerService singleton directly (keeps tool in sync with provider changes)
    final svc = DownloadManagerService.I;
    await svc.init();

    // --- Parse Arguments ---
    final checkStatus = args['checkStatus'] as bool? ?? false;
    final cancelTask = args['cancelTask'] as bool? ?? false;
    final installApk = args['installApk'] as bool? ?? false; // NEW
    final taskId = args['taskId'] as String?;
    final url = args['url'] as String?;
    final batchTasks = (args['batchTasks'] as List?)
        ?.cast<Map<String, dynamic>>();
    final apkPath = args['apkPath'] as String?; // NEW

    // --- Action Logic (Ensure only one action per call) ---
    if (checkStatus && cancelTask) {
      final error = ToolError.invalidArgument(
        'action',
        'Both checkStatus and cancelTask are true',
        suggestion:
            'Specify only one action per call: either checkStatus or cancelTask.',
      );
      return [ChatContent.text(error.toMessage())];
    }
    if ((url != null || (batchTasks != null && batchTasks.isNotEmpty)) &&
        (checkStatus || cancelTask || installApk)) {
      final error = ToolError.invalidArgument(
        'action',
        'Download and status/install actions mixed',
        suggestion:
            'Separate download operations from status checks or installations into different calls.',
      );
      return [ChatContent.text(error.toMessage())];
    }
    if (installApk && (checkStatus || cancelTask)) {
      final error = ToolError.invalidArgument(
        'action',
        'APK install mixed with status/cancel',
        suggestion:
            'Separate APK installation from status checks or cancellations into different calls.',
      );
      return [ChatContent.text(error.toMessage())];
    }

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
          final error = ToolError.notFound(
            'Download task with ID "$taskId"',
            suggestion:
                'Verify the taskId from a previous download call or check active/completed tasks.',
          );
          return [ChatContent.text(error.toMessage())];
        }
        log(
          'Status for $taskId: ${item.status}, Progress: ${(item.progress! * 100).toStringAsFixed(1)}%, Path: ${item.savedPath}',
        );
        return [ChatContent.text(_formatItem(item))];
      } else {
        log('Listing status for all tasks');

        final records = <DownloadItem>[...svc.activeItems(), ...svc.history()];
        if (records.isEmpty) {
          final error = ToolError.notFound(
            'Active or recent download tasks',
            suggestion:
                'Start a download first using the downloader tool with a URL.',
          );
          return [ChatContent.text(error.toMessage())];
        }
        final statusList = records.map(_formatItem).join('\n---\n');
        log(
          'All tasks: ${records.length} items (active: ${svc.activeItems().length}, history: ${svc.history().length})',
        );
        return [ChatContent.text(statusList)];
      }
    }

    // 2. Cancel Task
    if (cancelTask) {
      if (taskId == null || taskId.isEmpty) {
        final error = ToolError.invalidInput(
          'taskId',
          suggestion:
              'Provide a valid taskId from a previous download operation.',
        );
        return [ChatContent.text(error.toMessage())];
      }
      log('Attempting to cancel task: $taskId');

      final success = await svc.cancel(taskId);
      if (success) {
        log('Cancellation signaled for $taskId');
        return [
          ChatContent.text(
            'Successfully signaled cancellation for task: $taskId',
          ),
        ];
      } else {
        log('Cancellation failed for $taskId');
        final error = ToolError.executionFailed(
          'Failed to cancel task',
          suggestion:
              'The task may not exist or may have already completed. Verify the taskId.',
        );
        return [ChatContent.text(error.toMessage())];
      }
    }

    // 4. Add Batch Tasks
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
      log(
        'Batch enqueued: ${taskIds.length} tasks, IDs: ${taskIds.join(', ')}',
      );
      return [
        ChatContent.text(
          'Successfully enqueued ${taskIds.length} download tasks. Task IDs: ${taskIds.join(', ')}',
        ),
      ];
    }

    // 5. Add Single Task
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
    final error = ToolError.invalidInput(
      'action',
      suggestion:
          'Specify one of: url (single download), batchTasks (multiple downloads), checkStatus, cancelTask, or installApk.',
    );
    return [ChatContent.text(error.toMessage())];
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
      // APK Hint: If it's an APK, suggest next step in the response
      if (item.filename!.toLowerCase().endsWith('.apk')) {
        result += '\n(APK detected: Ready for installation if user confirms)';
      }
    }
    return result;
  }
}
