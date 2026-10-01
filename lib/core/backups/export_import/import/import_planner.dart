import '../models/import_action.dart';
import 'import_plan.dart';

final class ImportItemPlanningInput {
  const ImportItemPlanningInput({
    required this.id,
    this.matchingItemId,
    this.compatibleTargetIds = const {},
    this.recommendedAction,
  });

  final String id;
  final String? matchingItemId;
  final Set<String> compatibleTargetIds;
  final ImportAction? recommendedAction;
}

final class ImportSourcePlanningInput {
  const ImportSourcePlanningInput({
    required this.id,
    required this.kind,
    this.selectionComplete = true,
    this.items = const [],
    this.recommendedAction,
  });

  final String id;
  final ImportSourceKind kind;
  final bool selectionComplete;
  final List<ImportItemPlanningInput> items;
  final ImportAction? recommendedAction;
}

final class ImportPlanner {
  const ImportPlanner();

  ProposedImportPlan plan(Iterable<ImportSourcePlanningInput> inputs) {
    final warnings = <ImportPlanIssue>[];
    final sources = <ProposedImportSource>[];
    for (final input in inputs) {
      final sourceActions = switch (input.kind) {
        ImportSourceKind.value => const {
          ImportAction.replace,
          ImportAction.skip,
        },
        ImportSourceKind.collection => {
          if (input.selectionComplete) ImportAction.replace,
          ImportAction.configureItems,
          ImportAction.skip,
        },
      };
      final sourceDefault = _recommendedOrFallback(
        recommendation: input.recommendedAction,
        available: sourceActions,
        fallback: input.kind == ImportSourceKind.collection
            ? ImportAction.configureItems
            : ImportAction.replace,
        onUnsupported: () => warnings.add(
          ImportPlanIssue(
            code: 'unsupported_recommended_action',
            sourceId: input.id,
          ),
        ),
      );
      final items = <ProposedImportItem>[];
      for (final item in input.items) {
        final actions = <ImportAction>{
          if (item.matchingItemId != null) ...{
            ImportAction.update,
            ImportAction.merge,
          },
          if (item.compatibleTargetIds.isNotEmpty) ImportAction.mergeIntoTarget,
          ImportAction.copy,
          ImportAction.skip,
        };
        final itemDefault = _recommendedOrFallback(
          recommendation: item.recommendedAction,
          available: actions,
          fallback: item.matchingItemId == null
              ? ImportAction.copy
              : ImportAction.update,
          onUnsupported: () => warnings.add(
            ImportPlanIssue(
              code: 'unsupported_recommended_action',
              sourceId: input.id,
              itemId: item.id,
            ),
          ),
        );
        items.add(
          ProposedImportItem(
            id: item.id,
            matchingItemId: item.matchingItemId,
            compatibleTargetIds: item.compatibleTargetIds,
            availableActions: actions,
            defaultAction: itemDefault,
          ),
        );
      }
      sources.add(
        ProposedImportSource(
          id: input.id,
          kind: input.kind,
          selectionComplete: input.selectionComplete,
          availableActions: sourceActions,
          defaultAction: sourceDefault,
          items: items,
        ),
      );
    }
    return ProposedImportPlan(sources: sources, warnings: warnings);
  }
}

ImportAction _recommendedOrFallback({
  required ImportAction? recommendation,
  required Set<ImportAction> available,
  required ImportAction fallback,
  required void Function() onUnsupported,
}) {
  if (recommendation == null) return fallback;
  if (available.contains(recommendation)) return recommendation;
  onUnsupported();
  return fallback;
}
