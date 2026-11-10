import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/bookmarks/src/data/stored_group_codec.dart';
import 'package:boorusama/core/bookmarks/src/types/stored_group_snapshot.dart';
import 'package:boorusama/core/content/types.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const references = ContentReferenceCodec();
  final pixiv = references.parse(
    engine: BooruType.pixiv,
    site: Uri.parse('https://www.pixiv.net'),
    kind: ContentKind.group,
    sourceKey: 'work:120',
  );
  final danbooru = references.parse(
    engine: BooruType.danbooru,
    site: Uri.parse('https://danbooru.donmai.us'),
    kind: ContentKind.group,
    sourceKey: 'pool:42',
  );
  final codec = StoredGroupCodec(
    metadata: GroupMetadataCodec(
      dataCodecFor: (engine) =>
          engine == BooruType.pixiv ? const _FixtureEngineCodec() : null,
    ),
  );

  test('Pixiv-shaped cached values survive a nested-map offline roundtrip', () {
    final summary = ContentGroupSummary(
      reference: pixiv,
      title: 'Illustration',
      sourceData: const _FixtureSummary('illustration'),
    );
    final details = ContentGroupDetails(
      summary: summary,
      description: const GroupDescription(
        text: 'Offline caption',
        format: GroupTextFormat.html,
      ),
      creators: [
        CreatorRef(displayName: 'Artist', sourceKey: 'artist:7', account: 'a'),
      ],
      sourceDates: GroupSourceDates(publishedAt: DateTime.utc(2024, 5, 6)),
      tags: GroupTags(
        values: [GroupTag(sourceId: '14', name: 'native tag')],
        coverage: MetadataCoverage.partial,
      ),
      sourceData: const _FixtureDetails(views: null, bookmarks: 0),
    );
    final snapshot = StoredGroupSnapshot(
      summary: summary,
      details: details,
      index: GroupBookmarkIndex(
        tags: const {'member-index-tag'},
        basis: GroupTagIndexBasis.memberUnion,
        coverage: MetadataCoverage.partial,
        coverPolicy: 'safe-fixture-policy',
      ),
    );

    final encoded = codec.encode(snapshot);
    final normalized = _hiveValue(encoded);
    final decoded = codec.decode(normalized);

    expect(decoded, snapshot);
    expect(decoded.summary.sourceData, const _FixtureSummary('illustration'));
    expect(decoded.details!.description!.text, 'Offline caption');
    expect(decoded.details!.creators!.single.sourceKey, 'artist:7');
    expect(
      decoded.details!.sourceData,
      const _FixtureDetails(views: null, bookmarks: 0),
    );
    expect(decoded.details!.tags!.values.single.sourceId, '14');
    expect(decoded.index!.tags, {'member-index-tag'});
    expect(decoded.index!.basis, GroupTagIndexBasis.memberUnion);
    expect((encoded['details']! as Map).containsKey('summary'), isFalse);
    expect(
      encoded.keys,
      unorderedEquals(['schemaVersion', 'summary', 'details', 'index']),
    );
    expect(encoded.keys, isNot(contains('members')));
    expect(encoded.keys, isNot(contains('cursor')));
    expect(encoded.keys, isNot(contains('pages')));
    expect(encoded.keys, isNot(contains('token')));
    expect(encoded.keys, isNot(contains('profile')));
    expect(encoded.keys, isNot(contains('favorite')));
  });

  test('Gallery-shaped source tags stay distinct from member index tags', () {
    final summary = ContentGroupSummary(
      reference: danbooru,
      previewTags: GroupTags(
        values: [GroupTag(sourceId: '721', name: 'source-preview')],
        coverage: MetadataCoverage.partial,
      ),
    );
    final snapshot = StoredGroupSnapshot(
      summary: summary,
      details: ContentGroupDetails(
        summary: summary,
        tags: GroupTags(
          values: [GroupTag(sourceId: '721', name: 'source-native')],
          coverage: MetadataCoverage.complete,
        ),
      ),
      index: GroupBookmarkIndex(
        tags: const {'member-union-only'},
        basis: GroupTagIndexBasis.memberUnion,
        coverage: MetadataCoverage.partial,
      ),
    );
    final decoded = codec.decode(codec.encode(snapshot));

    expect(decoded.details!.tags!.values.single.name, 'source-native');
    expect(decoded.index!.tags, {'member-union-only'});
    expect(decoded.index!.basis, GroupTagIndexBasis.memberUnion);
  });

  test('unknown counts and fields remain unknown, not zero or empty', () {
    final cardOnly = StoredGroupSnapshot(
      summary: ContentGroupSummary(reference: pixiv),
    );
    final decoded = codec.decode(codec.encode(cardOnly));

    expect(decoded.summary.memberCount, isNull);
    expect(decoded.details, isNull);
    expect(decoded.index, isNull);
    expect(decoded.summary.previewTags, isNull);
  });

  test('rejects engine-mismatched and unsupported typed payload versions', () {
    final pixivSummary = ContentGroupSummary(
      reference: pixiv,
      sourceData: const _FixtureSummary('manga'),
    );
    final pixivWire = codec.encode(StoredGroupSnapshot(summary: pixivSummary));
    final pixivSummaryWire = pixivWire['summary']! as Map;
    final danbooruCodec = StoredGroupCodec(
      metadata: GroupMetadataCodec(
        dataCodecFor: (_) => const _FixtureEngineCodec(),
      ),
    );
    expect(
      () => danbooruCodec.decode({
        ...pixivWire,
        'summary': {
          ...pixivSummaryWire,
          'reference': references.encode(danbooru),
        },
      }),
      throwsFormatException,
    );

    final wire = codec.encode(StoredGroupSnapshot(summary: pixivSummary));
    final summaryWire = wire['summary']! as Map;
    final data = summaryWire['sourceData']! as Map;
    expect(
      () => codec.decode({
        ...wire,
        'summary': {
          ...summaryWire,
          'sourceData': {...data, 'schemaVersion': 99},
        },
      }),
      throwsFormatException,
    );
    expect(
      () => codec.decode({...wire, 'schemaVersion': 99}),
      throwsFormatException,
    );
    final withDetails = codec.encode(
      StoredGroupSnapshot(
        summary: pixivSummary,
        details: ContentGroupDetails(
          summary: pixivSummary,
          sourceData: const _FixtureDetails(views: 0, bookmarks: null),
        ),
      ),
    );
    final detailsWire = withDetails['details']! as Map;
    expect(
      () => codec.decode({
        ...withDetails,
        'details': {
          ...detailsWire,
          'sourceData': {
            ...detailsWire['sourceData']! as Map,
            'schemaVersion': 99,
          },
        },
      }),
      throwsFormatException,
    );
  });
}

Object? _hiveValue(Object? value) => switch (value) {
  final Map map => <Object?, Object?>{
    for (final entry in map.entries) entry.key: _hiveValue(entry.value),
  },
  final List list => list.map(_hiveValue).toList(),
  _ => value,
};

@immutable
final class _FixtureSummary implements BooruGroupSummaryData {
  const _FixtureSummary(this.workType);
  final String workType;
  @override
  String get typeKey => 'pixiv.work.summary';
  @override
  int get schemaVersion => 1;
  @override
  bool operator ==(Object other) =>
      other is _FixtureSummary && other.workType == workType;
  @override
  int get hashCode => workType.hashCode;
}

@immutable
final class _FixtureDetails implements BooruGroupDetailsData {
  const _FixtureDetails({required this.views, required this.bookmarks});
  final int? views;
  final int? bookmarks;
  @override
  String get typeKey => 'pixiv.work.details';
  @override
  int get schemaVersion => 1;
  @override
  bool operator ==(Object other) =>
      other is _FixtureDetails &&
      other.views == views &&
      other.bookmarks == bookmarks;
  @override
  int get hashCode => Object.hash(views, bookmarks);
}

final class _FixtureEngineCodec implements BooruGroupDataCodec {
  const _FixtureEngineCodec();
  @override
  BooruType get engine => BooruType.pixiv;
  @override
  Map<String, Object?> encodeSummary(BooruGroupSummaryData data) => {
    'typeKey': data.typeKey,
    'schemaVersion': data.schemaVersion,
    'workType': (data as _FixtureSummary).workType,
  };
  @override
  BooruGroupSummaryData decodeSummary(Map<String, Object?> value) {
    if (value['typeKey'] != 'pixiv.work.summary' ||
        value['schemaVersion'] != 1 ||
        value['workType'] is! String) {
      throw const FormatException('Unsupported synthetic summary');
    }
    return _FixtureSummary(value['workType']! as String);
  }

  @override
  Map<String, Object?> encodeDetails(BooruGroupDetailsData data) => {
    'typeKey': data.typeKey,
    'schemaVersion': data.schemaVersion,
    'views': (data as _FixtureDetails).views,
    'bookmarks': data.bookmarks,
  };
  @override
  BooruGroupDetailsData decodeDetails(Map<String, Object?> value) {
    if (value['typeKey'] != 'pixiv.work.details' ||
        value['schemaVersion'] != 1) {
      throw const FormatException('Unsupported synthetic details');
    }
    return _FixtureDetails(
      views: value['views'] as int?,
      bookmarks: value['bookmarks'] as int?,
    );
  }
}
