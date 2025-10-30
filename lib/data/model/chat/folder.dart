import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hive_ce/hive.dart';
import 'package:shortid/shortid.dart';

part 'folder.g.dart';

@JsonSerializable()
@HiveType(typeId: 20)
final class ChatFolder {
  @HiveField(0)
  final String id;
  @HiveField(1)
  final String name;
  @JsonKey(includeIfNull: false)
  @HiveField(2)
  final String? colorIndicator;
  @JsonKey(includeIfNull: false)
  @HiveField(3)
  final bool? isExpanded;

  ChatFolder({
    required this.id,
    required this.name,
    this.colorIndicator,
    this.isExpanded,
  });

  ChatFolder.noid({
    required this.name,
    this.colorIndicator,
    this.isExpanded,
  }) : id = shortid.generate();

  factory ChatFolder.fromJson(Map<String, dynamic> json) =>
      _$ChatFolderFromJson(json);

  Map<String, dynamic> toJson() => _$ChatFolderToJson(this);

  ChatFolder copyWith({
    String? name,
    String? colorIndicator,
    bool? isExpanded,
  }) {
    return ChatFolder(
      id: id,
      name: name ?? this.name,
      colorIndicator: colorIndicator ?? this.colorIndicator,
      isExpanded: isExpanded ?? this.isExpanded,
    );
  }

  @override
  String toString() => 'ChatFolder($id, $name)';
}
