part of '../home.dart';

class _HomeBottom extends StatefulWidget {
  final bool isHome;

  const _HomeBottom({required this.isHome});

  @override
  State<_HomeBottom> createState() => _HomeBottomState();
}

final class _HomeBottomState extends State<_HomeBottom> {
  static const _boxShadow = [
    BoxShadow(color: Colors.black12, blurRadius: 3, offset: Offset(0, -0.5)),
  ];

  static const _boxShadowDark = [
    BoxShadow(color: Colors.white12, blurRadius: 3, offset: Offset(0, -0.5)),
  ];

  // Hold-to-record runtime state
  bool _isRecording = false;
  String? _recordingPath;

  @override
  void initState() {
    super.initState();
    // Update token counter when user types
  }

  @override
  void dispose() {
    super.dispose();
  }

  // void onTextChangedForTokens({String? modelText = ''}) {
  //   final userText = inputCtrl.text;
  //   // Only user text here; model text is added during streams (see token update hooks below)
  //   // TokenCounter.updateFrom(userText: userText, modelText: '');
  //   final u = userText;
  //   final m = modelText ?? '';
  //   String total;
  //   total = u + m;

  //   final encoding = tk.getEncoding('cl100k_base');
  //   final xcounter = ss.currentTokenCount.get();
  //  // _curPage.value == HomePageEnum.history;

  //   final countr = encoding.encode(total).length;
  //   ss.currentTokenCount.set(countr + xcounter);
  //   // notifyListeners(); // Notify listeners that current token count has changed
  // }

  Future<void> _startHoldRecord() async {
    if (_isRecording) return;
    if (!await _ensureRecordPermission()) {
      context.showSnackBar(l10n.emptyFields('Microphone permission'));
      return;
    }
    final dir = await Directory.systemTemp.createTemp('rec_hold_');
    _recordingPath = p.join(
      dir.path,
      'hold_${DateTime.now().millisecondsSinceEpoch}.wav',
    );

    try {
      await _audioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 16000,
          bitRate: 128000,
        ),
        path: _recordingPath!,
      );
      setState(() => _isRecording = true);
    } catch (e) {
      context.showSnackBar('Record start failed: $e');
    }
  }

  Future<void> _stopHoldRecord({bool cancel = false}) async {
    if (!_isRecording) return;
    try {
      await _audioRecorder.stop();
    } catch (_) {}
    setState(() => _isRecording = false);

    if (cancel) return;

    final path = _recordingPath;
    _recordingPath = null;
    if (path == null || !File(path).existsSync()) {
      context.showSnackBar('No audio captured');
      return;
    }

    // Route recorded audio: text + recorded audio -> stream textual answer
    // This uses the existing voice input flow (VoiceJustInput) so it attaches the audio base64.
    final chatId = _curChatId.value;
    final text = inputCtrl.text; // keep any current text
    _onTtsModel(context, chatId, text, [path]);
  }

  @override
  Widget build(BuildContext context) {
    final child = _homeBottomRN.listen(_build);

    return _isDesktop.listenVal((isDesktop) {
      if (isDesktop != widget.isHome) return child;
      return UIs.placeholder;
    });
  }

  Widget _build() {
    return Container(
      padding: isDesktop
          ? const EdgeInsets.only(left: 11, right: 11, top: 5, bottom: 17)
          : const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(17)),
        boxShadow: RNodes.dark.value ? _boxShadow : _boxShadowDark,
      ),
      child: AnimatedPadding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        curve: Curves.fastEaseInToSlowEaseOut,
        duration: Durations.short1,
        child: _buildBottom(),
      ),
    );
  }

  Widget _buildBottom() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _PickedFilesPreview(), // now powered by AttachmentPreview adapter
        _buildBottomFnsTwoRows(),
        _buildTextField(),
        SizedBox(height: MediaQuery.paddingOf(context).bottom),
      ],
    );
  }
//final url = "https://www.google.com";


Widget _buildBottomFnsTwoRows() {
  return Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          IconButton(
            onPressed: () {
              _switchChat(_newChat().id);
              _historyRN.notify();
              if (_curPage.value == HomePageEnum.history) {
                _switchPage(HomePageEnum.chat);
              }
            },
            icon: const Icon(MingCute.add_fill, size: 17),
          ),
          IconButton(
            onPressed: () => _onTapDeleteChat(_curChatId.value, context),
            icon: const Icon(Icons.delete, size: 19),
          ),
          _buildFileBtn(),
          _buildSettingsBtn(), // existing chat settings
          _buildOpenSettingsDrawerBtn(), // new: open Hive-backed drawer
          _buildRight(),
        ],
      ),
      const SizedBox(height: 2),
      Row(
        children: [
          IconButton(
            tooltip: 'Canvas',
            icon: const Icon(Icons.edit_note_rounded, size: 19),
            onPressed: () => _openCanvas(context, inputCtrl),
          ),
          IconButton(
            tooltip: 'Translate Files',
            icon: const Icon(Icons.translate, size: 19),
            onPressed: () => _navigateToAnotherPage(context),
          ),
          //     IconButton(
          //   tooltip: 'G sign',
          //   icon: const Icon(Icons.g_mobiledata, size: 19),
          //   onPressed: () => _navigateToWebView(context),
          // ),
         // IconButton(
         //   tooltip: 'Voice mode',
          //  onPressed: () {
            //   Navigator.of(context).push(
            //     MaterialPageRoute(
            //       builder: (_) => VoiceAssistantScreen(
            //         // controller: VoiceSessionController(
            //         //   chatId: _curChatId.value,
            //         //   onUserPartial: (p) {
            //         //     // Optional: Show floating live transcript
            //         //   },
            //         //   onTtsChunk: (pcm) {
            //         //     // Hook for UI animations; playback handling can be implemented by you if needed
            //         //   },
            //        // ),
            //       ),
            //     ),
            //   );
         //   },
            // icon: const Icon(Icons.record_voice_over, size: 20),
        //  ),
          const Spacer(),
          UIs.width7,
          _buildSwitchChatType(),
          UIs.width7,
        ],
      ),
    ],
  );
}

// Widget _buildBottomFnsScrollable() {
//   return SingleChildScrollView(
//     scrollDirection: Axis.horizontal,
//     padding:  EdgeInsets.symmetric(horizontal: 8),
//     child: Row(
//       mainAxisSize: MainAxisSize.min,
//       children: [
//         IconButton(
//           onPressed: () {
//             _switchChat(_newChat().id);
//             _historyRN.notify();
//             if (_curPage.value == HomePageEnum.history) {
//               _switchPage(HomePageEnum.chat);
//             }
//           },
//           icon:  Icon(MingCute.add_fill, size: 17),
//         ),
//         IconButton(
//           onPressed: () => _onTapDeleteChat(_curChatId.value, context),
//           icon:  Icon(Icons.delete, size: 17),
//         ),
//         _buildFileBtn(),
//         _buildSettingsBtn(), // existing chat settings
//         _buildOpenSettingsDrawerBtn(), // new: open Hive-backed drawer
//         _buildRight(),
//         IconButton(
//           tooltip: 'Canvas',
//           icon: const Icon(Icons.edit_note_rounded, size: 17),
//           onPressed: () => _openCanvas(context, inputCtrl),
//         ),
//         IconButton(
//           tooltip: 'Translate Files',
//           icon: const Icon(Icons.translate, size: 17),
//           onPressed: () => _navigateToAnotherPage(context),
//         ),
//         IconButton(
//           tooltip: 'Voice mode',
//           onPressed: (){}, //{
//           //  Navigator.of(context).push(
//            //   MaterialPageRoute(
//            //     builder: (_) => VoiceAssistantScreen(
//               //     controller: VoiceSessionController(
//               //       chatId: _curChatId.value,
//               //       onUserPartial: (p) {
//               //         // Optional: Show floating live transcript
//               //       },
//               //       onTtsChunk: (pcm) {
//               //         // Hook for UI animations; playback handling can be implemented by you if needed
//               //       },
//               //     ),
//                //  ),
//             //   ),
//           //  ),
//        //  ] },
//           icon:  Icon(Icons.record_voice_over, size: 17),
//         ),
//         const SizedBox(width: 4),
//         UIs.width7,
//         _buildSwitchChatType(),
//         UIs.width7,
//       ],
//     ),
//   );
// }
  Widget _buildSettingsBtn() {
    return IconButton(
      onPressed: _onTapSetting,
      icon:  Icon(Icons.settings, size: 17),
    );
  }

  Widget _buildOpenSettingsDrawerBtn() {
    return IconButton(
      tooltip: 'Open Settings Drawer',
      onPressed: () {
        // Requires Scaffold with endDrawer: AiSettingsDrawerHive(...)
        final scaffold = Scaffold.maybeOf(context);
        if (scaffold == null) {
          context.showSnackBar('No Scaffold found for opening drawer.');
          return;
        }
        scaffold.openEndDrawer();
      },
      icon:  Icon(Icons.tune, size: 17),
    );
  }

  Widget _buildFileBtn() {
    return Cfg.chatType.listenVal((chatType) {
      return switch (chatType) {
        ChatType.text || ChatType.img => IconButton(
          onPressed: () => _onTapFilePick(context),
          icon: const Icon(MingCute.file_upload_fill, size: 19),
        ),
        ChatType.audio => IconButton(
          onPressed: () => _onTapFilePick(context),
          icon: const Icon(MingCute.file_upload_fill, size: 19),
        ),
        ChatType.voice => IconButton(
          onPressed: () => _onTapFilePick(context),
          icon: const Icon(MingCute.file_upload_fill, size: 19),
        ),
        ChatType.voicejustin => IconButton(
          onPressed: () => _onTapFilePick(context),
          icon: const Icon(MingCute.file_upload_fill, size: 19),
        ),
        ChatType.autoenglishtrans => IconButton(
          onPressed: () => _onTapFilePick(context),
          icon: const Icon(MingCute.file_upload_fill, size: 19),
        ),
      };
    });
  }

  Widget _buildTextField() {
    return Column(
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Tokens: ${ss.currentTokenCount.get()}',
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),

        Input(
          controller: inputCtrl,
          label: l10n.message,
          node: _imeFocus,
          action: TextInputAction.newline,
          maxLines: 5,
          minLines: 1,
          type: TextInputType
              .multiline, // Keep this, or 'Wrap' will not work on iOS
          autoCorrect: true,
          suggestion: true,
          onTap: () async {
            if (_curPage.value != HomePageEnum.chat) {
              await _switchPage(HomePageEnum.chat);
            }
            await Future.delayed(Durations.medium4);
            _scrollBottom();
          },
          onTapOutside: (p0) {
            if (_curPage.value == HomePageEnum.chat) return;
            _imeFocus.unfocus();
          },
          contextMenuBuilder: (context, editableTextState) {
            final List<ContextMenuButtonItem> buttonItems =
                editableTextState.contextMenuButtonItems;
            if (inputCtrl.text.isNotEmpty) {
              buttonItems.add(
                ContextMenuButtonItem(
                  label: libL10n.clear,
                  onPressed: () {
                    inputCtrl.clear();
                  },
                ),
              );
            }
            return AdaptiveTextSelectionToolbar.buttonItems(
              anchors: editableTextState.contextMenuAnchors,
              buttonItems: buttonItems,
            );
          },
          suffix: _curChatId.listenVal((chatId) {
            return _loadingChatIds.listenVal((chats) {
              final isWorking = chats.contains(chatId);
              if (isWorking) {
                return Btn.icon(
                  onTap: () => _onStopStreamSub(chatId),
                  icon: const Icon(Icons.stop),
                );
              }
              // Dynamic: if no text -> hold-to-record button; else -> send button
              return ListenableBuilder(
                listenable: inputCtrl,
                builder: (_, __) {
                  final hasText = inputCtrl.text.trim().isNotEmpty;
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!hasText)
                        _HoldToRecordButton(
                          isRecording: _isRecording,
                          onStart: _startHoldRecord,
                          onCancel: () => _stopHoldRecord(cancel: true),
                          onStopAndSend: () => _stopHoldRecord(),
                        ),
                      if (hasText)
                        Btn.icon(
                          onTap: () =>
                              _onCreateRequest(context, _curChatId.value),
                          icon: const Icon(Icons.send, size: 18),
                        ),
                      IconButton(
                        tooltip: 'Prompt generator',
                        onPressed: _openPromptGenerator,
                        icon: const Icon(Icons.auto_awesome, size: 18),
                      ),
                    ],
                  );
                },
              );
            });
          }),
        ),
      ],
    );
  }

  void _openPromptGenerator() {
    showDialog(
      context: context,
      builder: (ctx) => PromptGeneratorDialog(
        onPromptGenerated: (gen) {
          if (gen.isEmpty) return;
          final cur = inputCtrl.text;
          inputCtrl.text = cur.isEmpty ? gen : '$cur\n$gen';
          inputCtrl.selection = TextSelection.fromPosition(
            TextPosition(offset: inputCtrl.text.length),
          );
        },
      ),
    );
  }

  Widget _buildSwitchChatType() {
    return Cfg.chatType.listenVal((chatT) {
      return FadeIn(
        key: ValueKey(chatT),
        child: PopupMenu(
          items: ChatType.btns,
          onSelected: (val) => Cfg.chatType.value = val,
          initialValue: chatT,
          tooltip: libL10n.select,
          borderRadius: BorderRadius.circular(17),
          child: _buildRoundRect(
            Row(
              children: [
                Icon(chatT.icon, size: 15),
                UIs.width7,
                Text(chatT.name, style: UIs.text13),
              ],
            ),
          ),
        ),
      );
    });
  }

  Future<void> _openCanvas(
    BuildContext context,
    TextEditingController inputCtrl,
  ) async {
    final result = await Navigator.of(
      context,
    ).push<CanvasResult>(_fadeRoute(const FreeCanvasPage()));
    if (result == null) return;

    for (final p in result.parts) {
      inputCtrl.text = p.text;
    }
  }

  Route<T> _fadeRoute<T>(Widget page) {
    return PageRouteBuilder<T>(
      pageBuilder: (_, __, ___) => page,
      transitionsBuilder: (_, anim, __, child) {
        return FadeTransition(
          opacity: anim.drive(CurveTween(curve: Curves.easeInOut)),
          child: child,
        );
      },
      transitionDuration: const Duration(milliseconds: 220),
      reverseTransitionDuration: const Duration(milliseconds: 200),
      opaque: true,
      fullscreenDialog: true,
    );
  }

  Future<void> _navigateToAnotherPage(BuildContext context) async {
    await Navigator.of(context).push<void>(
      _fadeRoute( ChunkerInterfaceand()),
    ); // Replace AnotherPage with your desired page
  }
// Future<void> _navigateToWebView(BuildContext context) async {
//     await Navigator.of(context).push<void>(
//       _fadeRoute( ()),
//     ); // Replace AnotherPage with your desired page
//   }

  Widget _buildRoundRect(Widget child) {
    return Container(
      decoration: BoxDecoration(
        color: const Color.fromARGB(35, 151, 151, 151),
        borderRadius: BorderRadius.circular(17),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      child: child,
    );
  }

  void _onTapSetting() async {
    final chat = _curChat;
    if (chat == null) {
      context.showSnackBar(libL10n.empty);
      return;
    }

    await _ChatSettings.route.go(context, chat);
  }

  Widget _buildRight() {
    return _curPage.listenVal((val) {
      return val == HomePageEnum.chat ? _buildChatMeta() : _buildSyncChats();
    });
  }

  Widget _buildSyncChats() {
    final rs = BakSync.instance.remoteStorage;
    if (rs == null) return UIs.placeholder;
    return IconButton(
      onPressed: _onTapSyncChats,
      icon: const Icon(Icons.sync, size: 19),
    );
  }

  Widget _buildChatMeta() {
    if (BuildMode.isRelease) return UIs.placeholder;
    return IconButton(
      icon: const Icon(Icons.code, size: 19),
      onPressed: _onTapMeta,
    );
  }

  void _onTapMeta() {
    final chat = _curChat;
    if (chat == null) {
      context.showSnackBar(libL10n.empty);
      return;
    }

    final jsonRaw = jsonIndentEncoder.convert(chat.toJson());
    final md =
        '''
```json
$jsonRaw
```''';

    context.showRoundDialog(
      title: l10n.raw,
      child: SingleChildScrollView(child: SimpleMarkdown(data: md)),
      actions: Btnx.oks,
    );
  }

  void _onTapSyncChats() async {
    await BakSync.instance.sync();
  }
}

class _HoldToRecordButton extends StatelessWidget {
  final bool isRecording;
  final VoidCallback onStart;
  final VoidCallback onStopAndSend;
  final VoidCallback onCancel;

  const _HoldToRecordButton({
    required this.isRecording,
    required this.onStart,
    required this.onStopAndSend,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPressStart: (_) => onStart(),
      onLongPressEnd: (_) => onStopAndSend(),
      onLongPressCancel: onCancel,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isRecording ? Colors.red.shade600 : Colors.blueGrey.shade700,
          shape: BoxShape.circle,
        ),
        child: Icon(
          isRecording ? Icons.mic : Icons.mic_none,
          size: 20,
          color: Colors.white,
        ),
      ),
    );
  }
}
