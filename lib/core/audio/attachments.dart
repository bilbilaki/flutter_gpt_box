import 'dart:convert';
import 'dart:io';
import 'package:mime/mime.dart';
import 'package:openai_dart/openai_dart.dart';
import 'audio_utils.dart';

class AttachmentPreparer {
  static Future<List<ChatCompletionMessageContentPart>> toChatParts(
    List<String> paths, {
    int maxTotalBytes = 30 * 1024 * 1024,
  }) async {
    final files = paths
        .where((p) => File(p).existsSync())
        .map((p) => File(p))
        .toList();
    final sizes = files.map((f) => f.lengthSync());
    if (!AudioUtils.underLimitBytes(sizes, maxBytes: maxTotalBytes)) {
      throw Exception('Attachments exceed 30MB total size.');
    }

    final parts = <ChatCompletionMessageContentPart>[];
    for (final f in files) {
      final mime = lookupMimeType(f.path) ?? 'application/octet-stream';
      final b64 = base64Encode(await f.readAsBytes());
      if (mime.startsWith('image/')) {
        parts.add(
          ChatCompletionMessageContentPart.image(
            imageUrl: ChatCompletionMessageImageUrl(
              url:
                  b64, // many providers accept base64 in url field for image parts
              detail: ChatCompletionMessageImageDetail.high,
            ),
          ),
        );
      } else if (mime.startsWith('audio/')) {
        parts.add(
          ChatCompletionMessageContentPart.audio(
            inputAudio: ChatCompletionMessageInputAudio(
              data: b64,
              // default to wav; adjust per actual file extension if needed
              format: ChatCompletionMessageInputAudioFormat.wav,
            ),
          ),
        );
      } else {
        // Fallback: send as text link or base64 chunk (providers vary)
        parts.add(
          ChatCompletionMessageContentPart.text(
            text: '[file:${f.path}($mime)]',
          ),
        );
      }
    }
    return parts;
  }
}
