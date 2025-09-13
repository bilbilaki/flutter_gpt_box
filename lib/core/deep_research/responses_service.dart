import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:gpt_box/data/res/openai.dart';
import 'package:http/http.dart' as http;
import 'responses_models.dart';

class ResponsesService {
  final http.Client _client;
  final Duration defaultTimeout;

  ResponsesService({
    http.Client? client,
    this.defaultTimeout = const Duration(minutes: 60),
  }) : _client = client ?? http.Client();

  Uri _endpoint() {
    final base = Cfg.current.url.trim().replaceAll(RegExp(r'/+$'), '');
    final root = base.endsWith('/v1') ? base : '$base/v1';
    return Uri.parse('$root/responses');
  }

  Uri _retrieveEndpoint(String id) {
    final base = Cfg.current.url.trim().replaceAll(RegExp(r'/+$'), '');
    final root = base.endsWith('/v1') ? base : '$base/v1';
    return Uri.parse('$root/responses/$id');
  }

  Map<String, String> _headers({bool sse = false}) {
    final token = Cfg.current.key;
    final base = <String, String>{
      if (token.isNotEmpty) 'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
      'Accept': sse
          ? 'text/event-stream, application/json'
          : 'application/json',
    };
    return base;
  }

  /// Create a deep research request (foreground, non-stream).
  /// If request.background == true, OpenAI returns a background job object; you should call retrieve() later.
  Future<DeepResponse> create(DeepResearchRequest request) async {
    final res = await _client
        .post(
          _endpoint(),
          headers: _headers(),
          body: jsonEncode(request.toJson(stream: false)),
        )
        .timeout(defaultTimeout);

    if (res.statusCode >= 200 && res.statusCode < 300) {
      final obj = jsonDecode(res.body) as Map<String, dynamic>;
      return DeepResponse.fromJson(obj);
    }
    throw HttpException(
      'Responses.create failed: ${res.statusCode} ${res.body}',
    );
  }

  /// Create a deep research request and stream SSE chunks (foreground only).
  /// Note: Do not set background=true when streaming.
  Stream<DeepResponseChunk> stream(DeepResearchRequest request) async* {
    final http.Request req = http.Request('POST', _endpoint());
    req.headers.addAll(_headers(sse: true));
    final body = request.toJson(stream: true);
    // Ensure streaming and background are not both on
    body.removeWhere((k, v) => k == 'background' && v == true);
    req.body = jsonEncode(body);

    final streamed = await _client.send(req).timeout(defaultTimeout);

    if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
      final bodyStr = await streamed.stream.bytesToString();
      throw HttpException(
        'Responses.stream failed: ${streamed.statusCode} $bodyStr',
      );
    }

    final decoder = const Utf8Decoder();
    final lineSplitter = const LineSplitter();
    final stream = streamed.stream.transform(decoder).transform(lineSplitter);

    await for (final rawLine in stream) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;
      String data = line;
      if (data.startsWith('data:')) data = data.substring(5).trim();
      if (data.isEmpty) continue;
      if (data == '[DONE]') {
        yield DeepResponseChunk(raw: const {'done': true});
        break;
      }
      try {
        final Map<String, dynamic> jsonObj = jsonDecode(data);
        yield DeepResponseChunk.fromJson(jsonObj);
      } catch (_) {
        // non-JSON chunk; surface as raw
        yield DeepResponseChunk(raw: {'raw': data});
      }
    }
  }

  /// Retrieve a response by id (useful for background jobs).
  Future<DeepResponse> retrieve(String id) async {
    final res = await _client
        .get(_retrieveEndpoint(id), headers: _headers())
        .timeout(defaultTimeout);

    if (res.statusCode >= 200 && res.statusCode < 300) {
      final obj = jsonDecode(res.body) as Map<String, dynamic>;
      return DeepResponse.fromJson(obj);
    }
    throw HttpException(
      'Responses.retrieve failed: ${res.statusCode} ${res.body}',
    );
  }

  /// Poll until completed or timeout. Returns the final DeepResponse.
  Future<DeepResponse> waitUntilDone(
    String id, {
    Duration pollEvery = const Duration(seconds: 4),
    Duration maxWait = const Duration(minutes: 60),
    bool Function(DeepResponse r)? isDone,
  }) async {
    final sw = Stopwatch()..start();

    bool done(DeepResponse r) {
      if (isDone != null) return isDone(r);
      return r.status == 'completed' ||
          r.status == 'failed' ||
          r.status == 'cancelled';
    }

    DeepResponse last = await retrieve(id);
    if (done(last)) return last;

    while (sw.elapsed < maxWait) {
      await Future.delayed(pollEvery);
      last = await retrieve(id);
      if (done(last)) return last;
    }
    throw TimeoutException(
      'waitUntilDone timed out after $maxWait',
      sw.elapsed,
    );
  }

  void dispose() => _client.close();
}
