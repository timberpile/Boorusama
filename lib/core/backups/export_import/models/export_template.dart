// Package imports:
import 'package:equatable/equatable.dart';

// Project imports:
import 'export_selection.dart';

final class ExportTemplate extends Equatable {
  ExportTemplate({
    required this.id,
    required this.name,
    required this.selection,
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
        selection is! Map<String, dynamic>) {
      throw const FormatException('Invalid export template');
    }
    try {
      return ExportTemplate(
        id: id,
        name: name,
        selection: ExportSelection.fromJson(selection),
      );
    } on ArgumentError {
      throw const FormatException('Invalid export template');
    }
  }

  final String id;
  final String name;
  final ExportSelection selection;

  Map<String, Object> toJson() => {
    'id': id,
    'name': name,
    'selection': selection.toJson(),
  };

  @override
  List<Object> get props => [id, name, selection];
}
