import 'package:boorusama/core/bookmarks/src/data/bookmark_collection_projection.dart';
import 'package:boorusama/core/bookmarks/src/types/content_group_bookmark.dart';
import 'package:boorusama/core/bookmarks/src/types/legacy_group_bookmark.dart';
import 'package:boorusama/core/bookmarks/src/types/pool_bookmark.dart';
import 'package:boorusama/core/bookmarks/src/types/stored_group_snapshot.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/content/content_map.dart';
import 'package:boorusama/core/content/types.dart';
import 'package:flutter_test/flutter_test.dart';

import 'pool_bookmark_test_utils.dart';

void main() {
  test('legacy projection derives memberships without inventing a locator', () {
    final metadata = testPool();
    final record = LegacyGroupBookmark.fromMetadata(id: 0, metadata: metadata);
    final date = DateTime.utc(2025, 4);
    final view = bookmarkCollectionProjection(
      record,
      memberships: {poolGroupB: date},
    )!;
    expect(view.bookmarkId, 0);
    expect(view.sourceSite, isNull);
    expect(view.origin, metadata.origin);
    expect(view.groupIds, {poolGroupB});
    expect(view.addedAt, {poolGroupB: date});
    expect(record.metadata.groupIds, isEmpty);
    expect(record.metadata.addedAt, isEmpty);
    expect(view.toJson().containsKey('bookmarkId'), isFalse);
    expect(view.toJson().containsKey('sourceSite'), isFalse);
  });

  test('an explicit installation URL creates a native snapshot with exact transport', () {
    final site = Uri.parse('http://example.test:8080/install');
    final metadata = testPool(host: site.toString())
        .copyWith(sourceSite: () => site);
    final record =
        collectionRecordForSave(metadata, id: 19) as ContentGroupBookmark;
    expect(record.reference.site, site);
    expect(record.reference.sourceKey, 'pool:10');
    expect(record.snapshot.index!.basis, GroupTagIndexBasis.memberUnion);
    expect(record.snapshot.index!.tags, metadata.tags);
    final reloaded = CollectionBookmark.fromJson({
      ...metadata.toJson(),
      'bookmarkId': 123,
      'sourceSite': 'https://untrusted.invalid',
    });
    expect(reloaded.bookmarkId, isNull);
    expect(reloaded.sourceSite, isNull);
    expect(
      collectionRecordForSave(reloaded, id: 20),
      isA<LegacyGroupBookmark>(),
    );
  });

  test(
    'Summary refresh retains loaded Details and original local creation time',
    () {
      final reference = const ContentReferenceCodec().parse(
        engine: BooruType.danbooru,
        site: Uri.parse('http://example.test/install'),
        kind: ContentKind.group,
        sourceKey: 'pool:10',
      );
      final summary = ContentGroupSummary(
        reference: reference,
        title: 'Original',
        previewTags: GroupTags(
          values: [GroupTag(name: 'source_owned')],
          coverage: MetadataCoverage.complete,
        ),
      );
      final details = ContentGroupDetails(
        summary: summary,
        description: const GroupDescription(
          text: 'Retained offline',
          format: GroupTextFormat.plainText,
        ),
        creators: [CreatorRef(displayName: 'Synthetic creator')],
      );
      final original = ContentGroupBookmark(
        id: 7,
        createdAt: DateTime.utc(2020),
        observedAt: DateTime.utc(2025),
        snapshot: StoredGroupSnapshot(summary: summary, details: details),
      );
      final view = bookmarkCollectionProjection(
        original,
        memberships: {poolGroupA: DateTime.utc(2021)},
      )!;
      expect(view.tags, isEmpty, reason: 'Native tags are not a member union');
      final refreshed = CollectionBookmark.fromJson({
        ...view.toJson(),
        'title': 'Updated',
        'observedAt': DateTime.utc(2026).toIso8601String(),
        'createdAt': DateTime.utc(1980).toIso8601String(),
      });
      final saved = collectionRecordForSave(
        refreshed,
        id: 7,
        previous: original,
      ) as ContentGroupBookmark;
      expect(saved.createdAt, original.createdAt);
      expect(saved.reference.site, reference.site);
      expect(saved.summary.title, 'Updated');
      expect(saved.snapshot.details!.description, details.description);
      expect(saved.snapshot.details!.creators, details.creators);
      expect(saved.summary.previewTags, summary.previewTags);
      expect(saved.snapshot.details!.summary, saved.summary);
    },
  );

  test(
    'metadata cannot borrow the engine interpretation of an existing reference',
    () {
      final site = Uri.parse('https://example.test');
      final metadata = testPool(host: site.toString())
          .copyWith(sourceSite: () => site);
      final original = collectionRecordForSave(metadata, id: 1);
      final wire = metadata.toJson();
      wire['origin'] = {
        ...contentMap(wire['origin']),
        'booruTypeId': BooruType.szurubooru.id,
      };
      final incompatible = CollectionBookmark.fromJson(wire);
      expect(
        () => collectionRecordForSave(incompatible, id: 1, previous: original),
        throwsFormatException,
      );
    },
  );
}
