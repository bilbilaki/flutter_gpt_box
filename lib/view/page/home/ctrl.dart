part of 'home.dart';

void _switchChat([String? id]) {
  id ??= allHistories.keys.firstOrNull ?? _newChat().id;

  final chat = allHistories[id];
  if (chat == null) {
    final msg = 'Switch Chat($id) not found';
    Loggers.app.warning(msg);
    return;
  }

  _curChatId.value = id;
  _chatItemRNMap.clear();
  _chatRN.notify();
  Future.delayed(_durationMedium, () {
    // Different chats have different height
    _chatFabRN.notify();
    if (Stores.setting.scrollAfterSwitch.get()) {
      _scrollBottom();
    }
  });
}

void _switchPreviousChat() {
  final iter = allHistories.keys.iterator;
  bool next = false;
  while (iter.moveNext()) {
    if (next) {
      _switchChat(iter.current);
      return;
    }
    if (iter.current == _curChatId.value) next = true;
  }
}

void _switchNextChat() {
  final iter = allHistories.keys.iterator;
  String? last;
  while (iter.moveNext()) {
    if (iter.current == _curChatId.value) {
      if (last != null) {
        _switchChat(last);
        return;
      }
    }
    last = iter.current;
  }
}

void _storeChat(String chatId) {
  final chat = allHistories[chatId];
  if (chat == null) {
    final msg = 'Store Chat($chatId) not found';
    Loggers.app.warning(msg);
    return;
  }

  chat.save();
}

ChatHistory _newChat() {
  late final ChatHistory newHistory;
  if (allHistories.isEmpty && !Stores.setting.initHelpShown.get()) {
    newHistory = ChatHistoryX.example;
  } else {
    newHistory = ChatHistoryX.empty;
  }

  /// Put newHistory to the first place, the default implementation of Dart's
  /// Map will put the new item to the last place.
  allHistories = {newHistory.id: newHistory, ...allHistories};
  return newHistory;
}

void _onTapDelChatItem(
  BuildContext context,
  List<ChatHistoryItem> chatItems,
  ChatHistoryItem chatItem,
) async {
  // Capture it.
  final chatId = _curChatId;
  final idx = chatItems.indexOf(chatItem) + 1;
  final result = await context.showRoundDialog<bool>(
    title: l10n.attention,
    child: Text(l10n.delFmt('${chatItem.role.localized}#$idx', l10n.chat)),
    actions: Btnx.okReds,
  );
  if (result != true) return;
  chatItems.remove(chatItem);
  _storeChat(chatId.value);
  _historyRN.notify();
  _chatRN.notify();
}

void _onTapDeleteChat(String chatId, BuildContext context) {
  final entity = allHistories[chatId];
  if (entity == null) {
    final msg = 'Delete Chat($chatId) not found';
    Loggers.app.warning(msg);
    context.showSnackBar(msg);
    return;
  }

  /// If items is empty, delete it directly
  if (entity.items.isEmpty) return _onDeleteChat(chatId);

  /// #119
  final diffTS = DateTime.now().millisecondsSinceEpoch - _noChatDeleteConfirmTS;
  if (diffTS < 30 * 1000) {
    return _onDeleteChat(chatId);
  }

  if (!Stores.setting.confrimDel.get()) return _onDeleteChat(chatId);

  final name = entity.name ?? 'Untitled';
  void onTap() {
    _onDeleteChat(chatId);
    context.pop();
  }

  context.showRoundDialog(
    title: l10n.attention,
    child: Text(l10n.delFmt(name, l10n.chat)),
    actions: [
      Btn.text(
        text: l10n.remember30s,
        onTap: () {
          _noChatDeleteConfirmTS = DateTime.now().millisecondsSinceEpoch;
          onTap();
        },
      ),
      Btn.ok(onTap: onTap),
    ],
  );
}

void _onDeleteChat(String chatId) {
  Stores.history.delete(chatId);

  if (_curChatId.value == chatId) {
    _switchPreviousChat();
  }
  final rmed = allHistories.remove(chatId);
  _historyRN.notify();

  if (rmed != null) {
    Stores.trash.addHistory(rmed);
  }
}

void _onTapRenameChat(String chatId, BuildContext context) async {
  final entity = allHistories[chatId];
  if (entity == null) {
    final msg = 'Rename Chat($chatId) not found';
    Loggers.app.warning(msg);
    context.showSnackBar(msg);
    return;
  }
  final ctrl = TextEditingController(text: entity.name);
  final title = await context.showRoundDialog<String>(
    title: l10n.rename,
    child: Input(
      controller: ctrl,
      autoFocus: true,
      onSubmitted: (p0) => context.pop(p0),
    ),
    actions: Btn.ok(onTap: () => context.pop(ctrl.text)).toList,
  );
  if (title == null || title.isEmpty) return;
  final ne = entity.copyWith(name: title)..save();
  allHistories[chatId] = ne;
  _historyRN.notify();
  _storeChat(chatId);
  _appbarTitleVN.value = title;
}

void _onCloneChat(String chatId, BuildContext context) async {
  final entity = allHistories[chatId];
  if (entity == null) {
    final msg = 'Clone Chat($chatId) not found';
    Loggers.app.warning(msg);
    context.showSnackBar(msg);
    return;
  }

  // Create a deep copy of the chat history
  final clonedItems = entity.items.map((item) {
    return ChatHistoryItem(
      role: item.role,
      content: item.content.map((c) => ChatContent(
        type: c.type,
        raw: c.raw,
        id: c.id,
      )).toList(),
      createdAt: item.createdAt,
      id: item.id,
      toolCallId: item.toolCallId,
      toolCalls: item.toolCalls,
      reasoning: item.reasoning,
      inputTokens: item.inputTokens,
      outputTokens: item.outputTokens,
      totalTokens: item.totalTokens,
      nanobenana: item.nanobenana,
    );
  }).toList();

  final clonedChat = ChatHistory.noid(
    items: clonedItems,
    name: '${entity.name ?? l10n.untitled} (Copy)',
    settings: entity.settings,
    isPinned: entity.isPinned,
    colorIndicator: entity.colorIndicator,
    folderId: entity.folderId,
  );

  allHistories = {clonedChat.id: clonedChat, ...allHistories};
  clonedChat.save();
  _historyRN.notify();
  context.showSnackBar('${l10n.chat} copied');
}

void _onTogglePinChat(String chatId, BuildContext context) {
  final entity = allHistories[chatId];
  if (entity == null) {
    final msg = 'Pin Chat($chatId) not found';
    Loggers.app.warning(msg);
    context.showSnackBar(msg);
    return;
  }

  final newPinState = !(entity.isPinned ?? false);
  final ne = entity.copyWith(isPinned: newPinState)..save();
  allHistories[chatId] = ne;
  _historyRN.notify();
  _storeChat(chatId);
  
  // Re-sort to show pinned chats at the top
  _resortHistories();
}

void _onSetColorIndicator(String chatId, BuildContext context) async {
  final entity = allHistories[chatId];
  if (entity == null) {
    final msg = 'Set color for Chat($chatId) not found';
    Loggers.app.warning(msg);
    context.showSnackBar(msg);
    return;
  }

  final colors = [
    null, // No color
    'red',
    'orange',
    'yellow',
    'green',
    'blue',
    'purple',
    'pink',
  ];

  final colorNames = [
    'None',
    '🔴 Red',
    '🟠 Orange',
    '🟡 Yellow',
    '🟢 Green',
    '🔵 Blue',
    '🟣 Purple',
    '🩷 Pink',
  ];

  final selectedColor = await context.showPickSingleDialog<String?>(
    title: 'Select Color',
    items: colors,
    display: (color) {
      final idx = colors.indexOf(color);
      return colorNames[idx];
    },
  );

  if (selectedColor == entity.colorIndicator) return;

  final ne = entity.copyWith(colorIndicator: selectedColor)..save();
  allHistories[chatId] = ne;
  _historyRN.notify();
  _storeChat(chatId);
}

void _onMoveToFolder(String chatId, BuildContext context) async {
  final entity = allHistories[chatId];
  if (entity == null) {
    final msg = 'Move Chat($chatId) not found';
    Loggers.app.warning(msg);
    context.showSnackBar(msg);
    return;
  }

  final folders = _allFolders.value.values.toList();
  final folderOptions = <String?>[null, ...folders.map((f) => f.id)];
  final folderNames = ['None', ...folders.map((f) => f.name)];

  final selectedFolderId = await context.showPickSingleDialog<String?>(
    title: 'Move to Folder',
    items: folderOptions,
    display: (folderId) {
      final idx = folderOptions.indexOf(folderId);
      return folderNames[idx];
    },
  );

  if (selectedFolderId == entity.folderId) return;

  final ne = entity.copyWith(folderId: selectedFolderId)..save();
  allHistories[chatId] = ne;
  _historyRN.notify();
  _storeChat(chatId);
}

void _onCreateFolder(BuildContext context) async {
  final ctrl = TextEditingController();
  final folderName = await context.showRoundDialog<String>(
    title: 'New Folder',
    child: Input(
      controller: ctrl,
      autoFocus: true,
      hint: 'Folder name',
      onSubmitted: (p0) => context.pop(p0),
    ),
    actions: Btn.ok(onTap: () => context.pop(ctrl.text)).toList,
  );

  if (folderName == null || folderName.isEmpty) return;

  final newFolder = ChatFolder.noid(name: folderName, isExpanded: true);
  _allFolders.value[newFolder.id] = newFolder;
  Stores.folder.put(newFolder);
  _allFolders.notify();
  _historyRN.notify();
}

void _onRenameFolder(String folderId, BuildContext context) async {
  final folder = _allFolders.value[folderId];
  if (folder == null) {
    final msg = 'Rename Folder($folderId) not found';
    Loggers.app.warning(msg);
    context.showSnackBar(msg);
    return;
  }

  final ctrl = TextEditingController(text: folder.name);
  final newName = await context.showRoundDialog<String>(
    title: l10n.rename,
    child: Input(
      controller: ctrl,
      autoFocus: true,
      onSubmitted: (p0) => context.pop(p0),
    ),
    actions: Btn.ok(onTap: () => context.pop(ctrl.text)).toList,
  );

  if (newName == null || newName.isEmpty) return;

  final updated = folder.copyWith(name: newName);
  _allFolders.value[folderId] = updated;
  Stores.folder.put(updated);
  _allFolders.notify();
  _historyRN.notify();
}

void _onDeleteFolder(String folderId, BuildContext context) async {
  final folder = _allFolders.value[folderId];
  if (folder == null) return;

  // Check if folder has chats
  final chatsInFolder = allHistories.values.where((h) => h.folderId == folderId);
  
  String message;
  if (chatsInFolder.isEmpty) {
    message = l10n.delFmt(folder.name, 'folder');
  } else {
    message = 'Delete folder "${folder.name}"? ${chatsInFolder.length} chat(s) will be moved out.';
  }

  final confirmed = await context.showRoundDialog<bool>(
    title: l10n.attention,
    child: Text(message),
    actions: Btnx.okReds,
  );

  if (confirmed != true) return;

  // Move all chats out of the folder
  for (final chat in chatsInFolder) {
    final updated = chat.copyWith(folderId: null)..save();
    allHistories[chat.id] = updated;
  }

  _allFolders.value.remove(folderId);
  Stores.folder.delete(folderId);
  _allFolders.notify();
  _historyRN.notify();
}

void _onDuplicateFolder(String folderId, BuildContext context) async {
  final folder = _allFolders.value[folderId];
  if (folder == null) return;

  final duplicated = ChatFolder.noid(
    name: '${folder.name} (Copy)',
    colorIndicator: folder.colorIndicator,
    isExpanded: folder.isExpanded,
  );

  _allFolders.value[duplicated.id] = duplicated;
  Stores.folder.put(duplicated);
  _allFolders.notify();
  _historyRN.notify();
}

void _onToggleFolderExpanded(String folderId) {
  final folder = _allFolders.value[folderId];
  if (folder == null) return;

  final updated = folder.copyWith(isExpanded: !(folder.isExpanded ?? true));
  _allFolders.value[folderId] = updated;
  Stores.folder.put(updated);
  _allFolders.notify();
}

void _resortHistories() {
  final entries = allHistories.entries.toList();
  
  // Sort: pinned first, then by last modified time
  entries.sort((a, b) {
    final aPinned = a.value.isPinned ?? false;
    final bPinned = b.value.isPinned ?? false;
    
    if (aPinned && !bPinned) return -1;
    if (!aPinned && bPinned) return 1;
    
    // Both pinned or both not pinned, sort by time
    final now = DateTime.now();
    final aTime = a.value.items.lastOrNull?.createdAt ?? now;
    final bTime = b.value.items.lastOrNull?.createdAt ?? now;
    return bTime.compareTo(aTime);
  });
  
  allHistories = Map.fromEntries(entries);
  _historyRN.notify();
}


/// Used in send btn and [_onCreateText]
void _onStopStreamSub(String chatId) async {
  _chatStreamSubs[chatId]?.cancel();
  _loadingChatIds.value.remove(chatId);
  _loadingChatIds.notify();
  _autoHideCtrl.autoHideEnabled = true;
}

void _onShareChat(BuildContext context) async {
  final curChat = _curChat;
  if (curChat == null) {
    final msg = 'Share Chat($_curChatId): null';
    Loggers.app.warning(msg);
    context.showSnackBar(msg);
    return;
  }

  final type = await context.showPickSingleDialog(
    title: l10n.share,
    items: ['img', 'txt'],
    display: (p0) => switch (p0) {
      'txt' => l10n.text,
      _ => l10n.image,
    },
  );
  if (type == null) return;

  if (type == 'txt') {
    final md = curChat.toMarkdown;
    Pfs.copy(md);
    context.showSnackBar(l10n.copied);
    return;
  }

  final result = curChat.gen4Share(context);
  var compressImg = false;
  final (pic, err) = await context.showLoadingDialog(
    fn: () async {
      final raw = await _screenshotCtrl.captureFromLongWidget(
        result,
        context: context,
        constraints: const BoxConstraints(maxWidth: 577),
        pixelRatio: MediaQuery.devicePixelRatioOf(context),
        delay: Durations.short4,
      );
      compressImg = Stores.setting.compressImg.get();
      if (compressImg) {
        return await ImageUtil.compress(raw, mime: 'image/png');
      }
      return raw;
    },
  );
  if (err != null || pic == null) return;

  final title = _curChat?.name ?? l10n.untitled;
  final ext = compressImg ? 'jpg' : 'png';
  final mime = compressImg ? 'image/jpeg' : 'image/png';
  await Pfs.shareBytes(
    bytes: pic,
    title: title,
    fileName: '$title.$ext',
    mime: mime,
  );
}

Future<void> _onTapFilePick(BuildContext context) async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowMultiple: true,
    allowedExtensions: [
      'txt',
      'md',
      'pdf',
      'doc',
      'docx',
      'xls',
      'xlsx',
      'ppt',
      'pptx',
      'png',
      'jpg',
      'jpeg',
      'mp3',
      'wav',
      'flac',
      'csv',
      'json',
      'dart',
      'py',
      'html',
      'sh',
    ],
  );
  final files = result?.files;
  if (files == null || files.isEmpty) return;
  _filesPicked.value.addAll(files.map((e) => e.path).whereType<String>());
  _filesPicked.notify();

    final bool? isModelUsingFilePathConfirmed = await _showFilePathUsageConfirmationDialog(context);

  if (isModelUsingFilePathConfirmed == true) {
    // User pressed 'Yes'
    print('User confirmed: Model *will* use file paths for tools.');
    // You can now proceed with logic that utilizes the file paths
    // for tool integration (e.g., passing paths to a backend service,
    // or a local tool execution).
    // Access the paths from _filesPicked.value
    for (String path in _filesPicked.value) {
      print('Path for tool usage: $path');
    }
  } else if (isModelUsingFilePathConfirmed == false) {
    // User pressed 'No'
    print('User denied: Model *will not* use file paths for tools. Perhaps only content is needed.');
    // You might decide to clear the paths, or process the files differently
    // (e.g., load file content directly without using their paths externally).
  } else {
    // Dialog was dismissed without explicit 'Yes' or 'No' (unlikely with barrierDismissible: false)
    print('Confirmation dialog was dismissed without a clear choice.');
  }
}





Future<bool?> _showFilePathUsageConfirmationDialog(BuildContext context) async {
  return showDialog<bool?>(
    context: context,
    // Set barrierDismissible to false to force the user to make a choice
    barrierDismissible: false,
    builder: (BuildContext dialogContext) {
      return AlertDialog(
        title: const Text('Confirm File Path Usage'),
        content: const Text(
          'Is the model intended to use the *file path* (not content) of these files for tool integration?',
          // Added clarity to the question
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () {
              // User pressed 'No'
              // Pop the dialog and return false
              Navigator.of(dialogContext).pop(false);
            },
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () {
              modelUseFilePath=true;
              // User pressed 'Yes'
              // Pop the dialog and return true
              Navigator.of(dialogContext).pop(true);
            },
            child: const Text('Yes'),
          ),
        ],
      );
    },
  );
}
// Set<String> _findAllDuplicateIds(Map<String, ChatHistory> allHistories) {
//   final existTitles = <String, Set<String>>{}; // {"title": ["id"]}
//   for (final item in allHistories.values) {
//     final title = item.name ?? '';
//     existTitles.putIfAbsent(title, () => {}).add(item.id);
//   }

//   final rmIds = <String>{};
//   for (final entry in existTitles.entries) {
//     /// If only one chat with the same title, skip
//     if (entry.value.length == 1) continue;
//     final ids = entry.value;

//     /// If the title is the same, first compare whether the content is the same

//     /// Collect all assist's reply content
//     final contentMap = <String, List<String>>{}; // {"id": ["content"]}
//     final timeMap = <String, int>{}; // {"id": time}
//     for (final id in ids) {
//       final history = allHistories[id];
//       if (history == null) continue;
//       for (final item in history.items) {
//         /// Only compare assist's reply which is variety
//         if (!item.role.isAssist) continue;
//         final content = item.toMarkdown;
//         contentMap.putIfAbsent(content, () => []).add(id);
//         final time = timeMap[id];
//         if (time == null || item.createdAt.millisecondsSinceEpoch > time) {
//           timeMap[id] = item.createdAt.millisecondsSinceEpoch;
//         }
//       }
//     }

//     /// Find out the same content
//     var anyDup = false;
//     for (var idx = 0; idx < contentMap.length - 1; idx++) {
//       final contentsA = contentMap.values.elementAt(idx);
//       final contentsB = contentMap.values.elementAt(idx + 1);
//       anyDup = contentsA.any((e) => contentsB.contains(e));
//       if (anyDup) break;
//     }

//     /// If there is no same content, skip
//     if (!anyDup) continue;

//     /// If there is same content, delete the old one
//     var latestTime = timeMap.values.first;
//     for (final entry in timeMap.entries) {
//       if (entry.value > latestTime) {
//         latestTime = entry.value;
//       }
//     }

//     rmIds.addAll(timeMap.entries
//         .where((e) => e.value != latestTime)
//         .map((e) => e.key)
//         .toList());
//   }
//   return rmIds;
// }

// void _removeDuplicateHistory(BuildContext context) async {
//   final rmIds = await compute(_findAllDuplicateIds, allHistories);
//   if (rmIds.isEmpty) return;

//   final rmCount = rmIds.length;
//   final children = <Widget>[Text(l10n.rmDuplicationFmt(rmCount))];
//   for (int idx = 0; idx < rmCount; idx++) {
//     final id = rmIds.elementAt(idx);
//     final item = allHistories[id];
//     if (item == null) continue;
//     children.add(Text(
//       '${idx + 1}. ${item.items.firstOrNull?.toMarkdown ?? libL10n.empty}',
//       maxLines: 1,
//       overflow: TextOverflow.ellipsis,
//       style: UIs.text12Grey,
//     ));
//   }
//   context.showRoundDialog(
//     title: l10n.attention,
//     child: SingleChildScrollView(
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: children,
//       ),
//     ),
//     actions: [
//       TextButton(
//         onPressed: () {
//           for (final id in rmIds) {
//             Stores.history.delete(id);
//             allHistories.remove(id);
//           }
//           _historyRN.notify();
//           if (!allHistories.keys.contains(_curChatId)) {
//             _switchChat();
//           }
//         },
//         child: Text(l10n.delete, style: UIs.textRed),
//       ),
//     ],
//   );
// }

void _locateHistoryListener() {
  Fns.throttle(
    () {
      // Calculate _curChatId is visible or not
      final idx = allHistories.keys.toList().indexOf(_curChatId.value);
      final offset = _historyScrollCtrl.offset;
      final height = _historyScrollCtrl.position.viewportDimension;
      final visible =
          offset - _historyLocateTollerance <= idx * _historyItemHeight &&
          offset + height + _historyLocateTollerance >=
              (idx + 1) * _historyItemHeight;
      _locateHistoryBtn.value = !visible;
    },
    id: 'calcChatLocateBtn',
    duration: 10,
  );
}

void _gotoHistory(String chatId) {
  final idx = allHistories.keys.toList().indexOf(chatId);
  if (idx == -1) return;
  _historyScrollCtrl.animateTo(
    idx * _historyItemHeight,
    duration: Durations.long1,
    curve: Curves.easeInOut,
  );
}

void _onTapReplay(
  BuildContext context,
  String chatId,
  ChatHistoryItem item,
) async {
  if (!item.role.isUser) return;
  final sure = await context.showRoundDialog<bool>(
    title: l10n.attention,
    child: Text('${l10n.replay} ?\n${l10n.replayTip}'),
    actions: Btnx.okReds,
  );
  if (sure != true) return;
  _onReplay(context: context, chatId: chatId, item: item);
}

void _onTapEditMsg(BuildContext context, ChatHistoryItem chatItem) async {
  final ctrl = TextEditingController(text: chatItem.toMarkdown);
  void onSubmit() {
    chatItem.content.clear();
    chatItem.content.add(ChatContent.text(ctrl.text));
    _storeChat(_curChatId.value);
    _chatRN.notify();
    context.pop();
  }

  await context.showRoundDialog(
    title: libL10n.edit,
    child: Input(
      controller: ctrl,
      maxLines: 7,
      minLines: 1,
      autoCorrect: true,
      autoFocus: true,
      action: TextInputAction.send,
      onSubmitted: (_) => onSubmit(),
    ),
    actions: Btn.ok(onTap: onSubmit).toList,
  );
}

void _autoScroll(String chatId) {
  if (Stores.setting.scrollBottom.get()) {
    Fns.throttle(
      () {
        // Only scroll to bottom when current chat is the working chat
        final isCurrentChat = chatId == _curChatId.value;
        if (!isCurrentChat) return;
        // If users stop the scroll, then disable auto scroll
        if (_userStoppedScroll) return;
        _scrollBottom();
      },
      id: 'autoScroll',
      duration: 100,
    );
  }
}

void _scrollBottom() async {
  final isDisplaying = _chatScrollCtrl.hasClients;
  if (isDisplaying) {
    await _chatScrollCtrl.animateTo(
      _chatScrollCtrl.position.maxScrollExtent,
      duration: _durationShort,
      curve: Curves.fastEaseInToSlowEaseOut,
    );
    // Sometimes the scroll is not at the bottom due to the caclulation of
    // [ListView.builder], so scroll again.
    _chatScrollCtrl.jumpTo(_chatScrollCtrl.position.maxScrollExtent);
  }
}

void _onSwitchModel(BuildContext context, {bool notifyKey = false}) async {
  final cfg = Cfg.current;
  if (cfg.key.isEmpty && notifyKey) {
    context.showRoundDialog(
      title: l10n.attention,
      child: Text(l10n.needOpenAIKey),
      actions: Btn.ok(
        onTap: () {
          context.pop();
          SettingsPage.route.go(
            context,
            args: SettingsPageArgs(tabIndex: SettingsTab.profile),
          );
        },
      ).toList,
    );
    return;
  }

  await Cfg.showPickModelDialog(
    context,
    initial: Cfg.chatType.value.model,
    onSelected: (model) {
      final newCfg = Cfg.chatType.value.copyWithModel(model);
      Cfg.setTo(cfg: newCfg);
    },
  );
}

// /// The chat type is determined by the following order:
// /// Programmatically -> AI -> Text
// Future<ChatType> _getChatType() async {
//   return _getChatTypeByProg() ?? await _getChatTypeByAI() ?? ChatType.text;
// }

// /// Recognize the chat type by the question content programmatically.
// ChatType? _getChatTypeByProg() {
//   if (isWeb) return ChatType.text;

//   final file = _filePicked.value;
//   if (file != null) {
//     final mime = file.mimeType;
//     if (mime != null) {
//       // If file is image
//       if (mime.startsWith('image/')) {
//         // explainImage / editImage
//         if (inputCtrl.text.isNotEmpty) {
//           return null;
//         }
//         return ChatType.varifyImage;
//       }
//       // If file is audio
//       if (mime.startsWith('audio/')) {
//         return ChatType.audioToText;
//       }
//     }
//   }

//   return null;
// }

// /// Send [inputCtrl.text] to OpenAI and get the chat type by the AI response.
// Future<ChatType?> _getChatTypeByAI() async {
//   if (inputCtrl.text.isEmpty) return null;

//   final config = OpenAICfg.current;
//   final result = await OpenAI.instance.chat.create(
//     model: config.model,
//     messages: [
//       ChatHistoryItem.single(
//         role: ChatRole.system,
//         raw: '''
// There are some types of chat:
// ${ChatType.values.map((e) => e.name).join('/')}
// Which is most proper type for this chat? (Only response the `code` of type, eg: `text`)
// ''',
//       ).toOpenAI,
//       ChatHistoryItem.single(
//         raw: inputCtrl.text,
//         role: ChatRole.user,
//       ).toOpenAI,
//     ],
//   );
//   final type =
//       result.choices.firstOrNull?.message.content?.firstOrNull?.text?.trim();
//   if (type == null) return null;
//   return ChatType.fromString(type);
// }

Future<void> _switchPage(HomePageEnum page) {
  return _pageCtrl.animateToPage(
    page.index,
    duration: _durationMedium,
    curve: Curves.fastEaseInToSlowEaseOut,
  );
}

Future<bool> _askMcpConfirm(
  BuildContext context,
  ToolFunc func,
  String help,
) async {
  final permittedMcp = Stores.mcp.permittedTools.get();
  if (permittedMcp.contains(func.name)) return true;

  final remember = false.vn;
  final permitted = await context.showRoundDialog(
    title: l10n.attention,
    child: SingleChildScrollView(
      child: SimpleMarkdown(data: '${l10n.toolConfirmFmt(func.name)}\n\n$help'),
    ),
    actions: [
      DontShowAgainTile(val: remember),
      Btnx.okRed,
    ],
  );
  if (permitted == true && remember.value) {
    permittedMcp.add(func.name);
    Stores.mcp.permittedTools.set(permittedMcp);
  }
  return permitted == true;
}
