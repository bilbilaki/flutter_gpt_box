part of 'home.dart';

class _ChatPage extends StatefulWidget {
  const _ChatPage();

  @override
  State<StatefulWidget> createState() => _ChatPageState();
}

class _ChatPageState extends State<_ChatPage>
    with AutomaticKeepAliveClientMixin {

final Map<int, String?> _translatedOverviews = {};
  final Map<int, bool> _isTranslatingMap = {};
  final _translator = MovieTvTranslator();
Future<void> _translateOverviewForEpisode(int key, String original) async {
    setState(() => _isTranslatingMap[key] = true);
    try {
      final translated = await _translator.mainTreanslator(
        original,
      );
      setState(() => _translatedOverviews[key] = translated);
    } finally {
      setState(() => _isTranslatingMap[key] = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Scaffold(
      body: _buildChat(),
      bottomNavigationBar: const _HomeBottom(isHome: false),
      floatingActionButton: _buildFAB(),
    );
  }

  Widget _buildFAB() {
    return AutoHide(
      scrollController: _chatScrollCtrl,
      hideController: _autoHideCtrl,
      direction: AxisDirection.right,
      offset: 75,
      child: ListenBuilder(
        listenable: _chatFabRN,
        builder: () {
          final valid =
              _chatScrollCtrl.positions.length == 1 &&
              _chatScrollCtrl.position.hasContentDimensions &&
              _chatScrollCtrl.position.maxScrollExtent > 0;
          return AnimatedSwitcher(
            transitionBuilder: (child, animation) {
              return RotationTransition(
                turns: Tween<double>(begin: 0.5, end: 0).animate(animation),
                child: child,
              );
            },
            duration: _durationShort,
            switchInCurve: Curves.fastEaseInToSlowEaseOut,
            switchOutCurve: Curves.fastEaseInToSlowEaseOut,
            child: valid ? _buildFABBtn() : UIs.placeholder,
          );
        },
      ),
    );
  }

  Widget _buildFABBtn() {
    final up =
        _chatScrollCtrl.offset >= _chatScrollCtrl.position.maxScrollExtent / 2;
    final icon = up ? MingCute.up_fill : MingCute.down_fill;
    return FloatingActionButton(
      key: ValueKey(up),
      mini: true,
      onPressed: () => _onTapFAB(up),
      child: Icon(icon),
    );
  }

  Widget _buildChat() {
    var switchDirection = SwitchDirection.next;
    final scrollSwitchChat = Stores.setting.scrollSwitchChat.get();

    final child = ListenBuilder(
      listenable: _chatRN,
      builder: () {
        final item = _curChat?.items;
        if (item == null) return UIs.placeholder;
        final listView = ListView.builder(
          key: Key(_curChatId.value), // Used for animation
          controller: _chatScrollCtrl,
          padding: const EdgeInsets.all(1),
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          itemCount: item.length,
          itemBuilder: (_, index) => _buildChatItem(item, index),
        );
        if (!scrollSwitchChat) return listView;
        return AnimatedSwitcher(
          duration: _durationShort,
          switchInCurve: Easing.standardDecelerate,
          switchOutCurve: Easing.standardDecelerate,
          transitionBuilder: (child, animation) => SlideTransitionX(
            position: animation,
            direction: switchDirection == SwitchDirection.next
                ? AxisDirection.up
                : AxisDirection.down,
            child: child,
          ),
          child: listView,
        );
      },
    );

    if (!scrollSwitchChat) return child;

    return SwitchIndicator(
      onSwitchPage: (direction) async {
        switchDirection = direction;
        switch (direction) {
          case SwitchDirection.previous:
            _switchPreviousChat();
            break;
          case SwitchDirection.next:
            _switchNextChat();
            break;
        }
      },
      child: child,
    );
  }

  Widget _buildChatItem(List<ChatHistoryItem> chatItems, int idx) {
    final chatItem = chatItems[idx];
    final node = _chatItemRNMap.putIfAbsent(chatItem.id, () => RNode());

    if (chatItem.toolCalls != null) {
      return SizedBox();
    }

    final title = switch (chatItem.role) {
      // User & System msgs have no loading status
      ChatRole.user ||
      ChatRole.system => ChatRoleTitle(role: chatItem.role, loading: false),
      ChatRole.tool || ChatRole.assist => _loadingChatIds.listenVal((chats) {
        final isLast = chatItems.length - 1 == idx;
        final isWorking = chats.contains(_curChatId.value) && isLast;
        return ChatRoleTitle(role: chatItem.role, loading: isWorking);
      }),
    };

    final child = Padding(
      padding: const EdgeInsets.only(top: 8, left: 11, right: 11, bottom: 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          title,
          const SizedBox(height: 6),
          ListenBuilder(
            listenable: node,
            builder: () {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Keep existing content rendering (text/images/etc.)
                  ChatHistoryContentView(
                    chatItem: chatItem,
                    postCallback: () {
                      setState(() {});
                    },
                  ),
                  // Append audio players if any audio contents exist
                  _audioPlayersFor(chatItem),
                ],
              );
            },
          ).paddingSymmetric(horizontal: 2),
          const SizedBox(height: 6),
        ],
      ),
    );

    final hovers = _buildChatItemHovers(chatItems, chatItem);
    const pad = 7.0;

    final content = InkWell(
      borderRadius: BorderRadius.circular(13),
      onLongPress: () => _onLongPressChatItem(context, chatItems, chatItem),
      child: child,
    );

    return Stack(
      children: [
        content,
        Positioned.fill(
          child: Hover(
            builder: (isHovered) {
              final hover = AnimatedContainer(
                duration: Durations.medium1,
                curve: Curves.fastEaseInToSlowEaseOut,
                width: isHovered ? (hovers.length * 33 + 2 * pad) : 0,
                height: 30,
                padding: const EdgeInsets.symmetric(horizontal: pad),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: hovers,
                  ),
                ),
              );
              return Align(
                alignment: context.isRTL
                    ? Alignment.topLeft
                    : Alignment.topRight,
                child: hover,
              );
            },
          ),
        ),
      ],
    );
  }

  // Treat both file paths and data URLs as audio
  bool looksLikeAudioDataUrl(String s) {
    final v = s.trim().toLowerCase();
    return (v.contains('data:audio/') == true 
//    ||            v.contains('data:image/') == true
            )
        ? true
        : false;
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

  Widget _audioPlayersFor(ChatHistoryItem item) {
    final audio = item.content.where(_isAudioContent).toList();
    if (audio.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final c in audio)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: audioTileFor(c),
          ),
      ],
    );
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

  // Case 2: data URL like "data:audio/wav;base64,...." (or raw PCM16)
  //   } else if (v.contains('data:image/') == true) {
  //     return Padding(
  //       padding: const EdgeInsets.symmetric(vertical: 8.0),
  //       child: ClipRRect(
  //         //   borderRadius: theme.codeBlockRadius,
  //         child: Base64ImageDisplay(fit: BoxFit.cover, base64String: c.raw,),
  //       ),
  //     );
  //   }
  //   // Fallback: return an empty widget if nothing matches
  //   return const SizedBox.shrink();
  // }

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

  List<Widget> _buildChatItemHovers(
    List<ChatHistoryItem> chatItems,
    ChatHistoryItem chatItem,
  ) {
        final int key = chatItems.index(chatItem);
    /// TODO  remember to implanting this => final bool isTranslating = _isTranslatingMap[key] == true;
    final String? translated = _translatedOverviews[key];

    final replayEnabled = chatItem.role.isUser;
    const size = 18.0;
    final color = context.theme.iconTheme.color?.withValues(alpha: 0.8);

    return [
      Btn.icon(
        onTap: () {
          context.pop();
          _MarkdownCopyPage.route.go(context, chatItem);
        },
        text: l10n.freeCopy,
        icon: Icon(BoxIcons.bxs_crop, size: size, color: color),
      ),
  //      Btn.icon(
  //       onTap: () async {
  //         context.pop();
  //       final tbase= await _MarkdownCopyPage.route.go(context, chatItem);
  //   if (translated != null) {
  //     setState(() => _translatedOverviews.remove(key));
  //     return;
  //   }
  //   await _translateOverviewForEpisode(key, tbase);
  //   if (_translatedOverviews[key] != null) {
  //   chatItem.content.clear();
  //   chatItem.content.add(ChatContent.text(translated!=''?translated!:'a problem exist in translation process that return translated text as ""'));
  //   _storeChat(_curChatId.value);
  //   _chatRN.notify();
  //   context.pop();
  // ///TODO  creating functions too can with one click switch between original message and translated one 

  //     ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Chat Message translated'), duration: Duration(seconds:1)));
  //   }

  //       },
  //       text: l10n.freeCopy,
  //       icon: Icon(BoxIcons.bxs_crop, size: size, color: color),
  //     ),
      if (replayEnabled)
        _loadingChatIds.listenVal((chats) {
          final isWorking = chats.contains(_curChatId.value);
          if (isWorking) return UIs.placeholder;
          return Btn.icon(
            onTap: () {
              context.pop();
              _onTapReplay(context, _curChatId.value, chatItem);
            },
            text: l10n.replay,
            icon: Icon(MingCute.refresh_4_line, size: size, color: color),
          );
        }),
      if (replayEnabled)
        Btn.icon(
          onTap: () {
            context.pop();
            _onTapEditMsg(context, chatItem);
          },
          text: libL10n.edit,
          icon: Icon(Icons.edit, size: size, color: color),
        ),
      Btn.icon(
        onTap: () {
          context.pop();
          _onTapDelChatItem(context, chatItems, chatItem);
        },
        text: l10n.delete,
        icon: Icon(Icons.delete, size: size, color: color),
      ),
      Btn.icon(
        onTap: () {
          context.pop();
          Pfs.copy(chatItem.toMarkdown);
        },
        text: libL10n.copy,
        icon: Icon(MingCute.copy_2_fill, size: size, color: color),
      ),
    ];
  }

  List<Widget> _buildChatItemFuncs(
    List<ChatHistoryItem> chatItems,
    ChatHistoryItem chatItem,
  ) {
    final replayEnabled = chatItem.role.isUser;

    return [
      Btn.tile(
        onTap: () {
          context.pop();
          _MarkdownCopyPage.route.go(context, chatItem);
        },
        text: l10n.freeCopy,
        icon: const Icon(BoxIcons.bxs_crop),
      ),
      if (replayEnabled)
        _loadingChatIds.listenVal((chats) {
          final isWorking = chats.contains(_curChatId.value);
          if (isWorking) return UIs.placeholder;
          return Btn.tile(
            onTap: () {
              context.pop();
              _onTapReplay(context, _curChatId.value, chatItem);
            },
            text: l10n.replay,
            icon: const Icon(MingCute.refresh_4_line),
          );
        }),
      if (replayEnabled)
        Btn.tile(
          onTap: () {
            context.pop();
            _onTapEditMsg(context, chatItem);
          },
          text: libL10n.edit,
          icon: const Icon(Icons.edit),
        ),
      Btn.tile(
        onTap: () {
          context.pop();
          _onTapDelChatItem(context, chatItems, chatItem);
        },
        text: l10n.delete,
        icon: const Icon(Icons.delete),
      ),
      Btn.tile(
        onTap: () {
          context.pop();
          Pfs.copy(chatItem.toMarkdown);
        },
        text: libL10n.copy,
        icon: const Icon(MingCute.copy_2_fill),
      ),
    ];
  }

  @override
  bool get wantKeepAlive => true;
}

extension on _ChatPageState {
  void _onTapFAB(bool up) async {
    if (!_chatScrollCtrl.hasClients) return;
    if (up) {
      await _chatScrollCtrl.animateTo(
        0,
        duration: _durationMedium,
        curve: Curves.easeInOut,
      );
    } else {
      _scrollBottom();
    }
    _chatFabRN.notify();
  }

  void _onLongPressChatItem(
    BuildContext context,
    List<ChatHistoryItem> chatItems,
    ChatHistoryItem chatItem,
  ) {
    final funcs = _buildChatItemFuncs(chatItems, chatItem);
    context.showRoundDialog(
      contentPadding: const EdgeInsets.all(11),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: funcs),
      ),
    );
  }
}

/// A widget that animates its child's visibility and size based on a boolean condition.
///
/// When [showContent] is true, the [child] fades in and expands.
/// When [showContent] is false, the [child] fades out and collapses to a SizedBox.shrink().
class AnimatedConditionalWidget extends StatefulWidget {
  /// Whether the [child] should be shown.
  /// Set to `true` to show content, `false` to hide.
  final bool showContent;

  /// The widget to be animated in or out.
  final Widget child;

  /// The duration of the animation.
  final Duration animationDuration;

  /// Creates an [AnimatedConditionalWidget].
  const AnimatedConditionalWidget({
    super.key,
    required this.showContent,
    required this.child,
    this.animationDuration = const Duration(milliseconds: 300),
  });

  @override
  State<AnimatedConditionalWidget> createState() =>
      _AnimatedConditionalWidgetState();
}

class _AnimatedConditionalWidgetState extends State<AnimatedConditionalWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacityAnimation;
  late Animation<double> _sizeFactorAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.animationDuration,
    );

    // Opacity animation: starts fading a bit earlier.
    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.7, curve: Curves.easeIn),
      ),
    );

    // Size animation: starts expanding/collapsing a bit later.
    _sizeFactorAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
      ),
    );

    // Initialize the state based on showContent
    if (widget.showContent) {
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(covariant AnimatedConditionalWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.showContent != oldWidget.showContent) {
      if (widget.showContent) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // We use SizeTransition to animate the height.
    // axisAlignment: -1.0 ensures the content collapses upwards (to the start of the axis).
    // The child of SizeTransition will then be wrapped by FadeTransition for opacity.
    return SizeTransition(
      sizeFactor: _sizeFactorAnimation,
      axisAlignment:
          -1.0, // Aligns to the top when collapsing/expanding vertically.
      child: FadeTransition(opacity: _opacityAnimation, child: widget.child),
    );
  }
}

class Base64Image extends StatelessWidget {
  final String? base64;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;
  final BorderRadius? borderRadius;
  final bool allowShrink;
  final Alignment alignment;
  final ImageRepeat repeat;

  const Base64Image({
    super.key,
    required this.base64,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
    this.borderRadius,
    this.allowShrink = true,
    this.alignment = Alignment.center,
    this.repeat = ImageRepeat.noRepeat,
  });

  Uint8List? _decodeBase64(String data) {
    try {
      final cleaned = _stripDataUri(data);
      return base64Decode(cleaned);
    } catch (_) {
      return null;
    }
  }

  String _stripDataUri(String s) {
    final commaIndex = s.indexOf(',');
    if (commaIndex >= 0 && s.substring(0, commaIndex).contains('base64')) {
      return s.substring(commaIndex + 1);
    }
    return s;
  }

  @override
  Widget build(BuildContext context) {
    if (base64 == null || base64!.trim().isEmpty) {
      return _wrap(placeholder ?? const SizedBox.shrink());
    }

    final bytes = _decodeBase64(base64!.trim());
    if (bytes == null || bytes.isEmpty) {
      return _wrap(errorWidget ?? const Icon(Icons.broken_image));
    }

    final image = Image.memory(
      bytes,
      width: width,
      height: height,
      fit: fit,
      alignment: alignment,
      repeat: repeat,
    );

    return _wrap(image);
  }

  Widget _wrap(Widget child) {
    if (borderRadius != null) {
      return ClipRRect(
        borderRadius: borderRadius!,
        child: SizedBox(width: width, height: height, child: child),
      );
    }
    if (!allowShrink && (width != null || height != null)) {
      return SizedBox(width: width, height: height, child: child);
    }
    return child;
  }
}

sealed class ChatEvent {}

class TextEvent extends ChatEvent {
  final String text;
  TextEvent(this.text);
}

class ImageEvent extends ChatEvent {
  final Uint8List imageBytes;
  ImageEvent(this.imageBytes);
}

class AudioEvent extends ChatEvent {
  final Uint8List audioBytes;
  AudioEvent(this.audioBytes);
}

final base64ImageRegex = RegExp(r'data:image\/\w+;base64,([A-Za-z0-9+/=]+)');
final base64AudioRegex = RegExp(r'data:audio\/\w+;base64,([A-Za-z0-9+/=]+)');

// class ChatStreamTransformer
//     extends StreamTransformerBase<String, ChatEvent> {
//   @override
//   Stream<ChatEvent> bind(StringBuffer stream) async* {
//     final buffer = StringBuffer();

//     await for (final chunk in stream) {
//       buffer.write(chunk);

//       final matches = base64ImageRegex.allMatches(buffer.toString());
//       if (matches.isNotEmpty) {
//         for (final match in matches) {
//           final base64Data = match.group(1)!;
//           final bytes = base64Decode(base64Data);
//           yield ImageEvent(bytes);
//         }
//         // Remove matched content from buffer
//         buffer.clear();
//       } else {
//         yield TextEvent(chunk);
//       }
//     }
//   }
// }
