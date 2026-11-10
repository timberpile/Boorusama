import 'dart:convert';
import 'dart:isolate';

import 'package:boorusama/boorus/gelbooru_v2/posts/post_codec.dart';
import 'package:boorusama/boorus/gelbooru_v2/posts/post_data.dart';
import 'package:boorusama/core/backups/preparation/version_checking.dart';
import 'package:boorusama/core/backups/sources/bookmark_backup_codec.dart';
import 'package:boorusama/core/backups/sources/bookmark_backup_data.dart';
import 'package:boorusama/core/backups/sources/bookmark_backup_worker.dart';
import 'package:boorusama/core/backups/types/types.dart';
import 'package:boorusama/core/backups/utils/data_converter.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/bookmarks/types.dart';
import 'package:boorusama/core/bookmarks/src/types/legacy_group_bookmark.dart';
import 'package:boorusama/core/content/types.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:coreutils/coreutils.dart';

import '../../support/fakes/test_post.dart';
import '../bookmarks/pool_bookmark_test_utils.dart';

void main() {
  late BookmarkBackupCodec codec;
  late BookmarkBackupWorker worker;
  late BookmarkBackupData data;
  final exportDate = DateTime.utc(2026, 11, 9, 12, 13, 14, 123, 456);

  setUp(() {
    // A provider lookup may capture an unsendable object. Only its resolved
    // engine codecs belong in worker tasks; the lookup itself must stay here.
    final port = ReceivePort();
    addTearDown(port.close);
    codec = BookmarkBackupCodec(
      postDataCodec: (type) {
        expect(port.sendPort, isNotNull);
        return type == BooruType.gelbooruV2
            ? const GelbooruV2PostCodec()
            : null;
      },
      groupMetadataResolver: () {
        expect(port.sendPort, isNotNull);
        return const GroupMetadataCodec();
      },
    );
    worker = BookmarkBackupWorker(codec);
    final post = TestPost(
      id: 7,
      origin: PostOrigin.fromSource(
        booruType: BooruType.gelbooruV2,
        booruId: BooruType.gelbooruV2.id,
        source: 'https://gelbooru.example/board/',
        profileIdHint: 'local-only-profile-hint',
      ),
      booruData: const GelbooruV2PostData(hasNotes: true),
    );
    final record = PostBookmark.fromSnapshot(
      id: 7,
      createdAt: DateTime(2020, 2, 3, 4, 5, 6, 123, 456),
      updatedAt: DateTime.utc(2022, 3, 4),
      sourceUrl: 'https://private.example/source?local=value',
      postId: post.id,
      post: post,
      snapshot: const StoredPostCodec().encode(
        post,
        dataCodec: const GelbooruV2PostCodec(),
      ),
    );
    final unknown = LegacyGroupBookmark.fromMetadata(
      id: 8,
      metadata: PoolBookmark(
        localId: 'unaddressable-legacy',
        origin: poolOrigin(host: 'legacy.example', type: BooruType.unknown),
        sourceTypeId: 777,
        poolId: 42,
        category: BookmarkedPoolCategory.series,
        title: 'Retained unknown engine',
        createdAt: DateTime.utc(2017),
        observedAt: DateTime.utc(2024),
        groupIds: const {},
        tags: const {'retained'},
        coverage: PoolTagCoverage.unknown,
        total: 12,
      ),
    );
    data = BookmarkBackupData.unified(
      records: [record, unknown],
      groups: [
        BookmarkGroupBackup(
          id: poolGroupA,
          name: 'Root',
          bookmarkIds: const [7, 8],
          addedAt: {7: DateTime.utc(2023), 8: DateTime.utc(2024)},
        ),
        const BookmarkGroupBackup(
          id: poolGroupB,
          name: 'Child',
          parentGroupId: poolGroupA,
          bookmarkIds: [],
        ),
      ],
    );
  });

  test(
    'worker preserves exact local recovery and revision JSON bytes',
    () async {
      final revision = jsonEncode({
        'data': codec.encodeLocalRecovery(data),
        ...data.extraFields,
      });
      final rollback = encodeData(
        version: 10,
        exportVersion: Version.parse('4.7.0'),
        exportDate: exportDate,
        payload: codec.encodeLocalRecovery(data),
        extraFields: data.extraFields,
      );
      expect(await worker.encodeRevision(data), revision);
      expect(
        await worker.encodeRollback(
          data,
          version: 10,
          exportVersion: Version.parse('4.7.0'),
          exportDate: exportDate,
        ),
        rollback,
      );
      final decoded = await worker.decode(rollback);
      expect(decoded.metadata.toJson(), decodeData(data: rollback).toJson());
      expect(decoded.parsed, codec.parse(decodeData(data: rollback)));
      final post = decoded.parsed.records.whereType<PostBookmark>().single;
      expect(post.post.booruData, const GelbooruV2PostData(hasNotes: true));
      expect(post.sourceUrl, data.bookmarks.single.sourceUrl);
      expect(rollback, contains('local-only-profile-hint'));
      expect(
        post.snapshot.origin.profileIdHint,
        codec
            .parse(decodeData(data: rollback))
            .bookmarks
            .single
            .snapshot
            .origin
            .profileIdHint,
      );
      expect(post.createdAt.isUtc, isFalse);
      expect(
        post.createdAt.toIso8601String(),
        data.bookmarks.single.createdAt.toIso8601String(),
      );
      final unknown = decoded.parsed.records
          .whereType<LegacyGroupBookmark>()
          .single;
      expect(unknown.metadata.sourceTypeId, 777);
      expect(unknown.metadata.tags, {'retained'});
      expect(decoded.parsed.groups.last.parentGroupId, poolGroupA);
    },
  );

  test(
    'worker rejects malformed rows, engine payloads and unsupported versions',
    () async {
      final encoded = await worker.encodeRollback(
        data,
        version: 10,
        exportVersion: null,
        exportDate: exportDate,
      );
      final malformedRow = jsonDecode(encoded) as Map<String, dynamic>;
      (malformedRow['data'] as List).add({'kind': 'post', 'id': 'invalid'});
      final malformedEngine = jsonDecode(encoded) as Map<String, dynamic>;
      final snapshot =
          ((malformedEngine['data'] as List).first as Map)['snapshot'] as Map;
      snapshot['custom'] = ['invalid object'];
      final unsupported = jsonDecode(encoded) as Map<String, dynamic>;
      unsupported['version'] = 999;
      for (final malformed in [malformedRow, malformedEngine, unsupported]) {
        await expectLater(
          worker.decode(jsonEncode(malformed)),
          throwsA(isA<InvalidBackupFormatException>()),
        );
      }
      await expectLater(
        worker.decode('{invalid'),
        throwsA(isA<InvalidBackupFormatException>()),
      );
    },
  );

  test(
    'async decode retains main-isolate validation and executor boundary',
    () async {
      final encoded = await worker.encodeRollback(
        data,
        version: 10,
        exportVersion: null,
        exportDate: exportDate,
      );
      final expected = codec.parse(decodeData(data: encoded));
      final owner = Isolate.current;
      var validated = false;
      var executed = false;
      final preparation =
          await ImportPreparationBuilder<BookmarkBackupData>(
            converter: DataBackupConverter(
              version: 10,
              exportVersion: null,
            ),
            currentVersion: null,
            validator: (parsed) {
              expect(Isolate.current, owner);
              expect(parsed, expected);
              validated = true;
              return true;
            },
          ).prepare(
            encoded,
            (_) => throw StateError('Main-isolate parser must not run'),
            (parsed, context) async {
              expect(Isolate.current, owner);
              expect(parsed, expected);
              executed = true;
            },
            null,
            decode: worker.decode,
          );
      expect(validated, isTrue);
      expect(executed, isFalse);
      await preparation.executeImport();
      expect(executed, isTrue);
    },
  );
}
