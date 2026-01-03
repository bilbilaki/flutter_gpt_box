import 'package:gpt_box/data/res/openai.dart';

class AudioEndpoints {
  // Ensures a single /v1 before endpoint
  static String _normalizeBase(String base) {
    final b = base.trim().replaceAll(RegExp(r'/+$'), '');
    if (b.endsWith('/v1')) return b;
    if (b.endsWith('/v1/')) return b.substring(0, b.length - 1);
    return '$b/v1';
  }

  static Uri transcriptions() {
    final base = _normalizeBase(Cfg.current.url);
    return Uri.parse('$base/audio/transcriptions');
  }

  static Uri speech() {
    final base = _normalizeBase(Cfg.current.url);
    return Uri.parse('$base/audio/speech');
  }

  static Map<String, String> authHeaders({Map<String, String>? extra}) {
    final key = Cfg.current.key;
    final headers = <String, String>{
      if (key.isNotEmpty) 'Authorization': 'Bearer $key',
    };
    if (extra != null) headers.addAll(extra);
    return headers;
  }
}
