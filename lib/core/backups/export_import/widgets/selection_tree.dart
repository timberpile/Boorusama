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
      initiallyExpanded: selection != null,
      leading: Checkbox(
        tristate: true,
        value: value,
        onChanged: (_) => onToggleSource(descriptor),
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
        contentPadding: EdgeInsetsDirectional.only(
          start: 16.0 * (depth + 1),
          end: 16,
        ),
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

    return Padding(
      padding: EdgeInsetsDirectional.only(start: 16.0 * depth),
      child: ExpansionTile(
        key: ValueKey('${descriptor.id}:${node.id}'),
        initiallyExpanded: rawIds.intersection(node.descendantIds).isNotEmpty,
        leading: Checkbox(
          tristate: true,
          value: value,
          onChanged: (_) => onToggle(descriptor, node),
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
      ),
    );
  }
}

class _ItemLabel extends StatelessWidget {
  const _ItemLabel({required this.label, this.trailingLabel});

  final String label;
  final String? trailingLabel;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(child: Text(label)),
      if (trailingLabel case final trailing?) ...[
        const SizedBox(width: 12),
        Text(
          trailing,
          textAlign: TextAlign.end,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    ],
  );
}

Set<String> _leafIds(ExportSelectionNode node) => node.children.isEmpty
    ? {node.id}
    : {for (final child in node.children) ..._leafIds(child)};

String _selectedCountLabel(BuildContext context, int selected, int total) =>
    context.t.settings.backup_and_restore.export_import.selected_count
        .replaceAll('{selected}', '$selected')
        .replaceAll('{total}', '$total');
