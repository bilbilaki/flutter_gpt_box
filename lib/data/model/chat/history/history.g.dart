// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'history.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ChatHistory _$ChatHistoryFromJson(Map<String, dynamic> json) => ChatHistory(
  lastResponseId: json['lastResponseId'] as String?,
  items: (json['items'] as List<dynamic>)
      .map((e) => ChatHistoryItem.fromJson(e as Map<String, dynamic>))
      .toList(),
  id: json['id'] as String,
  name: json['name'] as String?,
  settings: json['settings'] == null
      ? null
      : ChatSettings.fromJson(json['settings'] as Map<String, dynamic>),
  isPinned: json['isPinned'] as bool?,
  colorIndicator: json['colorIndicator'] as String?,
  folderId: json['folderId'] as String?,
);

Map<String, dynamic> _$ChatHistoryToJson(ChatHistory instance) =>
    <String, dynamic>{
      'id': instance.id,
      'items': instance.items,
      'name': ?instance.name,
      'lastResponseId': ?instance.lastResponseId,
      'settings': ?instance.settings,
      'isPinned': ?instance.isPinned,
      'colorIndicator': ?instance.colorIndicator,
      'folderId': ?instance.folderId,
    };

ChatHistoryItem _$ChatHistoryItemFromJson(Map<String, dynamic> json) =>
    ChatHistoryItem(
      role: $enumDecode(_$ChatRoleEnumMap, json['role']),
      content: (json['content'] as List<dynamic>)
          .map((e) => ChatContent.fromJson(e as Map<String, dynamic>))
          .toList(),
      createdAt: DateTime.parse(json['createdAt'] as String),
      id: json['id'] as String,
      lastResponseId: json['lastResponseId'] as String?,
      toolCallId: json['toolCallId'] as String?,
      toolCalls: (json['toolCalls'] as List<dynamic>?)
          ?.map(
            (e) => ChatCompletionMessageToolCall.fromJson(
              e as Map<String, dynamic>,
            ),
          )
          .toList(),
      reasoning: json['reasoning'] as String?,
      inputTokens: (json['inputTokens'] as num?)?.toInt(),
      outputTokens: (json['outputTokens'] as num?)?.toInt(),
      totalTokens: (json['totalTokens'] as num?)?.toInt(),
      nanobenana: json['nanobenana'] as String?,
      translatedContent: json['translatedContent'] as String?,
      grammarFixedContent: json['grammarFixedContent'] as String?,
      autoTranslate: json['autoTranslate'] as bool?,
    );

Map<String, dynamic> _$ChatHistoryItemToJson(ChatHistoryItem instance) =>
    <String, dynamic>{
      'role': _$ChatRoleEnumMap[instance.role]!,
      'content': instance.content,
      'createdAt': instance.createdAt.toIso8601String(),
      'id': instance.id,
      'toolCallId': ?instance.toolCallId,
      'toolCalls': ?instance.toolCalls,
      'reasoning': ?instance.reasoning,
      'lastResponseId': ?instance.lastResponseId,
      'inputTokens': ?instance.inputTokens,
      'outputTokens': ?instance.outputTokens,
      'totalTokens': ?instance.totalTokens,
      'nanobenana': ?instance.nanobenana,
      'translatedContent': ?instance.translatedContent,
      'grammarFixedContent': ?instance.grammarFixedContent,
      'autoTranslate': ?instance.autoTranslate,
    };

const _$ChatRoleEnumMap = {
  ChatRole.user: 'user',
  ChatRole.assist: 'assist',
  ChatRole.system: 'system',
  ChatRole.tool: 'tool',
  ChatRole.ask: 'ask',
  ChatRole.developer: 'developer',
  ChatRole.jinjatemplate: 'jinjatemplate',
  ChatRole.embeddingstore: 'embeddingstore',
};

ChatContent _$ChatContentFromJson(Map<String, dynamic> json) => ChatContent(
  lastResponseId: json['lastResponseId'] as String?,
  type: $enumDecode(_$ChatContentTypeEnumMap, json['type']),
  raw: json['raw'] as String,
  id: json['id'] as String,
);

Map<String, dynamic> _$ChatContentToJson(ChatContent instance) =>
    <String, dynamic>{
      'type': _$ChatContentTypeEnumMap[instance.type]!,
      'lastResponseId': ?instance.lastResponseId,
      'raw': instance.raw,
      'id': instance.id,
    };

const _$ChatContentTypeEnumMap = {
  ChatContentType.text: 'text',
  ChatContentType.audio: 'audio',
  ChatContentType.image: 'image',
  ChatContentType.file: 'file',
  ChatContentType.nanobenana: 'nanobenana',
  ChatContentType.video: 'video',
  ChatContentType.embedded: 'embedded',
  ChatContentType.tts: 'tts',
  ChatContentType.stt: 'stt',
};

ChatSettings _$ChatSettingsFromJson(Map<String, dynamic> json) => ChatSettings(
  headTailMode: json['htm'] as bool?,
  useTools: json['ut'] as bool?,
  ignoreContextConstraint: json['icc'] as bool?,
);

Map<String, dynamic> _$ChatSettingsToJson(ChatSettings instance) =>
    <String, dynamic>{
      'htm': instance.headTailMode,
      'ut': instance.useTools,
      'icc': instance.ignoreContextConstraint,
    };
