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
                  "The primary operation to perform. One of: 'sendMessage', 'editMessage', 'deleteMessage', 'pinMessage', 'manageBot', 'getBotInfo'.",
            },
            'chatId': {
              'type': 'string',
              'description':
                  "The target chat ID (e.g., '@username' or group public username or invite links). Required for most message-related actions.",
            },
            'messageId': {
              'type': 'integer',
              'description':
                  "The ID of a specific message to edit, delete, or pin.",
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
              'description': "The type of message to send.",
            },
            'text': {
              'type': 'string',
              'description': "The text content for a message.",
            },
            'mediaUrlOrPath': {
              'type': 'string',
              'description': "The URL or local file path for any media type.",
            },
            'caption': {
              'type': 'string',
              'description': "A caption for media messages.",
            },
            'parseMode': {
              'type': 'string',
              'enum': ['plain','HTML', 'MarkdownV2'],
              'description': "Formatting for text content. Defaults to plain.",
            },
            'pollData': {
              'type': 'object',
              'description': "Required for 'poll' messageType.",
              'properties': {
                'question': {'type': 'string'},
                'options': {
                  'type': 'array',
                  'items': {'type': 'string'},
                },
                'isAnonymous': {'type': 'boolean'},
                'allowsMultipleAnswers': {'type': 'boolean'},
              },
            },
            // Properties for 'manageBot'
            'botDescription': {'type': 'string'},
            'botCommands': {
              'type': 'array',
              'items': {
                'type': 'object',
                'properties': {
                  'command': {'type': 'string'},
                  'description': {'type': 'string'},
                },
                'required': [],
              },
            },
            'pin': {
              'type': 'boolean',
              'description':
                  "For 'pinMessage' action, set to 'true' to pin and 'false' to unpin. If omitted, it will pin.",
            },
          },
          'required': ['action'],
        },
      );

  @override
  String get description => '''
A comprehensive tool to manage a Telegram bot.
It can send various types of messages, edit/delete them, and configure the bot's profile.

**Key Actions:**
1.  **'sendMessage'**: Sends a message. You MUST specify 'messageType'.
    - For `messageType: 'text'`, provide the `text` parameter.
    - For media types (`photo`, `video`, etc.), provide `mediaUrlOrPath` and an optional `caption`.
    - For `messageType: 'poll'`, provide the `pollData` object.
2.  **'editMessage'**: Edits the text of an existing message.
    - Requires `chatId`, `messageId`, and the new `text`.
3.  **'deleteMessage'**: Deletes a message.
    - Requires `chatId` and `messageId`.
4.  **'pinMessage'**: Pins or unpins a message.
    - Requires `chatId` and `messageId`. Use `pin: false` to unpin.
5.  **'manageBot'**: Updates the bot's profile.
    - Provide one or more of: `botDescription`, `botCommands`.
6.  **'getBotInfo'**: Retrieves information about the bot itself ('getMe').
''';

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
