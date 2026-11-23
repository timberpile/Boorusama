import 'package:boorusama/core/bookmarks/src/data/legacy_group_codec.dart';
import 'package:boorusama/core/bookmarks/src/types/legacy_group_bookmark.dart';
import 'package:boorusama/core/bookmarks/src/types/stored_group_snapshot.dart';
import 'package:boorusama/core/bookmarks/types.dart';
import 'package:boorusama/core/content/types.dart';
import 'package:boorusama/core/posts/related/related_family.dart';
import 'package:boorusama/core/posts/related/related_posts_order.dart';
import 'package:flutter_test/flutter_test.dart';

import 'pool_bookmark_test_utils.dart';

void main() {
  const codec = LegacyGroupCodec();
  test('legacy scheme evidence stays missing while membership authority is removed', () {
    final old = testPool(groups: {poolGroupA, poolGroupB});
    final saved = LegacyGroupBookmark.fromMetadata(id: 0, metadata: old);
    expect(saved.metadata.groupIds, isEmpty);
    expect(saved.metadata.addedAt, isEmpty);
    expect(saved.identity!.sourceKey, 'pool:10');
    expect(saved.index.basis, GroupTagIndexBasis.memberUnion);
    expect(saved.index.coverage, MetadataCoverage.partial);
    final encoded = codec.encode(saved);
    final metadata = encoded['metadata']! as Map;
    expect(metadata.keys, isNot(contains('groupIds')));
    expect(metadata.keys, isNot(contains('addedAt')));
    expect(metadata.keys, isNot(contains('site')));
    final decoded = codec.decode(
      <Object?, Object?>{...encoded},
      id: 0,
      createdAt: saved.createdAt,
      observedAt: saved.observedAt,
    );
    expect(decoded, saved);
    expect(
      decoded
          .tryReferenceForProvenSite(Uri.parse('http://danbooru.donmai.us'))!
          .site
          .scheme,
      'http',
    );
    expect(
      decoded.tryReferenceForProvenSite(Uri.parse('https://unrelated.test')),
      isNull,
    );
  });

  test('only retained Related records carry their nullable order', () {
    final raw = RelatedCollectionBookmark(
      family: RelatedFamilyReference(origin: poolOrigin(), anchorId: 99),
      localId: 'old',
      createdAt: DateTime.utc(2025),
      observedAt: DateTime.utc(2026),
      groupIds: const {poolGroupA},
    );
    final saved = LegacyGroupBookmark.fromMetadata(
      id: 1,
      metadata: raw,
      preferredOrder: RelatedPostsOrder.newest,
    );
    expect(saved, isA<LegacyRelatedGroupBookmark>());
    final decoded = codec.decode(
      codec.encode(saved),
      id: saved.id,
      createdAt: saved.createdAt,
      observedAt: saved.observedAt,
      preferredOrder: RelatedPostsOrder.newest,
    );
    expect(decoded, saved);
    expect(
      (decoded as LegacyRelatedGroupBookmark).preferredOrder,
      RelatedPostsOrder.newest,
    );
    expect(
      () => LegacyGroupBookmark.fromMetadata(
        id: 2,
        metadata: testPool(),
        preferredOrder: RelatedPostsOrder.oldest,
      ),
      throwsFormatException,
    );
  });

  test('unknown legacy engine evidence is retained without semantic or access proof', () {
    final saved = LegacyGroupBookmark.fromMetadata(id: 0, metadata: testPool());
    final wire = codec.encode(saved);
    final metadata = wire['metadata']! as Map;
    final origin = metadata['origin']! as Map;
    final unknown = codec.decode(
      {
        ...wire,
        'metadata': {
          ...metadata,
          'origin': {...origin, 'booruTypeId': 999},
        },
      },
      id: 0,
      createdAt: saved.createdAt,
      observedAt: saved.observedAt,
    );
    expect(unknown.metadata.sourceTypeId, 999);
    expect(unknown.identity, isNull);
    expect(
      unknown.tryReferenceForProvenSite(
        Uri.parse('https://danbooru.donmai.us'),
      ),
      isNull,
    );
    final encoded = codec.encode(unknown)['metadata']! as Map;
    expect((encoded['origin']! as Map)['booruTypeId'], 999);
  });

  test(
    'unsupported envelopes and embedded local authority fail structurally',
    () {
      final saved = LegacyGroupBookmark.fromMetadata(
        id: 0,
        metadata: testPool(),
      );
      final wire = codec.encode(saved);
      expect(
        () => codec.decode(
          {...wire, 'version': 2},
          id: 0,
          createdAt: saved.createdAt,
          observedAt: saved.observedAt,
        ),
        throwsFormatException,
      );
      expect(
        () => codec.decode(
          {
            ...wire,
            'metadata': {
              ...wire['metadata']! as Map,
              'groupIds': [poolGroupA],
            },
          },
          id: 0,
          createdAt: saved.createdAt,
          observedAt: saved.observedAt,
        ),
        throwsFormatException,
      );
    },
  );
}
