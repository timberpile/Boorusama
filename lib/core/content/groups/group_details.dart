import 'package:equatable/equatable.dart';

import '../content_reference.dart';
import 'group_metadata.dart';
import 'group_summary.dart';

final class ContentGroupDetails extends Equatable {
  ContentGroupDetails({
    required this.summary,
    this.description,
    Iterable<CreatorRef>? creators,
    this.tags,
    this.sourceDates,
    this.sourceData,
  }) : creators = creators == null ? null : List.unmodifiable(creators);

  final ContentGroupSummary summary;
  final GroupDescription? description;
  final List<CreatorRef>? creators;
  final GroupTags? tags;
  final GroupSourceDates? sourceDates;
  final BooruGroupDetailsData? sourceData;

  /// A Summary-only observation cannot erase previously loaded Details.
  /// Authoritative source deletions use an explicit new Details value.
  ContentGroupDetails withSummary(ContentGroupSummary updated) {
    const ContentReferenceCodec().requireCompatible(
      summary.reference,
      updated.reference,
    );
    return ContentGroupDetails(
      summary: updated,
      description: description,
      creators: creators,
      tags: tags,
      sourceDates: sourceDates,
      sourceData: sourceData,
    );
  }

  /// Partial observations retain unknown fields. Known empty values replace
  /// their previous value; authoritative removal bypasses this merge.
  ContentGroupDetails mergeWithPrevious(ContentGroupDetails? previous) {
    if (previous == null) return this;
    const ContentReferenceCodec().requireCompatible(
      previous.summary.reference,
      summary.reference,
    );
    final dates = sourceDates;
    final oldDates = previous.sourceDates;
    return ContentGroupDetails(
      summary: summary,
      description: description ?? previous.description,
      creators: creators ?? previous.creators,
      tags: tags ?? previous.tags,
      sourceDates: dates == null
          ? oldDates
          : GroupSourceDates(
              createdAt: dates.createdAt ?? oldDates?.createdAt,
              publishedAt: dates.publishedAt ?? oldDates?.publishedAt,
              updatedAt: dates.updatedAt ?? oldDates?.updatedAt,
            ),
      sourceData: sourceData ?? previous.sourceData,
    );
  }

  @override
  List<Object?> get props => [
    summary,
    description,
    creators,
    tags,
    sourceDates,
    sourceData,
  ];
}
