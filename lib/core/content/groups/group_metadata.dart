import 'package:equatable/equatable.dart';

import '../../boorus/booru/types.dart';
import '../content_reference.dart';

enum MetadataCoverage { unknown, partial, complete }

enum GroupTextFormat { plainText, dtext, html }

abstract interface class BooruGroupSummaryData {
  String get typeKey;
  int get schemaVersion;
}

abstract interface class BooruGroupDetailsData {
  String get typeKey;
  int get schemaVersion;
}

/// An engine owns both payload families, including their version validation.
abstract interface class BooruGroupDataCodec {
  BooruType get engine;
  Map<String, Object?> encodeSummary(BooruGroupSummaryData data);
  BooruGroupSummaryData decodeSummary(Map<String, Object?> value);
  Map<String, Object?> encodeDetails(BooruGroupDetailsData data);
  BooruGroupDetailsData decodeDetails(Map<String, Object?> value);
}

final class GroupCover extends Equatable {
  GroupCover({
    required this.thumbnail,
    this.sample,
    this.original,
    this.width,
    this.height,
    this.representedPost,
    this.visibility,
    Map<String, String> variants = const {},
  }) : variants = Map.unmodifiable(variants) {
    [thumbnail, ?sample, ?original].forEach(validateGroupMetadataUri);
    if ((width != null && width! <= 0) ||
        (height != null && height! <= 0) ||
        (representedPost != null &&
            representedPost!.kind != ContentKind.post)) {
      throw const FormatException('Invalid Group cover');
    }
  }
  final Uri thumbnail;
  final Uri? sample;
  final Uri? original;
  final int? width;
  final int? height;
  final ContentReference? representedPost;
  final GroupCoverVisibility? visibility;
  final Map<String, String> variants;
  @override
  List<Object?> get props => [
    thumbnail,
    sample,
    original,
    width,
    height,
    representedPost,
    visibility,
    variants,
  ];
}

/// Only the selected cover's filtering facts; no member manifest or media bytes.
final class GroupCoverVisibility extends Equatable {
  GroupCoverVisibility({
    required Iterable<String> tags,
    required this.rating,
    required this.deleted,
    required this.banned,
    this.tagCoverage = MetadataCoverage.complete,
  }) : tags = Set.unmodifiable(tags);
  final Set<String> tags;
  final MetadataCoverage tagCoverage;
  final String rating;
  final bool deleted;
  final bool banned;
  Map<String, Object?> toJson() => {
    'tags': tags.toList()..sort(),
    'rating': rating,
    'deleted': deleted,
    'banned': banned,
    'tagCoverage': tagCoverage.name,
  };
  factory GroupCoverVisibility.fromJson(Map<String, dynamic> json) =>
      GroupCoverVisibility(
        tags: (json['tags'] as List).cast<String>(),
        rating: json['rating'] as String,
        deleted: json['deleted'] as bool,
        banned: json['banned'] as bool,
        tagCoverage: json['tagCoverage'] == null
            ? MetadataCoverage.complete
            : MetadataCoverage.values
                      .where((value) => value.name == json['tagCoverage'])
                      .firstOrNull ??
                  MetadataCoverage.unknown,
      );
  @override
  List<Object?> get props => [tags, rating, deleted, banned, tagCoverage];
}

final class GroupDescription extends Equatable {
  const GroupDescription({required this.text, required this.format});
  final String text;
  final GroupTextFormat format;
  @override
  List<Object?> get props => [text, format];
}

final class GroupTags extends Equatable {
  GroupTags({required Iterable<GroupTag> values, required this.coverage})
    : values = List.unmodifiable(values);
  final List<GroupTag> values;
  final MetadataCoverage coverage;
  @override
  List<Object?> get props => [values, coverage];
}

GroupTags? mergeGroupTagObservation(GroupTags? current, GroupTags? previous) {
  if (current == null || current.coverage == MetadataCoverage.unknown)
    return previous ?? current;
  if (previous == null || current.coverage == MetadataCoverage.complete)
    return current;
  Object identity(GroupTag tag) => tag.sourceId == null
      ? ('name', tag.category, tag.name?.toLowerCase())
      : ('id', tag.category, tag.sourceId);
  return GroupTags(
    coverage: MetadataCoverage.partial,
    values: {
      for (final tag in previous.values) identity(tag): tag,
      for (final tag in current.values) identity(tag): tag,
    }.values,
  );
}

final class GroupTag extends Equatable {
  GroupTag({this.sourceId, this.name, this.category, this.displayName}) {
    if ((sourceId == null && name == null) || sourceId == '' || name == '') {
      throw const FormatException('Invalid Group tag');
    }
  }
  final String? sourceId;
  final String? name;
  final String? category;
  final String? displayName;
  @override
  List<Object?> get props => [sourceId, name, category, displayName];
}

final class CreatorRef extends Equatable {
  CreatorRef({
    required this.displayName,
    this.sourceKey,
    this.account,
    this.avatar,
    this.sourceUrl,
  }) {
    if (displayName.trim().isEmpty) {
      throw const FormatException('Invalid creator name');
    }
    if (avatar != null) validateGroupMetadataUri(avatar!);
    if (sourceUrl != null) validateGroupMetadataUri(sourceUrl!);
  }
  final String displayName;
  final String? sourceKey;
  final String? account;
  final Uri? avatar;
  final Uri? sourceUrl;
  @override
  List<Object?> get props => [
    displayName,
    sourceKey,
    account,
    avatar,
    sourceUrl,
  ];
}

final class GroupSourceDates extends Equatable {
  const GroupSourceDates({this.createdAt, this.publishedAt, this.updatedAt});
  final DateTime? createdAt;
  final DateTime? publishedAt;
  final DateTime? updatedAt;
  @override
  List<Object?> get props => [createdAt, publishedAt, updatedAt];
}

/// Metadata URLs are retained facts, never authorization for a request. Unlike
/// installation locators, media URLs may carry a source-owned query string.
void validateGroupMetadataUri(Uri uri) {
  if ((uri.scheme != 'http' && uri.scheme != 'https') ||
      !uri.hasAuthority ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty ||
      uri.hasFragment ||
      uri.port <= 0 ||
      uri.port > 65535 ||
      RegExp(r'[\x00-\x20\x7f\\]').hasMatch(Uri.decodeFull(uri.toString()))) {
    throw const FormatException('Invalid Group metadata URL');
  }
}
