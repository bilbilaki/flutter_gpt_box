import 'package:gpt_box/main.dart';
import 'package:openai_dart/openai_dart.dart';

import '../../../data/res/openai.dart';

/// Service for handling translation via OpenAI API.
class TranslationService {
  OpenAIClient? _client;
  void setApiKey() {
    _client = OpenAIClient(
      apiKey: Cfg.current.key,
      baseUrl: Cfg.current.url,
    );
  }

  Future<String> _translateTextChunk(String text, String targetLanguage) async {
    if (_client == null) {
      throw Exception(
        'API Key not set. Please provide a valid OpenAI API key.',
      );
    }
    if (text.trim().isEmpty) {
      return text;
    }

    final prompt =
        '${translatorConfig.systemPrompt} ${translatorConfig.outputLang}';
    //   'Translate the following text to $targetLanguage. Return only the translated text, without any introductory phrases or explanations.';
    try {
      final res = await _client!.createChatCompletion(
        request: CreateChatCompletionRequest(
          model: ChatCompletionModel.modelId(translatorConfig.modelId),
          messages: [
            ChatCompletionMessage.user(
              content: ChatCompletionUserMessageContent.string(
                '$prompt\n\nText: """$text"""',
              ),
            ),
          ],
          temperature: translatorConfig.temp,
        ),
      );
      return res.choices.first.message.content?.trim() ??
          '[Translation Failed: Empty Response]';
    } catch (e) {
      return '[Translation Error: ${e.toString()}]';
    }
  }

  Future<void> translateChunksConcurrently({
    required List<String> chunks,
    required String targetLanguage,
    required Function(int index, String translatedChunk) onChunkTranslated,
    required int batchSize,
  }) async {
    if (_client == null) {
      throw Exception('API Key not set before starting translation.');
    }

    for (int i = 0; i < chunks.length; i += batchSize) {
      int end = (i + batchSize > chunks.length) ? chunks.length : i + batchSize;
      List<String> batchChunks = chunks.sublist(i, end);

      List<Future<String>> batchFutures = batchChunks
          .map((chunk) => _translateTextChunk(chunk, targetLanguage))
          .toList();

      List<String> translatedBatch = await Future.wait(batchFutures);

      for (int j = 0; j < translatedBatch.length; j++) {
        onChunkTranslated(i + j, translatedBatch[j]);
      }
    }
  }
}
