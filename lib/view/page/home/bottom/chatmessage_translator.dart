part of '../home.dart';
class TranslatableText extends StatefulWidget {
  const TranslatableText(
    this.text, {
    super.key,
    required this.targetLang,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
  });

  final String text;
  final String targetLang;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  @override
  State<TranslatableText> createState() => _TranslatableTextState();
}

class _TranslatableTextState extends State<TranslatableText> {
  String _display = '';

  @override
  void initState() {
    super.initState();
    final svc = TranslationService(
      apiKey: Cfg.current.key,
      baseUrl: Cfg.current.url,
      modelId: 'gemini-2.5-flash-lite',
    );
    _display = svc.translateSyncFirst(
      text: widget.text,
      targetLang: widget.targetLang,
      onUpdate: (fresh) {
        if (mounted) setState(() => _display = fresh);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      _display.isEmpty ? widget.text : _display,
      style: widget.style,
      textAlign: widget.textAlign,
      maxLines: widget.maxLines,
      overflow: widget.overflow ?? TextOverflow.clip,
    );
  }
}
class _Lru<K, V> {
  final int capacity;
  final _map = LinkedHashMap<K, V>();
  _Lru(this.capacity);
  V? get(K k) {
    final v = _map.remove(k);
    if (v != null) _map[k] = v;
    return v;
  }

  void set(K k, V v) {
    if (_map.containsKey(k)) _map.remove(k);
    _map[k] = v;
    if (_map.length > capacity) _map.remove(_map.keys.first);
  }
}

class TranslationService {
  TranslationService({
    required this.apiKey,
    required this.baseUrl,
    this.modelId = 'gemini-2.5-flash-lite',
    this.cacheTtl = const Duration(days: 14),
    this.memoryCapacity = 2000,
  });

  final String apiKey;
  final String baseUrl;
  final String modelId;
  final Duration cacheTtl;
  final int memoryCapacity;

  late final openai.OpenAIClient _client = openai.OpenAIClient(
    apiKey: apiKey,
    baseUrl: baseUrl,
  );
final PrefStore pref= PrefStore();
  final _mem = _Lru<String, Map<String, dynamic>>(2000);
  final _inFlight = <String, Future<String>>{};

  Future<void> _init() async {
  }

  String _key(String text, String lang) {
    final norm = text.trim().replaceAll(RegExp(r'\s+'), ' ');
    return 'tr_v2|$modelId|$lang|${norm.hashCode}';
    // keep key short to avoid SharedPreferences size bloat
  }

  String? _getCached(String text, String lang) {
    final k = _key(text, lang);
    final now = DateTime.now();
    final mem = _mem.get(k);
    if (mem != null) {
      final ts = DateTime.parse(mem['ts'] as String);
      if (now.difference(ts) < cacheTtl) return mem['t'] as String;
    }
    final s = pref.get(k);
    if (s != null) {
      final obj = s as Map<String, dynamic>;
      final ts = DateTime.tryParse(obj['ts'] as String? ?? '');
      if (ts != null && DateTime.now().difference(ts) < cacheTtl) {
        _mem.set(k, obj);
        return obj['t'] as String?;
      }
    }
    return null;
  }

  Future<void> _setCached(String text, String lang, String t) async {
    final k = _key(text, lang);
    final obj = {'t': t, 'ts': DateTime.now().toIso8601String()};
    _mem.set(k, obj);
    await pref.set(k, json.encode(obj));
  }

  // Sync-first: returns cached value (or original) immediately. Fetches fresh in background.
  String translateSyncFirst({
    required String text,
    required String targetLang,
    void Function(String fresh)? onUpdate,
    bool fallbackToOriginal = true,
  }) {
    final cached = _getCached(text, targetLang);
    if (cached != null) return cached;
    if (onUpdate != null) {
      unawaited(
        translate(
          text: text,
          targetLang: targetLang,
        ).then(onUpdate).catchError((_) {}),
      );
    }
    return fallbackToOriginal ? text : '';
  }

  Future<String> translate({
    required String text,
    required String targetLang,
  }) async {
    await _init();
    final cached = _getCached(text, targetLang);
    if (cached != null) return cached;

    final k = _key(text, targetLang);
    if (_inFlight.containsKey(k)) return _inFlight[k]!;

    final f = _translateNetwork(text: text, targetLang: targetLang)
        .then((t) async {
          await _setCached(text, targetLang, t);
          return t;
        })
        .whenComplete(() => _inFlight.remove(k));

    _inFlight[k] = f;
    return f;
  }

  Future<String> _translateNetwork({
    required String text,
    required String targetLang,
  }) async {
    final res = await _client.createChatCompletion(
      request: openai.CreateChatCompletionRequest(
        model: openai.ChatCompletionModel.modelId(modelId),
        messages: [
          openai.ChatCompletionMessage.system(
            content: 'Translate the input to $targetLang. Return JSON only.',
          ),
          openai.ChatCompletionMessage.user(
            content: openai.ChatCompletionUserMessageContent.string(
              'text="$text"\nlang="$targetLang"',
            ),
          ),
        ],
        temperature: 0.1,
        responseFormat: openai.ResponseFormat.jsonSchema(
          jsonSchema: openai.JsonSchemaObject(
            name: 'TranslateResult',
            description: 'Deterministic translation result',
            strict: true,
            schema: {
              'type': 'object',
              'properties': {
                't': {'type': 'string', 'description': 'translated text'},
              },
              'required': ['t'],
              'additionalProperties': false,
            },
          ),
        ),
      ),
    );

    // Guaranteed JSON matching schema
    final content = res.choices.first.message.content ?? '{}';
    final obj = json.decode(content) as Map<String, dynamic>;
    return (obj['t'] as String).trim();
  }

  // Batch translate: returns one line per input; uses Structured Outputs
  Future<List<String>> translateBatch({
    required List<String> texts,
    required String targetLang,
  }) async {
    await _init();

    final out = List<String?>.filled(texts.length, null);
    var allCached = true;
    for (var i = 0; i < texts.length; i++) {
      final c = _getCached(texts[i], targetLang);
      out[i] = c;
      if (c == null) allCached = false;
    }
    if (allCached) return out.cast<String>();

    // Prepare only missing items
    final pending = <int, String>{};
    for (var i = 0; i < texts.length; i++) {
      if (out[i] == null) pending[i] = texts[i];
    }

    final res = await _client.createChatCompletion(
      request: openai.CreateChatCompletionRequest(
        model: openai.ChatCompletionModel.modelId(modelId),
        messages: [
          openai.ChatCompletionMessage.system(
            content: 'Translate each item to $targetLang. Return JSON only.',
          ),
          openai.ChatCompletionMessage.user(
            content: openai.ChatCompletionUserMessageContent.string(
              json.encode({
                'lang': targetLang,
                'items': pending.entries
                    .map((e) => {'i': e.key, 'text': e.value})
                    .toList(),
              }),
            ),
          ),
        ],
        temperature: 0.1,
        responseFormat: openai.ResponseFormat.jsonSchema(
          jsonSchema: openai.JsonSchemaObject(
            name: 'BatchTranslate',
            description: 'Batch translation results',
            strict: true,
            schema: {
              'type': 'object',
              'properties': {
                'results': {
                  'type': 'array',
                  'items': {
                    'type': 'object',
                    'properties': {
                      'i': {'type': 'integer'},
                      't': {'type': 'string'},
                    },
                    'required': ['i', 't'],
                    'additionalProperties': false,
                  },
                },
              },
              'required': ['results'],
              'additionalProperties': false,
            },
          ),
        ),
      ),
    );

    final content = res.choices.first.message.content ?? '{}';
    final obj = json.decode(content) as Map<String, dynamic>;
    final results = (obj['results'] as List).cast<Map<String, dynamic>>();
    for (final r in results) {
      final i = r['i'] as int;
      final t = (r['t'] as String).trim();
      out[i] = t;
      unawaited(_setCached(texts[i], targetLang, t));
    }
    // Fill any remaining holes with original text
    return List<String>.generate(texts.length, (i) => out[i] ?? texts[i]);
  }
}
class MovieTvTranslator {


  MovieTvTranslator() ;


  final client = openai.OpenAIClient(
    apiKey: Cfg.current.key,
    baseUrl: Cfg.current.url,
  );

Future<String> translateTextForMoviesAndTV(String text) async {
  final targetLanguage = Cfg.current.defaultTranslateLanguage ?? 'English';

  return persistentCache.runOrGet(text, targetLanguage, () async {
    final res = await client.createChatCompletion(
      request: openai.CreateChatCompletionRequest(
        model: openai.ChatCompletionModel.modelId("gemini-2.5-flash-lite"),
      messages: [
  openai.ChatCompletionMessage.system(content: 'You are an expert translator for an AI chat application. You must follow the user\'s instructions precisely to handle complex text with code, math, and multiple languages.'),
  openai.ChatCompletionMessage.user(
    content: openai.ChatCompletionUserMessageContent.string(
      '''Translate the following text to $targetLanguage.

Follow these rules:
1.  **Do not translate code:** Keep any content within markdown code blocks (```) in its original form.
2.  **Preserve math:** Do not translate any mathematical equations or formulas.
3.  **Handle mixed languages:** If the message already contains parts in $targetLanguage, or any other language that should not be translated, leave them unchanged.
4.  **Output:** Return ONLY the translated text, without any additional comments or explanations.

Text to translate: """$text"""'''
    ),
  ),
],

      
        temperature: 0.9,
      ),
    );
    return (res.choices.first.message.content ?? '').trim();
  });
}}