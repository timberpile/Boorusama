import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/bookmarks/src/data/stored_bookmark_codec.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark.dart';
import 'package:boorusama/core/bookmarks/src/types/content_group_bookmark.dart';
import 'package:boorusama/core/bookmarks/src/types/legacy_group_bookmark.dart';
import 'package:boorusama/core/bookmarks/src/types/stored_group_snapshot.dart';
import 'package:boorusama/core/content/types.dart';
import 'package:boorusama/core/posts/related/related_posts_order.dart';
import 'package:flutter_test/flutter_test.dart';

import 'dart:convert';

import 'pool_bookmark_test_utils.dart';

void main() {
  const codec = StoredBookmarkCodec();
  const references = ContentReferenceCodec();
  final created = DateTime.utc(2025);
  final observed = DateTime.utc(2026);
  ContentGroupBookmark group(String key, {int id = 1}) {
    final snapshot = StoredGroupSnapshot(
      summary: ContentGroupSummary(
        reference: references.parse(
          engine: BooruType.danbooru,
          site: Uri.parse('http://example.test:8080/install'),
          kind: ContentKind.group,
          sourceKey: key,
        ),
      ),
    );
    return key.startsWith('related:')
        ? RelatedBookmark(
            id: id,
            snapshot: snapshot,
            createdAt: created,
            observedAt: observed,
            preferredOrder: RelatedPostsOrder.newest,
          )
        : ContentGroupBookmark(
            id: id,
            snapshot: snapshot,
            createdAt: created,
            observedAt: observed,
          );
  }

  test('one tagged array roundtrips Post, native Group, Related and legacy evidence', () {
    final records = <Bookmark>[
      testPoolPost(7).copyWith(id: 0),
      group('pool:42'),
      group('related:99', id: 2),
      LegacyGroupBookmark.fromMetadata(id: 3, metadata: testPool()),
    ];
    final wire = records.map(codec.encode).toList();
    final restored = wire
        .map((value) => codec.decode(<Object?, Object?>{...value}))
        .toList();
    expect(restored, records);
    expect(wire.map((value) => value['kind']), [
      'post',
      'group',
      'related',
      'group',
    ]);
    expect(
      (records.first as PostBookmark).sourceUrl,
      isEmpty,
      reason: 'A semantic namespace cannot reconstruct an HTTP scheme',
    );
    for (final record in wire) {
      expect(record.keys, isNot(contains('groupIds')));
      expect(record.keys, isNot(contains('addedAt')));
    }
    expect(
      (restored[2] as RelatedBookmark).preferredOrder,
      RelatedPostsOrder.newest,
    );
    expect(codec.identityOf(restored[1]), group('pool:42').reference.identity);
    expect(codec.engineOf(restored[1]), BooruType.danbooru);
  });

  test(
    'file-local IDs above the target key range remain data for later mapping',
    () {
      const largeFileId = maxBookmarkId + 10;
      final imported = group('pool:42', id: largeFileId);
      expect(codec.decode(codec.encode(imported)).id, largeFileId);
      expect(imported.copyWith(id: 0).reference, imported.reference);
    },
  );

  test('transfers retain the existing Post source-URL privacy policy', () {
    final post = testPoolPost(7).copyWith(
      sourceUrl: 'https://user:fixture-secret@example.test/posts/7?api_key=fixture-token',
    );
    expect(codec.encode(post)['sourceUrl'], post.sourceUrl);
    final transfer = codec.encodeForTransfer(post);
    expect(transfer.containsKey('sourceUrl'), isFalse);
    expect(jsonEncode(transfer), isNot(contains('fixture-secret')));
    expect(jsonEncode(transfer), isNot(contains('fixture-token')));
    expect((codec.decode(transfer) as PostBookmark).snapshot, post.snapshot);
  });

  test(
    'readable unaddressable Post snapshots remain outside the identity index',
    () {
      final legacy = PostBookmark.empty.copyWith(
        id: 9,
        sourceUrl: '',
        postId: () => null,
      );
      final wire = codec.encode(legacy);
      final restored = codec.decode(wire) as PostBookmark;
      expect(restored.snapshot.toJson(), legacy.snapshot.toJson());
      expect(restored.postId, isNull);
      expect(codec.identityOf(restored), isNull);
      expect(restored.post.origin.sourceHost, isEmpty);
    },
  );

  test(
    'kind conflicts, unsupported order and dual Group payloads are rejected',
    () {
      final related = codec.encode(group('related:99'));
      expect(
        () => codec.decode({...related, 'kind': 'group'}),
        throwsFormatException,
      );
      expect(
        () => codec.decode({...related, 'preferredOrder': 'future-order'}),
        throwsFormatException,
      );
      expect(
        () => codec.decode({
          ...related,
          'legacy': {'version': 1},
        }),
        throwsFormatException,
      );
      expect(
        () => codec.decode({...related, 'kind': 'future-kind'}),
        throwsFormatException,
      );
      final plain = codec.encode(group('pool:42'));
      expect(
        () => codec.decode({...plain, 'preferredOrder': null}),
        throwsFormatException,
      );
      expect(() => codec.decode({...plain, 'id': -1}), throwsFormatException);
      final post = codec.encode(testPoolPost(7));
      expect(() => codec.decode({...post, 'postId': 8}), throwsFormatException);
    },
  );
}
