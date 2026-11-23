import 'package:boorusama/core/bookmarks/src/data/bookmark_collection_projection.dart';
import 'package:boorusama/core/bookmarks/src/data/legacy_group_codec.dart';
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
  test(
    'first save persists already loaded Details and projection retains them',
    () {
      final site = Uri.parse('http://example.test:8080/install');
      final reference = const ContentReferenceCodec().parse(
        engine: BooruType.danbooru,
        site: site,
        kind: ContentKind.group,
        sourceKey: 'pool:10',
      );
      final details = ContentGroupDetails(
        summary: ContentGroupSummary(reference: reference),
        description: const GroupDescription(
          text: 'Already loaded',
          format: GroupTextFormat.dtext,
        ),
        creators: [CreatorRef(displayName: 'Already loaded creator')],
        tags: GroupTags(
          values: [GroupTag(name: 'native_tag')],
          coverage: MetadataCoverage.partial,
        ),
        sourceDates: GroupSourceDates(createdAt: DateTime.utc(2010)),
      );
      final metadata = testPool(host: site.toString()).copyWith(
        sourceSite: () => site,
        loadedDetails: () => details,
      );
      final record =
          collectionRecordForSave(metadata, id: 12) as ContentGroupBookmark;
      expect(record.snapshot.details!.description, details.description);
      expect(record.snapshot.details!.creators, details.creators);
      expect(record.snapshot.details!.tags, details.tags);
      expect(record.snapshot.details!.sourceDates, details.sourceDates);
      expect(record.snapshot.details!.summary, record.summary);
      final projected = bookmarkCollectionProjection(record, memberships: {})!;
      expect(projected.loadedDetails, record.snapshot.details);
      expect(
        projected.withGroups({poolGroupA}).loadedDetails,
        record.snapshot.details,
      );
      expect(projected.toJson().containsKey('loadedDetails'), isFalse);
      expect(
        CollectionBookmark.fromJson(projected.toJson()).loadedDetails,
        isNull,
      );
    },
  );

  test('loaded Details from another Group cannot be silently discarded', () {
    final site = Uri.parse('https://example.test');
    final metadata = testPool(host: site.toString()).copyWith(
      sourceSite: () => site,
      loadedDetails: () => ContentGroupDetails(
        summary: ContentGroupSummary(
          reference: const ContentReferenceCodec().parse(
            engine: BooruType.danbooru,
            site: site,
            kind: ContentKind.group,
            sourceKey: 'pool:99',
          ),
        ),
      ),
    );
    expect(
      () => collectionRecordForSave(metadata, id: 12),
      throwsFormatException,
    );
  });

  test(
    'partial loaded Details retain cached fields during a metadata refresh',
    () {
      final site = Uri.parse('https://example.test');
      final metadata = testPool(host: site.toString())
          .copyWith(sourceSite: () => site);
      final original =
          collectionRecordForSave(metadata, id: 12) as ContentGroupBookmark;
      final details = ContentGroupDetails(
        summary: original.summary,
        description: const GroupDescription(
          text: 'Previous',
          format: GroupTextFormat.dtext,
        ),
        creators: [CreatorRef(displayName: 'Retained creator')],
        sourceDates: GroupSourceDates(
          createdAt: DateTime.utc(2010),
          updatedAt: DateTime.utc(2011),
        ),
      );
      final previous = original.copyWith(
        snapshot: StoredGroupSnapshot(
          summary: original.summary,
          details: details,
        ),
      );
      final incoming = ContentGroupDetails(
        summary: original.summary,
        description: const GroupDescription(
          text: '',
          format: GroupTextFormat.dtext,
        ),
        sourceDates: GroupSourceDates(updatedAt: DateTime.utc(2012)),
      );
      final refreshed = collectionRecordForSave(
        metadata.copyWith(loadedDetails: () => incoming),
        id: 12,
        previous: previous,
      ) as ContentGroupBookmark;
      expect(refreshed.snapshot.details!.description!.text, '');
      expect(refreshed.snapshot.details!.creators, details.creators);
      expect(
        refreshed.snapshot.details!.sourceDates!.createdAt,
        DateTime.utc(2010),
      );
      expect(
        refreshed.snapshot.details!.sourceDates!.updatedAt,
        DateTime.utc(2012),
      );
    },
  );
  test(
    'legacy encoding fails instead of dropping transient loaded Details',
    () {
      final site = Uri.parse('https://example.test');
      final details = ContentGroupDetails(
        summary: ContentGroupSummary(
          reference: const ContentReferenceCodec().parse(
            engine: BooruType.danbooru,
            site: site,
            kind: ContentKind.group,
            sourceKey: 'pool:10',
          ),
        ),
      );
      final metadata = testPool(host: site.toString())
          .copyWith(loadedDetails: () => details);
      final legacy = LegacyGroupBookmark.fromMetadata(
        id: 2,
        metadata: metadata,
      );
      expect(
        () => const LegacyGroupCodec().encode(legacy),
        throwsFormatException,
      );
      final native =
          collectionRecordForSave(metadata, id: 2) as ContentGroupBookmark;
      expect(
        native.reference.site,
        site,
        reason: 'Already validated Details provide their exact locator',
      );
      expect(native.snapshot.details, details.withSummary(native.summary));
    },
  );
}
