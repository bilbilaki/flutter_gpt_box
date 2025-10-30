import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shortid/shortid.dart';

part 'folder.g.dart';

@JsonSerializable()
final class ChatFolder {
  final String id;
  final String name;
  @JsonKey(includeIfNull: false)
  final String? colorIndicator;
  @JsonKey(includeIfNull: false)
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
