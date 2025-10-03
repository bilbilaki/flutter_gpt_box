part of '../tool.dart';

// You will need to import the telegram package
// import 'package:telegram/telegram.dart';

/// Tool for interacting with the Telegram Bot API.
final class TfTelegramManager extends ToolFunc {
  static const instance = TfTelegramManager._();

const TfTelegramManager._()
    : super(
        name: 'telegramManager',
        parametersSchema: const {
          'type': 'object',
          'properties': {
            'action': {
              'type': 'string',
              'description':
                  "The primary operation to perform. Must be exactly one of: 'sendMessage' (send new message), 'editMessage' (update message text), 'deleteMessage' (remove a message), 'pinMessage' (pin/unpin message).",
            },
            'chatId': {
              'type': 'string',
              'description':
                  "The target chat ID (e.g., '@channelid' or 'userid' or '@userid', for user/group, or invite link)",
            },
            'messageId': {
              'type': 'integer',
              'description':
                  "The unique ID of a specific message (obtained from previous 'sendMessage' response or bot logs). Required for 'editMessage', 'deleteMessage', and 'pinMessage'. Verify the ID to avoid errors.",
            },
            // Properties for 'sendMessage'
            'messageType': {
              'type': 'string',
              'enum': [
                'text',
                'photo',
                'video',
                'audio',
                'document',
                'sticker',
                'animation',
                'voice',
                'videoNote',
                'poll',
                'dice',
              ],
              'description':
                  "The type of message to send for 'sendMessage' action (e.g., 'text' for plain messages, 'photo' for images). Required for 'sendMessage'; defaults not applicable—choose based on user request.",
            },
            'text': {
              'type': 'string',
              'description':
                  "The main text content for 'text' messages or captions. For 'sendMessage', provide for text types; for media, use as optional caption. Keep concise and confirm sensitive content with user.",
            },
            'mediaUrlOrPath': {
              'type': 'string',
              'description':
                  "The URL (e.g., 'https://example.com/image.jpg') or local file path for media types ('photo', 'video', etc.) in 'sendMessage'. Verify accessibility before calling; use trusted sources only.",
            },
            'caption': {
              'type': 'string',
              'description':
                  "Optional short description for media messages (under 1024 chars). Use for context; confirm if it includes links or sensitive info.",
            },
            'parseMode': {
              'type': 'string',
              'enum': ['plain', 'HTML', 'MarkdownV2'],
              'description':
                  "Text formatting for 'text' or 'caption' (e.g., 'HTML' for bold/italics). Defaults to 'plain'. Use 'MarkdownV2' carefully for advanced escapes.",
            },
            'pin': {
              'type': 'boolean',
              'description':
                  "For 'pinMessage' action, set to true to pin a message or false to unpin. Defaults to true (pin) if omitted. Confirm pinning for group chats to avoid spam.",
            },
          },
          'required': ['action','chatId','messageType','text'],
        },
      );

  @override
  String get description => '''
Use this tool to manage Telegram bot interactions when the user explicitly requests it (e.g., "Send a photo to my channel" or "Update my bot's description"). Ideal for sending messages, editing content, or bot configuration—integrate with other tools like 'downloader' for media. Do not call unsolicited; always confirm chat IDs, content, and actions with the user to respect privacy and Telegram's rules (e.g., no spam). Responses include message IDs for follow-ups (e.g., edit later).
This tool handles one operation per call—use sequentially for multi-step tasks (e.g., send then edit). Focus on user-authorized chats; obtain chat IDs from user or bot context.

**Actions and Usage (Choose Exactly One Per Call):**
1. **'sendMessage'**: Sends a new message to a chat.
   - Required: 'chatId', 'messageType' (e.g., 'text', 'photo'), and relevant content ('text' for text, 'mediaUrlOrPath' for media, 'pollData' for polls).
   - Optional: 'caption', 'parseMode' for formatting.
   - Example: For text: {'text': 'Hello!'}; for photo: {'mediaUrlOrPath': 'url.jpg', 'caption': 'Check this out'}.
   - Response: Sent message details with 'messageId'. Offer: "Message sent to @channel—want to edit or pin it?"
   - Tip: For polls/dice, ensure options are neutral; confirm media URLs are valid.

2. **'editMessage'**: Updates the text/caption of an existing message.
   - Required: 'chatId', 'messageId', 'text' (new content).
   - Optional: 'parseMode'.
   - Response: Updated message info. Confirm changes: "Editing message to say 'Updated text'—okay?"

3. **'deleteMessage'**: Removes a message from a chat.
   - Required: 'chatId', 'messageId'.
   - Response: Confirmation of deletion. Always confirm destructive action: "Delete this message? It's permanent."

4. **'pinMessage'**: Pins a message to the top of a chat (or unpins).
   - Required: 'chatId', 'messageId'; optional 'pin' (true/false).
   - Response: Pin status. Useful for announcements; confirm for groups: "Pin this for visibility?".''';
  @override
  Future<_Ret?> run(_CallResp call, _Map args, OnToolLog log) async {
    // IMPORTANT: Configure your bot token here or in your app's startup logic.
    // This is a placeholder. In a real app, load this from a secure config.
    Telegram.setBotToken(telBotToken);

    final action = args['action'] as String?;
    if (action == null) {
      return [ChatContent.text("Error: 'action' is required.")];
    }

    final chatId = args['chatId'] as String?;
    final messageId = args['messageId'] as int?;

    log(
      '[telegramManager] action: $action, chatId: $chatId, messageId: $messageId',
    );

    try {
      switch (action) {
        case 'sendMessage':
          return await _handleSendMessage(args, log);

        case 'editMessage':
          if (chatId == null || messageId == null || args['text'] == null) {
            return [
              ChatContent.text(
                "Error: 'chatId', 'messageId', and 'text' are required for editMessage.",
              ),
            ];
          }
          await Telegram.editMessageText(
            chatId: chatId,
            messageId: messageId,
            text: args['text'] as String,
            parseMode: args['parseMode'] as String?,
          );
          return [ChatContent.text('Message $messageId edited successfully.')];

        case 'deleteMessage':
          if (chatId == null || messageId == null) {
            return [
              ChatContent.text(
                "Error: 'chatId' and 'messageId' are required for deleteMessage.",
              ),
            ];
          }
          final success = await Telegram.deleteMessage(
            chatId: chatId,
            messageId: messageId,
          );
          return [
            ChatContent.text(
              success ? 'Message deleted.' : 'Failed to delete message.',
            ),
          ];

        case 'pinMessage':
          if (chatId == null || messageId == null) {
            return [
              ChatContent.text(
                "Error: 'chatId' and 'messageId' are required for pinMessage.",
              ),
            ];
          }
          final unpin = args['pin'] == false;
          if (unpin) {
            await Telegram.unpinChatMessage(
              chatId: chatId,
              messageId: messageId,
            );
            return [ChatContent.text('Message unpinned.')];
          } else {
            await Telegram.pinChatMessage(chatId: chatId, messageId: messageId);
            return [ChatContent.text('Message pinned.')];
          }

        case 'manageBot':
          final description = args['botDescription'] as String?;
          final shortDescription = args['botShortDescription'] as String?;
          final commandsList = (args['botCommands'] as List?)
              ?.cast<Map<String, dynamic>>();

          if (description != null) {
            await Telegram.setMyDescription(description: description);
          }
          if (shortDescription != null) {
            await Telegram.setMyShortDescription(
              shortDescription: shortDescription,
            );
          }
         if (commandsList != null) {
            // Normalize to List<Map<String, String>> (keys and values must be strings)
            final commandsListStrings = (commandsList as List)
                .map(
                  (e) => (e as Map).map(
                    (k, v) => MapEntry(k.toString(), v?.toString() ?? ''),
                  ),
                )
                .cast<Map<String, String>>()
                .toList();

            await Telegram.setMyCommands(commands: commandsListStrings);
          }
          return [ChatContent.text('Bot profile updated successfully.')];

        case 'getBotInfo':
          final botInfo = await Telegram.getMe();
          return [ChatContent.text(jsonEncode(botInfo))];

        default:
          return [ChatContent.text("Error: Unknown action '$action'.")];
      }
    } catch (e, st) {
      log('[telegramManager] Error: $e\n$st');
      return [ChatContent.text('Telegram API Error: $e')];
    }
  }

  Future<_Ret?> _handleSendMessage(_Map args, OnToolLog log) async {
    final chatId = args['chatId'] as String?;
    final messageType = args['messageType'] as String?;
    if (chatId == null || messageType == null) {
      return [
        ChatContent.text(
          "Error: 'chatId' and 'messageType' are required for sendMessage.",
        ),
      ];
    }

    final parseMode = args['parseMode'] as String?;
    final caption = args['caption'] as String?;

    switch (messageType) {
      case 'text':
        final text = args['text'] as String?;
        if (text == null) {
          return [
            ChatContent.text(
              "Error: 'text' is required for messageType 'text'.",
            ),
          ];
        }
        await Telegram.sendMessage(
          chatId: chatId,
          text: text,
          parseMode: parseMode,
        );
        break;

      case 'photo':
      case 'video':
      case 'audio':
      case 'document':
      case 'sticker':
      case 'animation':
      case 'voice':
      case 'videoNote':
        final url = args['mediaUrlOrPath'] as String?;
        if (url == null) {
          return [
            ChatContent.text(
              "Error: 'mediaUrlOrPath' is required for media messages.",
            ),
          ];
        }

        // This is where you map the messageType to the correct SDK function
        switch (messageType) {
          case 'photo':
            await Telegram.sendPhoto(
              chatId: chatId,
              photo: url,
              caption: caption,
              parseMode: parseMode,
            );
            break;
          case 'video':
            await Telegram.sendVideo(
              chatId: chatId,
              video: url,
              caption: caption,
              parseMode: parseMode,
            );
            break;
          case 'audio':
            await Telegram.sendAudio(
              chatId: chatId,
              audio: url,
              caption: caption,
              parseMode: parseMode,
            );
            break;
          case 'document':
            await Telegram.sendDocument(
              chatId: chatId,
              document: url,
              caption: caption,
              parseMode: parseMode,
            );
            break;
          case 'sticker':
            await Telegram.sendSticker(chatId: chatId, sticker: url);
            break;
          case 'animation':
            await Telegram.sendAnimation(
              chatId: chatId,
              animation: url,
              caption: caption,
              parseMode: parseMode,
            );
            break;
          case 'voice':
            await Telegram.sendVoice(
              chatId: chatId,
              voice: url,
              caption: caption,
              parseMode: parseMode,
            );
            break;
          case 'videoNote':
            await Telegram.sendVideoNote(chatId: chatId, videoNote: url);
            break;
        }
        break;

      case 'poll':
        final pollData = args['pollData'] as Map<String, dynamic>?;
        if (pollData == null) {
          return [
            ChatContent.text(
              "Error: 'pollData' object is required for messageType 'poll'.",
            ),
          ];
        }
        await Telegram.sendPoll(
          chatId: chatId,
          question: pollData['question'] as String,
          options: (pollData['options'] as List).cast<String>(),
          isAnonymous: pollData['isAnonymous'] as bool? ?? true,
          allowsMultipleAnswers:
              pollData['allowsMultipleAnswers'] as bool? ?? false,
        );
        break;

      case 'dice':
        await Telegram.sendDice(
          chatId: chatId,
          emoji: '🎲',
        ); // emoji can be extended as a parameter if needed
        break;

      default:
        return [ChatContent.text("Error: Unknown messageType '$messageType'.")];
    }

    return [
      ChatContent.text(
        "Message of type '$messageType' sent successfully to $chatId.",
      ),
    ];
  }
  
  @override
  String get l10nName => 'Telegram Tool';
}
