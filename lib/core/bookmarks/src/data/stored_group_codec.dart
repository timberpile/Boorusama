import '../../../content/content_map.dart';
import '../../../content/types.dart';
import '../types/stored_group_snapshot.dart';

final class StoredGroupCodec {
  const StoredGroupCodec({
    GroupMetadataCodec metadata = const GroupMetadataCodec(),
    this.metadataResolver,
  }) : _metadata = metadata;

  final GroupMetadataCodec _metadata;
  final GroupMetadataCodec Function()? metadataResolver;
  GroupMetadataCodec get metadata => metadataResolver?.call() ?? _metadata;

  Map<String, Object?> encode(StoredGroupSnapshot snapshot) => {
    'schemaVersion': snapshot.schemaVersion,
    'summary': metadata.encodeSummary(snapshot.summary),
    if (snapshot.details case final details?)
      'details': metadata.encodeDetails(details, includeSummary: false),
    if (snapshot.index case final index?)
      'index': {
        'tags': index.tags.toList()..sort(),
        'basis': index.basis.name,
        'coverage': index.coverage.name,
        'oldestMemberUpload': ?index.oldestMemberUpload?.toIso8601String(),
        'newestMemberUpload': ?index.newestMemberUpload?.toIso8601String(),
        'coverPolicy': ?index.coverPolicy,
      },
  };

  StoredGroupSnapshot decode(Object? value) {
    try {
      final map = contentMap(value);
      if (map['schemaVersion'] != 1) {
        throw const FormatException('Unsupported stored Group schema');
      }
      final summary = metadata.decodeSummary(map['summary']);
      final index = map['index'] == null ? null : contentMap(map['index']);
      return StoredGroupSnapshot(
        summary: summary,
        details: map['details'] == null
            ? null
            : metadata.decodeDetails(map['details'], summary: summary),
        index: index == null
            ? null
            : GroupBookmarkIndex(
                tags: (index['tags']! as List).map(contentString).toSet(),
                basis: _enum(GroupTagIndexBasis.values, index['basis']),
                coverage: _enum(MetadataCoverage.values, index['coverage']),
                oldestMemberUpload: _date(index['oldestMemberUpload']),
                newestMemberUpload: _date(index['newestMemberUpload']),
                coverPolicy: index['coverPolicy'] as String?,
              ),
      );
      // Hive/JSON maps are untrusted; normalize field-type failures for preflight.
      // ignore: avoid_catching_errors
    } on TypeError {
      throw const FormatException('Invalid stored Group field');
      // ignore: avoid_catching_errors
    } on ArgumentError {
      throw const FormatException('Invalid stored Group field');
    }
  }

  static T _enum<T extends Enum>(List<T> values, Object? value) =>
      values.where((entry) => entry.name == value).firstOrNull ??
      (throw const FormatException('Unsupported stored Group value'));
  static DateTime? _date(Object? value) =>
      value == null ? null : DateTime.parse(contentString(value)).toUtc();
}
