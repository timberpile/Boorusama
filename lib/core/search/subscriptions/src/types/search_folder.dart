import 'package:equatable/equatable.dart';

class SearchFolder extends Equatable {
  SearchFolder({
    required this.id,
    required this.profileId,
    required String name,
    required this.position,
    required Iterable<String> searchIds,
  }) : name = name.trim(),
       searchIds = Set.unmodifiable(searchIds) {
    if (id.isEmpty || this.name.isEmpty || position < 0) {
      throw const FormatException('Invalid search folder');
    }
  }

  factory SearchFolder.fromJson(Map<dynamic, dynamic> json) => switch (json) {
    {
      'id': final String id,
      'profileId': final int profileId,
      'name': final String name,
      'position': final int position,
      'searchIds': final List ids,
    } =>
      SearchFolder(
        id: id,
        profileId: profileId,
        name: name,
        position: position,
        searchIds: ids.whereType<String>(),
      ),
    _ => throw const FormatException('Invalid search folder data'),
  };

  final String id;
  final int profileId;
  final String name;
  final int position;
  final Set<String> searchIds;

  SearchFolder copyWith({
    String? name,
    int? position,
    Iterable<String>? searchIds,
  }) => SearchFolder(
    id: id,
    profileId: profileId,
    name: name ?? this.name,
    position: position ?? this.position,
    searchIds: searchIds ?? this.searchIds,
  );

  Map<String, Object> toJson() => {
    'id': id,
    'profileId': profileId,
    'name': name,
    'position': position,
    'searchIds': searchIds.toList(),
  };

  @override
  List<Object?> get props => [id, profileId, name, position, searchIds];
}
