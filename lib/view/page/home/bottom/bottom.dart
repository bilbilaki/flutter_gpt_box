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
  bool _isExtrasMenuExpanded = false;
  late File _recordingPath;

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
    final appdir = await getApplicationCacheDirectory();
 final   _recordingPath1= await Directory(
          p.join(
            appdir.path,
            'rec_hold',
            
          ),).create();
        _recordingPath= await  File(p.join(_recordingPath1.path, 'record_${DateTime.now().millisecondsSinceEpoch}.wav')).create();
    
    try {
      await _audioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 16000,
          bitRate: 128000,
        ),
        path: _recordingPath.path,
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

    final path = _recordingPath.path;
    if (!File(path).existsSync()) {
      context.showSnackBar('No audio captured');
    

      return;
    }

    final chatId = _curChatId.value;
      final files = [File(path)];
  if (files.isEmpty) return;
  _filesPicked.value.addAll(files.map((e) => e.path).whereType<String>());
  _filesPicked.notify();
    _onCreateRequest(context, chatId);
   // File(_recordingPath.path).deleteSync();
   ////TODO thinking about how remove old files and implant result if find answer
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
       const SizedBox(height: 0.5),
       Row(children: [
            _buildExtrasMenu(),
            const Spacer(),
            UIs.width7,
            _buildSwitchChatType(),
            UIs.width7,


       ]),
        
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

  Widget _buildExtrasMenu() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedSize(
          duration: Durations.short1,
          curve: Curves.fastOutSlowIn,
          child: ClipRect(
            child: Align(
              alignment: Alignment.bottomCenter,
              heightFactor: _isExtrasMenuExpanded ? 1 : 0,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildExtrasMenuItem(
                    context,
                    label: 'X.Search',
                    icon: Icons.one_x_mobiledata,
                    onPressed: () => _openExtrasPage(XAiSearchFantasy()),
                  ),
                  _buildExtrasMenuItem(
                    context,
                    label: 'Media Lab',
                    icon: Icons.photo_library,
                    onPressed: () => _openExtrasPage(const MediaLabPage()),
                  ),
                  _buildExtrasMenuItem(
                    context,
                    label: 'Speech',
                    icon: Icons.record_voice_over,
                    onPressed: () => _openExtrasPage(const OpenAITTSPage()),
                  ),
                ],
              ),
            ),
          ),
        ),
        IconButton(
          tooltip: _isExtrasMenuExpanded ? 'Close extras menu' : 'Extras menu',
          icon: Icon(
            _isExtrasMenuExpanded ? Icons.expand_more : Icons.menu_open,
            size: 19,
          ),
          onPressed: () => setState(() => _isExtrasMenuExpanded = !_isExtrasMenuExpanded),
        ),
      ],
    );
  }

  Future<void> _openExtrasPage(Widget page) async {
    setState(() => _isExtrasMenuExpanded = false);
    await _navigateToPage(context, page);
  }

  Widget _buildExtrasMenuItem(
    BuildContext context, {
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: TextButton.icon(
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          minimumSize: const Size(0, 0),
          backgroundColor: colorScheme.surface.withOpacity(0.12),
          foregroundColor: colorScheme.onSurface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onPressed: onPressed,
        icon: Icon(icon, size: 17),
        label: Text(label, style: UIs.text13),
      ),
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
                builder: (_, _) {
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
