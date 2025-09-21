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
    this.defaultTimeout = const Duration(minutes: 30),
  }) : _client = client ?? http.Client();

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

  Stream<DeepResponseChunk> stream(ResponsesRequest request) async* {
    final req = http.Request('POST', _root());
    final body = request.toJson(stream: true);
    req.headers.addAll(_headers(sse: true));
    req.body = jsonEncode(body);

    final streamed = await _client.send(req).timeout(defaultTimeout);
    if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
      final bodyStr = await streamed.stream.bytesToString();
      throw HttpException(
        'Responses.stream failed: ${streamed.statusCode} $bodyStr',
      );
    }

    final decoder = const Utf8Decoder();
    final split = const LineSplitter();
    final lines = streamed.stream.transform(decoder).transform(split);

    await for (final raw in lines) {
      final line = raw.trim();
      if (line.isEmpty) continue;
      var data = line;
      if (data.startsWith('data:')) data = data.substring(5).trim();
      if (data.isEmpty) continue;
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

    final decoder = const Utf8Decoder();
    final split = const LineSplitter();
    final lines = streamed.stream.transform(decoder).transform(split);

    await for (final raw in lines) {
      final line = raw.trim();
      if (line.isEmpty) continue;
      var data = line;
      if (data.startsWith('data:')) data = data.substring(5).trim();
      if (data.isEmpty) continue;
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

  Future<DeepResponse> waitUntilDone(
    String id, {
    Duration pollEvery = const Duration(seconds: 4),
    Duration maxWait = const Duration(minutes: 30),
  }) async {
    final sw = Stopwatch()..start();
    DeepResponse last = await retrieve(id);
    while (sw.elapsed < maxWait) {
      if (last.status == 'completed' ||
          last.status == 'failed' ||
          last.status == 'cancelled') {
        return last;
      }
      await Future.delayed(pollEvery);
      last = await retrieve(id);
    }
    throw TimeoutException('waitUntilDone timed out', sw.elapsed);
  }

  void dispose() => _client.close();
}
