import '../../boorus/booru/types.dart';
import '../content_map.dart';
import '../content_reference.dart';
import 'group_details.dart';
import 'group_metadata.dart';
import 'group_summary.dart';

/// Common export-safe metadata. Engine payload validation remains with the
/// registered engine codec; an unavailable network reader is irrelevant here.
final class GroupMetadataCodec {
  const GroupMetadataCodec({
    this.references = const ContentReferenceCodec(),
    this.dataCodecFor,
  });
  final ContentReferenceCodec references;
  final BooruGroupDataCodec? Function(BooruType engine)? dataCodecFor;

  Map<String, Object?> encodeSummary(ContentGroupSummary summary) => {
    'reference': references.encode(summary.reference),
    'title': ?summary.title,
    'cover': ?switch (summary.cover) {
      final cover? => _encodeCover(cover),
      _ => null,
    },
    'memberCount': ?summary.memberCount,
    'displayCategory': ?summary.displayCategory,
    'previewTags': ?switch (summary.previewTags) {
      final tags? => _encodeTags(tags),
      _ => null,
    },
    'sourceData': ?switch (summary.sourceData) {
      final data? => _encodeSummaryData(summary.reference.engine, data),
      _ => null,
    },
  };

  ContentGroupSummary decodeSummary(Object? value) => _decode(() {
    final map = contentMap(value);
    final reference = references.decode(map['reference']);
    return ContentGroupSummary(
      reference: reference,
      title: map['title'] as String?,
      cover: map['cover'] == null ? null : _decodeCover(map['cover']),
      memberCount: map['memberCount'] as int?,
      displayCategory: map['displayCategory'] as String?,
      previewTags: map['previewTags'] == null
          ? null
          : _decodeTags(map['previewTags']),
      sourceData: map['sourceData'] == null
          ? null
          : _decodeSummaryData(reference.engine, map['sourceData']),
    );
  });

  Map<String, Object?> encodeDetails(
    ContentGroupDetails details, {
    bool includeSummary = true,
  }) => {
    if (includeSummary) 'summary': encodeSummary(details.summary),
    'description': ?switch (details.description) {
      final value? => {'text': value.text, 'format': value.format.name},
      _ => null,
    },
    'creators': ?details.creators
        ?.map(
          (value) => {
            'displayName': value.displayName,
            'sourceKey': ?value.sourceKey,
            'account': ?value.account,
            'avatar': ?value.avatar?.toString(),
            'sourceUrl': ?value.sourceUrl?.toString(),
          },
        )
        .toList(),
    'tags': ?switch (details.tags) {
      final tags? => _encodeTags(tags),
      _ => null,
    },
    'sourceDates': ?switch (details.sourceDates) {
      final dates? => {
        'createdAt': ?dates.createdAt?.toUtc().toIso8601String(),
        'publishedAt': ?dates.publishedAt?.toUtc().toIso8601String(),
        'updatedAt': ?dates.updatedAt?.toUtc().toIso8601String(),
      },
      _ => null,
    },
    'sourceData': ?switch (details.sourceData) {
      final data? => _encodeDetailsData(details.summary.reference.engine, data),
      _ => null,
    },
  };

  ContentGroupDetails decodeDetails(
    Object? value, {
    ContentGroupSummary? summary,
  }) => _decode(() {
    final map = contentMap(value);
    if (summary != null && map.containsKey('summary')) {
      throw const FormatException('Duplicate Group summary');
    }
    final actualSummary = summary ?? decodeSummary(map['summary']);
    final description = map['description'] == null
        ? null
        : contentMap(map['description']);
    final dates = map['sourceDates'] == null
        ? null
        : contentMap(map['sourceDates']);
    return ContentGroupDetails(
      summary: actualSummary,
      description: description == null
          ? null
          : GroupDescription(
              text: description['text']! as String,
              format: _enum(GroupTextFormat.values, description['format']),
            ),
      creators: (map['creators'] as List?)?.map((item) {
        final row = contentMap(item);
        return CreatorRef(
          displayName: contentString(row['displayName']),
          sourceKey: row['sourceKey'] as String?,
          account: row['account'] as String?,
          avatar: _uri(row['avatar']),
          sourceUrl: _uri(row['sourceUrl']),
        );
      }),
      tags: map['tags'] == null ? null : _decodeTags(map['tags']),
      sourceDates: dates == null
          ? null
          : GroupSourceDates(
              createdAt: _date(dates['createdAt']),
              publishedAt: _date(dates['publishedAt']),
              updatedAt: _date(dates['updatedAt']),
            ),
      sourceData: map['sourceData'] == null
          ? null
          : _decodeDetailsData(
              actualSummary.reference.engine,
              map['sourceData'],
            ),
    );
  });

  Map<String, Object?> _encodeCover(GroupCover cover) => {
    'thumbnail': cover.thumbnail.toString(),
    'sample': ?cover.sample?.toString(),
    'original': ?cover.original?.toString(),
    'width': ?cover.width,
    'height': ?cover.height,
    'representedPost': ?switch (cover.representedPost) {
      final post? => references.encode(post),
      _ => null,
    },
    'variants': cover.variants,
  };
  GroupCover _decodeCover(Object? value) {
    final map = contentMap(value);
    return GroupCover(
      thumbnail: Uri.parse(contentString(map['thumbnail'])),
      sample: _uri(map['sample']),
      original: _uri(map['original']),
      width: map['width'] as int?,
      height: map['height'] as int?,
      representedPost: map['representedPost'] == null
          ? null
          : references.decode(map['representedPost']),
      variants: map['variants'] == null
          ? const {}
          : contentMap(map['variants'])
                .map((key, value) => MapEntry(key, value! as String)),
    );
  }

  Map<String, Object?> _encodeTags(GroupTags tags) => {
    'coverage': tags.coverage.name,
    'values': tags.values
        .map(
          (value) => {
            'sourceId': ?value.sourceId,
            'name': ?value.name,
            'category': ?value.category,
            'displayName': ?value.displayName,
          },
        )
        .toList(),
  };
  GroupTags _decodeTags(Object? value) {
    final map = contentMap(value);
    return GroupTags(
      coverage: _enum(MetadataCoverage.values, map['coverage']),
      values: (map['values']! as List).map((item) {
        final row = contentMap(item);
        return GroupTag(
          sourceId: row['sourceId'] as String?,
          name: row['name'] as String?,
          category: row['category'] as String?,
          displayName: row['displayName'] as String?,
        );
      }),
    );
  }

  BooruGroupDataCodec _codec(BooruType engine) {
    final codec = dataCodecFor?.call(engine);
    if (codec == null || codec.engine != engine) {
      throw const FormatException('Unavailable Group data codec');
    }
    return codec;
  }

  Map<String, Object?> _encodeSummaryData(
    BooruType engine,
    BooruGroupSummaryData data,
  ) {
    final map = _codec(engine).encodeSummary(data);
    _requirePayload(map, data.typeKey, data.schemaVersion);
    return map;
  }

  Map<String, Object?> _encodeDetailsData(
    BooruType engine,
    BooruGroupDetailsData data,
  ) {
    final map = _codec(engine).encodeDetails(data);
    _requirePayload(map, data.typeKey, data.schemaVersion);
    return map;
  }

  BooruGroupSummaryData _decodeSummaryData(BooruType engine, Object? value) {
    final map = contentMap(value);
    final data = _codec(engine).decodeSummary(map);
    _requirePayload(map, data.typeKey, data.schemaVersion);
    return data;
  }

  BooruGroupDetailsData _decodeDetailsData(BooruType engine, Object? value) {
    final map = contentMap(value);
    final data = _codec(engine).decodeDetails(map);
    _requirePayload(map, data.typeKey, data.schemaVersion);
    return data;
  }

  static void _requirePayload(
    Map<String, Object?> map,
    String typeKey,
    int version,
  ) {
    if (typeKey.isEmpty ||
        version < 1 ||
        map['typeKey'] != typeKey ||
        map['schemaVersion'] != version) {
      throw const FormatException('Incompatible Group data payload');
    }
  }

  static T _enum<T extends Enum>(List<T> values, Object? value) =>
      values.where((item) => item.name == value).firstOrNull ??
      (throw const FormatException('Unsupported Group metadata value'));
  static Uri? _uri(Object? value) =>
      value == null ? null : Uri.parse(contentString(value));
  static DateTime? _date(Object? value) =>
      value == null ? null : DateTime.parse(contentString(value)).toUtc();
  static T _decode<T>(T Function() decode) {
    try {
      return decode();
      // Casts and URI decoding are an untrusted wire boundary. Normalize their
      // runtime failures so preflight can reject the whole record without writes.
      // ignore: avoid_catching_errors
    } on TypeError {
      throw const FormatException('Invalid Group metadata field');
      // ignore: avoid_catching_errors
    } on ArgumentError {
      throw const FormatException('Invalid Group metadata field');
    }
  }
}
