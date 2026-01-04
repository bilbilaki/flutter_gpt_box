 part of 'package:gpt_box/view/page/home/home.dart';

class ResponsesService {
  late http.Client _client;
  final Duration defaultTimeout;

  ResponsesService({
    http.Client? client,
    this.defaultTimeout = const Duration(minutes: 30),
  }) : _client = client ?? httpCli;


  Uri _root() {
    final base = Cfg.current.url.trim().replaceAll(RegExp(r'/+$'), '');
    final root = base.endsWith('/v1') ? base : '$base/v1';
    return Uri.parse('$root/responses');
  }

  Uri _byId(String id) {
    final base = Cfg.current.url.trim().replaceAll(RegExp(r'/+$'), '');
    final root = base.endsWith('/v1') ? base : '$base/v1';
    return Uri.parse('$root/responses/$id');
  }

  Map<String, String> _headers({bool sse = false}) {
    final t = Cfg.current.key;
    return {
      if (t.isNotEmpty) 'Authorization': 'Bearer $t',
      'Content-Type': 'application/json',
      'Accept': sse
          ? 'text/event-stream, application/json'
          : 'application/json',
    };
  }
  Future<DeepResponse> createRaw(Map<String, dynamic> body) async {
    final res = await _client
        .post(_root(), headers: _headers(), body: jsonEncode(body))
        .timeout(defaultTimeout);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return DeepResponse.fromJson(jsonDecode(res.body));
    }
    throw HttpException(
      'Responses.createRaw failed: ${res.statusCode} ${res.body}',
    );
  }

  /// Parse SSE into complete `data:` payloads per event.
  Stream<String> _sseDataEvents(Stream<List<int>> byteStream) async* {
    final decoder = const Utf8Decoder();
    final textStream = byteStream.transform(decoder);

    final buffer = StringBuffer();
    await for (final chunk in textStream) {
      buffer.write(chunk);

      while (true) {
        final full = buffer.toString();
        final sepIndex = full.indexOf('\n\n');
        if (sepIndex == -1) break;

        final eventBlock = full.substring(0, sepIndex);
        final rest = full.substring(sepIndex + 2);
        buffer
          ..clear()
          ..write(rest);

        final lines = eventBlock.split('\n');
        final dataLines = <String>[];
        for (var line in lines) {
          line = line.trimRight();
          if (line.startsWith('data:')) {
            dataLines.add(line.substring(5).trimLeft());
          }
        }
        if (dataLines.isEmpty) continue;

        final data = dataLines.join('\n').trim();
        if (data.isEmpty) continue;

        yield data;
      }
    }
  }

  Future<DeepResponse> create(ResponsesRequest request) async {
    final res = await _client
        .post(
          _root(),
          headers: _headers(),
          body: jsonEncode(request.toJson(stream: false)),
        )
        .timeout(defaultTimeout);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return DeepResponse.fromJson(jsonDecode(res.body));
    }
    throw HttpException(
      'Responses.create failed: ${res.statusCode} ${res.body}',
    );
  }

  Stream<DeepResponseChunk> stream(ResponsesRequest request) async* {
    final req = http.Request('POST', _root());
    req.headers.addAll(_headers(sse: true));
    req.body = jsonEncode(request.toJson(stream: true));

    final streamed = await _client.send(req).timeout(defaultTimeout);
    if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
      final bodyStr = await streamed.stream.bytesToString();
      throw HttpException(
        'Responses.stream failed: ${streamed.statusCode} $bodyStr',
      );
    }

    await for (final data in _sseDataEvents(streamed.stream)) {
      if (data == '[DONE]') {
        yield DeepResponseChunk(raw: const {'done': true});
        break;
      }
      try {
        yield DeepResponseChunk.fromJson(jsonDecode(data));
      } catch (_) {
        yield DeepResponseChunk(raw: {'raw': data});
      }
    }
  }

  Stream<DeepResponseChunk> streamRaw(Map<String, dynamic> body) async* {
    final req = http.Request('POST', _root());
    req.headers.addAll(_headers(sse: true));
    body['stream'] = true;
    if (body['background'] == true) body.remove('background');
    req.body = jsonEncode(body);

    final streamed = await _client.send(req).timeout(defaultTimeout);
    if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
      final bodyStr = await streamed.stream.bytesToString();
      throw HttpException(
        'Responses.streamRaw failed: ${streamed.statusCode} $bodyStr',
      );
    }

    await for (final data in _sseDataEvents(streamed.stream)) {
      if (data == '[DONE]') {
        yield DeepResponseChunk(raw: const {'done': true});
        break;
      }
      try {
        yield DeepResponseChunk.fromJson(jsonDecode(data));
      } catch (_) {
        yield DeepResponseChunk(raw: {'raw': data});
      }
    }
  }

  Future<DeepResponse> retrieve(String id) async {
    final res = await _client
        .get(_byId(id), headers: _headers())
        .timeout(defaultTimeout);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return DeepResponse.fromJson(jsonDecode(res.body));
    }
    throw HttpException(
      'Responses.retrieve failed: ${res.statusCode} ${res.body}',
    );
  }

  void dispose() => _client.close();
}
