// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'hive_adapters.dart';

// **************************************************************************
// AdaptersGenerator
// **************************************************************************

class ChatHistoryItemAdapter extends TypeAdapter<ChatHistoryItem> {
  @override
  final typeId = 0;

  @override
  ChatHistoryItem read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ChatHistoryItem(
      role: fields[0] as ChatRole,
      content: (fields[1] as List).cast<ChatContent>(),
      createdAt: fields[2] as DateTime,
      id: fields[3] as String,
      toolCallId: fields[4] as String?,
      toolCalls: (fields[5] as List?)?.cast<ChatCompletionMessageToolCall>(),
      reasoning: fields[6] as String?,
      inputTokens: (fields[7] as num?)?.toInt(),
      outputTokens: (fields[8] as num?)?.toInt(),
      totalTokens: (fields[9] as num?)?.toInt(),
      nanobenana: fields[10] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, ChatHistoryItem obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.role)
      ..writeByte(1)
      ..write(obj.content)
      ..writeByte(2)
      ..write(obj.createdAt)
      ..writeByte(3)
      ..write(obj.id)
      ..writeByte(4)
      ..write(obj.toolCallId)
      ..writeByte(5)
      ..write(obj.toolCalls)
      ..writeByte(6)
      ..write(obj.reasoning)
      ..writeByte(7)
      ..write(obj.inputTokens)
      ..writeByte(8)
      ..write(obj.outputTokens)
      ..writeByte(9)
      ..write(obj.totalTokens)
      ..writeByte(10)
      ..write(obj.nanobenana);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChatHistoryItemAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ChatContentTypeAdapter extends TypeAdapter<ChatContentType> {
  @override
  final typeId = 1;

  @override
  ChatContentType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return ChatContentType.text;
      case 1:
        return ChatContentType.audio;
      case 2:
        return ChatContentType.image;
      case 3:
        return ChatContentType.file;
      case 4:
        return ChatContentType.nanobenana;
      default:
        return ChatContentType.text;
    }
  }

  @override
  void write(BinaryWriter writer, ChatContentType obj) {
    switch (obj) {
      case ChatContentType.text:
        writer.writeByte(0);
      case ChatContentType.audio:
        writer.writeByte(1);
      case ChatContentType.image:
        writer.writeByte(2);
      case ChatContentType.file:
        writer.writeByte(3);
      case ChatContentType.nanobenana:
        writer.writeByte(4);
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChatContentTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ChatContentAdapter extends TypeAdapter<ChatContent> {
  @override
  final typeId = 2;

  @override
  ChatContent read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ChatContent(
      type: fields[0] as ChatContentType,
      raw: fields[1] as String,
      id: fields[2] as String,
    );
  }

  @override
  void write(BinaryWriter writer, ChatContent obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.type)
      ..writeByte(1)
      ..write(obj.raw)
      ..writeByte(2)
      ..write(obj.id);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChatContentAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ChatRoleAdapter extends TypeAdapter<ChatRole> {
  @override
  final typeId = 3;

  @override
  ChatRole read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return ChatRole.user;
      case 1:
        return ChatRole.assist;
      case 2:
        return ChatRole.system;
      case 3:
        return ChatRole.tool;
      default:
        return ChatRole.user;
    }
  }

  @override
  void write(BinaryWriter writer, ChatRole obj) {
    switch (obj) {
      case ChatRole.user:
        writer.writeByte(0);
      case ChatRole.assist:
        writer.writeByte(1);
      case ChatRole.system:
        writer.writeByte(2);
      case ChatRole.tool:
        writer.writeByte(3);
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChatRoleAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ChatHistoryAdapter extends TypeAdapter<ChatHistory> {
  @override
  final typeId = 5;

  @override
  ChatHistory read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ChatHistory(
      items: (fields[1] as List).cast<ChatHistoryItem>(),
      id: fields[0] as String,
      name: fields[2] as String?,
      settings: fields[6] as ChatSettings?,
    );
  }

  @override
  void write(BinaryWriter writer, ChatHistory obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.items)
      ..writeByte(2)
      ..write(obj.name)
      ..writeByte(6)
      ..write(obj.settings);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChatHistoryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ChatConfigAdapter extends TypeAdapter<ChatConfig> {
  @override
  final typeId = 6;

  @override
  ChatConfig read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ChatConfig(
      prompt: fields[0] == null ? '' : fields[0] as String,
      url: fields[1] == null
          ? 'https://api.openai.com/v1'
          : fields[1] as String,
      key: fields[2] == null ? '' : fields[2] as String,
      model: fields[3] == null ? '' : fields[3] as String,
      historyLen: fields[7] == null ? 7 : (fields[7] as num).toInt(),
      id: fields[8] == null ? 'defaultId' : fields[8] as String,
      name: fields[9] == null ? '' : fields[9] as String,
      genTitlePrompt: fields[14] as String?,
      genTitleModel: fields[15] as String?,
      imgModel: fields[16] as String?,
      file: fields[17] as String?,
      image: fields[18] as String?,
      audio: fields[19] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, ChatConfig obj) {
    writer
      ..writeByte(13)
      ..writeByte(0)
      ..write(obj.prompt)
      ..writeByte(1)
      ..write(obj.url)
      ..writeByte(2)
      ..write(obj.key)
      ..writeByte(3)
      ..write(obj.model)
      ..writeByte(7)
      ..write(obj.historyLen)
      ..writeByte(8)
      ..write(obj.id)
      ..writeByte(9)
      ..write(obj.name)
      ..writeByte(14)
      ..write(obj.genTitlePrompt)
      ..writeByte(15)
      ..write(obj.genTitleModel)
      ..writeByte(16)
      ..write(obj.imgModel)
      ..writeByte(17)
      ..write(obj.file)
      ..writeByte(18)
      ..write(obj.image)
      ..writeByte(19)
      ..write(obj.audio);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChatConfigAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ChatTypeAdapter extends TypeAdapter<ChatType> {
  @override
  final typeId = 7;

  @override
  ChatType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return ChatType.text;
      case 1:
        return ChatType.img;
      case 2:
        return ChatType.audio;
      case 3:
        return ChatType.voice;
      case 4:
        return ChatType.voicejustin;
      case 5:
        return ChatType.autoenglishtrans;
      default:
        return ChatType.text;
    }
  }

  @override
  void write(BinaryWriter writer, ChatType obj) {
    switch (obj) {
      case ChatType.text:
        writer.writeByte(0);
      case ChatType.img:
        writer.writeByte(1);
      case ChatType.audio:
        writer.writeByte(2);
      case ChatType.voice:
        writer.writeByte(3);
      case ChatType.voicejustin:
        writer.writeByte(4);
      case ChatType.autoenglishtrans:
        writer.writeByte(5);
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChatTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ChatSettingsAdapter extends TypeAdapter<ChatSettings> {
  @override
  final typeId = 8;

  @override
  ChatSettings read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ChatSettings(
      headTailMode: fields[0] as bool?,
      useTools: fields[1] as bool?,
      ignoreContextConstraint: fields[2] as bool?,
    );
  }

  @override
  void write(BinaryWriter writer, ChatSettings obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.headTailMode)
      ..writeByte(1)
      ..write(obj.useTools)
      ..writeByte(2)
      ..write(obj.ignoreContextConstraint);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChatSettingsAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class DownloadTaskAdapter extends TypeAdapter<DownloadTask> {
  @override
  final typeId = 11;

  @override
  DownloadTask read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DownloadTask(
      id: fields[0] == null ? '' : fields[0] as String,
      url: fields[1] as String,
      urlQueryParameters: fields[2] == null
          ? {}
          : (fields[2] as Map).cast<String, String>(),
      filename: fields[3] == null ? '' : fields[3] as String,
      headers: fields[4] == null
          ? {}
          : (fields[4] as Map).cast<String, String>(),
      directory: fields[5] == null ? '' : fields[5] as String,
      updates: fields[6] == null
          ? Updates.statusAndProgress
          : fields[6] as Updates,
      requiresWiFi: fields[7] == null ? false : fields[7] as bool,
      retries: fields[8] == null ? 0 : (fields[8] as num).toInt(),
      allowPause: fields[9] == null ? false : fields[9] as bool,
      metaData: fields[10] as String?,
      createdAt: fields[11] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, DownloadTask obj) {
    writer
      ..writeByte(12)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.url)
      ..writeByte(2)
      ..write(obj.urlQueryParameters)
      ..writeByte(3)
      ..write(obj.filename)
      ..writeByte(4)
      ..write(obj.headers)
      ..writeByte(5)
      ..write(obj.directory)
      ..writeByte(6)
      ..write(obj.updates)
      ..writeByte(7)
      ..write(obj.requiresWiFi)
      ..writeByte(8)
      ..write(obj.retries)
      ..writeByte(9)
      ..write(obj.allowPause)
      ..writeByte(10)
      ..write(obj.metaData)
      ..writeByte(11)
      ..write(obj.createdAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DownloadTaskAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class UpdatesAdapter extends TypeAdapter<Updates> {
  @override
  final typeId = 12;

  @override
  Updates read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return Updates.none;
      case 1:
        return Updates.status;
      case 2:
        return Updates.statusAndProgress;
      default:
        return Updates.none;
    }
  }

  @override
  void write(BinaryWriter writer, Updates obj) {
    switch (obj) {
      case Updates.none:
        writer.writeByte(0);
      case Updates.status:
        writer.writeByte(1);
      case Updates.statusAndProgress:
        writer.writeByte(2);
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UpdatesAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class TaskStatusAdapter extends TypeAdapter<TaskStatus> {
  @override
  final typeId = 13;

  @override
  TaskStatus read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return TaskStatus.queued;
      case 1:
        return TaskStatus.running;
      case 2:
        return TaskStatus.paused;
      case 3:
        return TaskStatus.complete;
      case 4:
        return TaskStatus.canceled;
      case 5:
        return TaskStatus.failed;
      default:
        return TaskStatus.queued;
    }
  }

  @override
  void write(BinaryWriter writer, TaskStatus obj) {
    switch (obj) {
      case TaskStatus.queued:
        writer.writeByte(0);
      case TaskStatus.running:
        writer.writeByte(1);
      case TaskStatus.paused:
        writer.writeByte(2);
      case TaskStatus.complete:
        writer.writeByte(3);
      case TaskStatus.canceled:
        writer.writeByte(4);
      case TaskStatus.failed:
        writer.writeByte(5);
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TaskStatusAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
