import 'package:equatable/equatable.dart';

final class ExportItemPresentation extends Equatable {
  const ExportItemPresentation({required this.label, this.trailingLabel});

  final String label;
  final String? trailingLabel;

  @override
  List<Object?> get props => [label, trailingLabel];
}

final class ExportSelectionPresentation extends Equatable {
  const ExportSelectionPresentation({required this.items});

  final Map<String, ExportItemPresentation> items;

  @override
  List<Object?> get props => [items];
}
