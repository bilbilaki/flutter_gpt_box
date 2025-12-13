import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'audio_endpoints.dart';

class TtsChunk {
  final Uint8List bytes;
  final bool done;
  const TtsChunk({required this.bytes, this.done = false});
}

class TtsService {
  final http.Client _client;
  TtsService({http.Client? client}) : _client = client ?? http.Client();

  Uri _endpoint() => AudioEndpoints.speech();
  Map<String, String> _headers({bool sse = false}) =>
      AudioEndpoints.authHeaders(
        extra: {
          'Content-Type': 'application/json',
          'Accept': sse
              ? 'text/event-stream, application/json'
              : 'application/json',
        },
      );

  Future<Uint8List> synthesize({
    required String model,
    required String input,
    required String voice,
    String format = 'wav', // or 'mp3'
  }) async {
    final res = await _client.post(
      _endpoint(),
      headers: _headers(),
      body: jsonEncode({
        'model': model,
        'input': input,
        'voice': voice,
        'format': format,
      }),
    );
    if (res.statusCode >= 200 && res.statusCode < 300) {
      // Many providers return binary audio directly. If JSON with base64 is returned, detect and decode.
      final ct = res.headers['content-type'] ?? '';
      if (ct.contains('application/json')) {
        final obj = jsonDecode(res.body);
        final b64 = (obj['audio'] ?? obj['data'])?.toString();
        if (b64 != null) {
          return base64.decode(b64);
        }
      }
      return res.bodyBytes;
    }
    throw Exception('TTS synthesize failed: ${res.statusCode} ${res.body}');
  }

  Stream<TtsChunk> streamSynthesize({
    required String model,
    required String input,
    required String voice,
  }) async* {
    final req = http.Request('POST', _endpoint());
    req.headers.addAll(_headers(sse: true));
    req.body = jsonEncode({
      'model': model,
      'input': input,
      'voice': voice,
      'stream': true,
      'stream_format': 'sse',
    });

    final streamed = await _client.send(req);
    if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
      final body = await streamed.stream.bytesToString();
      throw Exception('TTS stream failed: ${streamed.statusCode} $body');
    }

    final decoder = const Utf8Decoder();
    final buffer = StringBuffer();
    await for (final chunk in streamed.stream) {
      buffer.write(decoder.convert(chunk));

      while (true) {
        final all = buffer.toString();
        final idx = all.indexOf('\n\n');
        if (idx == -1) break;

        final block = all.substring(0, idx).trim();
        final remain = all.substring(idx + 2);
        buffer.clear();
        buffer.write(remain);

        final lines = block.split(RegExp(r'\r?\n'));
        final dataLines = <String>[];
        for (final l in lines) {
          if (l.startsWith('data:')) dataLines.add(l.substring(5).trim());
        }
        if (dataLines.isEmpty) continue;

        final dataStr = dataLines.join('\n');
        if (dataStr == '[DONE]') {
          yield TtsChunk(bytes: Uint8List(0), done: true);
          return;
        }

        Uint8List? bytes;
        try {
          final parsed = jsonDecode(dataStr);
          if (parsed is Map && parsed['audio'] is String) {
            bytes = base64.decode(parsed['audio'] as String);
          } else if (parsed is String) {
            bytes = base64.decode(parsed);
          }
        } catch (_) {
          try {
            bytes = base64.decode(dataStr);
          } catch (_) {
            bytes = null;
          }
        }

        if (bytes != null) {
          yield TtsChunk(bytes: bytes, done: false);
        }
      }
    }
    yield TtsChunk(bytes: Uint8List(0), done: true);
  }

  void dispose() => _client.close();
}
