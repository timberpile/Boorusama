import 'package:kurumi/material.dart';

import '../models/export_item_presentation.dart';
import '../models/export_selection.dart';

typedef ImportItemBuilder =
    Widget Function(
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

class ImportItemTree extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final treeIds = descriptor.childIds;
    return Column(
      children: [
        for (final root in descriptor.rootNodes)
          if (_visibleNode(root, itemIds) case final visible?)
            _ImportTreeNode(
              node: visible,
              itemIds: itemIds,
              presentation: presentation,
              itemBuilder: itemBuilder,
            ),
        for (final id in itemIds.difference(treeIds))
          itemBuilder(
            context,
            id,
            fallbackPresentation?.call(id) ?? ExportItemPresentation(label: id),
          ),
      ],
    );
  }
}

class _ImportTreeNode extends StatelessWidget {
  const _ImportTreeNode({
    required this.node,
    required this.itemIds,
    required this.presentation,
    required this.itemBuilder,
  });

  final ExportSelectionNode node;
  final Set<String> itemIds;
  final ExportSelectionPresentation presentation;
  final ImportItemBuilder itemBuilder;

  @override
  Widget build(BuildContext context) {
    final item =
        presentation.items[node.id] ?? ExportItemPresentation(label: node.id);
    if (!node.isCollection) {
      return itemBuilder(context, node.id, item);
    }
    return ExpansionTile(
      key: ValueKey('import-tree:${node.id}'),
      title: ImportItemLabel(item: item),
      children: [
        if (itemIds.contains(node.id)) itemBuilder(context, node.id, item),
        for (final child in node.children)
          if (_visibleNode(child, itemIds) case final visible?)
            _ImportTreeNode(
              node: visible,
              itemIds: itemIds,
              presentation: presentation,
              itemBuilder: itemBuilder,
            ),
      ],
    );
  }
}

class ImportItemLabel extends StatelessWidget {
  const ImportItemLabel({super.key, required this.item});

  final ExportItemPresentation item;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        flex: 2,
        child: Text(item.label, maxLines: 2, overflow: TextOverflow.ellipsis),
      ),
      if (item.trailingLabel case final trailing?) ...[
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            trailing,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.end,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    ],
  );
}

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
