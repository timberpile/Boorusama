import '../../sources/bookmark_backup_schema.dart';
import '../models/package_manifest.dart';

const bookmarkTransferPartBytes = 32 * 1024 * 1024;
const bookmarkTransferRowBytes = 8 * 1024 * 1024;
const bookmarkTransferExpandedBytes = 8 * 1024 * 1024 * 1024;
// One short final part per table can be present in addition to the full parts.
const bookmarkTransferPartCount =
    bookmarkTransferExpandedBytes ~/ bookmarkTransferPartBytes + 3;

enum BookmarkTransferTable { groups, bookmarks, memberships }

const _directory = 'sources/bookmarks';
final _partPath = RegExp(
  r'^sources/bookmarks/(groups|bookmarks|memberships)-([0-9]{4})\.ndjson$',
);

String bookmarkTransferPartPath(BookmarkTransferTable table, int index) =>
    '$_directory/${table.name}-${index.toString().padLeft(4, '0')}.ndjson';

bool isBookmarkTransferPart(String path) => _partPath.hasMatch(path);

/// The legacy bookmark envelope also has a v7 Local Media variant.
Map<BookmarkTransferTable, List<ExportPartManifest>>? bookmarkTransferParts(
  ExportSourceManifest source,
) {
  if (source.id != 'bookmarks' ||
      source.schemaVersion != kBookmarksBackupVersion ||
      source.parts.every((part) => !isBookmarkTransferPart(part.path))) {
    return null;
  }
  final byTable = {
    for (final table in BookmarkTransferTable.values)
      table: <ExportPartManifest>[],
  };
  for (final part in source.parts) {
    final match = _partPath.firstMatch(part.path);
    if (match == null) {
      throw const FormatException('Invalid Bookmark transfer part layout');
    }
    final table = BookmarkTransferTable.values.byName(match[1]!);
    byTable[table]!.add(part);
  }
  for (final entry in byTable.entries) {
    final parts = entry.value..sort((a, b) => a.path.compareTo(b.path));
    if (parts.isEmpty) {
      throw const FormatException('Missing Bookmark transfer table');
    }
    for (var i = 0; i < parts.length; i++) {
      if (parts[i].path != bookmarkTransferPartPath(entry.key, i)) {
        throw const FormatException(
          'Missing or repeated Bookmark transfer part',
        );
      }
    }
  }
  return byTable;
}
