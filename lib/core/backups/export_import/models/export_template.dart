// Package imports:
import 'package:equatable/equatable.dart';

// Project imports:
import 'export_selection.dart';
import 'import_action.dart';

final class ExportTemplate extends Equatable {
  ExportTemplate({
    required this.id,
    required this.name,
    required this.selection,
    this.recommendedActions = const {},
    this.itemRecommendedActions = const {},
  }) {
    if (id.trim().isEmpty || name.trim().isEmpty) {
      throw ArgumentError('Template ID and name must not be empty');
    }
    if (selection.mode != ExportSelectionMode.custom) {
      throw ArgumentError('User templates must freeze their app sources');
    }
  }

  factory ExportTemplate.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final name = json['name'];
    final selection = json['selection'];
    if (id is! String ||
        name is! String ||
        selection is! Map<String, dynamic> ||
        id.trim().isEmpty ||
        name.trim().isEmpty ||
        selection['mode'] != 'custom') {
      throw const FormatException('Invalid export template');
    }
    return ExportTemplate(
      id: id,
      name: name,
      selection: ExportSelection.fromJson(selection),
      recommendedActions: _actionsFromJson(json['recommendedActions']),
      itemRecommendedActions: _itemActionsFromJson(
        json['itemRecommendedActions'],
      ),
    );
  }

  final String id;
  final String name;
  final ExportSelection selection;
  final Map<String, ImportAction> recommendedActions;
  final Map<String, Map<String, ImportAction>> itemRecommendedActions;

  Map<String, Object> toJson() => {
    'id': id,
    'name': name,
    'selection': selection.toJson(),
    'recommendedActions': {
      for (final entry in recommendedActions.entries)
        entry.key: entry.value.name,
    },
    'itemRecommendedActions': {
      for (final source in itemRecommendedActions.entries)
        source.key: {
          for (final entry in source.value.entries) entry.key: entry.value.name,
        },
    },
  };

  @override
  List<Object> get props => [
    id,
    name,
    selection,
    recommendedActions,
    itemRecommendedActions,
  ];
}

Map<String, ImportAction> _actionsFromJson(Object? value) {
  if (value == null) return const {};
  if (value is! Map) throw const FormatException('Invalid template actions');
  final actions = <String, ImportAction>{};
  for (final entry in value.entries) {
    final id = entry.key;
    if (id is! String) {
      throw const FormatException('Invalid template action ID');
    }
    actions[id] = importActionFromJson(entry.value);
  }
  return Map.unmodifiable(actions);
}

Map<String, Map<String, ImportAction>> _itemActionsFromJson(Object? value) {
  if (value == null) return const {};
  if (value is! Map) {
    throw const FormatException('Invalid template item actions');
  }
  final actions = <String, Map<String, ImportAction>>{};
  for (final entry in value.entries) {
    final id = entry.key;
    if (id is! String) {
      throw const FormatException('Invalid template source ID');
    }
    actions[id] = _actionsFromJson(entry.value);
  }
  return Map.unmodifiable(actions);
}
