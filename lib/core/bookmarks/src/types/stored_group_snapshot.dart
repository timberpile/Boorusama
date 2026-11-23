import 'package:equatable/equatable.dart';

import '../../../content/types.dart';

enum GroupTagIndexBasis { sourceGroup, memberUnion }

final class GroupBookmarkIndex extends Equatable {
  GroupBookmarkIndex({
    required Set<String> tags,
    required this.basis,
    required this.coverage,
    DateTime? oldestMemberUpload,
    DateTime? newestMemberUpload,
    this.coverPolicy,
  }) : tags = Set.unmodifiable(tags),
       oldestMemberUpload = oldestMemberUpload?.toUtc(),
       newestMemberUpload = newestMemberUpload?.toUtc() {
    if (oldestMemberUpload != null &&
        newestMemberUpload != null &&
        oldestMemberUpload.isAfter(newestMemberUpload)) {
      throw const FormatException('Invalid Group member upload bounds');
    }
  }

  final Set<String> tags;
  final GroupTagIndexBasis basis;
  final MetadataCoverage coverage;
  final DateTime? oldestMemberUpload;
  final DateTime? newestMemberUpload;
  final String? coverPolicy;

  @override
  List<Object?> get props => [
    tags,
    basis,
    coverage,
    oldestMemberUpload,
    newestMemberUpload,
    coverPolicy,
  ];
}

/// Export-safe observations only. Saving this value performs no preparation or
/// network request and never embeds a member manifest or a Page snapshot.
final class StoredGroupSnapshot extends Equatable {
  StoredGroupSnapshot({
    this.schemaVersion = 1,
    required this.summary,
    ContentGroupDetails? details,
    this.index,
  }) : details = details?.withSummary(summary) {
    if (schemaVersion != 1) {
      throw const FormatException('Unsupported stored Group schema');
    }
  }

  final int schemaVersion;
  final ContentGroupSummary summary;
  final ContentGroupDetails? details;
  final GroupBookmarkIndex? index;

  StoredGroupSnapshot withSummary(ContentGroupSummary summary) =>
      StoredGroupSnapshot(
        schemaVersion: schemaVersion,
        summary: summary,
        details: details,
        index: index,
      );

  @override
  List<Object?> get props => [schemaVersion, summary, details, index];
}
