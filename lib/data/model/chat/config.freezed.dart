// dart format width=80
// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'config.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ChatConfig {

 String get prompt; String get url; String get key; String get model; int get historyLen; String get id; String get name; String? get genTitlePrompt; String? get genTitleModel; String? get imgModel; String? get audioModel; String? get tskrModel; String? get altrModel; String? get wrkrModel; String? get trnscrbModel; String? get defaultTranslateLanguage;// Newly added nullable fields
 String? get file; String? get image; String? get audio; bool? get isVertex; String? get vertexProjectId; String? get vertexLocation;
/// Create a copy of ChatConfig
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ChatConfigCopyWith<ChatConfig> get copyWith => _$ChatConfigCopyWithImpl<ChatConfig>(this as ChatConfig, _$identity);

  /// Serializes this ChatConfig to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ChatConfig&&(identical(other.prompt, prompt) || other.prompt == prompt)&&(identical(other.url, url) || other.url == url)&&(identical(other.key, key) || other.key == key)&&(identical(other.model, model) || other.model == model)&&(identical(other.historyLen, historyLen) || other.historyLen == historyLen)&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.genTitlePrompt, genTitlePrompt) || other.genTitlePrompt == genTitlePrompt)&&(identical(other.genTitleModel, genTitleModel) || other.genTitleModel == genTitleModel)&&(identical(other.imgModel, imgModel) || other.imgModel == imgModel)&&(identical(other.audioModel, audioModel) || other.audioModel == audioModel)&&(identical(other.tskrModel, tskrModel) || other.tskrModel == tskrModel)&&(identical(other.altrModel, altrModel) || other.altrModel == altrModel)&&(identical(other.wrkrModel, wrkrModel) || other.wrkrModel == wrkrModel)&&(identical(other.trnscrbModel, trnscrbModel) || other.trnscrbModel == trnscrbModel)&&(identical(other.defaultTranslateLanguage, defaultTranslateLanguage) || other.defaultTranslateLanguage == defaultTranslateLanguage)&&(identical(other.file, file) || other.file == file)&&(identical(other.image, image) || other.image == image)&&(identical(other.audio, audio) || other.audio == audio)&&(identical(other.isVertex, isVertex) || other.isVertex == isVertex)&&(identical(other.vertexProjectId, vertexProjectId) || other.vertexProjectId == vertexProjectId)&&(identical(other.vertexLocation, vertexLocation) || other.vertexLocation == vertexLocation));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,prompt,url,key,model,historyLen,id,name,genTitlePrompt,genTitleModel,imgModel,audioModel,tskrModel,altrModel,wrkrModel,trnscrbModel,defaultTranslateLanguage,file,image,audio,isVertex,vertexProjectId,vertexLocation]);



}

/// @nodoc
abstract mixin class $ChatConfigCopyWith<$Res>  {
  factory $ChatConfigCopyWith(ChatConfig value, $Res Function(ChatConfig) _then) = _$ChatConfigCopyWithImpl;
@useResult
$Res call({
 String prompt, String url, String key, String model, int historyLen, String id, String name, String? genTitlePrompt, String? genTitleModel, String? imgModel, String? audioModel, String? tskrModel, String? altrModel, String? wrkrModel, String? trnscrbModel, String? defaultTranslateLanguage, String? file, String? image, String? audio, bool? isVertex, String? vertexProjectId, String? vertexLocation
});




}
/// @nodoc
class _$ChatConfigCopyWithImpl<$Res>
    implements $ChatConfigCopyWith<$Res> {
  _$ChatConfigCopyWithImpl(this._self, this._then);

  final ChatConfig _self;
  final $Res Function(ChatConfig) _then;

/// Create a copy of ChatConfig
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? prompt = null,Object? url = null,Object? key = null,Object? model = null,Object? historyLen = null,Object? id = null,Object? name = null,Object? genTitlePrompt = freezed,Object? genTitleModel = freezed,Object? imgModel = freezed,Object? audioModel = freezed,Object? tskrModel = freezed,Object? altrModel = freezed,Object? wrkrModel = freezed,Object? trnscrbModel = freezed,Object? defaultTranslateLanguage = freezed,Object? file = freezed,Object? image = freezed,Object? audio = freezed,Object? isVertex = freezed,Object? vertexProjectId = freezed,Object? vertexLocation = freezed,}) {
  return _then(_self.copyWith(
prompt: null == prompt ? _self.prompt : prompt // ignore: cast_nullable_to_non_nullable
as String,url: null == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String,key: null == key ? _self.key : key // ignore: cast_nullable_to_non_nullable
as String,model: null == model ? _self.model : model // ignore: cast_nullable_to_non_nullable
as String,historyLen: null == historyLen ? _self.historyLen : historyLen // ignore: cast_nullable_to_non_nullable
as int,id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,genTitlePrompt: freezed == genTitlePrompt ? _self.genTitlePrompt : genTitlePrompt // ignore: cast_nullable_to_non_nullable
as String?,genTitleModel: freezed == genTitleModel ? _self.genTitleModel : genTitleModel // ignore: cast_nullable_to_non_nullable
as String?,imgModel: freezed == imgModel ? _self.imgModel : imgModel // ignore: cast_nullable_to_non_nullable
as String?,audioModel: freezed == audioModel ? _self.audioModel : audioModel // ignore: cast_nullable_to_non_nullable
as String?,tskrModel: freezed == tskrModel ? _self.tskrModel : tskrModel // ignore: cast_nullable_to_non_nullable
as String?,altrModel: freezed == altrModel ? _self.altrModel : altrModel // ignore: cast_nullable_to_non_nullable
as String?,wrkrModel: freezed == wrkrModel ? _self.wrkrModel : wrkrModel // ignore: cast_nullable_to_non_nullable
as String?,trnscrbModel: freezed == trnscrbModel ? _self.trnscrbModel : trnscrbModel // ignore: cast_nullable_to_non_nullable
as String?,defaultTranslateLanguage: freezed == defaultTranslateLanguage ? _self.defaultTranslateLanguage : defaultTranslateLanguage // ignore: cast_nullable_to_non_nullable
as String?,file: freezed == file ? _self.file : file // ignore: cast_nullable_to_non_nullable
as String?,image: freezed == image ? _self.image : image // ignore: cast_nullable_to_non_nullable
as String?,audio: freezed == audio ? _self.audio : audio // ignore: cast_nullable_to_non_nullable
as String?,isVertex: freezed == isVertex ? _self.isVertex : isVertex // ignore: cast_nullable_to_non_nullable
as bool?,vertexProjectId: freezed == vertexProjectId ? _self.vertexProjectId : vertexProjectId // ignore: cast_nullable_to_non_nullable
as String?,vertexLocation: freezed == vertexLocation ? _self.vertexLocation : vertexLocation // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// @nodoc
@JsonSerializable()

class _ChatConfig extends ChatConfig {
  const _ChatConfig({this.prompt = '', this.url = ChatConfigX.defaultUrl, this.key = '', this.model = '', this.historyLen = ChatConfigX.defaultHistoryLen, this.id = ChatConfigX.defaultId, this.name = '', this.genTitlePrompt, this.genTitleModel, this.imgModel, this.audioModel, this.tskrModel, this.altrModel, this.wrkrModel, this.trnscrbModel, this.defaultTranslateLanguage, this.file, this.image, this.audio, this.isVertex, this.vertexProjectId, this.vertexLocation}): super._();
  factory _ChatConfig.fromJson(Map<String, dynamic> json) => _$ChatConfigFromJson(json);

@override@JsonKey() final  String prompt;
@override@JsonKey() final  String url;
@override@JsonKey() final  String key;
@override@JsonKey() final  String model;
@override@JsonKey() final  int historyLen;
@override@JsonKey() final  String id;
@override@JsonKey() final  String name;
@override final  String? genTitlePrompt;
@override final  String? genTitleModel;
@override final  String? imgModel;
@override final  String? audioModel;
@override final  String? tskrModel;
@override final  String? altrModel;
@override final  String? wrkrModel;
@override final  String? trnscrbModel;
@override final  String? defaultTranslateLanguage;
// Newly added nullable fields
@override final  String? file;
@override final  String? image;
@override final  String? audio;
@override final  bool? isVertex;
@override final  String? vertexProjectId;
@override final  String? vertexLocation;

/// Create a copy of ChatConfig
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ChatConfigCopyWith<_ChatConfig> get copyWith => __$ChatConfigCopyWithImpl<_ChatConfig>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ChatConfigToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ChatConfig&&(identical(other.prompt, prompt) || other.prompt == prompt)&&(identical(other.url, url) || other.url == url)&&(identical(other.key, key) || other.key == key)&&(identical(other.model, model) || other.model == model)&&(identical(other.historyLen, historyLen) || other.historyLen == historyLen)&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.genTitlePrompt, genTitlePrompt) || other.genTitlePrompt == genTitlePrompt)&&(identical(other.genTitleModel, genTitleModel) || other.genTitleModel == genTitleModel)&&(identical(other.imgModel, imgModel) || other.imgModel == imgModel)&&(identical(other.audioModel, audioModel) || other.audioModel == audioModel)&&(identical(other.tskrModel, tskrModel) || other.tskrModel == tskrModel)&&(identical(other.altrModel, altrModel) || other.altrModel == altrModel)&&(identical(other.wrkrModel, wrkrModel) || other.wrkrModel == wrkrModel)&&(identical(other.trnscrbModel, trnscrbModel) || other.trnscrbModel == trnscrbModel)&&(identical(other.defaultTranslateLanguage, defaultTranslateLanguage) || other.defaultTranslateLanguage == defaultTranslateLanguage)&&(identical(other.file, file) || other.file == file)&&(identical(other.image, image) || other.image == image)&&(identical(other.audio, audio) || other.audio == audio)&&(identical(other.isVertex, isVertex) || other.isVertex == isVertex)&&(identical(other.vertexProjectId, vertexProjectId) || other.vertexProjectId == vertexProjectId)&&(identical(other.vertexLocation, vertexLocation) || other.vertexLocation == vertexLocation));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,prompt,url,key,model,historyLen,id,name,genTitlePrompt,genTitleModel,imgModel,audioModel,tskrModel,altrModel,wrkrModel,trnscrbModel,defaultTranslateLanguage,file,image,audio,isVertex,vertexProjectId,vertexLocation]);



}

/// @nodoc
abstract mixin class _$ChatConfigCopyWith<$Res> implements $ChatConfigCopyWith<$Res> {
  factory _$ChatConfigCopyWith(_ChatConfig value, $Res Function(_ChatConfig) _then) = __$ChatConfigCopyWithImpl;
@override @useResult
$Res call({
 String prompt, String url, String key, String model, int historyLen, String id, String name, String? genTitlePrompt, String? genTitleModel, String? imgModel, String? audioModel, String? tskrModel, String? altrModel, String? wrkrModel, String? trnscrbModel, String? defaultTranslateLanguage, String? file, String? image, String? audio, bool? isVertex, String? vertexProjectId, String? vertexLocation
});




}
/// @nodoc
class __$ChatConfigCopyWithImpl<$Res>
    implements _$ChatConfigCopyWith<$Res> {
  __$ChatConfigCopyWithImpl(this._self, this._then);

  final _ChatConfig _self;
  final $Res Function(_ChatConfig) _then;

/// Create a copy of ChatConfig
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? prompt = null,Object? url = null,Object? key = null,Object? model = null,Object? historyLen = null,Object? id = null,Object? name = null,Object? genTitlePrompt = freezed,Object? genTitleModel = freezed,Object? imgModel = freezed,Object? audioModel = freezed,Object? tskrModel = freezed,Object? altrModel = freezed,Object? wrkrModel = freezed,Object? trnscrbModel = freezed,Object? defaultTranslateLanguage = freezed,Object? file = freezed,Object? image = freezed,Object? audio = freezed,Object? isVertex = freezed,Object? vertexProjectId = freezed,Object? vertexLocation = freezed,}) {
  return _then(_ChatConfig(
prompt: null == prompt ? _self.prompt : prompt // ignore: cast_nullable_to_non_nullable
as String,url: null == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String,key: null == key ? _self.key : key // ignore: cast_nullable_to_non_nullable
as String,model: null == model ? _self.model : model // ignore: cast_nullable_to_non_nullable
as String,historyLen: null == historyLen ? _self.historyLen : historyLen // ignore: cast_nullable_to_non_nullable
as int,id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,genTitlePrompt: freezed == genTitlePrompt ? _self.genTitlePrompt : genTitlePrompt // ignore: cast_nullable_to_non_nullable
as String?,genTitleModel: freezed == genTitleModel ? _self.genTitleModel : genTitleModel // ignore: cast_nullable_to_non_nullable
as String?,imgModel: freezed == imgModel ? _self.imgModel : imgModel // ignore: cast_nullable_to_non_nullable
as String?,audioModel: freezed == audioModel ? _self.audioModel : audioModel // ignore: cast_nullable_to_non_nullable
as String?,tskrModel: freezed == tskrModel ? _self.tskrModel : tskrModel // ignore: cast_nullable_to_non_nullable
as String?,altrModel: freezed == altrModel ? _self.altrModel : altrModel // ignore: cast_nullable_to_non_nullable
as String?,wrkrModel: freezed == wrkrModel ? _self.wrkrModel : wrkrModel // ignore: cast_nullable_to_non_nullable
as String?,trnscrbModel: freezed == trnscrbModel ? _self.trnscrbModel : trnscrbModel // ignore: cast_nullable_to_non_nullable
as String?,defaultTranslateLanguage: freezed == defaultTranslateLanguage ? _self.defaultTranslateLanguage : defaultTranslateLanguage // ignore: cast_nullable_to_non_nullable
as String?,file: freezed == file ? _self.file : file // ignore: cast_nullable_to_non_nullable
as String?,image: freezed == image ? _self.image : image // ignore: cast_nullable_to_non_nullable
as String?,audio: freezed == audio ? _self.audio : audio // ignore: cast_nullable_to_non_nullable
as String?,isVertex: freezed == isVertex ? _self.isVertex : isVertex // ignore: cast_nullable_to_non_nullable
as bool?,vertexProjectId: freezed == vertexProjectId ? _self.vertexProjectId : vertexProjectId // ignore: cast_nullable_to_non_nullable
as String?,vertexLocation: freezed == vertexLocation ? _self.vertexLocation : vertexLocation // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
