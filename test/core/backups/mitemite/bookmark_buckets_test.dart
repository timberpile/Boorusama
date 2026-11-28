import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:boorusama/core/backups/export_import/package/bookmark_transfer_format.dart';
import 'package:boorusama/core/backups/export_import/package/export_package_exception.dart';
import 'package:boorusama/core/backups/mitemite/bookmark_buckets.dart';
import 'package:boorusama/core/backups/mitemite/catalog.dart';
import 'package:boorusama/core/backups/mitemite/protocol.dart';
import 'package:boorusama/core/backups/mitemite/seen_state.dart';
import 'package:boorusama/core/backups/mitemite/storage.dart';
import 'package:boorusama/core/backups/sources/bookmark_backup_codec.dart';
import 'package:boorusama/core/backups/sources/bookmark_backup_schema.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../benchmark/scalability/fixtures.dart';

void main() {
  final collection = SyncCollectionId(
    publisher: '11111111-2222-4333-8444-555555555555',
    kind: 'bookmarks',
    source: '22222222-2222-4333-8444-555555555555',
  );
  final date = DateTime.utc(2024, 6, 7, 8, 9, 10, 111, 123);
  final codec = BookmarkBackupCodec();
  final record = scalabilityBookmark(9, upstreamId: 7, uploadedAt: date);
  final key = syncBookmarkMemberKey(record);
  final bucket = syncBookmarkBucket(key, 64);
  SyncEncodedChunk object(DateTime addedAt, {int revision = 5}) =>
      encodeSyncBookmarkBucket(
        members: [(key: key, addedAt: addedAt, record: record)],
        codec: codec,
        bucket: bucket,
        revision: revision,
      ).single;

  test('stable partition cutoffs and SHA-256 high bits', () {
    expect(
      [
        0,
        100,
        256,
        257,
        4096,
        4097,
        10000,
        16384,
        16385,
        100000,
      ].map(syncBookmarkBucketCount),
      [1, 1, 1, 16, 16, 64, 64, 64, 256, 256],
    );
    // SHA-256 of UTF-8 "abc" starts with 0xba.
    expect([1, 16, 64, 256].map((count) => syncBookmarkBucket('abc', count)), [
      0,
      11,
      46,
      186,
    ]);
  });

  test('stable exact bytes and separate date-aware semantics', () async {
    final original = object(date);
    expect(object(date, revision: 6).bytes, original.bytes);
    expect(
      object(date.add(const Duration(microseconds: 1))).reference.semanticHash,
      isNot(original.reference.semanticHash),
    );
    final members = await visitSyncBookmarkChunk(
      bytes: original.bytes,
      chunk: original.reference,
      bucketCount: 64,
      codec: codec,
    ).toList();
    expect(members.single.key, key);
    expect(members.single.record.id, 0);
    expect(members.single.addedAt, date);
    expect(
      isOwnedSyncRevisionPath(
        original.reference.path(collection),
        collection.publisher,
      ),
      isTrue,
    );
    expect(
      isOwnedSyncRevisionPath(
        original.reference.path(collection),
        collection.source,
      ),
      isFalse,
    );
  });

  test('rejects an oversized UTF-8 row before parsing it', () async {
    final original = object(date);
    final row = jsonDecode(
      utf8.decode(gzip.decode(original.bytes)),
    ) as Map<String, Object?>;
    row['padding'] = 'é' * (bookmarkTransferRowBytes ~/ 2);
    final expanded = utf8.encode('${jsonEncode(row)}\n');
    final bytes = Uint8List.fromList(gzip.encode(expanded));
    final declared = SyncBookmarkChunk.fromJson({
      ...original.reference.toJson(),
      'sha256': syncDigest(bytes),
      'compressedBytes': bytes.length,
      'expandedBytes': expanded.length,
    });
    await expectLater(
      visitSyncBookmarkChunk(
        bytes: bytes,
        chunk: declared,
        bucketCount: 64,
        codec: codec,
      ).toList(),
      throwsA(isA<ExportPackageLimitException>()),
    );
  });

  test(
    'manifest advertises a complete empty group and an explicit scope gate',
    () {
      final empty = SyncBookmarkManifest(
        collection: collection,
        revision: 5,
        bucketCount: 1,
        chunks: const [],
      );
      final parsed = SyncBookmarkManifest.fromJson(
        jsonDecode(utf8.decode(empty.encode())) as Map<String, Object?>,
      );
      expect(parsed.chunks, isEmpty);
      final revision = SyncRevision(
        collection: collection,
        revision: 5,
        length: empty.encode().length,
        sha256: syncDigest(empty.encode()),
        semanticHash: empty.semanticHash,
        schema: kBookmarksBackupVersion,
        bookmarkManifest: true,
      );
      final catalog = SyncCatalog(
        publisher: collection.publisher,
        sequence: 6,
        name: 'Publisher',
        completeSnapshot: true,
        publicationRoots: {collection},
        entries: [
          SyncCatalogEntry(
            id: collection,
            name: 'Empty',
            state: SyncPublicationState.active,
            revision: revision,
          ),
        ],
      );
      expect(catalog.toJson()['publicationScopeVersion'], 3);
      expect(
        SyncCatalog.fromJson(
          jsonDecode(canonicalSyncJson(catalog.toJson()))
              as Map<String, dynamic>,
        ).usesBookmarkManifests,
        isTrue,
      );
      expect(
        () => SyncCatalog.fromJson(
          jsonDecode(
            canonicalSyncJson({
              ...catalog.toJson(),
              'publicationScopeVersion': 2,
            }),
          ) as Map<String, dynamic>,
        ),
        throwsFormatException,
      );
    },
  );

  test(
    'duplicate parts, future references and wrong partition fail closed',
    () async {
      final chunk = object(date);
      SyncBookmarkManifest create(List<SyncBookmarkChunk> references) =>
          SyncBookmarkManifest(
            collection: collection,
            revision: 5,
            bucketCount: 64,
            chunks: references,
          );
      expect(
        () => create([chunk.reference, chunk.reference]),
        throwsFormatException,
      );
      expect(
        () => create([object(date, revision: 6).reference]),
        throwsFormatException,
      );
      final wrongBucket = SyncBookmarkChunk.fromJson({
        ...chunk.reference.toJson(),
        'bucket': (bucket + 1) % 64,
      });
      await expectLater(
        visitSyncBookmarkChunk(
          bytes: chunk.bytes,
          chunk: wrongBucket,
          bucketCount: 64,
          codec: codec,
        ).toList(),
        throwsFormatException,
      );
    },
  );
}
