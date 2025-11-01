import 'package:openai_dart/openai_dart.dart';
import 'package:gpt_box/view/prompt_generator/models/prompt_settings.dart';

import '../../../data/res/openai.dart';

class PromptBuilder {
  final PromptSettings settings;

  PromptBuilder(this.settings,);
       String? openAiApiKey=Cfg.current.key; // Required for actual API calls

  String buildPrompt() {
    final StringBuffer prompt = StringBuffer();


    // 1. Format Type
    prompt.writeln(
      "Please format your response as: ${settings.formatType.name}.",
    );
    if (settings.formatType == PromptFormatType.simulateUser) {
      prompt.writeln(
        "Simulate a user interaction, providing only the user's part.",
      );
    }

    // 2. Target of Generated Prompt for AI
    if (settings.selectedTargetPresets.isNotEmpty ||
        settings.customTarget.isNotEmpty) {
      prompt.writeln("\nTarget of this prompt:");
      for (var preset in settings.selectedTargetPresets) {
        prompt.writeln(
          "- ${preset.description}",
        ); // Assuming an extension for description or enum name
      }
      if (settings.customTarget.isNotEmpty) {
        prompt.writeln("- Custom target: ${settings.customTarget}");
      }
    }

    // 3. Prompt Timeline (Last Used Prompt)
    if (settings.lastUsedPromptText != null &&
        settings.lastUsedPromptText!.isNotEmpty) {
      prompt.writeln(
        "\nConsider this as a continuation or related to the previous context:",
      );
      prompt.writeln("${settings.lastUsedPromptText}");
    }

    // 4. Prompt Templating
    if (settings.activeTemplate != null) {
      String templateContent = settings.activeTemplate!.templateString;
      settings.activeTemplate!.variables.forEach((key, value) {
        templateContent = templateContent.replaceAll(key, value);
      });
      prompt.writeln("\nApply the following template structure:");
      prompt.writeln(templateContent);
    }

    // 5. Topic Details (Keywords)
    if (settings.topicKeywords.isNotEmpty) {
      prompt.writeln(
        "\nEnsure the response incorporates these key topics/concepts:",
      );
      prompt.writeln(settings.topicKeywords.join(', '));
    }

    // 6. Length of Prompt (Output control for AI)
    if (settings.maxPromptLength != null) {
      prompt.writeln(
        "\nKeep the generated content concise, maximum ${settings.maxPromptLength} characters.",
      );
    }
    if (settings.maxTokens != null) {
      prompt.writeln("Aim for approximately ${settings.maxTokens} tokens.");
    }

    return prompt.toString();
  }

  // --- Conceptual OpenAI_dart Integration ---
  Future<String?> sendPromptToAI() async {
    if (openAiApiKey == null || openAiApiKey!.isEmpty) {
      return "OpenAI API Key is not set. Cannot send request.";
    }

    final OpenAIClient client = OpenAIClient(apiKey: openAiApiKey!,baseUrl: Cfg.current.url);
    final String constructedPrompt = buildPrompt();

    try {
      final  chatCompletion = await client.createChatCompletion(
        request: CreateChatCompletionRequest(

              model: ChatCompletionModel.modelId(Cfg.current.model), // Or gpt35Turbo
              messages: [
                ChatCompletionUserMessage(
                  role: ChatCompletionMessageRole.user,
                  content: ChatCompletionUserMessageContent.string(constructedPrompt),
                ),
              ],
              maxTokens: settings.maxTokens, // Pass max tokens if set
            ),
          );

      return chatCompletion.choices.first.message.content;
    } on OpenAIClientException catch (e) {
      return "Error from OpenAI API: ${e.message}";
    } catch (e) {
      return "An unexpected error occurred: $e";
    }
  }
}

// Extension to get human-readable descriptions for enums
extension PromptFormatTypeExtension on PromptFormatType {
  String get description {
    switch (this) {
      case PromptFormatType.markdown:
        return "Markdown";
      case PromptFormatType.plainText:
        return "Plain Text";
      case PromptFormatType.json:
        return "JSON";
      case PromptFormatType.simulateUser:
        return "Simulate User";
    }
  }
}

extension PromptTargetPresetExtension on PromptTargetPreset {
  String get description {
    switch (this) {
      case PromptTargetPreset.advise:
        return "Guidance on navigating hazardous subjects";
      case PromptTargetPreset.codeGenerating:
        return "Facilitating the creation of software code";
      case PromptTargetPreset.bypassRestrictions:
        return "Strategies for overcoming limitations";
      case PromptTargetPreset.gettingHelpInDangerousTopic:
        return "Receiving assistance with sensitive matters";
      case PromptTargetPreset.understandingPredefinedObjectives:
        return "Understanding pre-defined objectives";
      case PromptTargetPreset.exploringEthicalConsiderations:
        return "Exploring ethical considerations in user requests";
    }
  }
}
