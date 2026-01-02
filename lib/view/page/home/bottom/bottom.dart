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

  bool _isRecording = false;
  String? _recordingPath;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

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
    if (path == null || !File(path).existsSync()) {
      context.showSnackBar('No audio captured');
      _recordingPath = null;

      return;
    }

    final chatId = _curChatId.value;
    final text = inputCtrl.text;
    _onAudioModel(context, chatId, text, [path]);
    _recordingPath = null;
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
          : const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
        _PickedFilesPreview(),
        _buildBottomFnsTwoRows(),
        _buildTextField(),
        SizedBox(height: MediaQuery.paddingOf(context).bottom),
      ],
    );
  }

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
            _buildSettingsBtn(),
            _buildOpenSettingsDrawerBtn(),
            _buildRight(),
            _buildFileSearchBtn(),
            _buildVoiceChatBtn(),
          ],
        ),
        const SizedBox(height: 1),
        Row(
          children: [
            IconButton(
              tooltip: 'X.Search',
              icon: const Icon(Icons.one_x_mobiledata, size: 19),
              onPressed: () => _navigateToPage(context, XAiSearchFantasy()),
            ),
            IconButton(
              tooltip: 'Browser Automation',
              icon: const Icon(Icons.auto_awesome_motion_sharp, size: 19),
              onPressed: () => _navigateToPage(context, PDFGeneratorWidget()),
            ),

            const Spacer(),
            UIs.width7,
            _buildSwitchChatType(),
            UIs.width7,
          ],
        ),
      ],
    );
  }

  Widget _buildSettingsBtn() {
    return IconButton(
      onPressed: _onTapSetting,
      icon: Icon(Icons.settings, size: 17),
    );
  }

  Widget _buildFileSearchBtn() {
    return IconButton(
      onPressed: () async {
        await _navigateToPage(context, GitLoaderApp());
      },
      icon: Icon(Icons.search, size: 17),
    );
  }

  Widget _buildVoiceChatBtn() {
    return IconButton(
      onPressed: () async {
        await _navigateToPage(context, VoiceAssistantScreen());
      },
      icon: Icon(Icons.voice_chat, size: 17),
    );
  }

  Widget _buildOpenSettingsDrawerBtn() {
    return IconButton(
      tooltip: 'Open Settings Drawer',
      onPressed: () {
        final state = homeScaffoldKey.currentState ?? Scaffold.maybeOf(context);
        if (state == null) {
          context.showSnackBar('No Scaffold found for opening drawer.');
          return;
        }
        state.openEndDrawer();
      },
      icon: Icon(Icons.tune, size: 17),
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
        Input(
          controller: inputCtrl,
          label: l10n.message,
          node: _imeFocus,
          action: TextInputAction.newline,
          maxLines: 5,
          minLines: 1,
          type: TextInputType.multiline,
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
                          icon: Icon(Icons.send, size: 18),
                        ),
                      IconButton(
                        tooltip: 'Prompt generator',
                        onPressed: _openPromptGenerator,
                        icon: Icon(Icons.auto_awesome, size: 18),
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

  Future<void> _navigateToPage(BuildContext context, Widget page) async {
    await Navigator.of(context).push<void>(_fadeRoute(page));
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
      return val == HomePageEnum.chat ? _buildChatMeta() : _buildChatMeta();
    });
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
