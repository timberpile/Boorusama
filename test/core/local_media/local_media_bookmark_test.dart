import 'dart:convert';

import 'package:boorusama/core/backups/mitemite/bookmark_package.dart';
import 'package:boorusama/core/backups/mitemite/protocol.dart';
import 'package:boorusama/core/backups/mitemite/reading_state.dart';
import 'package:boorusama/core/backups/sources/bookmark_backup_codec.dart';
import 'package:boorusama/core/backups/sources/bookmark_backup_data.dart';
import 'package:boorusama/core/backups/sources/bookmark_backup_schema.dart';
import 'package:boorusama/core/backups/utils/data_converter.dart';
import 'package:boorusama/core/bookmarks/src/data/stored_bookmark_codec.dart';
import 'package:boorusama/core/bookmarks/src/providers/bookmark_group_selectors.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_record_fields.dart';
import 'package:boorusama/core/bookmarks/types.dart';
import 'package:boorusama/core/local_media/local_media_models.dart';
import 'package:boorusama/core/local_media/local_media_reference.dart';
import 'package:boorusama/core/posts/details/src/types/viewer_entry.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/foundation/filesystem.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const groupId = '71fcb1e3-4e42-4b05-bbe1-bb9fe038ef03';
  final hash = List.filled(32, 'ab').join();
  final reference = LocalMediaReference.parse(hash);
  final at = DateTime.utc(2026);
  final codec = BookmarkBackupCodec();

  PostBookmark bookmark({int rowId = 1}) {
    final post = localMediaPost(
      reference,
      id: rowId,
      source: 'https://example.invalid/private-source',
      tags: [(name: 'private_tag', category: 'general')],
    );
    return PostBookmark.fromSnapshot(
      id: 7,
      createdAt: at,
      updatedAt: at,
      snapshot: const StoredPostCodec().encode(post),
      post: post,
      postId: null,
    );
  }

  BookmarkBackupData data(List<Bookmark> records) => BookmarkBackupData.unified(
    records: records,
    groups: [
      BookmarkGroupBackup(
        id: groupId,
        name: 'Group',
        bookmarkIds: [for (final record in records) record.id],
        addedAt: {for (final record in records) record.id: at},
      ),
    ],
  );

  test('stable identity does not depend on a library row or bookmark ID', () {
    final first = bookmark();
    final second = bookmark(rowId: 55).copyWith(id: 77);
    expect(first.identity, second.identity);
    expect(first.identity.postKey, hash);
    expect(postViewerIdentity(first.post), postViewerIdentity(second.post));
    expect(
      PostViewerEntry(post: first.post, occurrenceId: 7).contentIdentity,
      bookmarkContentIdentity(first),
    );
    expect(syncBookmarkMemberKey(first), syncBookmarkMemberKey(second));
    expect(
      () => LocalMediaReference.parse(hash.toUpperCase()),
      throwsFormatException,
    );
  });

  test('Local source uses the typed bookmark even if no file is available', () {
    final saved = bookmark();
    final stored = const StoredBookmarkCodec().encodeForTransfer(saved);
    final restored = const StoredBookmarkCodec().decode(stored) as PostBookmark;
    final source = bookmarkSourceHost(restored)!;
    expect(source, LocalMediaReference.namespace);
    expect(
      bookmarkSourceMatchesHost(source, LocalMediaReference.namespace),
      isTrue,
    );
    expect(
      bookmarkSourceMatchesHost(
        'https://example.invalid',
        LocalMediaReference.namespace,
      ),
      isFalse,
    );
    expect(bookmarkSourceMatchesHost(source, 'example.invalid'), isFalse);
  });

  test('v7 record contains only the hash and bookmark fields', () {
    final saved = bookmark();
    final encoded = const StoredBookmarkCodec().encodeForTransfer(saved);
    expect(encoded, {
      'id': saved.id,
      'kind': 'localMedia',
      'createdAt': at.toIso8601String(),
      'updatedAt': at.toIso8601String(),
      'sha256': hash,
    });
    expect(
      () => const StoredBookmarkCodec().decode({
        ...encoded,
        'path': '/private/file',
      }),
      throwsFormatException,
    );
    final snapshot = data([saved]);
    final metadata = {
      'version': bookmarkTransferVersion(snapshot.records),
      'data': codec.encode(snapshot),
      ...snapshot.extraFields,
    };
    final decoded = codec.parse(decodeData(data: jsonEncode(metadata)));
    final restored = decoded.records.single as PostBookmark;
    expect(decoded.groups.single.addedAt, {saved.id: at});
    expect(restored.identity, saved.identity);
    expect(restored.post.id, 0);
    expect(restored.post.originalImageUrl, isEmpty);
    expect(restored.post.tags, isEmpty);
    expect(
      () => codec.parse(
        decodeData(data: jsonEncode({...metadata, 'version': 6})),
      ),
      throwsException,
    );
  });

  test('MiteMite builds reference-bearing packages with v7 and empty groups with v6', () async {
    final identity = await SyncSigningIdentity.create();
    final collection = SyncCollectionId(
      publisher: identity.id,
      kind: 'bookmarks',
      source: groupId,
    );
    const fs = IoFileSystem();
    final builder = SyncBookmarkPackageBuilder(fs: fs, codec: codec);
    for (final (records, version) in [
      (<Bookmark>[], kRemoteBookmarksBackupVersion),
      ([bookmark()], kBookmarksBackupVersion),
    ]) {
      final built = await builder.build(
        collection: collection,
        data: data(records),
        appVersion: '4.6.1',
        createdAt: at,
      );
      expect(built.schemaVersion, version);
      final validated = await SyncBookmarkPackageValidator(
        fs: fs,
        codec: codec,
      ).validate(collection: collection, bytes: built.bytes);
      expect(validated.schemaVersion, version);
      expect(validated.semanticHash, built.semanticHash);
      final received = await validated.materialize();
      expect(
        received.records.map(bookmarkContentIdentity),
        records.map(bookmarkContentIdentity),
      );
    }
  });
}
