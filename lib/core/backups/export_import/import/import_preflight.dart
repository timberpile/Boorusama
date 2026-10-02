import 'package:equatable/equatable.dart';

import '../models/import_action.dart';
import 'import_plan.dart';

final class PlannedChangeSummary extends Equatable {
  const PlannedChangeSummary({
    this.created = 0,
    this.updated = 0,
    this.deleted = 0,
    this.preserved = 0,
    this.unchanged = 0,
  });

  final int created;
  final int updated;
  final int deleted;
  final int preserved;
  final int unchanged;

  bool get hasMutations => created > 0 || updated > 0 || deleted > 0;

  PlannedChangeSummary operator +(PlannedChangeSummary other) =>
      PlannedChangeSummary(
        created: created + other.created,
        updated: updated + other.updated,
        deleted: deleted + other.deleted,
        preserved: preserved + other.preserved,
        unchanged: unchanged + other.unchanged,
      );

  @override
  List<Object?> get props => [created, updated, deleted, preserved, unchanged];
}

final class SourcePreflightSnapshot extends Equatable {
  SourcePreflightSnapshot({
    required this.sourceId,
    required this.revisionToken,
    this.summary = const PlannedChangeSummary(),
    Iterable<ImportPlanIssue> warnings = const [],
    Iterable<ImportPlanIssue> errors = const [],
    this.rollbackBytes = 0,
  }) : warnings = List.unmodifiable(warnings),
       errors = List.unmodifiable(errors);

  final String sourceId;
  final String revisionToken;
  final PlannedChangeSummary? summary;
  final List<ImportPlanIssue> warnings;
  final List<ImportPlanIssue> errors;
  final int rollbackBytes;

  @override
  List<Object?> get props => [
    sourceId,
    revisionToken,
    summary,
    warnings,
    errors,
    rollbackBytes,
  ];
}

final class ValidatedImportPlan extends Equatable {
  ValidatedImportPlan({
    required this.plan,
    required Map<String, String> revisionTokens,
    required this.summary,
  }) : revisionTokens = Map.unmodifiable(revisionTokens);

  final ResolvedImportPlan plan;
  final Map<String, String> revisionTokens;
  final PlannedChangeSummary summary;

  @override
  List<Object?> get props => [plan, revisionTokens, summary];
}

final class ImportPreflightResult extends Equatable {
  ImportPreflightResult({
    required Iterable<ImportPlanIssue> warnings,
    required Iterable<ImportPlanIssue> errors,
    required this.summary,
    Map<String, PlannedChangeSummary> sourceSummaries = const {},
    this.validatedPlan,
  }) : warnings = List.unmodifiable(warnings),
       errors = List.unmodifiable(errors),
       sourceSummaries = Map.unmodifiable(sourceSummaries);

  final List<ImportPlanIssue> warnings;
  final List<ImportPlanIssue> errors;
  final PlannedChangeSummary summary;
  final Map<String, PlannedChangeSummary> sourceSummaries;
  final ValidatedImportPlan? validatedPlan;

  bool get isValid => errors.isEmpty && validatedPlan != null;
  bool get requiresWarningAcknowledgement =>
      warnings.isNotEmpty && summary.hasMutations;

  @override
  List<Object?> get props => [
    warnings,
    errors,
    summary,
    sourceSummaries,
    validatedPlan,
  ];
}

final class ImportPreflight {
  const ImportPreflight();

  ImportPreflightResult validate({
    required ProposedImportPlan proposed,
    required ResolvedImportPlan resolved,
    required Iterable<SourcePreflightSnapshot> sources,
    required int availableBytes,
    required int stagingBytes,
    required bool warningsAcknowledged,
  }) {
    final warnings = [...proposed.warnings];
    final errors = [...proposed.errors];
    var summary = const PlannedChangeSummary();
    final sourceSummaries = <String, PlannedChangeSummary>{};
    final revisions = <String, String>{};
    var rollbackBytes = 0;

    final resolvedById = {
      for (final source in resolved.sources) source.id: source,
    };
    final selectedSourceIds = <String>{};
    for (final source in proposed.sources) {
      final resolution = resolvedById[source.id];
      if (resolution == null ||
          !source.availableActions.contains(resolution.action)) {
        errors.add(
          ImportPlanIssue(code: 'invalid_source_action', sourceId: source.id),
        );
        continue;
      }
      if (resolution.action != ImportAction.skip) {
        selectedSourceIds.add(source.id);
      }
      final items = {for (final item in source.items) item.id: item};
      for (final itemResolution in resolution.items) {
        final item = items[itemResolution.id];
        if (item == null ||
            !item.availableActions.contains(itemResolution.action)) {
          errors.add(
            ImportPlanIssue(
              code: 'invalid_item_action',
              sourceId: source.id,
              itemId: itemResolution.id,
            ),
          );
          continue;
        }
        if (itemResolution.action == ImportAction.mergeIntoTarget &&
            !item.compatibleTargetIds.contains(itemResolution.targetId)) {
          errors.add(
            ImportPlanIssue(
              code: 'invalid_merge_target',
              sourceId: source.id,
              itemId: itemResolution.id,
            ),
          );
        }
        if (item.targetRequiredActions.contains(itemResolution.action) &&
            !item.compatibleTargetIds.contains(itemResolution.targetId)) {
          errors.add(
            ImportPlanIssue(
              code: 'unresolved_item_target',
              sourceId: source.id,
              itemId: itemResolution.id,
            ),
          );
        }
      }
    }

    for (final source in sources) {
      warnings.addAll(source.warnings);
      errors.addAll(source.errors);
      if (source.summary case final sourceSummary?) {
        summary += sourceSummary;
        sourceSummaries[source.sourceId] = sourceSummary;
      }
      rollbackBytes += source.rollbackBytes;
      if (revisions[source.sourceId] != null) {
        errors.add(
          ImportPlanIssue(
            code: 'duplicate_source_preflight',
            sourceId: source.sourceId,
          ),
        );
      }
      revisions[source.sourceId] = source.revisionToken;
    }
    for (final sourceId in selectedSourceIds.difference(
      revisions.keys.toSet(),
    )) {
      errors.add(
        ImportPlanIssue(
          code: 'missing_source_preflight',
          sourceId: sourceId,
        ),
      );
    }
    if (stagingBytes + rollbackBytes > availableBytes) {
      errors.add(
        const ImportPlanIssue(
          code: 'insufficient_storage',
          sourceId: 'package',
        ),
      );
    }
    if (warnings.isNotEmpty && summary.hasMutations && !warningsAcknowledged) {
      errors.add(
        const ImportPlanIssue(
          code: 'warnings_not_acknowledged',
          sourceId: 'package',
        ),
      );
    }
    return ImportPreflightResult(
      warnings: warnings,
      errors: errors,
      summary: summary,
      sourceSummaries: sourceSummaries,
      validatedPlan: errors.isEmpty
          ? ValidatedImportPlan(
              plan: resolved,
              revisionTokens: revisions,
              summary: summary,
            )
          : null,
    );
  }
}
