import 'package:equatable/equatable.dart';

import '../models/import_action.dart';

final class CollectionImportAction extends Equatable {
  const CollectionImportAction({
    required this.itemId,
    required this.action,
    this.targetId,
    this.destinationId,
  });

  final String itemId;
  final ImportAction action;
  final String? targetId;
  final String? destinationId;

  @override
  List<Object?> get props => [itemId, action, targetId, destinationId];
}
