// Package imports:
import 'package:equatable/equatable.dart';

final class SharedSearchFolder extends Equatable {
  SharedSearchFolder({
    required this.id,
    required String name,
    required Iterable<String> searchIds,
  }) : name = name.trim(),
       searchIds = List.unmodifiable(searchIds) {
    if (id.trim().isEmpty || this.name.isEmpty) {
      throw const FormatException('Invalid shared search folder');
    }
  }

  factory SharedSearchFolder.fromJson(Map<dynamic, dynamic> json) =>
      switch (json) {
        {
          'id': final String id,
          'name': final String name,
          'searchIds': final List ids,
        } =>
          SharedSearchFolder(
            id: id,
            name: name,
            searchIds: ids.map(
              (value) => switch (value) {
                final String id => id,
                _ => throw const FormatException(
                  'Invalid shared search folder IDs',
                ),
              },
            ),
          ),
        _ => throw const FormatException('Invalid shared search folder data'),
      };

  final String id;
  final String name;
  final List<String> searchIds;

  Map<String, Object> toJson() => {
    'id': id,
    'name': name,
    'searchIds': searchIds,
  };

  @override
  List<Object?> get props => [id, name, searchIds];
}

final class SearchOrganization extends Equatable {
  SearchOrganization({
    required Iterable<SharedSearchFolder> folders,
    required Iterable<String> homeSearchIds,
  }) : folders = List.unmodifiable(folders),
       homeSearchIds = List.unmodifiable(homeSearchIds);

  factory SearchOrganization.fromJson(Map<dynamic, dynamic> json) =>
      switch (json) {
        {
          'folders': final List folders,
          'homeSearchIds': final List homeSearchIds,
        } =>
          SearchOrganization(
            folders: folders.map(
              (value) => switch (value) {
                final Map folder => SharedSearchFolder.fromJson(folder),
                _ => throw const FormatException(
                  'Invalid shared search folders',
                ),
              },
            ),
            homeSearchIds: homeSearchIds.map(
              (value) => switch (value) {
                final String id => id,
                _ => throw const FormatException('Invalid shared Home IDs'),
              },
            ),
          ),
        _ => throw const FormatException('Invalid shared search organization'),
      };

  final List<SharedSearchFolder> folders;
  final List<String> homeSearchIds;

  Map<String, Object> toJson() => {
    'folders': folders.map((folder) => folder.toJson()).toList(),
    'homeSearchIds': homeSearchIds,
  };

  @override
  List<Object?> get props => [folders, homeSearchIds];
}
