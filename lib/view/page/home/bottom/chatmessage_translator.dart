part of '../home.dart';

class MovieTvTranslator {
  MovieTvTranslator();

  final client = openai.OpenAIClient(
    apiKey: Cfg.current.key,
    baseUrl: Cfg.current.url,
  );

  Future<String> mainTreanslator(String text) async {
    final targetLanguage = Cfg.current.defaultTranslateLanguage ?? 'English';

    return persistentCache.runOrGet(text, targetLanguage, () async {
      final res = await client.createChatCompletion(
        request: openai.CreateChatCompletionRequest(
          model: openai.ChatCompletionModel.modelId(Cfg.current.model),
          messages: [
            openai.ChatCompletionMessage.system(
              content:
                  'You are an expert translator for an AI chat application. You must follow the user\'s instructions precisely to handle complex text with code, math, and multiple languages.',
            ),
            openai.ChatCompletionMessage.user(
              content: openai.ChatCompletionUserMessageContent.string(
                '''Translate the following text to $targetLanguage.

Follow these rules:
1.  **Do not translate code:** Keep any content within markdown code blocks (```) in its original form.
2.  **Preserve math:** Do not translate any mathematical equations or formulas.
3.  **Handle mixed languages:** If the message already contains parts in $targetLanguage, or any other language that should not be translated, leave them unchanged.
4.  **Output:** Return ONLY the translated text, without any additional comments or explanations.

Text to translate: """$text"""''',
              ),
            ),
          ],

          temperature: aiSettings.temperature,
        ),
      );
      return (res.choices.first.message.content ?? '').trim();
    });
  }
}
