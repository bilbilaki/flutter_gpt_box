import 'dart:io';
import 'dart:typed_data';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:gpt_box/data/model/chat/history/history.dart';
import 'package:gpt_box/view/page/home/home.dart';
import 'package:gpt_box/view/widget/code.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:gpt_box/view/widget/image_base64_viewer.dart';
import 'dart:convert';
import 'package:flutter_markdown_latex/flutter_markdown_latex.dart';
import 'package:before_after/before_after.dart';

final class ChatRoleTitle extends StatelessWidget {
  final ChatRole role;
  final bool loading;

  ChatRoleTitle({required this.role, required this.loading, super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final text = Text(role.localized, style: const TextStyle(fontSize: 15));
    final label = Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(13),
        color: isDark
            ? const Color.fromARGB(37, 203, 203, 203)
            : const Color.fromARGB(29, 84, 84, 84),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(13),
              color: role.color,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
          ),
          const SizedBox(width: 5),
          Transform.translate(offset: const Offset(0, -0.8), child: text),
        ],
      ),
    );
    if (!loading) return label;
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        label,
        UIs.width13,
        const SizedBox(
          height: 15,
          width: 15,
          child: CircularProgressIndicator(),
        ),
      ],
    );
  }
}

final class ChatHistoryContentView extends StatelessWidget {
  final ChatHistoryItem chatItem;
  String bas = '';
  void Function()? postCallback;

  ChatHistoryContentView({
    required this.chatItem,
    this.postCallback,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    if (chatItem.role.isTool) {
      final md = chatItem.toMarkdown;
      final text = Text(
        md,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: UIs.textGrey,
      );
      return text;
    }

    final children = chatItem.content.map((e) {
      final fn = switch (e.type) {
        // ChatContentType.audio => _buildAudio(e),
        ChatContentType.image => _buildImage,
        ChatContentType.file => _buildFile,
        _ => _buildText,
      };
      return fn(context, e);
    }).toList();

    final reasoningContent = chatItem.reasoning;
    if (reasoningContent != null) {
      final reasoning = ExpandTile(
        title: Text(
          libL10n.thinking,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        tilePadding: const EdgeInsets.symmetric(horizontal: 17, vertical: 0),
        childrenPadding: const EdgeInsets.symmetric(horizontal: 9, vertical: 9),
        children: [_buildMarkdown(context, reasoningContent)],
      ).cardx;
      children.insert(0, reasoning);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: children.joinWith(UIs.height13),
    );
  }

  Widget _buildText(BuildContext context, ChatContent content) {
    // If the text contains inline base64 data URIs (e.g. data:image/...),
    // split the text into segments and render decoded images inline.
    final s = content.raw;
    // Match data:image/...;base64,.... and allow optional parameters like
    // charset before the final `;base64` (e.g. data:image/png;charset=utf-8;base64,...)
    final dataUriRe = RegExp(
      r'(data:image\/[^;,\s]+(?:;[^,\s]+)*;base64,[A-Za-z0-9+/=\r\n]+)',
    );
    final matches = dataUriRe.allMatches(s).toList();
    if (matches.isEmpty) return _buildMarkdown(context, s);

    final widgets = <Widget>[];
    var lastIndex = 0;
    for (final m in matches) {
      if (m.start > lastIndex) {
        final textPart = s.substring(lastIndex, m.start);
        widgets.add(_buildMarkdown(context, textPart));
      }
      final dataUri = s.substring(m.start, m.end);
      // Try decode base64 body (strip the prefix up to the first comma)
      try {
        final comma = dataUri.indexOf(',');
        final body = comma >= 0 ? dataUri.substring(comma + 1) : dataUri;
        // Normalize by removing whitespace/newlines which sometimes appear in long base64 strings
        final normalized = body.replaceAll(RegExp(r'\s+'), '');
        // Validate base64
        base64Decode(normalized);
        // Pass only the base64 body to the display widget (prefix removed)
        widgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: ClipRRect(
              child: bas != ''
                  ? Base64ImageDisplay(
                      base64String: normalized,
                      bas: bas,
                      postCallback: postCallback,
                    )
                  : Base64ImageDisplay(base64String: normalized),
            ),
          ),
        );
      } catch (_) {
        // Fallback: show raw markdown if decoding fails
        widgets.add(_buildMarkdown(context, dataUri));
      }
      lastIndex = m.end;
    }
    if (lastIndex < s.length) {
      widgets.add(_buildMarkdown(context, s.substring(lastIndex)));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: widgets.joinWith(UIs.height13),
    );
  }

  Widget _buildImage(BuildContext context, ChatContent content) {
    String normalized = '';
    final s = content.raw;
    // Match data:image/...;base64,.... and allow optional parameters like
    // charset before the final `;base64` (e.g. data:image/png;charset=utf-8;base64,...)
    final dataUriRe = RegExp(
      r'(data:image\/[^;,\s]+(?:;[^,\s]+)*;base64,[A-Za-z0-9+/=\r\n]+)',
    );
    final matches = dataUriRe.allMatches(s).toList();

    final widgets = <Widget>[];
    var lastIndex = 0;
    for (final m in matches) {
      if (m.start > lastIndex) {
        final textPart = s.substring(lastIndex, m.start);
        widgets.add(_buildMarkdown(context, textPart));
      }
      final dataUri = s.substring(m.start, m.end);
      // Try decode base64 body (strip the prefix up to the first comma)
      final comma = dataUri.indexOf(',');
      final body = comma >= 0 ? dataUri.substring(comma + 1) : dataUri;
      // Normalize by removing whitespace/newlines which sometimes appear in long base64 strings
      normalized = body.replaceAll(RegExp(r'\s+'), '');
      bas = normalized;
      postCallback;
      // Validate base64
    }
    // Pass only the base64 body to the display widget (prefix removed)

    return LayoutBuilder(
      builder: (_, cons) {
        return Base64ImageDisplay(
          key: ValueKey(content.hashCode),
          base64String: normalized,
        );
      },
    );
  }
}

Widget _buildFile(BuildContext context, ChatContent content) {
  return FileCardView(path: content.raw);
}

Widget _buildAudio(ChatContent content) {
  return audioTileFor(content);
}

bool looksLikeAudioDataUrl(String s) {
  final v = s.trim().toLowerCase();
  return (v.contains('data:audio/') == true ||
          v.contains('data:image/') == true)
      ? true
      : false;
}

Future<Uint8List> _readFileBytesSafe(File f) async {
  try {
    return await f.readAsBytes();
  } catch (_) {
    return Uint8List(0);
  }
}

Widget _audioSkeleton() {
  return Container(
    height: 66,
    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    decoration: BoxDecoration(
      color: Colors.black12,
      borderRadius: BorderRadius.circular(12),
    ),
    child: const Center(
      child: SizedBox(
        height: 20,
        width: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    ),
  );
}

Widget audioError(String msg) {
  return Container(
    height: 66,
    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    decoration: BoxDecoration(
      color: Colors.red.withOpacity(0.08),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Center(
      child: Text(msg, style: const TextStyle(color: Colors.redAccent)),
    ),
  );
}

bool _isAudioContent(ChatContent c) {
  // File path with audio extension
  if (c.type.isFile && isAudioPath(c.raw)) return true;
  // Inline base64 audio data url
  if (c.type.isText && looksLikeAudioDataUrl(c.raw)) return true;
  // Fallback: if content claims to be audio in your model (if any)
  return c.type.isAudio; // uncomment if you have such a type
  // return false;
}

Widget audioTileFor(ChatContent c) {
  // Case 1: file path stored in raw
  if (isAudioPath(c.raw)) {
    final f = File(c.raw);
    return FutureBuilder<Uint8List>(
      future: _readFileBytesSafe(f),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return _audioSkeleton();
        }
        if (snap.hasError || !snap.hasData || (snap.data?.isEmpty ?? true)) {
          return audioError('Failed to load audio file');
        }
        final ensured = ensureWavBytes(
          snap.data!,
          sampleRate: kTtsSampleRate,
          channels: 1,
        );
        return AudioPlayerTile(
          bytes: ensured,
          file: f,
          // autoPlay: true, // enable if you want first-time autoplay
        );
      },
    );
  }

  // Case 2: data URL like "data:audio/wav;base64,...." (or raw PCM16)
  if (c.type.isText && looksLikeAudioDataUrl(c.raw)) {
    try {
      final comma = c.raw.indexOf(',');
      final body = comma >= 0 ? c.raw.substring(comma + 1) : c.raw;
      final bytes = base64Decode(body);
      final ensured = ensureWavBytes(
        bytes,
        sampleRate: kTtsSampleRate,
        channels: 1,
      );
      return AudioPlayerTile(bytes: ensured);
    } catch (_) {
      return audioError('Invalid audio data URL');
    }
  }

  // Fallback: treat raw as base64 string if any
  try {
    final comma = c.raw.indexOf(',');
    final body = comma >= 0 ? c.raw.substring(comma + 1) : c.raw;
    final bytes = base64Decode(body);
    final ensured = ensureWavBytes(
      bytes,
      sampleRate: kTtsSampleRate,
      channels: 1,
    );
    return AudioPlayerTile(bytes: ensured);
  } catch (_) {
    return audioError('Unsupported audio payload');
  }
}

Widget _buildMarkdown(BuildContext context, String content) {
  return MarkdownBody(
    data: content,
    builders: {
      'code': CodeElementBuilder(onCopy: Pfs.copy),
      'latex': LatexElementBuilder(),
    },
    styleSheet: MarkdownStyleSheet.fromTheme(
      context.theme,
    ).copyWith(a: TextStyle(color: UIs.primaryColor)),
    extensionSet: MarkdownUtils.extensionSet,
    onTapLink: MarkdownUtils.onLinkTap,
    shrinkWrap: false,
    // Keep it false, or the ScrollView's height calculation will be wrong.
    fitContent: false,
    // User experience is better when this is false.
    selectable: isDesktop,
  );
}

extension on ChatHistoryContentView {
  void _onImgRet(ImagePageRet ret, String raw) async {
    if (ret.isDeleted) {
      FileApi.delete([raw]);
    }
  }
}
