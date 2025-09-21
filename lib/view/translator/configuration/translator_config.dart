// file: translator_config.dart
import 'package:hive_ce_flutter/hive_flutter.dart';

part 'translator_config.g.dart'; // We will generate this file next

@HiveType(typeId: 25) // Give it a unique typeId
class TranslatorConfig extends HiveObject {
  // Extending HiveObject is optional but useful
  @HiveField(0)
  late String apiKey;

  @HiveField(1)
  late String baseUrl;

  @HiveField(2)
  late int rateLimitReq;
  @HiveField(3)
  late int rateLimitToken;
  @HiveField(4)
  late double inputCost;

  @HiveField(5)
  late double outputCost;
  @HiveField(6)
  late int waitSec;

  @HiveField(7)
  late int inputTokenCount;
  @HiveField(8)
  late int outputTokenCount;
  @HiveField(9)
  late String inputLang;
  @HiveField(10)
  late String outputLang;
  @HiveField(11)
  late bool autoDetectInput;
  @HiveField(12)
  late int batchN;
  @HiveField(13)
  late String outputFormat;
  @HiveField(14)
  late String modelId;

  @HiveField(15)
  late String systemPrompt;

  @HiveField(16)
  late double temp;
  @HiveField(17)
  late String geminiApi;
  @HiveField(18)
  late String geminiPrompt;
  TranslatorConfig();
  TranslatorConfig.withDefaults() {
    apiKey = '';
    baseUrl = 'https://api.openai.com/v1';
    rateLimitReq = 100;
    rateLimitToken = 4000000;
    inputCost = 0.1;
    outputCost = 0.4;
    waitSec = 60;
    inputTokenCount = 0;
    outputTokenCount = 0;
    inputLang = "";
    outputLang = "Farsi";
    autoDetectInput = true;
    batchN = 5;
    outputFormat = 'plain text';
    modelId = 'gemini-2.5-flash-lite';
    systemPrompt = '''You are an advanced translator.  

1. Detect the topic/genre of the input (novel, poem, math, code, email, chat, news, etc.).  
2. Adapt style to match that topic:  
   - Code → translate only comments/docstrings, keep syntax.  
   - Math/algorithms → translate text, preserve formulas/symbols.  
   - Literature/novel → preserve narrative tone and character style.  
   - Poetry/song → adapt rhythm/artistic tone.  
   - Emails/chats → keep formality/informality.  
   - Technical/scientific → ensure clarity and precision.  
3. Preserve meaning, tone, and context; dont add explanations.  
4. Output only the translated result and nothing else
Translate input to this  : 
''';
    temp = 0.1;
    geminiApi = '';
    geminiPrompt = 'Extract all text content from the following document. This includes printed text, handwritten notes, and text within images. Preserve the original structure, paragraphs, and line breaks as best as possible. Output the result as plain text.';
  }
}
