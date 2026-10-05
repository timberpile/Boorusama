import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';

// Separate migration identities from application-generated profile/group UUIDs.
const migrationUuidNamespace = 'b4bac68d-06c2-5d76-8f57-1d9f22c51c28';

List<int> encodeMigrationPackage({
  required String bookmarks,
  required String blacklistedTags,
  required String pinnedSearches,
}) {
  final bookmarkData = jsonDecode(bookmarks) as Map<String, dynamic>;
  final pinnedData = jsonDecode(pinnedSearches) as Map<String, dynamic>;
  final groupIds = [
    for (final group in bookmarkData['groups'] as List) 'group:${group['id']}',
  ];
  final pinnedIds = [
    for (final row in pinnedData['data'] as List)
      if (row['kind'] == 'folder')
        'folder:${row['id']}'
      else if (row['kind'] == 'search')
        'search:${row['id']}',
  ];
  final selections = {
    'bookmarks': groupIds,
    'blacklisted_tags': <String>[],
    'pinned_searches': pinnedIds,
  };
  final sources = {
    'bookmarks': bookmarks,
    'blacklisted_tags': blacklistedTags,
    'pinned_searches': pinnedSearches,
  };
  final archive = Archive();
  final manifests = <Map<String, Object?>>[];
  for (final entry in sources.entries) {
    final bytes = utf8.encode(entry.value);
    final path = 'sources/${entry.key}/data.json';
    // Fixed ZIP timestamps keep identical conversions byte-for-byte identical.
    archive.add(
      ArchiveFile(path, bytes.length, bytes)..lastModTime = 315532800,
    );
    manifests.add({
      'id': entry.key,
      'schemaVersion': entry.key == 'bookmarks' ? 4 : 1,
      'selection': {'kind': 'explicit', 'childIds': selections[entry.key]},
      'recommendedAction': entry.key == 'blacklisted_tags'
          ? 'skip'
          : 'configureItems',
      if (entry.key != 'blacklisted_tags')
        'itemRecommendedActions': {
          for (final id in selections[entry.key]!) id: 'copy',
        },
      'parts': [
        {
          'path': path,
          'sha256': sha256.convert(bytes).toString(),
          'byteLength': bytes.length,
        },
      ],
    });
  }
  final manifest = utf8.encode(
    jsonEncode({
      'format': 'boorusama-export',
      'formatVersion': 1,
      'exportId': const Uuid().v5(migrationUuidNamespace, jsonEncode(sources)),
      'createdAt': DateTime.parse(
        bookmarkData['date'] as String,
      ).toUtc().toIso8601String(),
      'appVersion': 'boorusama-cli-animeboxes',
      'preset': 'custom',
      'containsCredentials': false,
      'sources': manifests,
    }),
  );
  archive.add(
    ArchiveFile('manifest.json', manifest.length, manifest)
      ..lastModTime = 315532800,
  );
  // The encoder interprets entry epochs in local time without this override.
  return ZipEncoder().encode(archive, modified: DateTime.utc(1980));
}
