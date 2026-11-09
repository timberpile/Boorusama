import 'package:kurumi/material.dart';
import 'package:flutter/foundation.dart' show setEquals;

import '../models/export_item_presentation.dart';
import '../models/export_selection.dart';
import 'import_bounded_list.dart';

typedef ImportItemBuilder = Widget Function(
  BuildContext context,
  String itemId,
  ExportItemPresentation presentation,
);

class ImportRecommendationTree extends StatelessWidget {
  const ImportRecommendationTree({
    super.key,
    required this.descriptors,
    required this.selections,
    required this.presentation,
    required this.sourceLabel,
    required this.itemBuilder,
  });

  final List<ExportSelectionDescriptor> descriptors;
  final Map<String, ExportNodeSelection> selections;
  final ExportSelectionPresentation presentation;
  final String Function(String sourceId) sourceLabel;
  final Widget Function(
    BuildContext context,
    String sourceId,
    String itemId,
    ExportItemPresentation presentation,
  )
  itemBuilder;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (final descriptor in descriptors)
        if (selections[descriptor.id] case final selection?)
          if (descriptor.isCollection)
            ExpansionTile(
              key: ValueKey('recommendation:${descriptor.id}'),
              tilePadding: _importTreePadding(0),
              title: Text(sourceLabel(descriptor.id)),
              children: [
                ImportItemTree(
                  descriptor: descriptor,
                  itemIds: selection.resolve(descriptor),
                  presentation: presentation,
                  itemBuilder: (context, itemId, item) => itemBuilder(
                    context,
                    descriptor.id,
                    itemId,
                    item,
                  ),
                ),
              ],
            ),
    ],
  );
}

class ImportItemTree extends StatefulWidget {
  const ImportItemTree({
    super.key,
    required this.descriptor,
    required this.itemIds,
    required this.presentation,
    required this.itemBuilder,
    this.fallbackPresentation,
  });

  final ExportSelectionDescriptor descriptor;
  final Set<String> itemIds;
  final ExportSelectionPresentation presentation;
  final ImportItemBuilder itemBuilder;
  final ExportItemPresentation Function(String itemId)? fallbackPresentation;

  @override
  State<ImportItemTree> createState() => _ImportItemTreeState();
}

class _ImportItemTreeState extends State<ImportItemTree> {
  final _expanded = <String>{};
  late List<ExportSelectionNode> _roots;
  late List<String> _extraIds;

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  @override
  void didUpdateWidget(ImportItemTree oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.descriptor, widget.descriptor) ||
        !setEquals(oldWidget.itemIds, widget.itemIds)) {
      if (oldWidget.descriptor.id != widget.descriptor.id) _expanded.clear();
      _prepare();
    }
  }

  void _prepare() {
    _roots = [
      for (final root in widget.descriptor.rootNodes)
        ?_visibleNode(root, widget.itemIds),
    ];
    _extraIds = widget.itemIds.difference(widget.descriptor.childIds).toList();
  }

  @override
  Widget build(BuildContext context) {
    return ImportBoundedList(
      storageKey: ('import-tree', widget.descriptor.id),
      itemCount: _roots.length + _extraIds.length,
      itemBuilder: (context, index) {
        if (index < _roots.length) {
          final root = _roots[index];
          return _ImportTreeNode(
            key: ValueKey(root.id),
            node: root,
            itemIds: widget.itemIds,
            presentation: widget.presentation,
            itemBuilder: widget.itemBuilder,
            expanded: _expanded,
            depth: 1,
          );
        }
        final id = _extraIds[index - _roots.length];
        return Padding(
          key: ValueKey(id),
          padding: _importTreePadding(1),
          child: widget.itemBuilder(
            context,
            id,
            widget.fallbackPresentation?.call(id) ??
                ExportItemPresentation(label: id),
          ),
        );
      },
    );
  }
}

class _ImportTreeNode extends StatelessWidget {
  const _ImportTreeNode({
    required this.node,
    required this.itemIds,
    required this.presentation,
    required this.itemBuilder,
    required this.expanded,
    required this.depth,
    super.key,
  });

  final ExportSelectionNode node;
  final Set<String> itemIds;
  final ExportSelectionPresentation presentation;
  final ImportItemBuilder itemBuilder;
  final Set<String> expanded;
  final int depth;

  @override
  Widget build(BuildContext context) {
    final item =
        presentation.items[node.id] ?? ExportItemPresentation(label: node.id);
    if (!node.isCollection) {
      return Padding(
        padding: _importTreePadding(depth),
        child: itemBuilder(context, node.id, item),
      );
    }
    return ExpansionTile(
      key: ValueKey('import-tree:${node.id}'),
      initiallyExpanded: expanded.contains(node.id),
      onExpansionChanged: (value) {
        if (value) {
          expanded.add(node.id);
        } else {
          expanded.remove(node.id);
        }
      },
      tilePadding: _importTreePadding(depth),
      title: itemIds.contains(node.id)
          ? itemBuilder(context, node.id, item)
          : ImportItemLabel(item: item),
      children: [
        Builder(
          builder: (context) => ImportBoundedList(
            storageKey: ('import-tree-children', node.id),
            itemCount: node.children.length,
            itemBuilder: (context, index) {
              final child = node.children[index];
              return _ImportTreeNode(
                key: ValueKey(child.id),
                node: child,
                itemIds: itemIds,
                presentation: presentation,
                itemBuilder: itemBuilder,
                expanded: expanded,
                depth: depth + 1,
              );
            },
          ),
        ),
      ],
    );
  }
}

class ImportItemLabel extends StatelessWidget {
  const ImportItemLabel({super.key, required this.item});

  final ExportItemPresentation item;

  @override
  Widget build(BuildContext context) {
    final trailing = item.trailingLabel;
    if (trailing == null) {
      return Text(item.label, maxLines: 2, overflow: TextOverflow.ellipsis);
    }
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) => Row(
        children: [
          Expanded(
            child: Text(
              item.label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: constraints.maxWidth * 0.5),
            child: Text(
              trailing,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant.withValues(
                  alpha: 0.72,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

EdgeInsetsDirectional _importTreePadding(int depth) =>
    EdgeInsetsDirectional.only(start: 12.0 + 8 * depth, end: 12);

ExportSelectionNode? _visibleNode(
  ExportSelectionNode node,
  Set<String> itemIds,
) {
  final children = [
    for (final child in node.children) ?_visibleNode(child, itemIds),
  ];
  if (!itemIds.contains(node.id) && children.isEmpty) return null;
  return ExportSelectionNode(
    id: node.id,
    children: children,
    canHaveChildren: node.canHaveChildren,
  );
}
