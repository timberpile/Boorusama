import 'package:equatable/equatable.dart';

import '../models/import_action.dart';

enum ImportSourceKind { value, collection }

final class ImportPlanIssue extends Equatable {
  const ImportPlanIssue({
    required this.code,
    required this.sourceId,
    this.itemId,
  });

  final String code;
  final String sourceId;
  final String? itemId;

  @override
  List<Object?> get props => [code, sourceId, itemId];
}

final class ProposedImportItem extends Equatable {
  ProposedImportItem({
    required this.id,
    required Iterable<ImportAction> availableActions,
    required this.defaultAction,
    required Iterable<String> compatibleTargetIds,
    this.matchingItemId,
  }) : availableActions = Set.unmodifiable(availableActions),
       compatibleTargetIds = Set.unmodifiable(compatibleTargetIds);

  final String id;
  final String? matchingItemId;
  final Set<String> compatibleTargetIds;
  final Set<ImportAction> availableActions;
  final ImportAction defaultAction;

  @override
  List<Object?> get props => [
    id,
    matchingItemId,
    compatibleTargetIds,
    availableActions,
    defaultAction,
  ];
}

final class ProposedImportSource extends Equatable {
  ProposedImportSource({
    required this.id,
    required this.kind,
    required this.selectionComplete,
    required Iterable<ImportAction> availableActions,
    required this.defaultAction,
    required Iterable<ProposedImportItem> items,
  }) : availableActions = Set.unmodifiable(availableActions),
       items = List.unmodifiable(items);

  final String id;
  final ImportSourceKind kind;
  final bool selectionComplete;
  final Set<ImportAction> availableActions;
  final ImportAction defaultAction;
  final List<ProposedImportItem> items;

  @override
  List<Object?> get props => [
    id,
    kind,
    selectionComplete,
    availableActions,
    defaultAction,
    items,
  ];
}

final class ProposedImportPlan extends Equatable {
  ProposedImportPlan({
    required Iterable<ProposedImportSource> sources,
    Iterable<ImportPlanIssue> warnings = const [],
    Iterable<ImportPlanIssue> errors = const [],
  }) : sources = List.unmodifiable(sources),
       warnings = List.unmodifiable(warnings),
       errors = List.unmodifiable(errors);

  final List<ProposedImportSource> sources;
  final List<ImportPlanIssue> warnings;
  final List<ImportPlanIssue> errors;

  ResolvedImportPlan resolveDefaults() => ResolvedImportPlan(
    sources: [
      for (final source in sources)
        ResolvedImportSource(
          id: source.id,
          action: source.defaultAction,
          items: [
            for (final item in source.items)
              ResolvedImportItem(id: item.id, action: item.defaultAction),
          ],
        ),
    ],
  );

  @override
  List<Object?> get props => [sources, warnings, errors];
}

final class ResolvedImportItem extends Equatable {
  const ResolvedImportItem({
    required this.id,
    required this.action,
    this.targetId,
  });

  final String id;
  final ImportAction action;
  final String? targetId;

  ResolvedImportItem copyWith({ImportAction? action, String? targetId}) =>
      ResolvedImportItem(
        id: id,
        action: action ?? this.action,
        targetId: targetId ?? this.targetId,
      );

  Map<String, Object?> toJson() => {
    'id': id,
    'action': action.name,
    'targetId': targetId,
  };

  @override
  List<Object?> get props => [id, action, targetId];
}

final class ResolvedImportSource extends Equatable {
  ResolvedImportSource({
    required this.id,
    required this.action,
    required Iterable<ResolvedImportItem> items,
  }) : items = List.unmodifiable(items);

  final String id;
  final ImportAction action;
  final List<ResolvedImportItem> items;

  ResolvedImportSource copyWith({
    ImportAction? action,
    Iterable<ResolvedImportItem>? items,
  }) => ResolvedImportSource(
    id: id,
    action: action ?? this.action,
    items: items ?? this.items,
  );

  Map<String, Object> toJson() => {
    'id': id,
    'action': action.name,
    'items': items.map((item) => item.toJson()).toList(),
  };

  @override
  List<Object?> get props => [id, action, items];
}

final class ResolvedImportPlan extends Equatable {
  ResolvedImportPlan({required Iterable<ResolvedImportSource> sources})
    : sources = List.unmodifiable(sources);

  final List<ResolvedImportSource> sources;

  ResolvedImportPlan replaceSource(ResolvedImportSource replacement) =>
      ResolvedImportPlan(
        sources: [
          for (final source in sources)
            if (source.id == replacement.id) replacement else source,
        ],
      );

  Map<String, Object> toJson() => {
    'sources': sources.map((source) => source.toJson()).toList(),
  };

  @override
  List<Object?> get props => [sources];
}
