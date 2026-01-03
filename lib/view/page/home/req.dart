part of 'home.dart';

bool _useResponsesApi(ChatConfig cfg) {
  final u = cfg.url.trim().toLowerCase();
  return u.startsWith('https://api.openai.com');
}

String _buildPinnedInstructions(ChatConfig cfg) {
  final memories = Stores.mcp.memories.get();
  final parts = <String>[
    if (cfg.prompt.trim().isNotEmpty) cfg.prompt.trim(),
    if (memories.isNotEmpty) memories.join('\n'),
  ];
  return parts.join('\n\n').trim();
}

Future<List<ResponseTool>> _responsesToolsForChat(ChatHistory chat) async {
  final chatScopeUseMcp = chat.settings?.useTools != false;
  if (!chatScopeUseMcp) return const [];

  final availableMcp = await OpenAIFuncCalls.tools;
  if (availableMcp.isEmpty) return const [];

  return availableMcp.map((t) {
    final fn = t.function;
    final params = fn.parameters == null
        ? <String, dynamic>{'type': 'object', 'properties': {}}
        : Map<String, dynamic>.from(fn.parameters!);

    // Ensure schema validity
    params['type'] = 'object';
    if (params['properties'] is! Map) {
      params['properties'] = <String, dynamic>{};
    }

    return FunctionTool(
      name: fn.name,
      description: fn.description,
      parameters: params,
    );
  }).toList();
}

class _RespFuncCall {
  final String callId;
  final String name;
  final Map<String, dynamic> arguments;

  _RespFuncCall({
    required this.callId,
    required this.name,
    required this.arguments,
  });
}

_RespFuncCall? _tryParseRespFunctionCall(Map<String, dynamic> raw) {
  // We mainly care about "response.output_item.added" or items with type "function_call".
  final type = raw['type']?.toString();
  final item = raw['output_item'];
  final map = item is Map<String, dynamic> ? item : raw;

  final t = map['type']?.toString() ?? type ?? '';

  if (!t.contains('function_call')) return null;

  final callId = (map['id'] ?? map['call_id'])?.toString();
  final name = map['name']?.toString();
  final argsAny = map['arguments'];

  if (callId == null || name == null) return null;

  Map<String, dynamic> args;
  try {
    if (argsAny is String) {
      args = jsonDecode(argsAny) is Map<String, dynamic>
          ? Map<String, dynamic>.from(jsonDecode(argsAny))
          : <String, dynamic>{};
    } else if (argsAny is Map) {
      args = Map<String, dynamic>.from(argsAny);
    } else {
      args = <String, dynamic>{};
    }
  } catch (_) {
    args = <String, dynamic>{};
  }

  return _RespFuncCall(callId: callId, name: name, arguments: args);
}

Map<String, dynamic> _toolOutputInput({
  required String callId,
  required String outputText,
}) {
  return {'type': 'tool_output', 'tool_call_id': callId, 'output': outputText};
}

List<Map<String, dynamic>> _chatContentToResponsesInput(
  List<ChatContent> contents,
) {
  return contents.map((c) {
    switch (c.type) {
      case ChatContentType.text:
        return {'type': 'input_text', 'text': c.raw};
      case ChatContentType.image:
        return {'type': 'input_image', 'image_url': c.raw};
      case ChatContentType.audio:
        return {'type': 'input_audio', 'audio_url': c.raw};
      case ChatContentType.file:
        return {'type': 'input_file', 'file_url': c.raw};
      case ChatContentType.nanobenana:
        return {'type': 'input_image', 'image_url': c.raw};
    }
  }).toList();
}

bool _validChatCfg(BuildContext context) {
  final config = Cfg.current;
  final urlEmpty = config.url == 'https://api.openai.com/v1';
  if (urlEmpty && config.key.isEmpty) {
    final msg = l10n.emptyFields('${l10n.secretKey} | Api Url');
    Loggers.app.warning(msg);
    context.showSnackBar(msg);
    return false;
  }
  return true;
}

Future<Iterable<ChatCompletionMessage>> _historyCarried(
  ChatHistory workingChat,
) async {
  final config = Cfg.current;

  final ignoreCtxCons = workingChat.settings?.ignoreContextConstraint == true;
  if (ignoreCtxCons) {
    return Future.wait(workingChat.items.map((e) => e.toOpenAI()));
  }

  final memories = Stores.mcp.memories.get();
  final promptParts = <String>[
    if (config.prompt.isNotEmpty) config.prompt.trim(),
    if (memories.isNotEmpty) memories.join('\n'),
  ];
  final promptStr = promptParts.join('\n\n');
  final prompt = promptStr.isNotEmpty
      ? await ChatHistoryItem.single(
          role: ChatRole.system,
          raw: promptStr,
        ).toOpenAI()
      : null;

  if (workingChat.settings?.headTailMode == true) {
    final first = await workingChat.items.firstOrNull?.toOpenAI();
    return [if (prompt != null) prompt, if (first != null) first];
  }

  var count = 0;
  final msgs = <ChatCompletionMessage>[];

  for (final item in workingChat.items.reversed) {
    if (count > config.historyLen) break;
    if (item.role.isSystem) continue;

    final isTool = item.role.isTool;
    final rawLen = item.toMarkdown.length;
    if (isTool && rawLen > 4000 && count > 2) {
      continue;
    }

    final msg = await item.toOpenAI();
    msgs.add(msg);
    count++;
  }

  if (prompt != null) msgs.add(prompt);
  return msgs.reversed;
}

void _onCreateRequest(BuildContext context, String chatId) async {
  if (!_validChatCfg(context)) return;

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
    (ChatType.audio, _) => _onAudioModel,
    (ChatType.voice, _) => _onTtsModel,
    (ChatType.voicejustin, _) => _onCreateText,
    (ChatType.autoenglishtrans, _) => _onCreateTextTranslated,
  };

  return await func(context, chatId, input, _filesPicked.value);
}

Future<void> _onCreateTextResponses(
  BuildContext context,
  String chatId,
  String input,
  List<String> files,
) async {
  final workingChat0 = allHistories[chatId];
  if (workingChat0 == null) {
    final msg = 'Chat($chatId) not found';
    Loggers.app.warning(msg);
    context.showSnackBar(msg);
    return;
  }

  final cfg = Cfg.current;
  final questionContents = <ChatContent>[ChatContent.text(input)];

  for (final file in files) {
    if (!modelUseFilePath) {
      final content = await contentFromPath(file);
      questionContents.add(content);
    } else {
      questionContents.add(
        ChatContent.text(
          'For Using Tools with file operation use this File Path: $file',
        ),
      );
      modelUseFilePath = false;
    }
  }

  final question = ChatHistoryItem.gen(
    role: ChatRole.user,
    content: questionContents,
  );

  // update UI history (same pattern as current)
  workingChat0.items.add(question);
  inputCtrl.clear();
  _chatRN.notify();
  _autoScroll(chatId);
  _filesPicked.value = [];

  final titleCompleter = await genChatTitle(context, chatId, cfg);

  final assistReply = ChatHistoryItem.single(role: ChatRole.assist);
  workingChat0.items.add(assistReply);
  _chatRN.notify();

  final mcpLogItem = ChatHistoryItem.single(role: ChatRole.tool, raw: '');
  bool mcpLogShown = false;

  void showMcpLogIfNeeded() {
    if (mcpLogShown) return;
    workingChat0.items.add(mcpLogItem);
    mcpLogShown = true;
    _chatRN.notify();
    _autoScroll(chatId);
  }

  void onToolLog(String s) {
    showMcpLogIfNeeded();
    final c = ChatContent.text(s);
    if (mcpLogItem.content.isEmpty) {
      mcpLogItem.content.add(c);
    } else {
      mcpLogItem.content[0] = c;
    }
    _chatItemRNMap[mcpLogItem.id]?.notify();
  }

  _loadingChatIds.value.add(chatId);
  _loadingChatIds.notify();
  _autoHideCtrl.autoHideEnabled = false;

  final responses = ResponsesService();
  final tools = await _responsesToolsForChat(workingChat0);
  final instructions = _buildPinnedInstructions(cfg);

  // We must not mutate ChatHistory directly (it’s immutable fields), so we will replace the map entry when updating lastResponseId.
  String? previousId = workingChat0.lastResponseId;

  final assistRawBuffer = StringBuffer();

  try {
    // tool continuation input payload
    List<dynamic>? nextInputArray;

    while (true) {
      final requestInputs =
          nextInputArray ??
          [
            {
              'role': 'user',
              'content': _chatContentToResponsesInput(questionContents),
            },
          ];

      final req = ResponsesRequest(
        model: cfg.model,
        previousResponseId: previousId,
        tools: tools,
        toolChoice: tools.isEmpty ? 'none' : 'auto',
        extra: {
          if (previousId == null && instructions.isNotEmpty)
            'instructions': instructions,
        },
        input: null,
        inputs: requestInputs, // serialized to "input" by toJson()
      );

      final calls = <_RespFuncCall>[];
      String? responseIdSeen;

      await for (final chunk in responses.stream(req)) {
        if (!_loadingChatIds.value.contains(chatId)) {
          // user stopped / cancelled
          break;
        }

        responseIdSeen ??= chunk.id;

        // Text delta
        final delta = chunk.deltaText;
        if (delta != null && delta.isNotEmpty) {
          assistRawBuffer.write(delta);
          final parts = splitDataUrisToChatContents(assistRawBuffer.toString());
          assistReply.content
            ..clear()
            ..addAll(parts);
          _chatItemRNMap[assistReply.id]?.notify();
          _autoScroll(chatId);
        }

        // Tool call extraction
        final call = _tryParseRespFunctionCall(chunk.raw);
        if (call != null) calls.add(call);

        if (chunk.raw['done'] == true) break;
        if (chunk.raw['type']?.toString() == 'response.completed') break;
      }

      // Update lastResponseId
      if (responseIdSeen != null) {
        previousId = responseIdSeen;

        // Replace chat in map with updated lastResponseId
        final cur = allHistories[chatId];
        if (cur != null && cur.lastResponseId != previousId) {
          final ne = cur.copyWith(l: previousId);
          allHistories[chatId] = ne;
          if (_curChatId.value == chatId) _curChat = ne;
        }
      }

      if (calls.isEmpty) {
        nextInputArray = null;
        break;
      }

      // Execute tool calls and prepare tool outputs as next "input" array
      final toolOutputs = <dynamic>[];
      for (final c in calls) {
        onToolLog('Calling tool: ${c.name}');
        // Ask confirm only for internal tools where mapping exists (your existing logic does this earlier).
        // Here we reuse your MCP handler through McpTools mapping; it will call internal server when applicable.
        final safeFuncId = c
            .name; // OpenAI will call with the function name we provided (safe id)
        final fakeToolCall = ChatCompletionMessageToolCall(
          id: c.callId,
          type: ChatCompletionMessageToolCallType.function,
          function: ChatCompletionMessageFunctionCall(
            name: safeFuncId,
            arguments: jsonEncode(c.arguments),
          ),
        );

        List<ChatContent>? out;
        try {
          out = await appResourcePool.withResource(() async {
            return await McpTools.handle(fakeToolCall, onToolLog);
          });
        } catch (e, s) {
          _onErr(e, s, chatId, 'Responses tool call');
        }

        final outputText = (out == null || out.isEmpty)
            ? ''
            : out.map((e) => e.raw).join('\n');

        toolOutputs.add(
          _toolOutputInput(callId: c.callId, outputText: outputText),
        );
      }

      nextInputArray = toolOutputs;
      // continue loop -> send tool outputs to model
    }

    // Persist the response id on the assistant item so replay can jump back via previousResponseId.
    if (previousId != null && assistReply.lastResponseId != previousId) {
      final idx = workingChat0.items.indexWhere((e) => e.id == assistReply.id);
      if (idx != -1) {
        workingChat0.items[idx] = assistReply.copyWith(
          lastResponseId: previousId,
        );
      }
    }

    // Remove mcp log item if it was only placeholder
    if (mcpLogShown && mcpLogItem.content.isEmpty) {
      workingChat0.items.remove(mcpLogItem);
    }

    _storeChat(chatId);
    await titleCompleter?.future;
    await Future.delayed(const Duration(milliseconds: 300));
  } catch (e, s) {
    _onErr(e, s, chatId, 'Responses');
  } finally {
    responses.dispose();
    _onStopStreamSub(chatId);
    _loadingChatIds.value.remove(chatId);
    _loadingChatIds.notify();
    _autoHideCtrl.autoHideEnabled = true;

    // cleanup UI log node
    _chatItemRNMap.remove(mcpLogItem.id)?.dispose();
  }
}

Future<void> _onCreateText(
  BuildContext context,
  String chatId,
  String input,
  List<String> files,
) async {
  if (_useResponsesApi(Cfg.current)) {
    _onCreateTextResponses(context, chatId, input, files);
    return;
  }
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

  final chatScopeUseMcp = workingChat.settings?.useTools != false;

  final availableMcp = await OpenAIFuncCalls.tools;
  final isMcpEmpty = availableMcp.isEmpty;

  if (mcpCompatible && chatScopeUseMcp && !isMcpEmpty) {
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
          final msg = await appResourcePool.withResource(() async {
            return await OpenAIFuncCalls.handle(
              mcpCall,
              (e, s) => _askMcpConfirm(context, e, s),
              onMcpLog,
            );
          });
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

  final assistRawBuffer = StringBuffer();

  try {
    final sub = chatStream.listen(
      (eve) async {
        final delta = eve.choices.firstOrNull?.delta;
        if (delta == null) return;

        final content = delta.content;
        if (content != null) {
          assistRawBuffer.write(content);
          final parts = splitDataUrisToChatContents(assistRawBuffer.toString());
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
  final prompt = input;
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

  var userQuestion = ChatHistoryItem.single(role: ChatRole.user, raw: prompt);
  workingChat.items.add(userQuestion);
  var assistReply = ChatHistoryItem.gen(role: ChatRole.assist, content: []);
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
    final client = HttpClient();
    final uri = Uri.parse('${cfg.url}/images/generations');
    final request = await client.postUrl(uri);

    request.headers.set('Content-Type', 'application/json');
    request.headers.set('Accept', 'application/json');
    request.headers.set('Authorization', 'Bearer ${cfg.key}');

    final body = jsonEncode({
      'model': imgModel,
      'prompt': prompt,
      'response_format': 'b64_json',
    });
    request.write(body);

    final response = await request.close();
    final responseBody = await response.transform(utf8.decoder).join();

    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}: $responseBody');
    }

    final Map<String, dynamic> jsonResponse = jsonDecode(responseBody);
    final List<dynamic>? dataList = jsonResponse['data'];

    if (dataList == null || dataList.isEmpty) {
      throw Exception('No data in response');
    }

    final responseBuffer = StringBuffer();
    for (final item in dataList) {
      final b64Json = item['b64_json'];
      if (b64Json != null && b64Json.toString().isNotEmpty) {
        final dataUri = 'data:image/jpeg;base64,${b64Json}';
        responseBuffer.write(dataUri);
        Loggers.app.info('Image generated (base64)');
      }

      final url = item['url'];
      if (url != null && url.toString().isNotEmpty) {
        responseBuffer.write(url.toString());
        Loggers.app.info('Image generated: $url');
      }

      final revisedPrompt = item['revised_prompt'];
      if (revisedPrompt != null && revisedPrompt.toString().isNotEmpty) {
        Loggers.app.info('Revised prompt: $revisedPrompt');
      }
    }

    if (responseBuffer.isEmpty) {
      final msg = 'Create image: empty response or no image data returned';
      Loggers.app.warning(msg);
      context.showSnackBar(msg);

      workingChat.items.remove(assistReply);
      _chatRN.notify();
      return;
    }

    final imgContents = splitDataUrisToChatContents(responseBuffer.toString());
    assistReply.content.addAll(imgContents);

    _storeChat(chatId);
    _chatRN.notify();
    _autoScroll(chatId);

    context.showSnackBar('Image generated successfully');

    client.close();
  } catch (e, s) {
    Loggers.app.severe('Create image error: $e\n$s');

    workingChat.items.remove(assistReply);
    _chatRN.notify();

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

void _onReplay({
  required BuildContext context,
  required String chatId,
  required ChatHistoryItem item,
}) async {
  if (!_validChatCfg(context)) return;

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

  final replayMsgIdx = chatHistory.items.indexOf(item);
  if (replayMsgIdx == -1) {
    final msg = 'Replay Chat($chatId) item($item) not found';
    Loggers.app.warning(msg);
    context.showSnackBar('${libL10n.fail}: $msg');
    return;
  }

  final chatType = Cfg.chatType.value;
  final usingResponsesApi =
      _useResponsesApi(Cfg.current) &&
      (chatType == ChatType.text || chatType == ChatType.voicejustin);
  String? prevResponseId;
  if (usingResponsesApi) {
    for (var i = replayMsgIdx - 1; i >= 0; i--) {
      final rid = chatHistory.items[i].lastResponseId;
      if (rid != null && rid.isNotEmpty) {
        prevResponseId = rid;
        break;
      }
    }

    // If this chat was created before we started persisting per-message response ids,
    // replay with Responses API can't reliably reconstruct earlier state.
    if (replayMsgIdx > 0 && prevResponseId == null) {
      context.showSnackBar(
        'Replay not available (missing response id history).',
      );
      return;
    }
  }

  chatHistory.items.removeRange(replayMsgIdx, chatHistory.items.length);

  if (usingResponsesApi) {
    final cur = allHistories[chatId];
    if (cur != null && cur.lastResponseId != prevResponseId) {
      final ne = cur.copyWith(items: cur.items, l: prevResponseId);
      allHistories[chatId] = ne;
      if (_curChatId.value == chatId) _curChat = ne;
    }
  }

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

  _loadingChatIds.value.remove(chatId);
  _loadingChatIds.notify();
  _autoHideCtrl.autoHideEnabled = true;

  final msg = '$e\n\n```$s```';
  final workingChat = allHistories[chatId];
  if (workingChat == null) return;

  if (workingChat.items.isNotEmpty) {
    final last = workingChat.items.last;
    final role = last.role;
    if ((role.isAssist || role.isTool) &&
        last.content.every((e) => e.raw.isEmpty)) {
      workingChat.items.removeLast();
    }
  }

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

final AudioRecorder _audioRecorder = AudioRecorder();

Future<bool> _ensureRecordPermission() async {
  try {
    return await _audioRecorder.hasPermission();
  } catch (_) {
    return false;
  }
}

bool isImagePath(String path) {
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
  return appResourcePool.withResource(() async {
    final bytes = await File(path).readAsBytes();
    return base64Encode(bytes);
  });
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
  header.add(_intToBytes(1, 2));
  header.add(_intToBytes(channels, 2));
  header.add(_intToBytes(sampleRate, 4));
  header.add(_intToBytes(byteRate, 4));
  header.add(_intToBytes(blockAlign, 2));
  header.add(_intToBytes(16, 2));
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
    try {
      final comma = dataUri.indexOf(',');
      final body = comma >= 0 ? dataUri.substring(comma + 1) : dataUri;
      base64Decode(body.replaceAll(RegExp(r'\s+'), ''));
      if (dataUri.toLowerCase().contains('data:image/')) {
        parts.add(ChatContent.image(dataUri));
      } else {
        parts.add(ChatContent.audio(dataUri));
      }
    } catch (_) {
      return [ChatContent.text(s)];
    }
    last = m.end;
  }
  if (last < s.length) parts.add(ChatContent.text(s.substring(last)));
  return parts;
}

Future<ChatContent> contentFromPath(String path) async {
  return appResourcePool.withResource(() async {
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
      } else if (getAppFileType(path) == AppFileType.reversefiletotext) {
        final content = await File(path).readAsString();
        final filename = p.basename(path);
        final metadata = File(path).statSync();
        return ChatContent.text('''User Attached File :   
        FileName: $filename
        MetaData: $metadata
        FilePath: $path
        FileContent: $content''');
      }
    }
    return ChatContent.file(
      'app cant process sending file , tell this to user and if this helpful this is file path : $path',
    );
  });
}

Future<String> _saveBase64ToFile(
  String base64Data, {
  String ext = '.wav',
}) async {
  return appResourcePool.withResource(() async {
    final bytes = base64Decode(base64Data);
    final dir = await Directory.systemTemp.createTemp('oai_audio_');
    final path = p.join(
      dir.path,
      'out_${DateTime.now().millisecondsSinceEpoch}$ext',
    );
    final f = File(path);
    await f.writeAsBytes(bytes, flush: true);
    return f.path;
  });
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

  final questionContents = <ChatContent>[ChatContent.text(input)];
  for (final file in files) {
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

  final assistReply = ChatHistoryItem.gen(role: ChatRole.assist, content: []);
  workingChat.items.add(assistReply);
  _chatRN.notify();
  _filesPicked.value = [];
  final audioDataBuffer = StringBuffer();
  final transcriptBuffer = StringBuffer();
var voice = await getCurrentVoice();
  try {
    final stream = Cfg.client.createChatCompletionStream(
      request: CreateChatCompletionRequest(
        model: ChatCompletionModel.modelId(
          Cfg.current.model,
        ),
        messages: msgs,
        modalities: [ ChatCompletionModality.text,ChatCompletionModality.audio],
        audio: ChatCompletionAudioOptions(
          voice: voice,
          format: ChatCompletionAudioFormat.pcm16,
        ),
        temperature: aiSettings.temperature,
      ),
    );

    final sub = stream.listen(
      (eve) async {
        final delta = eve.choices.firstOrNull?.delta;
        if (delta == null) return;

        final a = delta.audio;
        if (a?.data != null && a!.data!.isNotEmpty) {
          audioDataBuffer.write(a.data);
        }
        if (a?.transcript != null && a!.transcript!.isNotEmpty) {
          transcriptBuffer.write(a.transcript);
        }

        if (transcriptBuffer.isNotEmpty) {
          final t = transcriptBuffer.toString();
          if (assistReply.content.isEmpty) {
            assistReply.content.add(ChatContent.text(t));
          } else {
            assistReply.content[0] = ChatContent.text(t);
          }
          _chatItemRNMap[assistReply.id]?.notify();
        }

        _autoScroll(chatId);
      },
      onDone: () async {
        try {
          if (audioDataBuffer.isNotEmpty) {
            final path = await _saveBase64ToFile(
              audioDataBuffer.toString(),
              ext: '.wav',
            );
            ss.voicePlayedUntilNow.set(false);
            if (assistReply.content.isEmpty) {
              assistReply.content.add(ChatContent.file(path));
            } else {
              final hasText =
                  assistReply.content.firstOrNull?.type.isText == true;
              if (hasText) {
                assistReply.content.add(ChatContent.file(path));
              } else {
                assistReply.content[0] = ChatContent.file(path);
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
////TODO refactoring and optimizing streaming audio above
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

  final questionContents = <ChatContent>[ChatContent.text(input)];
  for (final file in files) {
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

  final chatScopeUseMcp = workingChat.settings?.useTools != false;

  final availableMcp = await OpenAIFuncCalls.tools;
  final isMcpEmpty = availableMcp.isEmpty;

  if (mcpCompatible && chatScopeUseMcp && !isMcpEmpty) {
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
          final msg = await appResourcePool.withResource(() async {
            return await OpenAIFuncCalls.handle(
              mcpCall,
              (e, s) => _askMcpConfirm(context, e, s),
              onMcpLog,
            );
          });
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

  final assistReplyStreaming = ChatHistoryItem.single(role: ChatRole.assist);
  workingChat.items.add(assistReplyStreaming);
  _chatRN.notify();

  final assistantTextBuffer = StringBuffer();

  try {
    final sub = chatStream.listen(
      (eve) async {
        final delta = eve.choices.firstOrNull?.delta;
        if (delta == null) return;

        final content = delta.content;
        if (content != null) {
          assistantTextBuffer.write(content);
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
        try {
          final finalText = assistantTextBuffer.toString();
          final finalAssist = ChatHistoryItem.gen(
            role: ChatRole.assist,
            content: [],
          );
          if (finalText.isNotEmpty) {
            finalAssist.content.add(ChatContent.text(finalText));
          }
          final idx = workingChat.items.indexOf(assistReplyStreaming);
          if (idx != -1) {
            workingChat.items[idx] = finalAssist;
          } else {
            workingChat.items.add(finalAssist);
          }
          _chatRN.notify();

          if (finalText.trim().isNotEmpty) {
            final ttsMsg = ChatHistoryItem.gen(
              content: [ChatContent.text(finalText)],
              role: ChatRole.user,
            );
            final con = (await _historyCarried(
              ChatHistory(
                lastResponseId: null,
                items: [ttsMsg],
                id: Uuid().v4(),
              ),
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
                    if (finalAssist.content.isEmpty) {
                      finalAssist.content.add(ChatContent.file(path));
                    } else {
                      finalAssist.content.add(ChatContent.file(path));
                    }
                    _chatItemRNMap[finalAssist.id]?.notify();
                  }
                } finally {}
              },
              onError: (e, s) {
                _onErr(e, s, chatId, 'TTS stream');
              },
            );

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

    _chatStreamSubs[chatId] = sub;
  } catch (e, s) {
    _loadingChatIds.value.remove(chatId);
    _loadingChatIds.notify();
    _onErr(e, s, chatId, 'Catch audio stream');
  }
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
          model: ChatCompletionModel.modelId(Cfg.current.model),
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

  final chatScopeUseMcp = workingChat.settings?.useTools != false;

  final availableMcp = await OpenAIFuncCalls.tools;
  final isMcpEmpty = availableMcp.isEmpty;

  if (mcpCompatible && chatScopeUseMcp && !isMcpEmpty) {
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
          final msg = await appResourcePool.withResource(() async {
            return await OpenAIFuncCalls.handle(
              mcpCall,
              (e, s) => _askMcpConfirm(context, e, s),
              onMcpLog,
            );
          });
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

        await titleCompleter?.future;
        await Future.delayed(const Duration(milliseconds: 300));
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
