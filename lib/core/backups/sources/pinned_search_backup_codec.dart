// Package imports:
import 'package:uuid/uuid.dart';

// Project imports:
import '../../search/subscriptions/types.dart';
import '../../groups/folder_tree.dart';
import '../types/types.dart';
import '../utils/json_handler.dart';
import 'pinned_search_backup_data.dart';
import 'search_backup_profile.dart';
import 'search_backup_envelope.dart';

class PinnedSearchBackupCodec extends JsonHandler<PinnedSearchBackupData> {
  @override
  PinnedSearchBackupData parse(ExportDataPayload metadata) {
    requireSearchBackupEnvelope(metadata, 'pinned_searches');
    final records = <PinnedSearchBackupRecord>[];
    final folders = <PinnedSearchFolderBackupRecord>[];
    final ids = <String>{};
    List<String>? homeSearchIds;
    for (final (index, value) in metadata.data.indexed) {
      final row = 'data[$index]';
      final json = _object(value, row);
      if (json['kind'] == 'organization') {
        if (homeSearchIds != null) {
          throw InvalidBackupFormatException('$row organization is repeated');
        }
        homeSearchIds = _searchIds(json['homeSearchIds'], '$row.homeSearchIds');
        continue;
      }
      final id = switch (json['id']) {
        final String id when Uuid.isValidUUID(fromString: id) =>
          id.toLowerCase(),
        _ => throw InvalidBackupFormatException('$row.id is invalid'),
      };
      if (!ids.add(id)) {
        throw InvalidBackupFormatException('$row.id is repeated');
      }
      if (json['kind'] == 'folder') {
        final members = metadata.version == 1
            ? _searchIds(json['searchIds'], '$row.searchIds')
            : <String>[];
        folders.add(
          PinnedSearchFolderBackupRecord(
            id: id,
            name: _nonBlankString(json['name'], '$row.name').trim(),
            parentId: metadata.version == 2
                ? _nullableUuid(json['parentId'], '$row.parentId')
                : null,
            position: _nonNegativeInt(json['position'], '$row.position'),
            searchIds: List.unmodifiable(members),
          ),
        );
        continue;
      }
      if (json['kind'] != 'search') {
        throw InvalidBackupFormatException('$row.kind is invalid');
      }
      final name = switch (json['name']) {
        null => null,
        final String name => name.trim().isEmpty ? null : name.trim(),
        _ => throw InvalidBackupFormatException('$row.name is invalid'),
      };
      final query = _nonBlankString(json['query'], '$row.query');
      final queryStructure = SearchQueryStructure.tryParse(
        json['queryStructure'],
      );
      records.add(
        PinnedSearchBackupRecord(
          id: id,
          name: name,
          query: query,
          queryStructure: switch (queryStructure) {
            final SearchQueryStructure structure
                when structure.matchesCanonicalQuery(query) =>
              structure,
            _ => null,
          },
          position: _nonNegativeInt(json['position'], '$row.position'),
          profile: parseBackupProfile(json['profile'], '$row.profile'),
          folderId: metadata.version == 2
              ? _nullableUuid(json['folderId'], '$row.folderId')
              : null,
          folderPosition: metadata.version == 2
              ? _nonNegativeInt(json['folderPosition'], '$row.folderPosition')
              : null,
        ),
      );
    }
    if (homeSearchIds == null) {
      throw const InvalidBackupFormatException('Missing organization row');
    }
    if (metadata.version == 2) {
      final rebuilt = [
        for (final f in folders)
          PinnedSearchFolderBackupRecord(
            id: f.id,
            name: f.name,
            parentId: f.parentId,
            position: f.position,
            searchIds:
                (records.where((r) => r.folderId == f.id).toList()..sort(
                      (a, b) => a.folderPosition!.compareTo(b.folderPosition!),
                    ))
                    .map((r) => r.id)
                    .toList(),
          ),
      ];
      folders
        ..clear()
        ..addAll(rebuilt);
      homeSearchIds =
          (records.where((r) => r.folderId == null).toList()..sort(
                (a, b) => a.folderPosition!.compareTo(b.folderPosition!),
              ))
              .map((r) => r.id)
              .toList();
    }
    try {
      FolderTree([
        for (final f in folders)
          CollectionFolder(
            id: f.id,
            name: f.name,
            parentId: f.parentId,
            position: f.position,
          ),
      ]).validatePlacements([
        for (final r in records)
          FolderPlacement(
            itemId: r.id,
            folderId: r.folderId,
            position: r.folderPosition ?? r.position,
          ),
      ]);
    } catch (_) {
      throw const InvalidBackupFormatException(
        'Invalid pinned search hierarchy',
      );
    }
    final independentIds = records.map((record) => record.id).toSet();
    final folderNames = <(String?, String)>{};
    for (final folder in folders) {
      if (!folderNames.add((folder.parentId, folder.name.toLowerCase()))) {
        throw const InvalidBackupFormatException('Repeated folder name');
      }
    }
    final assigned = <String>{};
    for (final id in [
      ...homeSearchIds,
      for (final folder in folders) ...folder.searchIds,
    ]) {
      if (!assigned.add(id) || !independentIds.contains(id)) {
        throw const InvalidBackupFormatException(
          'Invalid organization search reference',
        );
      }
    }
    if (metadata.version == 1) {
      homeSearchIds = [
        ...homeSearchIds,
        for (final r in records)
          if (!assigned.contains(r.id)) r.id,
      ];
      final locations = {
        for (final f in folders)
          for (final (i, id) in f.searchIds.indexed)
            id: FolderPlacement(itemId: id, folderId: f.id, position: i),
        for (final (i, id) in homeSearchIds.indexed)
          id: FolderPlacement(itemId: id, position: i),
      };
      final normalized = [
        for (final r in records)
          PinnedSearchBackupRecord(
            id: r.id,
            name: r.name,
            query: r.query,
            queryStructure: r.queryStructure,
            position: r.position,
            profile: r.profile,
            folderId: locations[r.id]?.folderId,
            folderPosition: locations[r.id]?.position ?? r.position,
          ),
      ];
      records
        ..clear()
        ..addAll(normalized);
    }
    return PinnedSearchBackupData(
      records: List.unmodifiable(records),
      folders: List.unmodifiable(folders),
      homeSearchIds: List.unmodifiable(homeSearchIds),
    );
  }

  @override
  List<dynamic> encode(PinnedSearchBackupData data) => [
    for (final folder in data.folders)
      {
        'kind': 'folder',
        'id': folder.id,
        'name': folder.name,
        'position': folder.position,
        'parentId': folder.parentId,
      },
    for (final record in data.records)
      {
        'kind': 'search',
        'id': record.id,
        'name': record.name,
        'query': record.query,
        if (record.queryStructure case final structure?)
          'queryStructure': structure.toJson(),
        'position': record.position,
        'folderId':
            record.folderId ??
            data.folders
                .where((f) => f.searchIds.contains(record.id))
                .firstOrNull
                ?.id,
        'folderPosition':
            record.folderPosition ??
            (() {
              final ids =
                  data.folders
                      .where((f) => f.searchIds.contains(record.id))
                      .firstOrNull
                      ?.searchIds ??
                  data.homeSearchIds;
              final index = ids.indexOf(record.id);
              return index < 0 ? record.position : index;
            })(),
        'profile': record.profile.toJson(),
      },
    {'kind': 'organization', 'homeSearchIds': <String>[]},
  ];
}

Map<String, dynamic> _object(Object? value, String field) => switch (value) {
  final Map<String, dynamic> value => value,
  _ => throw InvalidBackupFormatException('$field must be an object'),
};

String _nonBlankString(Object? value, String field) => switch (value) {
  final String value when value.trim().isNotEmpty => value,
  _ => throw InvalidBackupFormatException('$field is invalid'),
};

int _nonNegativeInt(Object? value, String field) => switch (value) {
  final int value when value >= 0 => value,
  _ => throw InvalidBackupFormatException('$field is invalid'),
};

List<String> _searchIds(Object? value, String field) => switch (value) {
  final List values => [
    for (final value in values)
      switch (value) {
        final String id when Uuid.isValidUUID(fromString: id) =>
          id.toLowerCase(),
        _ => throw InvalidBackupFormatException('$field is invalid'),
      },
  ],
  _ => throw InvalidBackupFormatException('$field is invalid'),
};

String? _nullableUuid(Object? value, String field) => switch (value) {
  null => null,
  final String id when Uuid.isValidUUID(fromString: id) => id.toLowerCase(),
  _ => throw InvalidBackupFormatException('$field is invalid'),
};
