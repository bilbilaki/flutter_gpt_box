/// OpenAI chat request related funcs
part of 'home.dart';

bool _validChatCfg(BuildContext context) {
  final config = Cfg.current;
  final urlEmpty = config.url == 'https://api.openai.com' || config.url.isEmpty;
  if (urlEmpty && config.key.isEmpty) {
    final msg = l10n.emptyFields('${l10n.secretKey} | Api Url');
    Loggers.app.warning(msg);
    context.showSnackBar(msg);
    return false;
  }
  return true;
}

/// Assumption that context len = 3:
/// - History len = 0 => [prompt]
/// - History len = 1 => [prompt, idx0]
/// - 2 => [prompt, idx0, idx1]
/// - n >= 3 => [prompt, idxn-2, idxn-1]
Future<Iterable<ChatCompletionMessage>> _historyCarried(
  ChatHistory workingChat,
) async {
  final config = Cfg.current;

  // #106
  final ignoreCtxCons = workingChat.settings?.ignoreContextConstraint == true;
  if (ignoreCtxCons) {
    return Future.wait(workingChat.items.map((e) => e.toOpenAI()));
  }

  final promptStr = config.prompt + Stores.mcp.memories.get().join('\n');
  final prompt = promptStr.isNotEmpty
      ? await ChatHistoryItem.single(
          role: ChatRole.system,
          raw: promptStr,
        ).toOpenAI()
      : null;

  // #101
  if (workingChat.settings?.headTailMode == true) {
    final first = await workingChat.items.firstOrNull?.toOpenAI();
    return [if (prompt != null) prompt, if (first != null) first];
  }

  var count = 0;
  final msgs = <ChatCompletionMessage>[];
  for (final item in workingChat.items.reversed) {
    if (count > config.historyLen) break;
    if (item.role.isSystem) continue;
    final msg = await item.toOpenAI();
    msgs.add(msg);
    count++;
  }
  if (prompt != null) msgs.add(prompt);
  return msgs.reversed;
}

/// Auto select model and send the request
void _onCreateRequest(BuildContext context, String chatId) async {
  if (!_validChatCfg(context)) return;

  // #18
  // Prohibit users from starting chat in the initial chat
  if (_curChat?.isInitHelp ?? false) {
    final newId = _newChat().id;
    _switchChat(newId);
    chatId = newId;
  }

  final chatType = Cfg.chatType.value;

  final input = inputCtrl.text;
  if (input.isEmpty) return;
  _imeFocus.unfocus();

  _loadingChatIds.value.add(chatId);
  _loadingChatIds.notify();
  _autoHideCtrl.autoHideEnabled = false;

  final func = switch ((chatType, _filesPicked.value)) {
    (ChatType.text, _) =>_onCreateText,
  //    ss.response == true ? _onCreateResponse : 
    (ChatType.img, _) => _onCreateImg,
    (ChatType.audio, _) =>
      _onAudioModel, // audio generation (TTS-like) streaming
    (ChatType.voice, _) => _onTtsModel, // voice in + voice out
    (ChatType.voicejustin, _) => _onCreateText, // voice in + text out (stream)
    (ChatType.autoenglishtrans, _) => _onCreateTextTranslated,
  };

  return await func(context, chatId, input, _filesPicked.value);
}

Future<void> _onCreateText(
  BuildContext context,
  String chatId,
  String input,
  List<String> files,
) async {
  final workingChat = allHistories[chatId];
  if (workingChat == null) {
    final msg = 'Chat($chatId) not found';
    Loggers.app.warning(msg);
    context.showSnackBar(msg);
    return;
  }
  final config = Cfg.current;

  final questionContents = <ChatContent>[ChatContent.text(input)];
  for (final file in files) {
    if (!modelUseFilePath) {
      // Ensure images are sent as base64 data URL
      final content = await contentFromPath(file);
      questionContents.add(content);
    } else if (modelUseFilePath) {
      final content = <ChatContent>[
        ChatContent.text(
          'For Using Tools with file operation use this File Path: $file',
        ),
      ];
      questionContents.addAll(content);
      modelUseFilePath = false;
    }
  }
  final question = ChatHistoryItem.gen(
    content: questionContents,
    role: ChatRole.user,
  );
  final msgs = (await _historyCarried(workingChat)).toList();
  msgs.add(await question.toOpenAI());

  workingChat.items.add(question);
  inputCtrl.clear();
  _chatRN.notify();
  _autoScroll(chatId);
  final titleCompleter = await genChatTitle(context, chatId, config);

  final mcpCompatible = Cfg.isMcpCompatible();

  // #104
  final chatScopeUseMcp = workingChat.settings?.useTools != false;

  // #111
  final availableMcp = await OpenAIFuncCalls.tools;
  final isMcpEmpty = availableMcp.isEmpty;

  if (mcpCompatible && chatScopeUseMcp && !isMcpEmpty) {
    // Used for logging mcp call resp
    final mcpReply = ChatHistoryItem.single(role: ChatRole.tool, raw: '');
    workingChat.items.add(mcpReply);
    _chatRN.notify();
    _autoScroll(chatId);

    CreateChatCompletionResponse? resp;
    try {
      resp = await Cfg.client.createChatCompletion(
        request: CreateChatCompletionRequest(
          messages: msgs,
          model: ChatCompletionModel.modelId(config.model),
          tools: availableMcp.toList(),
        ),
      );
    } catch (e, s) {
      _onErr(e, s, chatId, 'MCP');
      return;
    }

    final firstMcpReply = resp.choices.firstOrNull;
    final mcpCalls = firstMcpReply?.message.toolCalls;
    if (mcpCalls != null && mcpCalls.isNotEmpty) {
      final assistReply = ChatHistoryItem.gen(
        role: ChatRole.assist,
        content: [],
        toolCalls: mcpCalls,
      );
      workingChat.items.add(assistReply);
      msgs.add(await assistReply.toOpenAI());
      void onMcpLog(String log) {
        final content = ChatContent.text(log);
        if (mcpReply.content.isEmpty) {
          mcpReply.content.add(content);
        } else {
          mcpReply.content[0] = content;
        }
        _chatItemRNMap[mcpReply.id]?.notify();
      }

      for (final mcpCall in mcpCalls) {
        final contents = <ChatContent>[];
        try {
          final msg = await OpenAIFuncCalls.handle(
            mcpCall,
            (e, s) => _askMcpConfirm(context, e, s),
            onMcpLog,
          );
          if (msg != null) contents.addAll(msg);
        } catch (e, s) {
          _onErr(e, s, chatId, 'MCP call');
        }
        if (contents.isNotEmpty && contents.every((e) => e.raw.isNotEmpty)) {
          final historyItem = ChatHistoryItem.gen(
            role: ChatRole.tool,
            content: contents,
            toolCallId: mcpCall.id,
          );
          workingChat.items.add(historyItem);
          msgs.add(await historyItem.toOpenAI());
        }
      }
    }

    _chatItemRNMap[mcpReply.id]?.notify();
    workingChat.items.remove(mcpReply);
    _chatRN.notify();
    _chatItemRNMap.remove(mcpReply.id)?.dispose();
  }

  final chatStream = Cfg.client.createChatCompletionStream(
    request: CreateChatCompletionRequest(
      messages: msgs,
      model: ChatCompletionModel.modelId(config.model),
      temperature: aiSettings.temperature,
    ),
  );
  final assistReply = ChatHistoryItem.single(role: ChatRole.assist);
  workingChat.items.add(assistReply);
  _chatRN.notify();
  _filesPicked.value = [];

  try {
    final sub = chatStream.listen(
      (eve) async {
        final delta = eve.choices.firstOrNull?.delta;
        if (delta == null) return;

        final content = delta.content;
        if (content != null) {
          // Merge previous raw parts into a single string for detection
          final prev = assistReply.content.isEmpty
              ? ''
              : assistReply.content.map((e) => e.raw).join();
          final merged = '$prev$content';
          // Try to split into text/image parts; if decoding fails,
          // fallback to a single text content so partial base64 isn't rendered as image.
          final parts = splitDataUrisToChatContents(merged);
          assistReply.content
            ..clear()
            ..addAll(parts);
          _chatItemRNMap[assistReply.id]?.notify();
        }

        final deltaResoningContent = delta.reasoningContent;
        if (deltaResoningContent != null) {
          final originReasoning = assistReply.reasoning ?? '';
          final newReasoning = '$originReasoning$deltaResoningContent';
          assistReply.reasoning = newReasoning;
          _chatItemRNMap[assistReply.id]?.notify();
        }

        _autoScroll(chatId);
      },
      onDone: () async {
        _onStopStreamSub(chatId);
        _loadingChatIds.value.remove(chatId);
        _loadingChatIds.notify();
        _autoHideCtrl.autoHideEnabled = true;

        _storeChat(chatId);

        // Wait for db to store the chat
        await titleCompleter?.future;
        await Future.delayed(const Duration(milliseconds: 300));
        //    BakSync.instance.sync();
      },
      onError: (e, s) {
        _onErr(e, s, chatId, 'Listen text stream');
      },
    );
    _chatStreamSubs[chatId] = sub;
  } catch (e, s) {
    _loadingChatIds.value.remove(chatId);
    _loadingChatIds.notify();
    _onErr(e, s, chatId, 'Catch text stream');
  }
}

Future<void> _onCreateImg(
  BuildContext context,
  String chatId,
  String input,
  List<String> files,
) async {
  final prompt = inputCtrl.text;
  if (prompt.isEmpty) return;
  _imeFocus.unfocus();
  inputCtrl.clear();

  final workingChat = allHistories[chatId];
  if (workingChat == null) {
    final msg = 'Chat($chatId) not found';
    Loggers.app.warning(msg);
    context.showSnackBar(msg);
    return;
  }

  final userQuestion = ChatHistoryItem.single(role: ChatRole.user, raw: prompt);
  workingChat.items.add(userQuestion);
  final assistReply = ChatHistoryItem.gen(role: ChatRole.assist, content: []);
  workingChat.items.add(assistReply);
  _chatRN.notify();
  _autoScroll(chatId);

  final cfg = Cfg.current;
  final imgModel = cfg.imgModel;
  if (imgModel == null) {
    final msg = l10n.emptyFields('Image Model');
    Loggers.app.warning(msg);
    context.showSnackBar(msg);
    return;
  }

  _loadingChatIds.value.add(chatId);
  _loadingChatIds.notify();
  _autoHideCtrl.autoHideEnabled = false;

  try {
    final resp = await Cfg.client.createImage(
      request: CreateImageRequest(
        prompt: prompt,
        model: CreateImageRequestModel.modelId(imgModel),
      ),
    );
    final imgs = <String>[];
    for (final item in resp.data) {
      final url = item.url;
      if (url != null) {
        imgs.add(url);
      }
    }
    if (imgs.isEmpty) {
      const msg = 'Create image: empty resp';
      Loggers.app.warning(msg);
      context.showSnackBar(msg);
      return;
    }

    final imgContents = imgs.map((e) => ChatContent.image(e)).toList();
    assistReply.content.addAll(imgContents);

    _storeChat(chatId);
    _chatRN.notify();
    _autoScroll(chatId);

    // Only sync if success
  } catch (e, s) {
    // _onErr handles removing loading state and enabling auto-hide
    _onErr(e, s, chatId, 'Create image');
  } finally {
    _loadingChatIds.value.remove(chatId);
    _loadingChatIds.notify();
    _autoHideCtrl.autoHideEnabled = true;
  }
}

Future<Completer<void>?> genChatTitle(
  BuildContext context,
  String chatId,
  ChatConfig cfg,
) async {
  if (!Stores.setting.genTitle.get()) return null;

  final entity = allHistories[chatId];
  if (entity == null) {
    final msg = 'Gen Chat($chatId) not found';
    Loggers.app.warning(msg);
    context.showSnackBar(msg);
    return null;
  }
  if (entity.items.where((e) => e.role.isUser).length > 1) return null;

  final completer = Completer<void>();
  void onErr(Object e, StackTrace s) {
    Loggers.app.warning('Gen title: $e');
    _historyRN.notify();
    completer.complete();
  }

  try {
    final msgs = [
      await ChatHistoryItem.single(
        raw: Cfg.current.genTitlePrompt ?? ChatTitleUtil.titlePrompt,
        role: ChatRole.system,
      ).toOpenAI(),
      await ChatHistoryItem.single(
        role: ChatRole.user,
        raw: entity.items.first.content
            .firstWhere((p0) => p0.type == ChatContentType.text)
            .raw,
      ).toOpenAI(),
    ];
    final model = ChatTitleUtil.pickSuitableModel ?? cfg.model;
    final req = CreateChatCompletionRequest(
      model: ChatCompletionModel.modelId(model),
      messages: msgs,
    );
    Cfg.client.createChatCompletion(request: req).then((resp) {
      var title = resp.choices.firstOrNull?.message.content;
      title = ChatTitleUtil.prettify(title ?? '');

      if (title.isNotEmpty) {
        final ne = entity.copyWith(name: title)..save();
        allHistories[chatId] = ne;
        _historyRN.notify();
        if (chatId == _curChatId.value) {
          _appbarTitleVN.value = title;
        }
      }

      completer.complete();
    }, onError: onErr);

    return completer;
  } catch (e, s) {
    onErr(e, s);
    return null;
  }
}

/// Remove the [ChatHistoryItem] behind this [item], and resend the [item] like
/// [_onCreateText], but append the result after this [item] instead of at the end.
void _onReplay({
  required BuildContext context,
  required String chatId,
  required ChatHistoryItem item,
}) async {
  if (!_validChatCfg(context)) return;

  // If is receiving the reply, ignore this action
  if (_loadingChatIds.value.contains(chatId)) {
    return;
  }

  final chatHistory = allHistories[chatId];
  if (chatHistory == null) {
    final msg = 'Replay Chat($chatId) not found';
    Loggers.app.warning(msg);
    context.showSnackBar(msg);
    return;
  }

  // Find the item, then delete all items behind it and itself
  final replayMsgIdx = chatHistory.items.indexOf(item);
  if (replayMsgIdx == -1) {
    final msg = 'Replay Chat($chatId) item($item) not found';
    Loggers.app.warning(msg);
    context.showSnackBar('${libL10n.fail}: $msg');
    return;
  }
  chatHistory.items.removeRange(replayMsgIdx, chatHistory.items.length);

  // Each item has only one text content inputed by user
  final text = item.content.firstWhereOrNull((e) => e.type.isText)?.raw;
  if (text != null) {
    inputCtrl.text = text;
  }

  final files = item.content
      .where((e) => !e.type.isText)
      .map((e) => e.raw)
      .toList();
  _filesPicked.value = files;

  _onCreateRequest(context, chatId);
}

void _onErr(Object e, StackTrace s, String chatId, String action) {
  Loggers.app.warning('$action: $e');
  _onStopStreamSub(chatId);
  // Ensure loading state is removed and auto-hide is enabled on error
  _loadingChatIds.value.remove(chatId);
  _loadingChatIds.notify();
  _autoHideCtrl.autoHideEnabled = true;

  final msg = '$e\n\n```$s```';
  final workingChat = allHistories[chatId];
  if (workingChat == null) return;

  // If previous msg is assistant reply and it's empty, remove it
  if (workingChat.items.isNotEmpty) {
    final last = workingChat.items.last;
    final role = last.role;
    if ((role.isAssist || role.isTool) &&
        last.content.every((e) => e.raw.isEmpty)) {
      workingChat.items.removeLast();
    }
  }

  // Add error msg to the chat
  workingChat.items.add(
    ChatHistoryItem.single(
      type: ChatContentType.text,
      raw: msg,
      role: ChatRole.system,
    ),
  );

  _chatRN.notify();

  if (Stores.setting.saveErrChat.get()) _storeChat(chatId);
}

/// =========================
/// Audio helpers/utilities
/// =========================

final AudioRecorder _audioRecorder = AudioRecorder();

Future<bool> _ensureRecordPermission() async {
  try {
    return await _audioRecorder.hasPermission();
  } catch (_) {
    return false;
  }
}

Future<String?> _quickRecordWav({
  Duration duration = const Duration(seconds: 6),
}) async {
  if (!await _ensureRecordPermission()) return null;
  final dir = Directory.systemTemp.createTempSync('rec_');
  final path = p.join(
    dir.path,
    'input_${DateTime.now().millisecondsSinceEpoch}.wav',
  );
  await _audioRecorder.start(
    const RecordConfig(
      encoder: AudioEncoder.wav,
      sampleRate: 16000,
      bitRate: 128000,
    ),
    path: path,
  );
  try {
    await Future.delayed(duration);
  } finally {
    try {
      await _audioRecorder.stop();
    } catch (_) {}
  }
  return File(path).existsSync() ? path : null;
}

bool _isImagePath(String path) {
  final ext = p.extension(path).toLowerCase();
  return [
    '.png',
    '.jpg',
    '.jpeg',
    '.webp',
    '.gif',
    '.bmp',
    '.heic',
    '.heif',
  ].contains(ext);
}

bool isAudioPath(String path) {
  final ext = p.extension(path).toLowerCase();
  return [
    '.wav',
    '.mp3',
    '.m4a',
    '.aac',
    '.flac',
    '.ogg',
    '.oga',
    '.webm',
  ].contains(ext);
}

String _mimeFromExt(String path) {
  final ext = p.extension(path).toLowerCase();
  switch (ext) {
    case '.png':
      return 'image/png';
    case '.jpg':
    case '.jpeg':
      return 'image/jpeg';
    case '.webp':
      return 'image/webp';
    case '.gif':
      return 'image/gif';
    case '.bmp':
      return 'image/bmp';
    case '.heic':
      return 'image/heic';
    case '.heif':
      return 'image/heif';
    default:
      return 'application/octet-stream';
  }
}

Future<String> _fileToBase64(String path) async {
  final bytes = await File(path).readAsBytes();
  return base64Encode(bytes);
}

Uint8List wavFromPcm16(
  Uint8List pcmBytes, {
  int sampleRate = 16000,
  int channels = 1,
}) {
  final byteRate = sampleRate * channels * 2;
  final blockAlign = channels * 2;
  final dataLen = pcmBytes.length;
  final header = BytesBuilder();
  header.add(ascii.encode('RIFF'));
  header.add(_intToBytes(36 + dataLen, 4));
  header.add(ascii.encode('WAVE'));
  header.add(ascii.encode('fmt '));
  header.add(_intToBytes(16, 4));
  header.add(_intToBytes(1, 2)); // PCM
  header.add(_intToBytes(channels, 2));
  header.add(_intToBytes(sampleRate, 4));
  header.add(_intToBytes(byteRate, 4));
  header.add(_intToBytes(blockAlign, 2));
  header.add(_intToBytes(16, 2)); // bits per sample
  header.add(ascii.encode('data'));
  header.add(_intToBytes(dataLen, 4));
  header.add(pcmBytes);
  return header.takeBytes();
}

Uint8List _intToBytes(int value, int byteCount) {
  final b = BytesBuilder();
  for (int i = 0; i < byteCount; i++) {
    b.addByte(value & 0xff);
    value >>= 8;
  }
  return b.takeBytes();
}

openai.ChatCompletionAudioVoice getOpenAIVoice(String voiceParams) {
  switch (voiceParams.toLowerCase()) {
    case 'alloy':
      return openai.ChatCompletionAudioVoice.alloy;
    case 'ash':
      return openai.ChatCompletionAudioVoice.ash;
    case 'echo':
      return openai.ChatCompletionAudioVoice.echo;
    case 'ballad':
      return openai.ChatCompletionAudioVoice.ballad;
    case 'sage':
      return openai.ChatCompletionAudioVoice.sage;
    case 'coral':
      return openai.ChatCompletionAudioVoice.coral;
    case 'shimmer':
      return openai.ChatCompletionAudioVoice.shimmer;
    default:
      return openai.ChatCompletionAudioVoice.alloy;
  }
}

Future<openai.ChatCompletionAudioVoice> getCurrentVoice() async {
  final dv = ss.defaultVoice.get();
  final vv = getOpenAIVoice(dv);
  return vv;
}

Future<String> _pathToDataUrl(String path) async {
  final mime = _mimeFromExt(path);
  final b64 = await _fileToBase64(path);
  return 'data:$mime;base64,$b64';
}

// Helper: split a string that may contain data:image/...;base64,... URIs into ChatContent pieces.
List<ChatContent> splitDataUrisToChatContents(String s) {
  final dataUriRe = RegExp(
    r'(data:(?:image|audio)\/[^;\s]+;base64,[A-Za-z0-9+/=\r\n]+)',
  );
  final matches = dataUriRe.allMatches(s).toList();
  if (matches.isEmpty) return [ChatContent.text(s)];

  final parts = <ChatContent>[];
  var last = 0;
  for (final m in matches) {
    if (m.start > last) {
      parts.add(ChatContent.text(s.substring(last, m.start)));
    }
    final dataUri = s.substring(m.start, m.end);
    // Validate base64 decodes; if invalid, bail and return single text chunk
    try {
      final comma = dataUri.indexOf(',');
      final body = comma >= 0 ? dataUri.substring(comma + 1) : dataUri;
      base64Decode(body.replaceAll(RegExp(r'\s+'), ''));
      // If decode OK, treat as image/audio content
      if (dataUri.toLowerCase().contains('data:image/')) {
        parts.add(ChatContent.image(dataUri));
      } else {
        parts.add(ChatContent.audio(dataUri));
      }
    } catch (_) {
      // If any decode fails, return the whole string as text to avoid partial rendering
      return [ChatContent.text(s)];
    }
    last = m.end;
  }
  if (last < s.length) parts.add(ChatContent.text(s.substring(last)));
  return parts;
}

Future<ChatContent> contentFromPath(String path) async {
  if (getAppFileType(path) == AppFileType.image) {
    final dataUrl = await _pathToDataUrl(path);
    return ChatContent.image(dataUrl);
  } else if (getAppFileType(path) == AppFileType.audio) {
    final dataUrl = await _pathToDataUrl(path);
    return ChatContent.audio(dataUrl);
  } else if (getAppFileType(path) == AppFileType.directdoc) {
    final dataUrl = await _pathToDataUrl(path);
    return ChatContent.file(dataUrl);
  } else if (getAppFileType(path) == AppFileType.undirectdoc) {
    final content = await File(path).readAsString();
    if (content.isNotEmpty && content != '') {
      Directory tmp = await getTemporaryDirectory();
      final newf = p.join(tmp.path, '${Uuid().v4()}.txt');
      final ffile = await File(newf).writeAsString(newf);
      final dataUrl = await _pathToDataUrl(ffile.path);
      return ChatContent.file(dataUrl);
    }
  }
  return ChatContent.file(
    'app cant process sending file , tell this to user and if this helpful this is file path : $path',
  );
}

Future<String> _saveBase64ToFile(
  String base64Data, {
  String ext = '.wav',
}) async {
  final bytes = base64Decode(base64Data);
  final dir = await Directory.systemTemp.createTemp('oai_audio_');
  final path = p.join(
    dir.path,
    'out_${DateTime.now().millisecondsSinceEpoch}$ext',
  );
  final f = File(path);
  await f.writeAsBytes(bytes, flush: true);
  return f.path;
}

// This helper may be referenced dynamically; suppress unused-element lint here.
// ignore: unused_element
Future<String?> _ensureAudioInputPath(List<String> files) async {
  final audio = files.firstWhereOrNull(isAudioPath);
  if (audio != null) return audio;
  // fallback quick record if nothing provided
  return await _quickRecordWav();
}

Future<String?> deppReSearch(
  BuildContext context,
  String chatId,
  String input,
  List<String> files,
) async {
  final svc = ResponsesService();
  final req = DeepResearchRequest(
    model: 'o4-mini-deep-research',
    input: input,
    tools: [WebSearchPreviewTool()],
    reasoning: {'summary': 'auto'},
  );
  await for (final chunk in svc.stream(req)) {
    try {
      if (chunk.deltaText != null && chunk.deltaText!.isNotEmpty) {
        stdout.write(chunk.deltaText);
        return chunk.deltaText!;
      }
    } catch (e) {
      return e.toString();
    }
    // print('\n[stream failed end]');
  }
  // If stream ended without producing deltaText, return null
  return null;
}

Future<void> _onAudioModel(
  BuildContext context,
  String chatId,
  String input,
  List<String> files,
) async {
  final workingChat = allHistories[chatId];
  if (workingChat == null) {
    final msg = 'Chat($chatId) not found';
    Loggers.app.warning(msg);
    context.showSnackBar(msg);
    return;
  }
  final config = Cfg.current;

  // Prepare user question (text + optionally images/files already attached)
  final questionContents = <ChatContent>[ChatContent.text(input)];
  for (final file in files) {
      // Ensure images are sent as base64 data URL
      final content = await contentFromPath(file);
      questionContents.add(content);
  }
  final question = ChatHistoryItem.gen(
    content: questionContents,
    role: ChatRole.user,
  );
  final msgs = (await _historyCarried(workingChat)).toList();
  msgs.add(await question.toOpenAI());

  workingChat.items.add(question);
  inputCtrl.clear();
  _chatRN.notify();
  _autoScroll(chatId);

  final titleCompleter = await genChatTitle(context, chatId, config);
  _loadingChatIds.value.add(chatId);
  _loadingChatIds.notify();
  _autoHideCtrl.autoHideEnabled = false;

  // Assistant reply placeholder (will attach audio file when done)
  final assistReply = ChatHistoryItem.gen(role: ChatRole.assist, content: []);
  workingChat.items.add(assistReply);
  _chatRN.notify();
  _filesPicked.value = [];
  // Accumulate streaming audio base64 and transcript for audio-preview model
  final audioDataBuffer = StringBuffer();
  final transcriptBuffer = StringBuffer();

  try {
    final stream = Cfg.client.createChatCompletionStream(
      request: CreateChatCompletionRequest(
        model: ChatCompletionModel.modelId(
          Cfg.current.audioModel ?? 'gpt-4o-mini-audio-preview',
        ),
        messages: msgs,
        modalities: Cfg.current.audioModel==  'gpt-4o-mini-audio-preview'?[ChatCompletionModality.audio, ChatCompletionModality.text]:[ChatCompletionModality.audio],
        audio: ChatCompletionAudioOptions(
          voice: await getCurrentVoice(),
          format: ChatCompletionAudioFormat.pcm16,
        ),
        temperature: aiSettings.temperature,
      ),
    );

    final sub = stream.listen(
      (eve) async {
        final delta = eve.choices.firstOrNull?.delta;
        if (delta == null) return;

        // Accumulate streaming audio base64
        final a = delta.audio;
        if (a?.data != null && a!.data!.isNotEmpty) {
          audioDataBuffer.write(a.data);
        }
        if (a?.transcript != null && a!.transcript!.isNotEmpty) {
          transcriptBuffer.write(a.transcript);
        }

        // Live transcript update (optional)
        if (transcriptBuffer.isNotEmpty) {
          final t = transcriptBuffer.toString();
          if (assistReply.content.isEmpty) {
            assistReply.content.add(ChatContent.text(t));
            //             final modelSoFar = assistReply.content.firstOrNull?.raw ?? '';
            // TokenCounter.updateFrom(userText: input, modelText: modelSoFar);
          } else {
            // Keep first content as transcript text until audio saved
            assistReply.content[0] = ChatContent.text(t);
            //  final modelSoFar = assistReply.content.firstOrNull?.raw ?? '';
            //   aiSettings.onTextChangedForTokens(modelText: modelSoFar);
          }
          _chatItemRNMap[assistReply.id]?.notify();
        }

        _autoScroll(chatId);
      },
      onDone: () async {
        try {
          // Persist audio
          if (audioDataBuffer.isNotEmpty) {
            final path = await _saveBase64ToFile(
              audioDataBuffer.toString(),
              ext: '.wav',
            );
            ss.voicePlayedUntilNow.set(false);
            if (assistReply.content.isEmpty) {
              assistReply.content.add(ChatContent.file(path));
              //               final modelSoFar = assistReply.content.firstOrNull?.raw ?? '';
              // TokenCounter.updateFrom(userText: input, modelText: modelSoFar);
            } else {
              // Keep transcript if present, also add audio as second content
              final hasText =
                  assistReply.content.firstOrNull?.type.isText == true;
              if (hasText) {
                assistReply.content.add(ChatContent.file(path));
              } else {
                assistReply.content[0] = ChatContent.file(path);
                //   final modelSoFar = assistReply.content.firstOrNull?.raw ?? '';
                //     aiSettings.onTextChangedForTokens(modelText: modelSoFar);
              }
            }
            _chatItemRNMap[assistReply.id]?.notify();
          }
        } finally {
          _onStopStreamSub(chatId);
          _loadingChatIds.value.remove(chatId);
          _loadingChatIds.notify();
          _autoHideCtrl.autoHideEnabled = true;

          _storeChat(chatId);
          await titleCompleter?.future;
          await Future.delayed(const Duration(milliseconds: 300));
        }
      },
      onError: (e, s) {
        _onErr(e, s, chatId, 'Listen audio stream');
      },
    );
    _chatStreamSubs[chatId] = sub;
  } catch (e, s) {
    _loadingChatIds.value.remove(chatId);
    _loadingChatIds.notify();
    _onErr(e, s, chatId, 'Catch audio stream');
  }
}

Future<void> _onTtsModel(
  BuildContext context,
  String chatId,
  String input,
  List<String> files,
) async {
  final workingChat = allHistories[chatId];
  if (workingChat == null) {
    final msg = 'Chat($chatId) not found';
    Loggers.app.warning(msg);
    context.showSnackBar(msg);
    return;
  }
  final config = Cfg.current;

  // Prepare user question (text + optionally images/files already attached)
  final questionContents = <ChatContent>[ChatContent.text(input)];
  for (final file in files) {
      // Ensure images are sent as base64 data URL
      final content = await contentFromPath(file);
      questionContents.add(content);

    }
  
  final question = ChatHistoryItem.gen(
    content: questionContents,
    role: ChatRole.user,
  );
  final msgs = (await _historyCarried(workingChat)).toList();
  msgs.add(await question.toOpenAI());

  workingChat.items.add(question);
  inputCtrl.clear();
  _chatRN.notify();
  _autoScroll(chatId);

  final titleCompleter = await genChatTitle(context, chatId, config);
  _loadingChatIds.value.add(chatId);
  _loadingChatIds.notify();
  _autoHideCtrl.autoHideEnabled = false;
  final mcpCompatible = Cfg.isMcpCompatible();

  // #104
  final chatScopeUseMcp = workingChat.settings?.useTools != false;

  // #111
  final availableMcp = await OpenAIFuncCalls.tools;
  final isMcpEmpty = availableMcp.isEmpty;

  if (mcpCompatible && chatScopeUseMcp && !isMcpEmpty) {
    // Used for logging mcp call resp
    final mcpReply = ChatHistoryItem.single(role: ChatRole.tool, raw: '');
    workingChat.items.add(mcpReply);
    _chatRN.notify();
    _autoScroll(chatId);

    CreateChatCompletionResponse? resp;
    try {
      resp = await Cfg.client.createChatCompletion(
        request: CreateChatCompletionRequest(
          messages: msgs,
          model: ChatCompletionModel.modelId(config.model),
          tools: availableMcp.toList(),
        ),
      );
    } catch (e, s) {
      _onErr(e, s, chatId, 'MCP');
      return;
    }

    final firstMcpReply = resp.choices.firstOrNull;
    final mcpCalls = firstMcpReply?.message.toolCalls;
    if (mcpCalls != null && mcpCalls.isNotEmpty) {
      final assistReply = ChatHistoryItem.gen(
        role: ChatRole.assist,
        content: [],
        toolCalls: mcpCalls,
      );
      workingChat.items.add(assistReply);
      msgs.add(await assistReply.toOpenAI());
      void onMcpLog(String log) {
        final content = ChatContent.text(log);
        if (mcpReply.content.isEmpty) {
          mcpReply.content.add(content);
        } else {
          mcpReply.content[0] = content;
        }
        _chatItemRNMap[mcpReply.id]?.notify();
      }

      for (final mcpCall in mcpCalls) {
        final contents = <ChatContent>[];
        try {
          final msg = await OpenAIFuncCalls.handle(
            mcpCall,
            (e, s) => _askMcpConfirm(context, e, s),
            onMcpLog,
          );
          if (msg != null) contents.addAll(msg);
        } catch (e, s) {
          _onErr(e, s, chatId, 'MCP call');
        }
        if (contents.isNotEmpty && contents.every((e) => e.raw.isNotEmpty)) {
          final historyItem = ChatHistoryItem.gen(
            role: ChatRole.tool,
            content: contents,
            toolCallId: mcpCall.id,
          );
          workingChat.items.add(historyItem);
          msgs.add(await historyItem.toOpenAI());
        }
      }
    }

    _chatItemRNMap[mcpReply.id]?.notify();
    workingChat.items.remove(mcpReply);
    _chatRN.notify();
    _chatItemRNMap.remove(mcpReply.id)?.dispose();
  }

  final chatStream = Cfg.client.createChatCompletionStream(
    request: CreateChatCompletionRequest(
      messages: msgs,
      model: ChatCompletionModel.modelId(config.model),
      temperature: aiSettings.temperature,
    ),
  );

  // Add two assist placeholders: one used while streaming text, one final to hold TTS file
  final assistReplyStreaming = ChatHistoryItem.single(role: ChatRole.assist);
  workingChat.items.add(assistReplyStreaming);
  _chatRN.notify();

  // We'll accumulate full assistant text here, then call TTS once on completion
  final assistantTextBuffer = StringBuffer();

  try {
    final sub = chatStream.listen(
      (eve) async {
        final delta = eve.choices.firstOrNull?.delta;
        if (delta == null) return;

        final content = delta.content;
        if (content != null) {
          // Append to streaming assistant text buffer
          assistantTextBuffer.write(content);

          // Update streaming UI with merged parts (handle data URIs)
          final prev = assistReplyStreaming.content.isEmpty
              ? ''
              : assistReplyStreaming.content.map((e) => e.raw).join();
          final merged = '$prev$content';
          final parts = splitDataUrisToChatContents(merged);
          assistReplyStreaming.content
            ..clear()
            ..addAll(parts);
          _chatItemRNMap[assistReplyStreaming.id]?.notify();
        }

        final deltaReasoning = delta.reasoningContent;
        if (deltaReasoning != null) {
          final origin = assistReplyStreaming.reasoning ?? '';
          assistReplyStreaming.reasoning = '$origin$deltaReasoning';
          _chatItemRNMap[assistReplyStreaming.id]?.notify();
        }

        _autoScroll(chatId);
      },
      onDone: () async {
        // At this point we've received the full assistant text in assistantTextBuffer
        try {
          final finalText = assistantTextBuffer.toString();

          // Replace streaming placeholder with final assist reply that will hold transcript + audio
          // Keep existing transcript text if any
          final finalAssist = ChatHistoryItem.gen(
            role: ChatRole.assist,
            content: [],
          );
          if (finalText.isNotEmpty) {
            finalAssist.content.add(ChatContent.text(finalText));
          }
          // Replace the streaming item with final one
          final idx = workingChat.items.indexOf(assistReplyStreaming);
          if (idx != -1) {
            workingChat.items[idx] = finalAssist;
          } else {
            workingChat.items.add(finalAssist);
          }
          _chatRN.notify();

          // Now call TTS once for the finalText (if non-empty)
          if (finalText.trim().isNotEmpty) {
            // Prepare a temporary chat message with the assistant text as user content for audio model
            final ttsMsg = ChatHistoryItem.gen(
              content: [ChatContent.text(finalText)],
              role: ChatRole.user,
            );
            final con = (await _historyCarried(
              ChatHistory(items: [ttsMsg], id: Uuid().v4()),
            )).toList();

            final ttsStream = Cfg.client.createChatCompletionStream(
              request: CreateChatCompletionRequest(
                model: ChatCompletionModel.modelId(
                  Cfg.current.audioModel ?? 'gpt-4o-mini-tts',
                ),
                messages: con,
                modalities: [ChatCompletionModality.audio],
                audio: ChatCompletionAudioOptions(
                  voice: await getCurrentVoice(),
                  format: ChatCompletionAudioFormat.pcm16,
                ),
                temperature: aiSettings.temperature,
              ),
            );

            // Accumulate audio from TTS stream
            final ttsAudioBuffer = StringBuffer();
            final ttsTranscriptBuffer = StringBuffer();

            final ttsSub = ttsStream.listen(
              (eve) {
                final delta = eve.choices.firstOrNull?.delta;
                if (delta == null) return;
                final a = delta.audio;
                if (a?.data != null && a!.data!.isNotEmpty) {
                  ttsAudioBuffer.write(a.data);
                }
                if (a?.transcript != null && a!.transcript!.isNotEmpty) {
                  ttsTranscriptBuffer.write(a.transcript);
                }
              },
              onDone: () async {
                try {
                  if (ttsAudioBuffer.isNotEmpty) {
                    final path = await _saveBase64ToFile(
                      ttsAudioBuffer.toString(),
                      ext: '.wav',
                    );
                    ss.voicePlayedUntilNow.set(false);
                    // Attach audio to finalAssist: if it already has text, add file; otherwise set file
                    if (finalAssist.content.isEmpty) {
                      finalAssist.content.add(ChatContent.file(path));
                    } else {
                      finalAssist.content.add(ChatContent.file(path));
                    }
                    _chatItemRNMap[finalAssist.id]?.notify();
                  }
                } finally {
                  // cleanup
                }
              },
              onError: (e, s) {
                _onErr(e, s, chatId, 'TTS stream');
              },
            );

            // keep ttsSub in map so user can cancel if needed
            _chatStreamSubs[chatId] = ttsSub;
          }
        } finally {
          _onStopStreamSub(chatId);
          _loadingChatIds.value.remove(chatId);
          _loadingChatIds.notify();
          _autoHideCtrl.autoHideEnabled = true;

          _storeChat(chatId);
          await titleCompleter?.future;
          await Future.delayed(const Duration(milliseconds: 300));
        }
      },
      onError: (e, s) {
        _onErr(e, s, chatId, 'Listen text stream');
      },
    );

    // store main chat stream subscription so it can be canceled
    _chatStreamSubs[chatId] = sub;
  } catch (e, s) {
    _loadingChatIds.value.remove(chatId);
    _loadingChatIds.notify();
    _onErr(e, s, chatId, 'Catch audio stream');
  }
}

/// Web search quick
Future<String> webSearchQuick(String query, {String model = 'gpt-5'}) async {
  final svc = respsvc.ResponsesService();
  final api = WebSearchApi(svc);
  final text = await api.quickSearch(query: query, model: model);
  return text;
}

/// Web search with filters and sources
Future<respmod.DeepResponse> webSearchWithFilters(
  String query, {
  String model = 'gpt-5',
  List<String>? allowedDomains,
  bool includeSources = true,
}) async {
  final svc = respsvc.ResponsesService();
  final api = WebSearchApi(svc);
  final resp = await api.searchWithFilters(
    query: query,
    model: model,
    allowedDomains: allowedDomains,
    includeSources: includeSources,
  );
  return resp;
}

/// Codex local shell loop runner
Future<respmod.DeepResponse> runCodexLocalShell(
  String userPrompt, {
  String model = 'codex-mini-latest',
  List<String>? allowListPrefixes,
  List<String>? denyListPrefixes,
  String? workingDirectory,
}) async {
  final svc = respsvc.ResponsesService();
  final agent = CodexLocalShellAgent(
    svc: svc,
    model: model,
    allowListPrefixes: allowListPrefixes,
    denyListPrefixes: denyListPrefixes,
    workingDirectory: workingDirectory,
  );

  final finalResp = await agent.run(userPrompt);
  return finalResp;
}

Future<String> transcribeFileToText(
  File file, {
  String model = 'gpt-4o-transcribe',
}) async {
  final svc = TranscriptionService();
  final res = await svc.transcribeFile(file, model: model);
  return res.text;
}

Future<String> synthesizeToWavAndSave({
  required String text,
  required String voice,
  String model = 'gpt-4o-mini-tts', // pick your provider’s TTS-capable model id
}) async {
  final tts = TtsService();
  final bytes = await tts.synthesize(model: model, input: text, voice: voice);
  final wav = AudioUtils.ensureWav(bytes);
  final dir = await Directory.systemTemp.createTemp('tts_');
  final path = p.join(
    dir.path,
    'out_${DateTime.now().millisecondsSinceEpoch}.wav',
  );
  final f = File(path);
  await f.writeAsBytes(wav, flush: true);
  return f.path;
}

Future<void> _onCreateTextTranslated(
  BuildContext context,
  String chatId,
  String input,
  List<String> files,
) async {
  final workingChat = allHistories[chatId];
  if (workingChat == null) {
    final msg = 'Chat($chatId) not found';
    Loggers.app.warning(msg);
    context.showSnackBar(msg);
    return;
  }
  const int maxAttempts = 10;
  const Duration delayBetween = Duration(milliseconds: 300);
  final String translatePrompt =
      'just without any changes to text content translate that to English and return translated text without anything more . Text Content : ${input}';
  String translated = '';
  CreateChatCompletionResponse? translatetxt;
  for (int attempt = 0; attempt < maxAttempts; attempt++) {
    try {
      translatetxt = await Cfg.client.createChatCompletion(
        request: CreateChatCompletionRequest(
          messages: [
            ChatCompletionMessage.user(
              content: ChatCompletionUserMessageContent.string(translatePrompt),
            ),
          ],
          model: ChatCompletionModel.modelId('gemini-2.5-flash-lite'),
        ),
      );
      translated =
          translatetxt.choices.firstOrNull?.message.content?.trim() ?? '';
    } catch (e) {
      translated = '';
    }
    if (translated.isNotEmpty) break;
    await Future.delayed(delayBetween);
  }
  if (translated.isEmpty) {
    final msg = 'Translator returned empty result';
    Loggers.app.warning(msg);
    context.showSnackBar(msg);
    return;
  }
  final questionContents = <ChatContent>[ChatContent.text(translated)];
  for (final file in files) {
    if (!modelUseFilePath) {
      // Ensure images are sent as base64 data URL
      final content = await contentFromPath(file);
      questionContents.add(content);
    } else if (modelUseFilePath) {
      final content = <ChatContent>[
        ChatContent.text(
          'For Using Tools with file operation use this File Path: $file',
        ),
      ];
      questionContents.addAll(content);
      modelUseFilePath = false;
    }
  }
  final question = ChatHistoryItem.gen(
    content: questionContents,
    role: ChatRole.user,
  );
  final msgs = (await _historyCarried(workingChat)).toList();
  msgs.add(await question.toOpenAI());

  workingChat.items.add(question);
  inputCtrl.clear();
  _chatRN.notify();
  _autoScroll(chatId);
  final titleCompleter = await genChatTitle(context, chatId, Cfg.current);

  final mcpCompatible = Cfg.isMcpCompatible();

  // #104
  final chatScopeUseMcp = workingChat.settings?.useTools != false;

  // #111
  final availableMcp = await OpenAIFuncCalls.tools;
  final isMcpEmpty = availableMcp.isEmpty;

  if (mcpCompatible && chatScopeUseMcp && !isMcpEmpty) {
    // Used for logging mcp call resp
    final mcpReply = ChatHistoryItem.single(role: ChatRole.tool, raw: '');
    workingChat.items.add(mcpReply);
    _chatRN.notify();
    _autoScroll(chatId);

    CreateChatCompletionResponse? resp;
    try {
      resp = await Cfg.client.createChatCompletion(
        request: CreateChatCompletionRequest(
          messages: msgs,
          model: ChatCompletionModel.modelId(Cfg.current.model),
          tools: availableMcp.toList(),
        ),
      );
    } catch (e, s) {
      _onErr(e, s, chatId, 'MCP');
      return;
    }

    final firstMcpReply = resp.choices.firstOrNull;
    final mcpCalls = firstMcpReply?.message.toolCalls;
    if (mcpCalls != null && mcpCalls.isNotEmpty) {
      final assistReply = ChatHistoryItem.gen(
        role: ChatRole.assist,
        content: [],
        toolCalls: mcpCalls,
      );
      workingChat.items.add(assistReply);
      msgs.add(await assistReply.toOpenAI());
      void onMcpLog(String log) {
        final content = ChatContent.text(log);
        if (mcpReply.content.isEmpty) {
          mcpReply.content.add(content);
        } else {
          mcpReply.content[0] = content;
        }
        _chatItemRNMap[mcpReply.id]?.notify();
      }

      for (final mcpCall in mcpCalls) {
        final contents = <ChatContent>[];
        try {
          final msg = await OpenAIFuncCalls.handle(
            mcpCall,
            (e, s) => _askMcpConfirm(context, e, s),
            onMcpLog,
          );
          if (msg != null) contents.addAll(msg);
        } catch (e, s) {
          _onErr(e, s, chatId, 'MCP call');
        }
        if (contents.isNotEmpty && contents.every((e) => e.raw.isNotEmpty)) {
          final historyItem = ChatHistoryItem.gen(
            role: ChatRole.tool,
            content: contents,
            toolCallId: mcpCall.id,
          );
          workingChat.items.add(historyItem);
          msgs.add(await historyItem.toOpenAI());
        }
      }
    }

    _chatItemRNMap[mcpReply.id]?.notify();
    workingChat.items.remove(mcpReply);
    _chatRN.notify();
    _chatItemRNMap.remove(mcpReply.id)?.dispose();
  }

  final chatStream = Cfg.client.createChatCompletionStream(
    request: CreateChatCompletionRequest(
      messages: msgs,
      model: ChatCompletionModel.modelId(Cfg.current.model),
    ),
  );
  final assistReply = ChatHistoryItem.single(role: ChatRole.assist);
  workingChat.items.add(assistReply);
  _chatRN.notify();
  _filesPicked.value = [];

  try {
    final sub = chatStream.listen(
      (eve) async {
        final delta = eve.choices.firstOrNull?.delta;
        if (delta == null) return;

        final content = delta.content;
        if (content != null) {
          final prev = assistReply.content.isEmpty
              ? ''
              : assistReply.content.map((e) => e.raw).join();
          final merged = '$prev$content';
          final parts = splitDataUrisToChatContents(merged);
          assistReply.content
            ..clear()
            ..addAll(parts);
          _chatItemRNMap[assistReply.id]?.notify();
        }

        final deltaResoningContent = delta.reasoningContent;
        if (deltaResoningContent != null) {
          final originReasoning = assistReply.reasoning ?? '';
          final newReasoning = '$originReasoning$deltaResoningContent';
          assistReply.reasoning = newReasoning;
          _chatItemRNMap[assistReply.id]?.notify();
        }

        _autoScroll(chatId);
      },
      onDone: () async {
        _onStopStreamSub(chatId);
        _loadingChatIds.value.remove(chatId);
        _loadingChatIds.notify();
        _autoHideCtrl.autoHideEnabled = true;

        _storeChat(chatId);

        // Wait for db to store the chat
        await titleCompleter?.future;
        await Future.delayed(const Duration(milliseconds: 300));
        //   BakSync.instance.sync();
      },
      onError: (e, s) {
        _onErr(e, s, chatId, 'Listen text stream');
      },
    );
    _chatStreamSubs[chatId] = sub;
  } catch (e, s) {
    _loadingChatIds.value.remove(chatId);
    _loadingChatIds.notify();
    _onErr(e, s, chatId, 'Catch text stream');
  }
}

// Future<void> _onCreateResponse(
//   BuildContext context,
//   String chatId,
//   String input,
//   List<String> files,
// ) async {
//   final workingChat = allHistories[chatId];
//   if (workingChat == null) {
//     final msg = 'Chat($chatId) not found';
//     Loggers.app.warning(msg);
//     context.showSnackBar(msg);
//     return;
//   }
//   final config = Cfg.current;

//   final questionContents = <ChatContent>[ChatContent.text(input)];
//   for (final file in files) {
//     if (!modelUseFilePath) {
//       // Ensure images are sent as base64 data URL
//       final content = await contentFromPath(file);
//       questionContents.add(content);
//     } else if (modelUseFilePath) {
//       final content = <ChatContent>[
//         ChatContent.text(
//           'For Using Tools with file operation use this File Path: $file',
//         ),
//       ];
//       questionContents.addAll(content);
//       modelUseFilePath = false;
//     }
//   }
//   final question = ChatHistoryItem.gen(
//     content: questionContents,
//     role: ChatRole.user,
//   );
//   final msgs = (await _historyCarried(workingChat)).toList();
//   msgs.add(await question.toOpenAI());

//   workingChat.items.add(question);
//   inputCtrl.clear();
//   _chatRN.notify();
//   _autoScroll(chatId);
//   final titleCompleter = await genChatTitle(context, chatId, config);



//     final chatStream = await Cfg.clientoc.streamResponse(
//       model: oc.ChatModel.fromJson(Cfg.current.model),
//       input: oc.ResponseInputText(msgs.join()),
//       text: const oc.TextFormatText(),
//     );
//     final assistReply = ChatHistoryItem.single(role: ChatRole.assist);
//     workingChat.items.add(assistReply);
//     _chatRN.notify();
//     _filesPicked.value = [];

//     await for (final eve in chatStream.events) {
//       if (eve is oc.ResponseOutputTextDelta) {
//         stdout.write(eve.delta);
//         final content = eve.delta;
//         final prev = assistReply.content.isEmpty
//             ? ''
//             : assistReply.content.map((e) => e.raw).join();
//         final merged = '$prev$content';
//         // Try to split into text/image parts; if decoding fails,
//         // fallback to a single text content so partial base64 isn't rendered as image.
//         final parts = splitDataUrisToChatContents(merged);
//         assistReply.content
//           ..clear()
//           ..addAll(parts);
//         _chatItemRNMap[assistReply.id]?.notify();

//         final deltaResoningContent = null;
//         if (deltaResoningContent != null) {
//           final originReasoning = assistReply.reasoning ?? '';
//           final newReasoning = '$originReasoning$deltaResoningContent';
//           assistReply.reasoning = newReasoning;
//           _chatItemRNMap[assistReply.id]?.notify();
//         }

//         _autoScroll(chatId);
//       }
//       if (eve is oc.ResponseOutputTextDone) stdout.writeln();
//       if (eve is oc.ResponseCompleted) break;
//     }

//     await chatStream.close();

//     Cfg.clientoc.close();
//   }


