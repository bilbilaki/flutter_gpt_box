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
    (ChatType.text, _) => _onCreateText,
    (ChatType.img, _) => _onCreateImg,
    (ChatType.audio, _) =>
      _onCreateSTT, // audio generation (TTS-like) streaming
    (ChatType.voice, _) => _onVoiceChat, // voice in + voice out
    (ChatType.voicejustin, _) =>
      _onVoiceJustInput, // voice in + text out (stream)
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
  final workingChat = _allHistories[chatId];
  if (workingChat == null) {
    final msg = 'Chat($chatId) not found';
    Loggers.app.warning(msg);
    context.showSnackBar(msg);
    return;
  }
  final config = Cfg.current;

  final questionContents = <ChatContent>[ChatContent.text(input)];
  for (final file in files) {
    // Ensure images are sent as base64 data URL
    final content = await _contentFromPath(file);
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
  final titleCompleter = await _genChatTitle(context, chatId, config);

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
    temperature: aiSettings.temperature
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
          final parts = _splitDataUrisToChatContents(merged);
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
        BakSync.instance.sync();
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

  final workingChat = _allHistories[chatId];
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

Future<Completer<void>?> _genChatTitle(
  BuildContext context,
  String chatId,
  ChatConfig cfg,
) async {
  if (!Stores.setting.genTitle.get()) return null;

  final entity = _allHistories[chatId];
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
        _allHistories[chatId] = ne;
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

  final chatHistory = _allHistories[chatId];
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
  final workingChat = _allHistories[chatId];
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
Uint8List wavFromPcm16(Uint8List pcmBytes, {int sampleRate = 16000, int channels = 1}) {
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

Future<String> _imagePathToDataUrl(String path) async {
  final mime = _mimeFromExt(path);
  final b64 = await _fileToBase64(path);
  return 'data:$mime;base64,$b64';
}

// Helper: split a string that may contain data:image/...;base64,... URIs into ChatContent pieces.
List<ChatContent> _splitDataUrisToChatContents(String s) {
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

Future<ChatContent> _contentFromPath(String path) async {
  if (_isImagePath(path)) {
    final dataUrl = await _imagePathToDataUrl(path);
    return ChatContent.image(dataUrl);
  }
  return ChatContent.file(path);
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

Future<String?> _ensureAudioInputPath(List<String> files) async {
  final audio = files.firstWhereOrNull(isAudioPath);
  if (audio != null) return audio;
  // fallback quick record if nothing provided
  return await _quickRecordWav();
}

/// =======================================
/// 1) Audio generation stream (CreateSTT)
/// Model: gpt-4o-mini-audio, modalities: [audio], stream audio
/// =======================================
Future<void> _onCreateSTT(
  BuildContext context,
  String chatId,
  String input,
  List<String> files,
) async {
  final workingChat = _allHistories[chatId];
  if (workingChat == null) {
    final msg = 'Chat($chatId) not found';
    Loggers.app.warning(msg);
    context.showSnackBar(msg);
    return;
  }
  final config = Cfg.current;

  // Prepare user question (text + optionally images/files already attached)
  final questionContents = <ChatContent>[ChatContent.text(input)];
  for (final f in files) {
    final content = await _contentFromPath(f);
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

  final titleCompleter = await _genChatTitle(context, chatId, config);
  _loadingChatIds.value.add(chatId);
  _loadingChatIds.notify();
  _autoHideCtrl.autoHideEnabled = false;

  // Assistant reply placeholder (will attach audio file when done)
  final assistReply = ChatHistoryItem.gen(role: ChatRole.assist, content: []);
  workingChat.items.add(assistReply);
  _chatRN.notify();
  _filesPicked.value = [];
  final audioDataBuffer = StringBuffer();
  final transcriptBuffer = StringBuffer();

  try {
    final stream = Cfg.client.createChatCompletionStream(
      request: CreateChatCompletionRequest(
        model: ChatCompletionModel.modelId('gpt-4o-mini-audio-preview'),
        messages: msgs,
        modalities: [ChatCompletionModality.audio, ChatCompletionModality.text],
        audio: ChatCompletionAudioOptions(
          voice: await getCurrentVoice(),
          format: ChatCompletionAudioFormat.pcm16,
        ),
      temperature: aiSettings.temperature
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
Future<Stream> _callAudioInModelStream({
  required List<ChatCompletionMessage> prevMessages,
  required String audioPath,
  String modelId = 'gpt-4o-mini-audio-preview',
  openai.ChatCompletionAudioVoice? voice,
}) async {
  if (!File(audioPath).existsSync()) {
    throw Exception('Audio not found: $audioPath');
  }
  final inputB64 = await _fileToBase64(audioPath);
  final userMsg = ChatCompletionMessage.user(
    content: ChatCompletionUserMessageContent.parts([
      ChatCompletionMessageContentPart.audio(
        inputAudio: ChatCompletionMessageInputAudio(
          data: inputB64,
          format: ChatCompletionMessageInputAudioFormat.wav,
        ),
      ),
    ]),
  );

  final req = CreateChatCompletionRequest(
    model: ChatCompletionModel.modelId(modelId),
    modalities: const [ChatCompletionModality.audio, ChatCompletionModality.text],
    messages: [...prevMessages, userMsg],
    audio: ChatCompletionAudioOptions(
      voice: voice ?? await getCurrentVoice(),
      format: ChatCompletionAudioFormat.pcm16,
    ),
    temperature: aiSettings.temperature,
  );

  final stream = Cfg.client.createChatCompletionStream(request: req);
  return stream;
}
Future<void> _onLiveVoiceTurnParallel(
  BuildContext context,
  String chatId, {
  required String audioPath,
  String userHintText = '',
  void Function(String partialUserTranscript)? onLiveUserTranscript,
  void Function(Uint8List pcmChunk)? onLiveTtsAudio,
}) async {
  if (!_validChatCfg(context)) return;

  final workingChat = _allHistories[chatId];
  if (workingChat == null) {
    final msg = 'Chat($chatId) not found';
    Loggers.app.warning(msg);
    context.showSnackBar(msg);
    return;
  }

  _loadingChatIds.value.add(chatId);
  _loadingChatIds.notify();
  _autoHideCtrl.autoHideEnabled = false;

  // 0) Add a user placeholder with the raw audio file to history immediately
  final userItem = ChatHistoryItem.gen(
    role: ChatRole.user,
    content: [
      if (userHintText.trim().isNotEmpty) ChatContent.text(userHintText.trim()),
      ChatContent.file(audioPath),
    ],
  );
  workingChat.items.add(userItem);
  _chatRN.notify();
  _autoScroll(chatId);

  // 1) Start STT (partial + final)
  final sttCompleter = Completer<String>();
  String finalUserTranscript = '';
  StreamSubscription? sttSub;
  try {
    final sttStream = await _streamTranscribeAudio(
      audioPath: audioPath,
      onPartial: (p) {
        final partial = p.trim();
        if (partial.isNotEmpty) {
          onLiveUserTranscript?.call(partial);
          // update userItem UI: replace or add a text content as partial
          if (userItem.content.isEmpty) {
            userItem.content.add(ChatContent.text(partial));
          } else {
            // keep first slot as transcript text
            if (userItem.content.first.type.isText) {
              userItem.content[0] = ChatContent.text(partial);
            } else {
              userItem.content.insert(0, ChatContent.text(partial));
            }
          }
          _chatItemRNMap[userItem.id]?.notify();
        }
      },
    );
    sttSub = sttStream.sub;
    // Wait for final transcript in background, but do not block model
    sttStream.done.future.then((finalT) {
      finalUserTranscript = finalT.trim();
      sttCompleter.complete(finalUserTranscript);
    }).catchError((e, s) {
      Loggers.app.warning('STT error: $e');
      sttCompleter.complete('');
    });
  } catch (e) {
    Loggers.app.warning('Start STT failed: $e');
    sttCompleter.complete('');
  }

  // 2) Start audio-in model stream in parallel
  final msgs = (await _historyCarried(workingChat)).toList();
  // Note: append a minimal user audio message so model sees prior context; we will also send the actual audio in the stream builder
  // But we will include full audio via _callAudioInModelStream
  final assistReply = ChatHistoryItem.single(role: ChatRole.assist);
  workingChat.items.add(assistReply);
  _chatRN.notify();

  StreamSubscription? modelSub;
  final assistantAudioBase64Buff = StringBuffer();
  final assistantTranscriptBuff = StringBuffer();
  final assistantTextBuff = StringBuffer();

  // streaming player to play assistant audio segments if you want progressive play
  _StreamingPlayer? streamer;
  try {
    streamer = await _StreamingPlayer.create();
  } catch (_) {}

  try {
    final stream = await _callAudioInModelStream(prevMessages: msgs, audioPath: audioPath);
    modelSub = stream.listen(
      (eve) async {
        final delta = eve.choices.firstOrNull?.delta;
        if (delta == null) return;

        // Handle assistant text content if present
        final content = delta.content;
        if (content != null && content.isNotEmpty) {
          // accumulate textual content
          assistantTextBuff.write(content);
          // update assistant text UI as it arrives
          final merged = (assistantTextBuff.toString());
          final parts = _splitDataUrisToChatContents(merged);
          assistReply.content
            ..clear()
            ..addAll(parts);
          _chatItemRNMap[assistReply.id]?.notify();
        }

        // Handle streaming audio binary pieces if provided
        final a = delta.audio;
        if (a?.data != null && a!.data!.isNotEmpty) {
          assistantAudioBase64Buff.write(a.data);
          // If the model provides transcript for its own audio, collect it
          if (a.transcript != null && a.transcript!.isNotEmpty) {
            assistantTranscriptBuff.write(a.transcript);
            // show partial transcript above audio if you want
            final t = assistantTranscriptBuff.toString();
            if (assistReply.content.isEmpty) {
              assistReply.content.add(ChatContent.text(t));
            } else {
              // keep first content as transcript while audio not saved
              assistReply.content[0] = ChatContent.text(t);
            }
            _chatItemRNMap[assistReply.id]?.notify();
          }

          // Progressive playback: decode small chunk and play as segment (only if a.data are raw PCM/wav base64 parts)
          try {
            final pcm = base64Decode(a.data);
            // If the stream sends full WAV chunks, you can append and play
            if (streamer != null) {
              await streamer.appendAndPlay(pcm);
            }
            // Also notify UI via onLiveTtsAudio for visualizer
            onLiveTtsAudio?.call(pcm);
          } catch (_) {}
        }
      },
      onDone: () async {
        // Model fully done. Persist audio and transcript, and finalize assistant item.
        // 1) Save accumulated base64 into file if exists
        if (assistantAudioBase64Buff.isNotEmpty) {
          try {
            final outPath = await _saveBase64ToFile(assistantAudioBase64Buff.toString(), ext: '.wav');
            // Attach audio to assist reply: replace text placeholder or add file
            final hasText = assistReply.content.isNotEmpty && assistReply.content.first.type.isText;
            if (hasText) {
              assistReply.content.add(ChatContent.file(outPath));
            } else {
              assistReply.content
                ..clear()
                ..add(ChatContent.file(outPath));
            }
            _chatItemRNMap[assistReply.id]?.notify();
          } catch (e) {
            Loggers.app.warning('Save assistant audio failed: $e');
          }
        }

        // 2) If assistant transcript empty but assistantTextBuff present, attach text
        final combinedText = assistantTranscriptBuff.toString().trim().isNotEmpty
            ? assistantTranscriptBuff.toString()
            : assistantTextBuff.toString();
        if (combinedText.trim().isNotEmpty) {
          // Add as text content (before audio) for accessibility/search
          final firstIsText = assistReply.content.isNotEmpty && assistReply.content.first.type.isText;
          if (firstIsText) {
            assistReply.content[0] = ChatContent.text(combinedText.trim());
          } else {
            assistReply.content.insert(0, ChatContent.text(combinedText.trim()));
          }
          _chatItemRNMap[assistReply.id]?.notify();
        } else {
          // Optionally run STT on assistant audio to generate transcript if needed
          if (assistantAudioBase64Buff.isNotEmpty) {
            try {
              final tmpPath = await _saveBase64ToFile(assistantAudioBase64Buff.toString(), ext: '.wav');
              final sttForAssist = await _streamTranscribeAudio(audioPath: tmpPath);
              final finalAssistTxt = await sttForAssist.done.future;
              if (finalAssistTxt.trim().isNotEmpty) {
                assistReply.content.insert(0, ChatContent.text(finalAssistTxt.trim()));
                _chatItemRNMap[assistReply.id]?.notify();
              }
              await sttForAssist.sub.cancel();
            } catch (_) {}
          }
        }

        // finalize: cleanup streamer, subscriptions, store chat & UI states
        try {
          await streamer?.stop();
        } catch (_) {}
        _onStopStreamSub(chatId);
        _loadingChatIds.value.remove(chatId);
        _loadingChatIds.notify();
        _autoHideCtrl.autoHideEnabled = true;
        _storeChat(chatId);
        BakSync.instance.sync();
      },
      onError: (e, s) {
        _onErr(e, s, chatId, 'Audio-in model stream');
      },
      cancelOnError: false,
    );
  } catch (e, s) {
    _onErr(e, s, chatId, 'Start audio-in model stream');
  }

  // 3) Wait for STT to finish to finalize user item text (do not block model)
  sttCompleter.future.then((finalUt) async {
    final text = (finalUt.trim().isEmpty) ? userHintText.trim() : finalUt.trim();
    if (text.isNotEmpty) {
      // Replace or insert text content at first slot of userItem
      if (userItem.content.isEmpty) {
        userItem.content.add(ChatContent.text(text));
      } else {
        // if first was file, insert text before it, otherwise replace
        if (userItem.content.first.type.isText) {
          userItem.content[0] = ChatContent.text(text);
        } else {
          userItem.content.insert(0, ChatContent.text(text));
        }
      }
      _chatItemRNMap[userItem.id]?.notify();
    }
    try {
      await sttSub?.cancel();
    } catch (_) {}
  });

  // Keep references to cancel externally if user taps to stop
  _chatStreamSubs[chatId] = modelSub!;
  await _chatStreamSubs[chatId]?.cancel();
await streamer?.stop();
_onStopStreamSub(chatId);
_loadingChatIds.value.remove(chatId);
_loadingChatIds.notify();
_autoHideCtrl.autoHideEnabled = true;
}


/// =======================================
/// 2) Voice chat (voice in + voice out)
/// modalities: [text, audio]; includes input audio part
/// =======================================
Future<void> _onVoiceChat(
  BuildContext context,
  String chatId,
  String input,
  List<String> files,
) async {
  final audioPath = await _ensureAudioInputPath(files);
  if (audioPath == null || !File(audioPath).existsSync()) {
    final msg = l10n.emptyFields('Voice input (record or pick an audio file)');
    Loggers.app.warning(msg);
    context.showSnackBar(msg);
    return;
  }
  await _onLiveVoiceTurn(
    context,
    chatId,
    audioPath: audioPath,
    userHintText: input,
  );
}

/// =======================================
/// 3) Voice input only (like text stream, but attach user audio input)
/// modalities: [text]; stream textual answer; user message contains text + audio
/// =======================================
Future<void> _onVoiceJustInput(
  BuildContext context,
  String chatId,
  String input,
  List<String> files,
) async {
  final workingChat = _allHistories[chatId];
  if (workingChat == null) {
    final msg = 'Chat($chatId) not found';
    Loggers.app.warning(msg);
    context.showSnackBar(msg);
    return;
  }
  final config = Cfg.current;

  final audioPath = await _ensureAudioInputPath(files);
  if (audioPath == null || !File(audioPath).existsSync()) {
    final msg = l10n.emptyFields('Voice input (record or pick an audio file)');
    Loggers.app.warning(msg);
    context.showSnackBar(msg);
    return;
  }

  // Build prev messages
  final prev = (await _historyCarried(workingChat)).toList();

  // Build user message for OpenAI directly to attach audio part
  final inputB64 = await _fileToBase64(audioPath);
  final userMsg = ChatCompletionMessage.user(
    content: ChatCompletionUserMessageContent.parts([
      if (input.isNotEmpty) ChatCompletionMessageContentPart.text(text: input),
      ChatCompletionMessageContentPart.audio(
        inputAudio: ChatCompletionMessageInputAudio(
          data: inputB64,
          format: ChatCompletionMessageInputAudioFormat.wav,
        ),
      ),
    ]),

  );

  // Mirror into our history
  final userItem = ChatHistoryItem.gen(
    role: ChatRole.user,
    content: [
      if (input.isNotEmpty) ChatContent.text(input),
      ChatContent.file(audioPath),
    ],
  );
  workingChat.items.add(userItem);
  inputCtrl.clear();
  _chatRN.notify();
  _autoScroll(chatId);

  final titleCompleter = await _genChatTitle(context, chatId, config);

  _loadingChatIds.value.add(chatId);
  _loadingChatIds.notify();
  _autoHideCtrl.autoHideEnabled = false;

  final request = CreateChatCompletionRequest(
    model: ChatCompletionModel.modelId(config.model),
    modalities: const [ChatCompletionModality.text],
    messages: [...prev, userMsg],
  );

  final assistReply = ChatHistoryItem.single(role: ChatRole.assist);
  workingChat.items.add(assistReply);
  _chatRN.notify();

  try {
    final stream = Cfg.client.createChatCompletionStream(request: request);

    final sub = stream.listen(
      (eve) async {
        final delta = eve.choices.firstOrNull?.delta;
        if (delta == null) return;

        final content = delta.content;
        if (content != null) {
          final prev = assistReply.content.isEmpty
              ? ''
              : assistReply.content.map((e) => e.raw).join();
          final merged = '$prev$content';
          final parts = _splitDataUrisToChatContents(merged);
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

        await titleCompleter?.future;
        await Future.delayed(const Duration(milliseconds: 300));
        BakSync.instance.sync();
      },
      onError: (e, s) {
        _onErr(e, s, chatId, 'Listen voice-input text stream');
      },
    );

    _chatStreamSubs[chatId] = sub;
  } catch (e, s) {
    _loadingChatIds.value.remove(chatId);
    _loadingChatIds.notify();
    _onErr(e, s, chatId, 'Catch voice-input text stream');
  }
}

// ============ Streaming TTS (text -> PCM16 audio chunks) ============
class _TtsStreamResult {
  final StreamSubscription sub;
  final Completer<void> done;
  _TtsStreamResult({required this.sub, required this.done});
}

/// Streams PCM16 audio chunks for the given text. Callers can:
/// - onAudioChunk: consume PCM16 chunks (Uint8List)
/// - onPartialTranscript: subscribe to model transcript of the audio
/// - onComplete: receive the full PCM16 concatenated (nullable if no audio)
Future<_TtsStreamResult> _streamTtsFromText({
  required String text,
  required void Function(Uint8List pcmChunk) onAudioChunk,
  void Function(String partialTranscript)? onPartialTranscript,
  void Function(Uint8List? fullPcm)? onComplete,
  openai.ChatCompletionAudioVoice? voice,
  String modelId = 'gpt-4o-mini-audio-preview',
}) async {
  final audioBuff = BytesBuilder(copy: false);
  final done = Completer<void>();

  final req = CreateChatCompletionRequest(
    model: ChatCompletionModel.modelId(modelId),
    modalities:  [
      ChatCompletionModality.audio,
      ChatCompletionModality.text,
    ],
    messages: [
      ChatCompletionMessage.user(
        content: ChatCompletionUserMessageContent.parts([
          ChatCompletionMessageContentPart.text(text: text),
        ]),
      ),
    ],
    audio: ChatCompletionAudioOptions(
      voice: voice ?? await getCurrentVoice(),
      format: ChatCompletionAudioFormat.wav,
    ),
    webSearchOptions: WebSearchOptions(),
    temperature: aiSettings.temperature
  );

  final stream = Cfg.client.createChatCompletionStream(request: req);
  final sub = stream.listen(
    (eve) {
      final delta = eve.choices.firstOrNull?.delta;
      if (delta == null) return;

      final a = delta.audio;
      if (a?.data != null && a!.data!.isNotEmpty) {
        try {
          final pcm = base64Decode(a.data.toString());
          audioBuff.add(pcm);
          onAudioChunk(pcm);
        } catch (_) {}
      }
      if (a?.transcript != null && a!.transcript!.isNotEmpty) {
        onPartialTranscript?.call(a.transcript!);
      }
    },
    onDone: () {
      onComplete?.call(audioBuff.length > 0 ? audioBuff.takeBytes() : null);
      done.complete();
    },
    onError: (e, s) {
      Loggers.app.warning('TTS stream: $e');
      done.completeError(e, s);
    },
    cancelOnError: true,
  );

  return _TtsStreamResult(sub: sub, done: done);
}

// ============ Streaming STT (audio -> text) ============
class _SttStreamResult {
  final StreamSubscription sub;
  final Completer<String> done;
  _SttStreamResult({required this.sub, required this.done});
}

/// Streams transcript from audio input via gpt-4o-mini-transcribe.
/// onPartial: receives partial text while streaming.
/// Returns final transcript string.
Future<_SttStreamResult> _streamTranscribeAudio({
  required String audioPath,
  void Function(String partial)? onPartial,
  String modelId = 'gpt-4o-mini-transcribe',
}) async {
  final done = Completer<String>();
  final accum = StringBuffer();

  if (!File(audioPath).existsSync()) {
    throw Exception('Audio not found: $audioPath');
  }
  // We send the full audio at once, but get transcript as a text stream.
  final inputB64 = await _fileToBase64(audioPath);
  final req = CreateChatCompletionRequest(
    model: ChatCompletionModel.modelId(modelId),
    // Request text-only transcript
    modalities:  [ChatCompletionModality.text,ChatCompletionModality.audio],
    messages: [
      ChatCompletionMessage.user(
        content: ChatCompletionUserMessageContent.parts([
          ChatCompletionMessageContentPart.audio(
            inputAudio: ChatCompletionMessageInputAudio(
              data: inputB64,
              format: ChatCompletionMessageInputAudioFormat.wav,
            ),
          ),
        ]),
      ),
    ],
  );

  final stream = Cfg.client.createChatCompletionStream(request: req);
  final sub = stream.listen(
    (eve) {
      final delta = eve.choices.firstOrNull?.delta;
      if (delta == null) return;
      final c = delta.content;
      if (c != null && c.isNotEmpty) {
        accum.write(c);
        onPartial?.call(accum.toString());
      }
    },
    onDone: () {
      done.complete(accum.toString());
    },
    onError: (e, s) {
      Loggers.app.warning('STT stream: $e');
      done.completeError(e, s);
    },
    cancelOnError: true,
  );

  return _SttStreamResult(sub: sub, done: done);
}

/// =======================================
/// Live voice turn: STT -> stream text -> stream TTS
/// - 1) Transcribe user audio (gpt-4o-mini-transcribe, streaming partials)
/// - 2) Add transcript as user message (text only)
/// - 3) Stream assistant text using selected model (existing text stream logic)
/// - 4) In parallel, stream TTS for assistant reply chunks
/// - 5) Persist all to history
/// =======================================
Future<void> _onLiveVoiceTurn(
  BuildContext context,
  String chatId, {
  required String audioPath,
  String userHintText = '',
  void Function(String partialUserTranscript)? onLiveUserTranscript,
  void Function(Uint8List pcmChunk)? onLiveTtsAudio,
}) async {
  if (!_validChatCfg(context)) return;

  final workingChat = _allHistories[chatId];
  if (workingChat == null) {
    final msg = 'Chat($chatId) not found';
    Loggers.app.warning(msg);
    context.showSnackBar(msg);
    return;
  }

  _loadingChatIds.value.add(chatId);
  _loadingChatIds.notify();
  _autoHideCtrl.autoHideEnabled = false;

  // 1) STT stream user audio
  String finalTranscript = '';
  try {
    final stt = await _streamTranscribeAudio(
      audioPath: audioPath,
      onPartial: (p) {
        final partial = p.trim();
        if (partial.isNotEmpty) onLiveUserTranscript?.call(partial);
      },
    );
    finalTranscript = await stt.done.future;
    await stt.sub.cancel();
  } catch (e, s) {
    _onErr(e, s, chatId, 'Live STT');
    return;
  }

  // 2) Mirror transcript into chat as user message (text only)
  if (finalTranscript.trim().isEmpty) {
    finalTranscript = userHintText.trim();
  }
  final userMsg = ChatHistoryItem.gen(
    role: ChatRole.user,
    content: [
      if (finalTranscript.trim().isNotEmpty)
        ChatContent.text(finalTranscript.trim()),
      // Optionally attach original audio if you want:
      // ChatContent.file(audioPath),
    ],
  );
  workingChat.items.add(userMsg);
  _chatRN.notify();
  _autoScroll(chatId);

  // 3) Build messages with history and stream assistant text
  final config = Cfg.current;
  final msgs = (await _historyCarried(workingChat)).toList();
  msgs.add(await userMsg.toOpenAI());

  final titleCompleter = await _genChatTitle(context, chatId, config);

  final assistReply = ChatHistoryItem.single(role: ChatRole.assist);
  workingChat.items.add(assistReply);
  _chatRN.notify();

  // Stream assistant text (default model)
  final req = CreateChatCompletionRequest(
    messages: msgs,
    model: ChatCompletionModel.modelId(config.model),
  );

  // Sentence chunker to feed TTS promptly as readable segments appear
  final sentenceBuf = StringBuffer();
  Future<_TtsStreamResult?> ttsStartForChunk(String chunk) async {
    if (chunk.trim().isEmpty) return null;
    try {
      return await _streamTtsFromText(
        text: chunk,
        onAudioChunk: (pcm) => onLiveTtsAudio?.call(pcm),
        onPartialTranscript: null,
        onComplete: (_) {},
      );
    } catch (_) {
      return null;
    }
  }
  final List<_TtsStreamResult> _activeTtsSubs = [];

  // Helper: feed text into UI and maybe TTS
  Future<void> appendAssistantText(String delta) async {
    if (delta.isEmpty) return;
    final prev = assistReply.content.isEmpty
        ? ''
        : assistReply.content.map((e) => e.raw).join();
    final merged = '$prev$delta';
    final parts = _splitDataUrisToChatContents(merged);
    assistReply.content
      ..clear()
      ..addAll(parts);
    _chatItemRNMap[assistReply.id]?.notify();

    // sentence-level chunking: push TTS for each sentence as soon as we can
    sentenceBuf.write(delta);
    final sentenceText = sentenceBuf.toString();
    // Split on sentence boundaries
    final sentenceParts = sentenceText.split(RegExp(r'(?<=[\.!\?\n])\s+'));
    // Keep last tail (possibly incomplete sentence) in the buffer
    for (int i = 0; i < sentenceParts.length - 1; i++) {
      final sentence = sentenceParts[i].trim();
      if (sentence.isEmpty) continue;
      final t = await ttsStartForChunk(sentence);
      if (t != null) _activeTtsSubs.add(t);
    }
    final tail = sentenceParts.isNotEmpty ? sentenceParts.last : '';
    sentenceBuf
      ..clear()
      ..write(tail);
  }

  try {
    final stream = Cfg.client.createChatCompletionStream(request: req);
    final sub = stream.listen(
      (eve) async {
        final delta = eve.choices.firstOrNull?.delta;
        if (delta == null) return;

        final content = delta.content ?? '';
        if (content.isNotEmpty) {
          await appendAssistantText(content);
        }

        final rc = delta.reasoningContent;
        if (rc != null && rc.isNotEmpty) {
          final origin = assistReply.reasoning ?? '';
          assistReply.reasoning = '$origin$rc';
          _chatItemRNMap[assistReply.id]?.notify();
        }
        _autoScroll(chatId);
      },
      onDone: () async {
        // flush final tail as a chunk
        final tail = sentenceBuf.toString().trim();
        if (tail.isNotEmpty) {
          final t = await ttsStartForChunk(tail);
          if (t != null) _activeTtsSubs.add(t);
        }
        sentenceBuf.clear();

        // Wait TTS chunks to complete
        for (final t in _activeTtsSubs) {
          try {
            await t.done.future;
            await t.sub.cancel();
          } catch (_) {}
        }
        _activeTtsSubs.clear();

        _onStopStreamSub(chatId);
        _loadingChatIds.value.remove(chatId);
        _loadingChatIds.notify();
        _autoHideCtrl.autoHideEnabled = true;

        _storeChat(chatId);
        await titleCompleter?.future;
        await Future.delayed(const Duration(milliseconds: 300));
        BakSync.instance.sync();
      },
      onError: (e, s) {
        _onErr(e, s, chatId, 'Live Voice turn: assistant stream');
      },
      cancelOnError: false,
    );
    _chatStreamSubs[chatId] = sub;
  } catch (e, s) {
    _loadingChatIds.value.remove(chatId);
    _loadingChatIds.notify();
    _onErr(e, s, chatId, 'Live Voice turn: start stream');
  }
}

class VoiceSessionController {
  final String chatId;
  final void Function(String partialUserTranscript)? onUserPartial;
  final void Function(Uint8List pcmChunk)? onTtsChunk;

  VoiceSessionController({
    required this.chatId,
    this.onUserPartial,
    this.onTtsChunk,
  });

  // Active recording path
  String? _recPath;

  Future<void> startRecording() async {
    if (!await _ensureRecordPermission()) {
      throw Exception('Microphone permission denied');
    }
    final dir = await Directory.systemTemp.createTemp('live_rec_');
    _recPath = p.join(
      dir.path,
      'live_${DateTime.now().millisecondsSinceEpoch}.wav',
    );
    await _audioRecorder.start(
      const RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: 16000,
        bitRate: 128000,
      ),
      path: _recPath!,
    );
  }

  Future<void> stopAndProcess(
    BuildContext context, {
    String userHintText = '',
  }) async {
    try {
      await _audioRecorder.stop();
    } catch (_) {}
    final path = _recPath;
    _recPath = null;
    if (path == null || !File(path).existsSync()) {
      throw Exception('No audio captured');
    }
    await _onLiveVoiceTurnParallel(
      context,
      chatId,
      audioPath: path,
      userHintText: userHintText,
      onLiveUserTranscript: onUserPartial,
      onLiveTtsAudio: onTtsChunk,
    );
  }

  Future<void> cancelRecording() async {
    try {
      await _audioRecorder.stop();
    } catch (_) {}
    _recPath = null;
  }
}

Future<void> _onCreateTextTranslated(
  BuildContext context,
  String chatId,
  String input,
  List<String> files,
) async {
  final workingChat = _allHistories[chatId];
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
              content:
                  ChatCompletionUserMessageContent.string(translatePrompt),
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
  final questionContents = <ChatContent>[
    ChatContent.text(translated),
  ];
  for (final file in files) {
    // Ensure images are sent as base64 data URL
    final content = await _contentFromPath(file);
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
  final titleCompleter = await _genChatTitle(context, chatId, Cfg.current);

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
          final parts = _splitDataUrisToChatContents(merged);
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
        BakSync.instance.sync();
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
