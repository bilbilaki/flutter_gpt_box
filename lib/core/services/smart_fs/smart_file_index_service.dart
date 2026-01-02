import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';

import 'models.dart';
import 'providers.dart';

class RemoteLink {
  final String url;
  final Map<String, String>? headers;
  const RemoteLink(this.url, {this.headers});
}

class IndexedFile {
  final String id;
  final String name; // base name, may include extension
  final String extension; // without dot
  final Uint8List? bytes; // in-memory (generated)
  final String? locator; // provider-specific locator
  final String? providerName;
  final RemoteLink? remote;

  const IndexedFile({
    required this.id,
    required this.name,
    required this.extension,
    this.bytes,
    this.locator,
    this.providerName,
    this.remote,
  });

  bool get isGenerated => bytes != null;
  bool get isLocal => locator != null && providerName != null;
  bool get isRemote => remote != null;
}

class SmartFileIndexService {
  SmartFileIndexService({
    required List<StorageProvider> providers,
    Dio? dio,
  })  : _providers = {for (final p in providers) p.name: p},
        _dio = dio ?? Dio();

  final Map<String, StorageProvider> _providers;
  final Dio _dio;
  final _uuid = const Uuid();

  final Map<String, IndexedFile> _index = {}; // id -> file

  StorageProvider provider(String name) {
    final p = _providers[name];
    if (p == null) throw StateError('Provider not registered: $name');
    return p;
  }

  String _newId() => _uuid.v4();

  /// Add generated/in-memory file
  String addGenerated({
    required String name,
    required Uint8List bytes,
  }) {
    final id = _newId();
    _index[id] = IndexedFile(
      id: id,
      name: name,
      extension: extFromName(name),
      bytes: bytes,
    );
    return id;
  }

  /// Index an existing local file entity from a provider.
  String indexLocalEntity({
    required StorageProvider provider,
    required FsEntityInfo entity,
  }) {
    final id = _newId();
    _index[id] = IndexedFile(
      id: id,
      name: entity.name,
      extension: entity.extension,
      locator: entity.locator,
      providerName: provider.name,
    );
    return id;
  }

  /// Index a remote file (download on demand)
  String indexRemote({
    required String name,
    required String url,
    Map<String, String>? headers,
  }) {
    final id = _newId();
    _index[id] = IndexedFile(
      id: id,
      name: name,
      extension: extFromName(name),
      remote: RemoteLink(url, headers: headers),
    );
    return id;
  }

  IndexedFile? get(String id) => _index[id];

  void clear() => _index.clear();

  /// List and index files from provider directory.
  /// Returns lightweight JSON-friendly maps (similar to your old API).
  Future<List<Map<String, dynamic>>> listAndIndex(
    StorageProvider provider,
    String directoryLocator, {
    Set<String>? extensions, // without dot, lowercase
  }) async {
    final children = await provider.list(directoryLocator);
    final out = <Map<String, dynamic>>[];

    for (final e in children) {
      if (e.type != FsEntityType.file) continue;

      final ext = e.extension;
      if (extensions != null && extensions.isNotEmpty) {
        if (!extensions.contains(ext)) continue;
      }

      final id = indexLocalEntity(provider: provider, entity: e);
      out.add({
        ...e.toJson(),
        'id': id, // override entity id with indexed id
      });
    }

    return out;
  }

  Future<Map<String, dynamic>> tree(StorageProvider provider, String root) =>
      provider.tree(root);

  /// Read bytes for any indexed file (generated/local/remote)
  Future<FsReadResult> readById(
    String id, {
    bool tryDecodeUtf8 = true,
  }) async {
    final item = _index[id];
    if (item == null) {
      throw StateError('Not indexed: $id');
    }

    if (item.bytes != null) {
      final bytes = item.bytes!;
      String? text;
      if (tryDecodeUtf8) {
        try {
          text = utf8.decode(bytes, allowMalformed: true);
        } catch (_) {}
      }
      return FsReadResult(bytes, text: text);
    }

    if (item.isLocal) {
      final p = provider(item.providerName!);
      return p.readFile(item.locator!, tryDecodeUtf8: tryDecodeUtf8);
    }

    if (item.isRemote) {
      final r = item.remote!;
      final resp = await _dio.get<List<int>>(
        r.url,
        options: Options(
          responseType: ResponseType.bytes,
          headers: r.headers,
        ),
      );
      final bytes = Uint8List.fromList(resp.data ?? const []);
      String? text;
      if (tryDecodeUtf8) {
        try {
          text = utf8.decode(bytes, allowMalformed: true);
        } catch (_) {}
      }
      return FsReadResult(bytes, text: text);
    }

    throw StateError('No source for indexed file: $id');
  }

  /// Save/export an indexed file into a provider directory (sandbox or desktop workspace).
  /// For Android "Downloads"/user folders, you should export using a save dialog (see note below).
  Future<FsEntityInfo> exportToProviderDir(
    String id, {
    required StorageProvider destinationProvider,
    required String destinationDirectoryLocator,
    String? overrideFileName,
    bool overwrite = true,
  }) async {
    final item = _index[id];
    if (item == null) throw StateError('Not indexed: $id');

    final read = await readById(id, tryDecodeUtf8: false);
    final fileName = overrideFileName ?? item.name;

    return destinationProvider.writeFile(
      destinationDirectoryLocator,
      fileName: fileName,
      bytes: read.bytes,
      overwrite: overwrite,
    );
  }

  /// Delete local entity by indexed id (only if local).
  Future<void> deleteLocalById(String id, {bool recursive = false}) async {
    final item = _index[id];
    if (item == null) return;
    if (!item.isLocal) throw StateError('Not a local entity: $id');

    final p = provider(item.providerName!);
    await p.deleteEntity(item.locator!, recursive: recursive);
    _index.remove(id);
  }
}