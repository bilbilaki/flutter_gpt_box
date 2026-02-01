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
      lastResponseId: fields[11] as String?,
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
      ..writeByte(12)
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
      ..write(obj.nanobenana)
      ..writeByte(11)
      ..write(obj.lastResponseId);
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
      lastResponseId: fields[3] as String?,
      type: fields[0] as ChatContentType,
      raw: fields[1] as String,
      id: fields[2] as String,
    );
  }

  @override
  void write(BinaryWriter writer, ChatContent obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.type)
      ..writeByte(1)
      ..write(obj.raw)
      ..writeByte(2)
      ..write(obj.id)
      ..writeByte(3)
      ..write(obj.lastResponseId);
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
      case 4:
        return ChatRole.ask;
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
      case ChatRole.ask:
        writer.writeByte(4);
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
      lastResponseId: fields[10] as String?,
      items: (fields[1] as List).cast<ChatHistoryItem>(),
      id: fields[0] as String,
      name: fields[2] as String?,
      settings: fields[6] as ChatSettings?,
      isPinned: fields[7] as bool?,
      colorIndicator: fields[8] as String?,
      folderId: fields[9] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, ChatHistory obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.items)
      ..writeByte(2)
      ..write(obj.name)
      ..writeByte(6)
      ..write(obj.settings)
      ..writeByte(7)
      ..write(obj.isPinned)
      ..writeByte(8)
      ..write(obj.colorIndicator)
      ..writeByte(9)
      ..write(obj.folderId)
      ..writeByte(10)
      ..write(obj.lastResponseId);
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
      prompt: fields[25] == null ? '' : fields[25] as String,
      url: fields[26] == null
          ? 'https://api.openai.com/v1'
          : fields[26] as String,
      key: fields[27] == null ? '' : fields[27] as String,
      model: fields[28] == null ? '' : fields[28] as String,
      historyLen: fields[29] == null ? 7 : (fields[29] as num).toInt(),
      id: fields[30] == null ? 'defaultId' : fields[30] as String,
      name: fields[31] == null ? '' : fields[31] as String,
      useLocalModel: fields[53] == null ? false : fields[53] as bool,
      listAvaliableLocalModel: fields[54] == null
          ? []
          : (fields[54] as List).cast<String>(),
      selectedLocalModelName: fields[55] as String?,
      selectedLocalModelPath: fields[56] as String?,
      localModelsPath: fields[57] as String?,
      lastResponseId: fields[47] as String?,
      genTitlePrompt: fields[32] as String?,
      genTitleModel: fields[33] as String?,
      imgModel: fields[34] as String?,
      audioModel: fields[35] as String?,
      tskrModel: fields[36] as String?,
      altrModel: fields[37] as String?,
      wrkrModel: fields[38] as String?,
      trnscrbModel: fields[39] as String?,
      defaultTranslateLanguage: fields[40] as String?,
      file: fields[41] as String?,
      image: fields[42] as String?,
      audio: fields[43] as String?,
      isVertex: fields[44] as bool?,
      vertexProjectId: fields[45] as String?,
      vertexLocation: fields[46] as String?,
      usingResponseAPI: fields[52] == null ? false : fields[52] as bool,
      proxyHost: fields[48] == null ? '' : fields[48] as String,
      proxyPort: fields[49] == null ? 0 : (fields[49] as num).toInt(),
      proxyType: fields[50] == null ? 'http' : fields[50] as String,
      proxyEnabled: fields[51] == null ? false : fields[51] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, ChatConfig obj) {
    writer
      ..writeByte(33)
      ..writeByte(25)
      ..write(obj.prompt)
      ..writeByte(26)
      ..write(obj.url)
      ..writeByte(27)
      ..write(obj.key)
      ..writeByte(28)
      ..write(obj.model)
      ..writeByte(29)
      ..write(obj.historyLen)
      ..writeByte(30)
      ..write(obj.id)
      ..writeByte(31)
      ..write(obj.name)
      ..writeByte(32)
      ..write(obj.genTitlePrompt)
      ..writeByte(33)
      ..write(obj.genTitleModel)
      ..writeByte(34)
      ..write(obj.imgModel)
      ..writeByte(35)
      ..write(obj.audioModel)
      ..writeByte(36)
      ..write(obj.tskrModel)
      ..writeByte(37)
      ..write(obj.altrModel)
      ..writeByte(38)
      ..write(obj.wrkrModel)
      ..writeByte(39)
      ..write(obj.trnscrbModel)
      ..writeByte(40)
      ..write(obj.defaultTranslateLanguage)
      ..writeByte(41)
      ..write(obj.file)
      ..writeByte(42)
      ..write(obj.image)
      ..writeByte(43)
      ..write(obj.audio)
      ..writeByte(44)
      ..write(obj.isVertex)
      ..writeByte(45)
      ..write(obj.vertexProjectId)
      ..writeByte(46)
      ..write(obj.vertexLocation)
      ..writeByte(47)
      ..write(obj.lastResponseId)
      ..writeByte(48)
      ..write(obj.proxyHost)
      ..writeByte(49)
      ..write(obj.proxyPort)
      ..writeByte(50)
      ..write(obj.proxyType)
      ..writeByte(51)
      ..write(obj.proxyEnabled)
      ..writeByte(52)
      ..write(obj.usingResponseAPI)
      ..writeByte(53)
      ..write(obj.useLocalModel)
      ..writeByte(54)
      ..write(obj.listAvaliableLocalModel)
      ..writeByte(55)
      ..write(obj.selectedLocalModelName)
      ..writeByte(56)
      ..write(obj.selectedLocalModelPath)
      ..writeByte(57)
      ..write(obj.localModelsPath);
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

class DownloadItemAdapter extends TypeAdapter<DownloadItem> {
  @override
  final typeId = 20;

  @override
  DownloadItem read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DownloadItem(
      taskId: fields[0] as String,
      url: fields[1] as String?,
      filename: fields[2] as String?,
      savedPath: fields[3] as String?,
      status: fields[4] as DownloadUiStatus?,
      progress: (fields[5] as num?)?.toDouble(),
      expectedFileSize: (fields[6] as num?)?.toInt(),
      networkSpeedBytesPerSec: (fields[7] as num?)?.toDouble(),
      timeRemainingSeconds: (fields[8] as num?)?.toInt(),
      group: fields[9] as String?,
      openAfterComplete: fields[10] as bool?,
      createdAt: fields[11] as DateTime?,
      finishedAt: fields[12] as DateTime?,
      displayName: fields[13] as String?,
      metaData: fields[14] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, DownloadItem obj) {
    writer
      ..writeByte(15)
      ..writeByte(0)
      ..write(obj.taskId)
      ..writeByte(1)
      ..write(obj.url)
      ..writeByte(2)
      ..write(obj.filename)
      ..writeByte(3)
      ..write(obj.savedPath)
      ..writeByte(4)
      ..write(obj.status)
      ..writeByte(5)
      ..write(obj.progress)
      ..writeByte(6)
      ..write(obj.expectedFileSize)
      ..writeByte(7)
      ..write(obj.networkSpeedBytesPerSec)
      ..writeByte(8)
      ..write(obj.timeRemainingSeconds)
      ..writeByte(9)
      ..write(obj.group)
      ..writeByte(10)
      ..write(obj.openAfterComplete)
      ..writeByte(11)
      ..write(obj.createdAt)
      ..writeByte(12)
      ..write(obj.finishedAt)
      ..writeByte(13)
      ..write(obj.displayName)
      ..writeByte(14)
      ..write(obj.metaData);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DownloadItemAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ChatFolderAdapter extends TypeAdapter<ChatFolder> {
  @override
  final typeId = 21;

  @override
  ChatFolder read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ChatFolder(
      id: fields[0] as String,
      name: fields[1] as String,
      colorIndicator: fields[2] as String?,
      isExpanded: fields[3] as bool?,
    );
  }

  @override
  void write(BinaryWriter writer, ChatFolder obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.colorIndicator)
      ..writeByte(3)
      ..write(obj.isExpanded);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChatFolderAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
