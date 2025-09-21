import 'package:flutter/foundation.dart';
import 'package:gpt_box/data/model/download.dart';
import '../services/download_manager_service.dart';

/// ChangeNotifier provider for UI
class DownloadProvider extends ChangeNotifier {
  final DownloadManagerService _svc = DownloadManagerService.I;

  List<DownloadItem> _active = const [];
  List<DownloadItem> _history = const [];

  List<DownloadItem> get active => _active;
  List<DownloadItem> get history => _history;

  Future<void> init() async {
    await _svc.init();
    _refresh();
  }

  void _refresh() {
    _active = _svc.activeItems();
    _history = _svc.history();
    notifyListeners();
  }

  Future<String?> addDownload(DownloadRequest req) async {
    final id = await _svc.enqueueSingle(req);
    _refresh();
    return id;
  }

  Future<List<bool>> addDownloads(List<DownloadRequest> reqs) async {
    final n = await _svc.enqueueMany(reqs);
    _refresh();
    return n;
  }

  Future<void> pause(String taskId) async {
    await _svc.pause(taskId);
  }

  Future<void> resume(String taskId) async {
    await _svc.resume(taskId);
  }

  Future<void> cancel(String taskId) async {
    await _svc.cancel(taskId);
    _refresh();
  }

  Future<void> cancelAll({String? group}) async {
    await _svc.cancelAll(group: group);
    _refresh();
  }

  Future<bool> openFile(String taskId) => _svc.openFileByTaskId(taskId);

  void setDefaultFolder({
    String? appFolderName,
    String? folderUnderApp,
    String? userSubdir,
  }) {
    _svc.setDefaultFolder(
      appFolderName: appFolderName,
      folderUnderApp: folderUnderApp,
      userSubdir: userSubdir,
    );
  }
}
