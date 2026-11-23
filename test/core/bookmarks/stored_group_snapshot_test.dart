import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/bookmarks/src/data/stored_group_codec.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark.dart';
import 'package:boorusama/core/bookmarks/src/types/content_group_bookmark.dart';
import 'package:boorusama/core/bookmarks/src/types/stored_group_snapshot.dart';
import 'package:boorusama/core/content/types.dart';
import 'package:boorusama/core/posts/related/related_posts_order.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const references = ContentReferenceCodec();
  final reference = references.parse(
    engine: BooruType.danbooru,
    site: Uri.parse('http://example.test:8080/install'),
    kind: ContentKind.group,
    sourceKey: 'pool:42',
  );
  const codec = StoredGroupCodec();

  test(
    'offline snapshot stores loaded details and Summary once without members',
    () {
      final summary = ContentGroupSummary(
        reference: reference,
        title: 'List title',
      );
      final details = ContentGroupDetails(
        summary: summary,
        description: const GroupDescription(
          text: 'Loaded caption',
          format: GroupTextFormat.dtext,
        ),
        creators: [CreatorRef(displayName: 'Creator')],
        tags: GroupTags(
          values: [GroupTag(name: 'native')],
          coverage: MetadataCoverage.complete,
        ),
      );
      final snapshot = StoredGroupSnapshot(
        summary: summary,
        details: details,
        index: GroupBookmarkIndex(
          tags: const {'sampled'},
          basis: GroupTagIndexBasis.memberUnion,
          coverage: MetadataCoverage.partial,
          oldestMemberUpload: DateTime.utc(2025),
          newestMemberUpload: DateTime.utc(2026),
          coverPolicy: 'fixture-policy',
        ),
      );
      final wire = codec.encode(snapshot);
      expect(wire['schemaVersion'], 1);
      expect((wire['details']! as Map).containsKey('summary'), isFalse);
      expect(
        wire.keys,
        unorderedEquals(['schemaVersion', 'summary', 'details', 'index']),
      );
      expect(codec.decode(<Object?, Object?>{...wire}), snapshot);
      expect(snapshot.details!.tags!.values.single.name, 'native');
      expect(snapshot.index!.tags, {'sampled'});
      final cardOnly = StoredGroupSnapshot(summary: summary);
      expect(codec.decode(codec.encode(cardOnly)).details, isNull);
      expect(cardOnly.summary.memberCount, isNull);
      final updated = snapshot.withSummary(
        ContentGroupSummary(reference: reference, title: 'New'),
      );
      expect(updated.details!.description, details.description);
      expect(updated.details!.summary, updated.summary);
      expect(codec.decode(codec.encode(updated)), updated);
      expect(() => snapshot.index!.tags.add('later'), throwsUnsupportedError);
    },
  );

  test(
    'malformed, incompatible and unsupported snapshots fail before writes',
    () {
      final summary = ContentGroupSummary(reference: reference);
      final wire = codec.encode(StoredGroupSnapshot(summary: summary));
      expect(
        () => codec.decode({...wire, 'schemaVersion': 2}),
        throwsFormatException,
      );
      expect(
        () => codec.decode({
          ...wire,
          'index': {'tags': 3},
        }),
        throwsFormatException,
      );
      final other = references.parse(
        engine: reference.engine,
        site: reference.site,
        kind: ContentKind.group,
        sourceKey: 'pool:43',
      );
      expect(
        () => StoredGroupSnapshot(
          summary: summary,
          details: ContentGroupDetails(
            summary: ContentGroupSummary(reference: other),
          ),
        ),
        throwsFormatException,
      );
      expect(
        () => GroupBookmarkIndex(
          tags: const {},
          basis: GroupTagIndexBasis.memberUnion,
          coverage: MetadataCoverage.unknown,
          oldestMemberUpload: DateTime.utc(2026),
          newestMemberUpload: DateTime.utc(2025),
        ),
        throwsFormatException,
      );
      expect(
        () => codec.decode({
          ...wire,
          'summary': {
            ...wire['summary']! as Map,
            'sourceData': {'typeKey': 'future', 'schemaVersion': 99},
          },
        }),
        throwsFormatException,
      );
    },
  );

  test(
    'Group records derive identity and Related alone retains nullable order',
    () {
      final snapshot = StoredGroupSnapshot(
        summary: ContentGroupSummary(reference: reference),
      );
      final group = ContentGroupBookmark(
        id: 0,
        snapshot: snapshot,
        createdAt: DateTime.utc(2025),
        observedAt: DateTime.utc(2026),
      );
      final Bookmark saved = group;
      expect(saved.id, 0);
      expect(group.reference, same(group.snapshot.summary.reference));
      expect(group.summary, same(group.snapshot.summary));
      expect(group.copyWith(snapshot: snapshot).createdAt, group.createdAt);
      expect(
        () => RelatedBookmark(
          id: 1,
          snapshot: snapshot,
          createdAt: group.createdAt,
          observedAt: group.observedAt,
        ),
        throwsFormatException,
      );
      final relatedReference = references.parse(
        engine: reference.engine,
        site: reference.site,
        kind: ContentKind.group,
        sourceKey: 'related:42',
      );
      final related = RelatedBookmark(
        id: 1,
        snapshot: StoredGroupSnapshot(
          summary: ContentGroupSummary(reference: relatedReference),
        ),
        createdAt: group.createdAt,
        observedAt: group.observedAt,
      );
      expect(related.preferredOrder, isNull);
      final ordered = related.copyWith(
        preferredOrder: () => RelatedPostsOrder.oldest,
      );
      expect(ordered.preferredOrder, RelatedPostsOrder.oldest);
      expect(
        ordered.copyWith(snapshot: ordered.snapshot).preferredOrder,
        ordered.preferredOrder,
      );
    },
  );
}
