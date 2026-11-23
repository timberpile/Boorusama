import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/content/types.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart';

void main() {
  const references = ContentReferenceCodec();
  final reference = references.parse(
    engine: BooruType.pixiv,
    site: Uri.parse('https://www.pixiv.net'),
    kind: ContentKind.group,
    sourceKey: 'work:120',
  );
  final codec = GroupMetadataCodec(
    dataCodecFor: (engine) =>
        engine == BooruType.pixiv ? const _DataCodec() : null,
  );

  test(
    'unknown and authoritative empty metadata are distinct immutable values',
    () {
      final unknown = ContentGroupDetails(
        summary: ContentGroupSummary(reference: reference),
      );
      final tags = <GroupTag>[];
      final creators = <CreatorRef>[];
      final empty = ContentGroupDetails(
        summary: ContentGroupSummary(reference: reference, memberCount: 0),
        tags: GroupTags(values: tags, coverage: MetadataCoverage.complete),
        creators: creators,
      );
      tags.add(GroupTag(name: 'later'));
      creators.add(CreatorRef(displayName: 'Later'));
      expect(unknown.tags, isNull);
      expect(unknown.creators, isNull);
      expect(unknown.summary.memberCount, isNull);
      expect(empty.summary.memberCount, 0);
      expect(empty.tags!.values, isEmpty);
      expect(empty.creators, isEmpty);
      expect(
        () => empty.creators!.add(CreatorRef(displayName: 'No')),
        throwsUnsupportedError,
      );
      expect(
        () => empty.tags!.values.add(GroupTag(name: 'No')),
        throwsUnsupportedError,
      );
      expect(codec.decodeDetails(codec.encodeDetails(empty)), empty);
      expect(codec.decodeDetails(codec.encodeDetails(unknown)), unknown);
    },
  );

  test(
    'partial Details merge unknown fields but keep authoritative empty values',
    () {
      final summary = ContentGroupSummary(reference: reference);
      final previous = ContentGroupDetails(
        summary: summary,
        description: const GroupDescription(
          text: 'Known',
          format: GroupTextFormat.html,
        ),
        creators: [CreatorRef(displayName: 'Known creator')],
        tags: GroupTags(
          values: [GroupTag(name: 'known')],
          coverage: MetadataCoverage.partial,
        ),
        sourceDates: GroupSourceDates(
          createdAt: DateTime.utc(2020),
          publishedAt: DateTime.utc(2021),
          updatedAt: DateTime.utc(2022),
        ),
        sourceData: const _DetailsData(views: 7),
      );
      final partial = ContentGroupDetails(
        summary: summary,
        creators: const [],
        tags: GroupTags(values: const [], coverage: MetadataCoverage.complete),
        sourceDates: GroupSourceDates(updatedAt: DateTime.utc(2026)),
      );
      final merged = partial.mergeWithPrevious(previous);
      expect(merged.description, previous.description);
      expect(merged.creators, isEmpty);
      expect(merged.tags!.values, isEmpty);
      expect(merged.tags!.coverage, MetadataCoverage.complete);
      expect(merged.sourceData, previous.sourceData);
      expect(merged.sourceDates!.createdAt, DateTime.utc(2020));
      expect(merged.sourceDates!.publishedAt, DateTime.utc(2021));
      expect(merged.sourceDates!.updatedAt, DateTime.utc(2026));
      expect(codec.decodeDetails(codec.encodeDetails(merged)), merged);
      final other = ContentGroupDetails(
        summary: ContentGroupSummary(
          reference: references.parse(
            engine: BooruType.pixiv,
            site: reference.site,
            kind: ContentKind.group,
            sourceKey: 'work:121',
          ),
        ),
      );
      expect(() => partial.mergeWithPrevious(other), throwsFormatException);
    },
  );

  test('Summary refresh retains loaded Details and source-native tags', () {
    final old = ContentGroupDetails(
      summary: ContentGroupSummary(
        reference: reference,
        title: 'Old',
        sourceData: const _SummaryData('manga'),
      ),
      description: const GroupDescription(
        text: '<p>Caption</p>',
        format: GroupTextFormat.html,
      ),
      tags: GroupTags(
        values: [GroupTag(sourceId: '7', name: 'native_tag')],
        coverage: MetadataCoverage.partial,
      ),
      creators: [
        CreatorRef(displayName: 'Artist', sourceKey: '42', account: 'artist'),
      ],
      sourceDates: GroupSourceDates(publishedAt: DateTime.utc(2026, 10, 5)),
      sourceData: const _DetailsData(views: 0),
    );
    final refreshed = old.withSummary(
      ContentGroupSummary(reference: reference, title: 'New'),
    );
    expect(refreshed.summary.title, 'New');
    expect(refreshed.description, old.description);
    expect(refreshed.tags, old.tags);
    expect(refreshed.sourceData, old.sourceData);
    expect(codec.decodeDetails(codec.encodeDetails(refreshed)), refreshed);
    final standalone = codec.encodeDetails(old, includeSummary: false);
    expect(standalone.containsKey('summary'), isFalse);
    expect(codec.decodeDetails(standalone, summary: old.summary), old);
    // Authoritative removal is explicit construction, not universal coalescing.
    expect(ContentGroupDetails(summary: old.summary).description, isNull);
  });

  test(
    'source payload envelopes reject unavailable codecs and future versions',
    () {
      final summary = ContentGroupSummary(
        reference: reference,
        sourceData: const _SummaryData('illustration'),
      );
      final wire = codec.encodeSummary(summary);
      expect(codec.decodeSummary(<Object?, Object?>{...wire}), summary);
      expect(
        () => const GroupMetadataCodec().decodeSummary(wire),
        throwsFormatException,
      );
      expect(
        () => codec.decodeSummary({
          ...wire,
          'sourceData': {
            'typeKey': 'pixiv.work.summary',
            'schemaVersion': 99,
            'workType': 'manga',
          },
        }),
        throwsFormatException,
      );
      expect(
        () => codec.decodeSummary({...wire, 'memberCount': -1}),
        throwsFormatException,
      );
      expect(
        () => codec.decodeSummary({
          ...wire,
          'cover': {'thumbnail': 'file:///tmp/image'},
        }),
        throwsFormatException,
      );
    },
  );

  test(
    'a Pool category observation changes metadata without changing identity',
    () {
      final pool = references.parse(
        engine: BooruType.danbooru,
        site: Uri.parse('https://example.test'),
        kind: ContentKind.group,
        sourceKey: 'pool:42',
      );
      final series = ContentGroupSummary(
        reference: pool,
        displayCategory: 'series',
      );
      final collection = ContentGroupSummary(
        reference: pool,
        displayCategory: 'collection',
      );
      expect(series.reference.identity, collection.reference.identity);
      expect(series, isNot(collection));
      expect(codec.decodeSummary(codec.encodeSummary(collection)), collection);
    },
  );

  test('covers retain only real Post references and immutable representation facts', () {
    final variants = {'thumbnail': 'webp'};
    final page = references.parse(
      engine: BooruType.pixiv,
      site: reference.site,
      kind: ContentKind.post,
      sourceKey: 'work-page:120:2',
    );
    final cover = GroupCover(
      thumbnail: Uri.parse('https://i.example.test/thumb.webp'),
      width: 120,
      height: 180,
      representedPost: page,
      variants: variants,
    );
    variants.clear();
    expect(cover.variants, {'thumbnail': 'webp'});
    final summary = ContentGroupSummary(
      reference: reference,
      cover: cover,
      memberCount: 3,
    );
    expect(codec.decodeSummary(codec.encodeSummary(summary)), summary);
    expect(
      () => GroupCover(thumbnail: cover.thumbnail, width: 0),
      throwsFormatException,
    );
    expect(
      () => GroupCover(thumbnail: cover.thumbnail, height: -1),
      throwsFormatException,
    );
    expect(
      () => GroupCover(thumbnail: cover.thumbnail, representedPost: reference),
      throwsFormatException,
    );
    expect(() => ContentGroupSummary(reference: page), throwsFormatException);
    expect(
      () => ContentGroupSummary(reference: reference, memberCount: -1),
      throwsFormatException,
    );
    expect(() => GroupTag(), throwsFormatException);
  });

  test(
    'Gallery-shaped metadata does not require a new global kind or count unit',
    () {
      final summary = ContentGroupSummary(
        reference: reference,
        title: 'Synthetic Gallery',
        memberCount: 41,
        previewTags: GroupTags(
          values: [GroupTag(sourceId: '721')],
          coverage: MetadataCoverage.partial,
        ),
      );
      final details = ContentGroupDetails(
        summary: summary,
        creators: const [],
        tags: GroupTags(
          values: [
            GroupTag(
              sourceId: '721',
              name: 'fixture_tag',
              category: 'tag',
              displayName: 'Fixture',
            ),
          ],
          coverage: MetadataCoverage.complete,
        ),
      );
      expect(codec.decodeDetails(codec.encodeDetails(details)), details);
      expect(details.summary.reference.kind, ContentKind.group);
      expect(details.tags!.values.single.sourceId, '721');
      expect(details.summary.memberCount, 41);
    },
  );
}

@immutable
final class _SummaryData implements BooruGroupSummaryData {
  const _SummaryData(this.workType);
  final String workType;
  @override
  String get typeKey => 'pixiv.work.summary';
  @override
  int get schemaVersion => 1;
  @override
  bool operator ==(Object other) =>
      other is _SummaryData && other.workType == workType;
  @override
  int get hashCode => workType.hashCode;
}

@immutable
final class _DetailsData implements BooruGroupDetailsData {
  const _DetailsData({this.views, this.bookmarks});
  final int? views;
  final int? bookmarks;
  @override
  String get typeKey => 'pixiv.work.details';
  @override
  int get schemaVersion => 1;
  @override
  bool operator ==(Object other) =>
      other is _DetailsData &&
      other.views == views &&
      other.bookmarks == bookmarks;
  @override
  int get hashCode => Object.hash(views, bookmarks);
}

final class _DataCodec implements BooruGroupDataCodec {
  const _DataCodec();
  @override
  BooruType get engine => BooruType.pixiv;
  @override
  Map<String, Object?> encodeSummary(BooruGroupSummaryData data) => {
    'typeKey': data.typeKey,
    'schemaVersion': data.schemaVersion,
    'workType': (data as _SummaryData).workType,
  };
  @override
  BooruGroupSummaryData decodeSummary(Map<String, Object?> value) {
    if (value['typeKey'] != 'pixiv.work.summary' ||
        value['schemaVersion'] != 1 ||
        value['workType'] is! String) {
      throw const FormatException('Unsupported fixture payload');
    }
    return _SummaryData(value['workType']! as String);
  }

  @override
  Map<String, Object?> encodeDetails(BooruGroupDetailsData data) => {
    'typeKey': data.typeKey,
    'schemaVersion': data.schemaVersion,
    'views': (data as _DetailsData).views,
    'bookmarks': data.bookmarks,
  };
  @override
  BooruGroupDetailsData decodeDetails(Map<String, Object?> value) {
    if (value['typeKey'] != 'pixiv.work.details' ||
        value['schemaVersion'] != 1) {
      throw const FormatException('Unsupported fixture payload');
    }
    return _DetailsData(
      views: value['views'] as int?,
      bookmarks: value['bookmarks'] as int?,
    );
  }
}
