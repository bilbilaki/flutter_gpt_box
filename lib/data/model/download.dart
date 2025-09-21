import 'dart:convert';
import 'dart:io';
import 'package:background_downloader/background_downloader.dart';
import 'package:hive_ce/hive.dart';

part 'download.g.dart';

enum DownloadUiStatus {
  enqueued,
  running,
  paused,
  waitingToRetry,
  complete,
  canceled,
  failed,
  notFound,
}

DownloadUiStatus mapTaskStatus(TaskStatus s) {
  switch (s) {
    case TaskStatus.enqueued:
      return DownloadUiStatus.enqueued;
    case TaskStatus.running:
      return DownloadUiStatus.running;
    case TaskStatus.paused:
      return DownloadUiStatus.paused;
    case TaskStatus.waitingToRetry:
      return DownloadUiStatus.waitingToRetry;
    case TaskStatus.complete:
      return DownloadUiStatus.complete;
    case TaskStatus.canceled:
      return DownloadUiStatus.canceled;
    case TaskStatus.failed:
      return DownloadUiStatus.failed;
    case TaskStatus.notFound:
      return DownloadUiStatus.notFound;
  }
}

/// Input object to request a download
class DownloadRequest {
  final String url;
  final String?
  filename; // null -> let server suggest, or use last path segment
  final Map<String, String>? headers;
  final Map<String, String>? urlQueryParameters;
  final bool allowPause;
  final bool requiresWiFi;
  final String group;
  final String displayName;
  final String metaData;
  final bool openAfterComplete;
  final bool moveToSharedDownloads; // Android: move after completion
  final String folderUnderApp; // e.g. "Downloads"
  final String userSubdir; // e.g. "user123/sessionA"

  const DownloadRequest({
    required this.url,
    this.filename,
    this.headers,
    this.urlQueryParameters,
    this.allowPause = true,
    this.requiresWiFi = false,
    this.group = FileDownloader.defaultGroup,
    this.displayName = '',
    this.metaData = '',
    this.openAfterComplete = false,
    this.moveToSharedDownloads = true,
    this.folderUnderApp = 'Downloads',
    this.userSubdir = '',
  });

  Map<String, dynamic> toJson() => {
    'url': url,
    'filename': filename,
    'headers': headers,
    'urlQueryParameters': urlQueryParameters,
    'allowPause': allowPause,
    'requiresWiFi': requiresWiFi,
    'group': group,
    'displayName': displayName,
    'metaData': metaData,
    'openAfterComplete': openAfterComplete,
    'moveToSharedDownloads': moveToSharedDownloads,
    'folderUnderApp': folderUnderApp,
    'userSubdir': userSubdir,
  };

  factory DownloadRequest.fromJson(Map<String, dynamic> json) =>
      DownloadRequest(
        url: json['url'] as String,
        filename: json['filename'] as String?,
        headers: (json['headers'] as Map?)?.cast<String, String>(),
        urlQueryParameters: (json['urlQueryParameters'] as Map?)
            ?.cast<String, String>(),
        allowPause: json['allowPause'] as bool? ?? true,
        requiresWiFi: json['requiresWiFi'] as bool? ?? false,
        group: json['group'] as String? ?? FileDownloader.defaultGroup,
        displayName: json['displayName'] as String? ?? '',
        metaData: json['metaData'] as String? ?? '',
        openAfterComplete: json['openAfterComplete'] as bool? ?? false,
        moveToSharedDownloads: json['moveToSharedDownloads'] as bool? ?? true,
        folderUnderApp: json['folderUnderApp'] as String? ?? 'Downloads',
        userSubdir: json['userSubdir'] as String? ?? '',
      );
}

/// UI model to track a task in memory and in Hive history
@HiveType(typeId: 112)
class DownloadItem extends HiveObject {
  @HiveField(0)
  String taskId;

  @HiveField(1)
  String? url;

  @HiveField(2)
  String? filename;

  @HiveField(3)
  String? savedPath; // absolute path if known

  @HiveField(4)
  DownloadUiStatus? status;

  @HiveField(5)
  double? progress; // 0..1 or negatives for special meaning

  @HiveField(6)
  int? expectedFileSize;

  @HiveField(7)
  double? networkSpeedBytesPerSec;

  @HiveField(8)
  int? timeRemainingSeconds;

  @HiveField(9)
  String? group;

  @HiveField(10)
  bool? openAfterComplete;

  @HiveField(11)
  DateTime? createdAt;

  @HiveField(12)
  DateTime? finishedAt;

  @HiveField(13)
  String? displayName;

  @HiveField(14)
  String? metaData;

  DownloadItem({
    required this.taskId,
     this.url,
     this.filename,
     this.savedPath,
     this.status,
     this.progress,
     this.expectedFileSize,
     this.networkSpeedBytesPerSec,
     this.timeRemainingSeconds,
     this.group,
     this.openAfterComplete,
     this.createdAt,
     this.finishedAt,
     this.displayName,
     this.metaData,
  });

  Map<String, dynamic> toJson() => {
    'taskId': taskId,
    'url': url,
    'filename': filename,
    'savedPath': savedPath,
    'status': status!.name,
    'progress': progress,
    'expectedFileSize': expectedFileSize,
    'networkSpeedBytesPerSec': networkSpeedBytesPerSec,
    'timeRemainingSeconds': timeRemainingSeconds,
    'group': group,
    'openAfterComplete': openAfterComplete,
    'createdAt': createdAt!.toIso8601String(),
    'finishedAt': finishedAt?.toIso8601String(),
    'displayName': displayName,
    'metaData': metaData,
  };

  factory DownloadItem.fromJson(Map<String, dynamic> json) => DownloadItem(
    taskId: json['taskId'],
    url: json['url'],
    filename: json['filename'],
    savedPath: json['savedPath'] ?? '',
    status: DownloadUiStatus.values.firstWhere(
      (e) => e.name == json['status'],
      orElse: () => DownloadUiStatus.enqueued,
    ),
    progress: (json['progress'] as num).toDouble(),
    expectedFileSize: json['expectedFileSize'] as int?,
    networkSpeedBytesPerSec: (json['networkSpeedBytesPerSec'] as num?)
        ?.toDouble(),
    timeRemainingSeconds: json['timeRemainingSeconds'] as int?,
    group: json['group'] ?? FileDownloader.defaultGroup,
    openAfterComplete: json['openAfterComplete'] ?? false,
    createdAt: DateTime.parse(json['createdAt']),
    finishedAt: json['finishedAt'] != null
        ? DateTime.parse(json['finishedAt'])
        : null,
    displayName: json['displayName'] ?? '',
    metaData: json['metaData'] ?? '',
  );
}
