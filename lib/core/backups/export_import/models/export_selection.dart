// Package imports:
import 'package:equatable/equatable.dart';

abstract interface class ExportSourceCatalog {
  List<ExportSelectionDescriptor> get selectionDescriptors;
}

enum ExportNodeSelectionKind { all, explicit }

final class ExportSelectionNode extends Equatable {
  const ExportSelectionNode({
    required this.id,
    this.children = const [],
    this.canHaveChildren = false,
  });

  final String id;
  final List<ExportSelectionNode> children;
  final bool canHaveChildren;

  bool get isCollection => canHaveChildren || children.isNotEmpty;

  Set<String> get allIds => {
    id,
    for (final child in children) ...child.allIds,
  };

  Set<String> get descendantIds => {
    for (final child in children) ...child.allIds,
  };

  ExportSelectionNode? find(String nodeId) {
    if (id == nodeId) return this;
    for (final child in children) {
      if (child.find(nodeId) case final match?) return match;
    }
    return null;
  }

  bool contains(String nodeId) => find(nodeId) != null;

  @override
  List<Object?> get props => [id, children, canHaveChildren];
}

final class ExportSelectionDescriptor extends Equatable {
  const ExportSelectionDescriptor.leaf({required this.id})
    : children = const [],
      _legacyChildIds = const {};

  const ExportSelectionDescriptor.collection({
    required this.id,
    this.children = const [],
    Set<String> childIds = const {},
  }) : _legacyChildIds = childIds;

  final String id;
  final List<ExportSelectionNode> children;
  final Set<String> _legacyChildIds;

  List<ExportSelectionNode> get rootNodes => [
    ...children,
    for (final childId in _legacyChildIds)
      if (!children.any((node) => node.contains(childId)))
        ExportSelectionNode(id: childId),
  ];

  Set<String> get childIds => {
    ..._legacyChildIds,
    for (final child in children) ...child.allIds,
  };

  bool get isCollection => childIds.isNotEmpty;

  ExportSelectionNode? findNode(String nodeId) {
    for (final child in rootNodes) {
      if (child.find(nodeId) case final match?) return match;
    }
    return null;
  }

  @override
  List<Object> get props => [id, rootNodes];
}

final class ExportNodeSelection extends Equatable {
  const ExportNodeSelection.all(this.nodeId)
    : kind = ExportNodeSelectionKind.all,
      childIds = const {};

  const ExportNodeSelection.explicit(this.nodeId, this.childIds)
    : kind = ExportNodeSelectionKind.explicit;

  const ExportNodeSelection.leaf(this.nodeId)
    : kind = ExportNodeSelectionKind.explicit,
      childIds = const {};

  factory ExportNodeSelection.fromJson(Map<String, dynamic> json) {
    final nodeId = json['nodeId'];
    final kind = json['kind'];
    final rawChildIds = json['childIds'];
    if (nodeId is! String || nodeId.isEmpty || kind is! String) {
      throw const FormatException('Invalid export node selection');
    }
    return switch (kind) {
      'all' => ExportNodeSelection.all(nodeId),
      'explicit'
          when rawChildIds is List<dynamic> &&
              rawChildIds.every((value) => value is String) =>
        ExportNodeSelection.explicit(
          nodeId,
          rawChildIds.cast<String>().toSet(),
        ),
      _ => throw const FormatException('Invalid export node selection'),
    };
  }

  final String nodeId;
  final ExportNodeSelectionKind kind;
  final Set<String> childIds;

  Set<String> resolve(ExportSelectionDescriptor descriptor) {
    if (descriptor.id != nodeId) return const {};
    if (!descriptor.isCollection) return {nodeId};
    return switch (kind) {
      ExportNodeSelectionKind.all => Set.unmodifiable(descriptor.childIds),
      ExportNodeSelectionKind.explicit => Set.unmodifiable({
        for (final childId in childIds)
          if (descriptor.findNode(childId) case final node?) ...node.allIds,
      }),
    };
  }

  Map<String, Object> toJson() => {
    'nodeId': nodeId,
    'kind': kind.name,
    'childIds': childIds.toList()..sort(),
  };

  @override
  List<Object> get props => [nodeId, kind, childIds];
}

enum ExportSelectionMode { full, custom }

final class ExportSelection extends Equatable {
  ExportSelection._({
    required this.mode,
    required Map<String, ExportNodeSelection> nodes,
    ExportSourceCatalog? catalog,
  }) : nodes = Map.unmodifiable(nodes),
       _catalog = catalog;

  factory ExportSelection.full(ExportSourceCatalog catalog) =>
      ExportSelection._(
        mode: ExportSelectionMode.full,
        nodes: const {},
        catalog: catalog,
      );

  factory ExportSelection.custom(Map<String, ExportNodeSelection> nodes) {
    if (nodes.entries.any((entry) => entry.key != entry.value.nodeId)) {
      throw ArgumentError.value(nodes, 'nodes', 'Keys must match node IDs');
    }
    return ExportSelection._(mode: ExportSelectionMode.custom, nodes: nodes);
  }

  factory ExportSelection.fromJson(Map<String, dynamic> json) {
    if (json['mode'] != 'custom' || json['nodes'] is! List<dynamic>) {
      throw const FormatException('A stored selection must be custom');
    }
    final nodes = <String, ExportNodeSelection>{};
    for (final raw in json['nodes'] as List<dynamic>) {
      if (raw is! Map<String, dynamic>) {
        throw const FormatException('Invalid export selection node');
      }
      final node = ExportNodeSelection.fromJson(raw);
      if (nodes[node.nodeId] != null) {
        throw const FormatException('Repeated export selection node');
      }
      nodes[node.nodeId] = node;
    }
    return ExportSelection.custom(nodes);
  }

  final ExportSelectionMode mode;
  final Map<String, ExportNodeSelection> nodes;
  final ExportSourceCatalog? _catalog;

  Set<String> get sourceIds => switch (mode) {
    ExportSelectionMode.full => {
      for (final descriptor in _catalog!.selectionDescriptors) descriptor.id,
    },
    ExportSelectionMode.custom => nodes.keys.toSet(),
  };

  Map<String, Object> toJson() {
    if (mode == ExportSelectionMode.full) {
      return const {'mode': 'full'};
    }
    final sorted = nodes.values.toList()
      ..sort((a, b) => a.nodeId.compareTo(b.nodeId));
    return {
      'mode': 'custom',
      'nodes': sorted.map((node) => node.toJson()).toList(),
    };
  }

  @override
  List<Object> get props => [
    mode,
    if (mode == ExportSelectionMode.custom) nodes,
  ];
}
