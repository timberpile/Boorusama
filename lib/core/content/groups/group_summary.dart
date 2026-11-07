import 'package:equatable/equatable.dart';

import '../content_reference.dart';
import 'group_metadata.dart';

final class ContentGroupSummary extends Equatable {
  ContentGroupSummary({
    required this.reference,
    this.title,
    this.cover,
    this.memberCount,
    this.displayCategory,
    this.previewTags,
    this.sourceData,
  }) {
    if (reference.kind != ContentKind.group ||
        (memberCount != null && memberCount! < 0)) {
      throw const FormatException('Invalid Group summary');
    }
  }
  final ContentReference reference;
  final String? title;
  final GroupCover? cover;
  final int? memberCount;
  final String? displayCategory;
  final GroupTags? previewTags;
  final BooruGroupSummaryData? sourceData;
  @override
  List<Object?> get props => [
    reference,
    title,
    cover,
    memberCount,
    displayCategory,
    previewTags,
    sourceData,
  ];
}
