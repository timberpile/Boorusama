import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';

import '../models/export_item_presentation.dart';
import '../models/export_selection.dart';

class ExportSelectionTree extends StatelessWidget {
  const ExportSelectionTree({
    super.key,
    required this.descriptors,
    required this.selections,
    required this.onToggleSource,
    required this.onToggleNode,
    required this.sourceLabel,
    required this.presentation,
  });

  final List<ExportSelectionDescriptor> descriptors;
  final Map<String, ExportNodeSelection> selections;
  final void Function(ExportSelectionDescriptor) onToggleSource;
  final void Function(ExportSelectionDescriptor, ExportSelectionNode)
  onToggleNode;
  final String Function(String) sourceLabel;
  final ExportSelectionPresentation presentation;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (final descriptor in descriptors)
        _SourceTile(
          descriptor: descriptor,
          selection: selections[descriptor.id],
          onToggleSource: onToggleSource,
          onToggleNode: onToggleNode,
          sourceLabel: sourceLabel(descriptor.id),
          presentation: presentation,
        ),
    ],
  );
}

class _SourceTile extends StatelessWidget {
  const _SourceTile({
    required this.descriptor,
    required this.selection,
    required this.onToggleSource,
    required this.onToggleNode,
    required this.sourceLabel,
    required this.presentation,
  });

  final ExportSelectionDescriptor descriptor;
  final ExportNodeSelection? selection;
  final void Function(ExportSelectionDescriptor) onToggleSource;
  final void Function(ExportSelectionDescriptor, ExportSelectionNode)
  onToggleNode;
  final String sourceLabel;
  final ExportSelectionPresentation presentation;

  @override
  Widget build(BuildContext context) {
    if (!descriptor.isCollection) {
      return CheckboxListTile(
        key: ValueKey(descriptor.id),
        contentPadding: _treeTilePadding(0),
        value: selection != null,
        onChanged: (_) => onToggleSource(descriptor),
        title: Text(sourceLabel),
        controlAffinity: ListTileControlAffinity.leading,
      );
    }

    final effectiveIds = selection?.resolve(descriptor) ?? const <String>{};
    final rawIds = selection?.childIds ?? const <String>{};
    final leafIds = {
      for (final node in descriptor.rootNodes) ..._leafIds(node),
    };
    final selectedLeafCount = effectiveIds.intersection(leafIds).length;
    final value = switch (selection?.kind) {
      null => false,
      ExportNodeSelectionKind.all => true,
      ExportNodeSelectionKind.explicit
          when selectedLeafCount == leafIds.length =>
        true,
      _ => null,
    };
    final subtitle = switch (selection?.kind) {
      ExportNodeSelectionKind.all =>
        context
            .t
            .settings
            .backup_and_restore
            .export_import
            .all_including_future,
      ExportNodeSelectionKind.explicit
          when selectedLeafCount == leafIds.length =>
        context.t.settings.backup_and_restore.export_import.all_current,
      ExportNodeSelectionKind.explicit => _selectedCountLabel(
        context,
        selectedLeafCount,
        leafIds.length,
      ),
      null => null,
    };

    return ExpansionTile(
      key: ValueKey(descriptor.id),
      tilePadding: _treeTilePadding(0),
      initiallyExpanded: selection != null,
      leading: Checkbox(
        tristate: true,
        value: value,
        onChanged: (_) => onToggleSource(descriptor),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      title: Text(sourceLabel),
      subtitle: subtitle == null ? null : Text(subtitle),
      children: [
        for (final node in descriptor.rootNodes)
          _SelectionNodeTile(
            descriptor: descriptor,
            node: node,
            selection: selection,
            effectiveIds: effectiveIds,
            rawIds: rawIds,
            presentation: presentation,
            depth: 1,
            onToggle: onToggleNode,
          ),
      ],
    );
  }
}

class _SelectionNodeTile extends StatelessWidget {
  const _SelectionNodeTile({
    required this.descriptor,
    required this.node,
    required this.selection,
    required this.effectiveIds,
    required this.rawIds,
    required this.presentation,
    required this.depth,
    required this.onToggle,
  });

  final ExportSelectionDescriptor descriptor;
  final ExportSelectionNode node;
  final ExportNodeSelection? selection;
  final Set<String> effectiveIds;
  final Set<String> rawIds;
  final ExportSelectionPresentation presentation;
  final int depth;
  final void Function(ExportSelectionDescriptor, ExportSelectionNode) onToggle;

  @override
  Widget build(BuildContext context) {
    final item = presentation.items[node.id];
    final title = _ItemLabel(
      label: item?.label ?? node.id,
      trailingLabel: item?.trailingLabel,
    );
    if (!node.isCollection) {
      return CheckboxListTile(
        key: ValueKey('${descriptor.id}:${node.id}'),
        contentPadding: _treeTilePadding(depth),
        value: effectiveIds.contains(node.id),
        onChanged: (_) => onToggle(descriptor, node),
        title: title,
        controlAffinity: ListTileControlAffinity.leading,
      );
    }

    final leafIds = _leafIds(node);
    final selectedLeafCount = effectiveIds.intersection(leafIds).length;
    final isDynamic =
        selection?.kind == ExportNodeSelectionKind.all ||
        rawIds.contains(node.id);
    final value = switch ((isDynamic, selectedLeafCount)) {
      (true, _) => true,
      (false, 0) => false,
      (false, final selected) when selected == leafIds.length => true,
      _ => null,
    };
    final subtitle = switch ((isDynamic, selectedLeafCount)) {
      (true, _) =>
        context
            .t
            .settings
            .backup_and_restore
            .export_import
            .all_including_future,
      (false, final selected) when selected == leafIds.length =>
        context.t.settings.backup_and_restore.export_import.all_current,
      (false, final selected) when selected > 0 => _selectedCountLabel(
        context,
        selected,
        leafIds.length,
      ),
      _ => null,
    };

    return ExpansionTile(
      key: ValueKey('${descriptor.id}:${node.id}'),
      tilePadding: _treeTilePadding(depth),
      initiallyExpanded: rawIds.intersection(node.descendantIds).isNotEmpty,
      leading: Checkbox(
        tristate: true,
        value: value,
        onChanged: (_) => onToggle(descriptor, node),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      title: title,
      subtitle: subtitle == null ? null : Text(subtitle),
      children: [
        for (final child in node.children)
          _SelectionNodeTile(
            descriptor: descriptor,
            node: child,
            selection: selection,
            effectiveIds: effectiveIds,
            rawIds: rawIds,
            presentation: presentation,
            depth: depth + 1,
            onToggle: onToggle,
          ),
      ],
    );
  }
}

class _ItemLabel extends StatelessWidget {
  const _ItemLabel({required this.label, this.trailingLabel});

  final String label;
  final String? trailingLabel;

  @override
  Widget build(BuildContext context) {
    final trailing = trailingLabel;
    if (trailing == null) {
      return Text(label, maxLines: 2, overflow: TextOverflow.ellipsis);
    }
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) => Row(
        children: [
          Expanded(
            child: Text(label, maxLines: 2, overflow: TextOverflow.ellipsis),
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

EdgeInsetsDirectional _treeTilePadding(int depth) =>
    EdgeInsetsDirectional.only(start: 8.0 * (depth + 1), end: 8);

Set<String> _leafIds(ExportSelectionNode node) => node.children.isEmpty
    ? {node.id}
    : {for (final child in node.children) ..._leafIds(child)};

String _selectedCountLabel(BuildContext context, int selected, int total) =>
    context.t.settings.backup_and_restore.export_import.selected_count
        .replaceAll('{selected}', '$selected')
        .replaceAll('{total}', '$total');
