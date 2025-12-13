import 'package:gpt_box/data/res/openai.dart';
import 'package:openai_dart/openai_dart.dart';

class AIService {
  final OpenAIClient _client;

  AIService(String apiKey)
    : _client = OpenAIClient(apiKey: Cfg.current.key, baseUrl: Cfg.current.url);

  Future<String> sendBatchRequest(String content) async {
    try {
      final response = await _client.createChatCompletion(
        request: CreateChatCompletionRequest(
          model: ChatCompletionModel.modelId(Cfg.current.model),
          messages: [
            ChatCompletionMessage.user(
              content: ChatCompletionUserMessageContent.string(content),
            ),
          ],
          temperature: 0.1, // Add a reasonable temperature
        ),
      );

      return response.choices.first.message.content ?? 'No response received';
    } catch (e) {
      throw Exception('Batch request failed: $e');
    }
  }
}
