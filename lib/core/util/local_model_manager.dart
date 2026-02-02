import 'package:llm_llamacpp/llm_llamacpp.dart';

class LocalModelManager {
  static LlamaCppChatRepository? _repo;
  static String? _loadedPath;
  static Future<void>? _loadingFuture;

  static bool get isLoaded => _repo != null;
  static String? get loadedPath => _loadedPath;

  static Future<LlamaCppChatRepository> loadModel(
    String modelPath, {
    int contextSize = 4096,
    int nGpuLayers = 0,
  }) async {
    if (_repo != null && _loadedPath == modelPath) {
      final loading = _loadingFuture;
      if (loading != null) {
        await loading;
        _loadingFuture = null;
      }
      return _repo!;
    }

    await eject();

    final repo = LlamaCppChatRepository(
      contextSize: contextSize,
      nGpuLayers: nGpuLayers,
    );
    _repo = repo;
    _loadedPath = modelPath;
    _loadingFuture = repo.loadModel(modelPath);
    await _loadingFuture;
    _loadingFuture = null;
    return repo;
  }

  static Future<void> eject() async {
    final loading = _loadingFuture;
    if (loading != null) {
      try {
        await loading;
      } catch (_) {}
    }
    _loadingFuture = null;
    _repo?.dispose();
    _repo = null;
    _loadedPath = null;
  }
}
