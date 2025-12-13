import 'dart:convert';
import 'dart:io';

import 'package:equatable/equatable.dart';
import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:gpt_box/data/res/l10n.dart';
import 'package:gpt_box/data/res/url.dart';
import 'package:gpt_box/data/store/all.dart';
import 'package:openai_dart/openai_dart.dart';
import 'package:shortid/shortid.dart';

part 'history.g.dart';
part 'history.ext.dart';

@JsonSerializable()
final class ChatHistory {
  final String id;
  final List<ChatHistoryItem> items;
  @JsonKey(includeIfNull: false)
  final String? name;
  @JsonKey(includeIfNull: false)
  final ChatSettings? settings;
  @JsonKey(includeIfNull: false)
  final bool? isPinned;
  @JsonKey(includeIfNull: false)
  final String? colorIndicator;
  @JsonKey(includeIfNull: false)
  final String? folderId;

  ChatHistory({
    required this.items,
    required this.id,
    this.name,
    this.settings,
    this.isPinned,
    this.colorIndicator,
    this.folderId,
  });

  ChatHistory.noid({
    required this.items,
    this.name,
    this.settings,
    this.isPinned,
    this.colorIndicator,
    this.folderId,
  }) : id = shortid.generate();

  factory ChatHistory.fromJson(Map<String, dynamic> json) =>
      _$ChatHistoryFromJson(json);

  Map<String, dynamic> toJson() => _$ChatHistoryToJson(this);

  /// Returns the last modified time of the history.
  DateTime? get lastTime {
    if (items.isEmpty) return null;
    var last = items.first.createdAt;
    for (final item in items) {
      if (item.createdAt.isAfter(last)) {
        last = item.createdAt;
      }
    }
    return last;
  }

  @override
  String toString() => 'ChatHistory($id, $name, $lastTime)';
}

@JsonSerializable()
final class ChatHistoryItem {
  final ChatRole role;
  final List<ChatContent> content;
  final DateTime createdAt;
  final String id;
  @JsonKey(includeIfNull: false)
  final String? toolCallId;
  @JsonKey(includeIfNull: false)
  final List<ChatCompletionMessageToolCall>? toolCalls;
  @JsonKey(includeIfNull: false)
  String? reasoning;
  @JsonKey(includeIfNull: false)
  final int? inputTokens; // New parameter for input token count
  @JsonKey(includeIfNull: false)
  final int? outputTokens; // New parameter for output token count
  @JsonKey(includeIfNull: false)
  final int? totalTokens; // New parameter for total token count
  @JsonKey(includeIfNull: false)
  final String? nanobenana;
  ChatHistoryItem({
    required this.role,
    required this.content,
    required this.createdAt,
    required this.id,
    this.toolCallId,
    this.toolCalls,
    this.reasoning,
    this.inputTokens, // Initialize new parameter
    this.outputTokens, // Initialize new parameter
    this.totalTokens,
    this.nanobenana, // Initialize new parameter
  });

  ChatHistoryItem.gen({
    required this.role,
    required this.content,
    this.toolCallId,
    this.toolCalls,
    this.reasoning,
    this.inputTokens, // Initialize new parameter
    this.outputTokens, // Initialize new parameter
    this.totalTokens, // Initialize new parameter
    this.nanobenana,
  }) : createdAt = DateTime.now(),
       id = shortid.generate();

  ChatHistoryItem.single({
    required this.role,
    String raw = '',
    ChatContentType type = ChatContentType.text,
    DateTime? createdAt,
    this.toolCallId,
    this.toolCalls,
    this.reasoning,
    this.inputTokens, // Initialize new parameter
    this.outputTokens, // Initialize new parameter
    this.totalTokens,
    this.nanobenana, // Initialize new parameter
  }) : content = [ChatContent.noid(type: type, raw: raw)],
       createdAt = createdAt ?? DateTime.now(),
       id = shortid.generate();

  factory ChatHistoryItem.fromJson(Map<String, dynamic> json) =>
      _$ChatHistoryItemFromJson(json);

  Map<String, dynamic> toJson() => _$ChatHistoryItemToJson(this);

  @override
  String toString() {
    return 'ChatHistoryItem($role, $content, $createdAt)';
  }
}

/// Handle [audio] and [image] as url (/path & https://) or base64
@JsonEnum()
enum ChatContentType {
  text,
  audio,
  image,
  file,
  nanobenana;

  bool get isText => this == text;
  bool get isAudio => this == audio;
  bool get isImage => this == image;
  bool get isFile => this == file;
  bool get isNanoBenana => this == nanobenana;
}

@JsonSerializable()
final class ChatContent with EquatableMixin {
  final ChatContentType type;

  late final String raw;
  @Default('')
  final String id;

  ChatContent({required this.type, required this.raw, required String id})
    : id = id.isEmpty ? shortid.generate() : id;
  ChatContent.noid({required this.type, required this.raw})
    : id = shortid.generate();
  ChatContent.text(this.raw)
    : type = ChatContentType.text,
      id = shortid.generate();
  ChatContent.audio(this.raw)
    : type = ChatContentType.audio,
      id = shortid.generate();
  ChatContent.image(this.raw)
    : type = ChatContentType.image,
      id = shortid.generate();
  ChatContent.file(this.raw)
    : type = ChatContentType.file,
      id = shortid.generate();
  ChatContent.nanobenana(this.raw)
    : type = ChatContentType.nanobenana,
      id = shortid.generate();

  factory ChatContent.fromJson(Map<String, dynamic> json) =>
      _$ChatContentFromJson(json);

  Map<String, dynamic> toJson() => _$ChatContentToJson(this);

  @override
  List<Object?> get props => [type, raw, id];
}

@JsonEnum()
enum ChatRole {
  user,
  assist,
  system,
  tool,
  ask;

  bool get isUser => this == user;
  bool get isAssist => this == assist;
  bool get isSystem => this == system;
  bool get isTool => this == tool;
  bool get isAsk => this == ask;

  String get localized => switch (this) {
    user => Stores.setting.avatar.get(),
    assist => '🤖',
    system => '⚙️',
    tool => '🛠️',
    ask => '🤖🛠️',
  };

  Color get color {
    final c = switch (this) {
      user => UIs.primaryColor,
      assist => UIs.primaryColor.withBlue(233),
      system => UIs.primaryColor.withRed(233),
      tool => UIs.primaryColor.withBlue(33),
      ask => UIs.primaryColor.withBlue(300),
    };
    return c.withValues(alpha: 0.6);
  }

  static ChatRole? fromString(String? val) => switch (val) {
    'assistant' => assist,
    _ => values.firstWhereOrNull((p0) => p0.name == val),
  };
}

@JsonSerializable()
final class ChatSettings {
  @JsonKey(name: 'htm')
  final bool headTailMode;

  @JsonKey(name: 'ut')
  final bool useTools;

  @JsonKey(name: 'icc')
  final bool ignoreContextConstraint;

  /// Use this constrctor pattern to avoid null value as the [ChatSettings]'s
  /// properties are changing frequently.
  const ChatSettings({
    bool? headTailMode,
    bool? useTools,
    bool? ignoreContextConstraint,
  }) : headTailMode = headTailMode ?? false,
       useTools = useTools ?? true,
       ignoreContextConstraint = ignoreContextConstraint ?? false;

  ChatSettings copyWith({
    bool? headTailMode,
    bool? useTools,
    bool? ignoreContextConstraint,
  }) {
    return ChatSettings(
      headTailMode: headTailMode ?? this.headTailMode,
      useTools: useTools ?? this.useTools,
      ignoreContextConstraint:
          ignoreContextConstraint ?? this.ignoreContextConstraint,
    );
  }

  @override
  String toString() => 'ChatSettings($hashCode)';

  factory ChatSettings.fromJson(Map<String, dynamic> json) =>
      _$ChatSettingsFromJson(json);

  Map<String, dynamic> toJson() => _$ChatSettingsToJson(this);
}
