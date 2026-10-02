import 'package:equatable/equatable.dart';

import '../models/import_action.dart';
import 'import_plan.dart';
import 'import_preflight.dart';

final class ImportSourceChangeFacts extends Equatable {
  const ImportSourceChangeFacts({
    required this.sourceId,
    this.incomingIds = const {},
    this.existingIds = const {},
    this.identicalIds = const {},
    this.isSingleValue = false,
  });

  final String sourceId;
  final Set<String> incomingIds;
  final Set<String> existingIds;
  final Set<String> identicalIds;
  final bool isSingleValue;

  @override
  List<Object> get props => [
    sourceId,
    incomingIds,
    existingIds,
    identicalIds,
    isSingleValue,
  ];
}

final class ImportChangeSummarizer {
  const ImportChangeSummarizer();

  PlannedChangeSummary summarize({
    required ResolvedImportSource source,
    required ImportSourceChangeFacts facts,
    int additionalCreated = 0,
  }) {
    if (source.action == ImportAction.skip) {
      return PlannedChangeSummary(preserved: facts.existingIds.length);
    }
    if (facts.isSingleValue) {
      return PlannedChangeSummary(updated: 1, created: additionalCreated);
    }
    if (source.action == ImportAction.replace) {
      final shared = facts.incomingIds.intersection(facts.existingIds);
      final unchanged = shared.intersection(facts.identicalIds).length;
      return PlannedChangeSummary(
        created:
            facts.incomingIds.difference(facts.existingIds).length +
            additionalCreated,
        updated: shared.length - unchanged,
        deleted: facts.existingIds.difference(facts.incomingIds).length,
        unchanged: unchanged,
      );
    }

    var created = additionalCreated;
    var updated = 0;
    var preserved = 0;
    var unchanged = 0;
    for (final item in source.items) {
      switch (item.action) {
        case ImportAction.copy:
          created++;
        case ImportAction.update ||
            ImportAction.merge ||
            ImportAction.mergeIntoTarget:
          if (facts.identicalIds.contains(item.id)) {
            unchanged++;
          } else {
            updated++;
          }
        case ImportAction.skip:
          preserved++;
        case ImportAction.replace || ImportAction.configureItems:
          break;
      }
    }
    return PlannedChangeSummary(
      created: created,
      updated: updated,
      preserved: preserved,
      unchanged: unchanged,
    );
  }
}
