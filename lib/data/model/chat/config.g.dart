// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'config.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ChatConfig _$ChatConfigFromJson(Map<String, dynamic> json) => _ChatConfig(
  prompt: json['prompt'] as String? ?? '',
  url: json['url'] as String? ?? ChatConfigX.defaultUrl,
  key: json['key'] as String? ?? '',
  model: json['model'] as String? ?? '',
  historyLen:
      (json['historyLen'] as num?)?.toInt() ?? ChatConfigX.defaultHistoryLen,
  id: json['id'] as String? ?? ChatConfigX.defaultId,
  name: json['name'] as String? ?? '',
  genTitlePrompt: json['genTitlePrompt'] as String?,
  genTitleModel: json['genTitleModel'] as String?,
  imgModel: json['imgModel'] as String?,
  audioModel: json['audioModel'] as String?,
  tskrModel: json['tskrModel'] as String?,
  altrModel: json['altrModel'] as String?,
  wrkrModel: json['wrkrModel'] as String?,
  trnscrbModel: json['trnscrbModel'] as String?,
  defaultTranslateLanguage: json['defaultTranslateLanguage'] as String?,
  file: json['file'] as String?,
  image: json['image'] as String?,
  audio: json['audio'] as String?,
  isVertex: json['isVertex'] as bool?,
  vertexProjectId: json['vertexProjectId'] as String?,
  vertexLocation: json['vertexLocation'] as String?,
);

Map<String, dynamic> _$ChatConfigToJson(_ChatConfig instance) =>
    <String, dynamic>{
      'prompt': instance.prompt,
      'url': instance.url,
      'key': instance.key,
      'model': instance.model,
      'historyLen': instance.historyLen,
      'id': instance.id,
      'name': instance.name,
      'genTitlePrompt': instance.genTitlePrompt,
      'genTitleModel': instance.genTitleModel,
      'imgModel': instance.imgModel,
      'audioModel': instance.audioModel,
      'tskrModel': instance.tskrModel,
      'altrModel': instance.altrModel,
      'wrkrModel': instance.wrkrModel,
      'trnscrbModel': instance.trnscrbModel,
      'defaultTranslateLanguage': instance.defaultTranslateLanguage,
      'file': instance.file,
      'image': instance.image,
      'audio': instance.audio,
      'isVertex': instance.isVertex,
      'vertexProjectId': instance.vertexProjectId,
      'vertexLocation': instance.vertexLocation,
    };
