import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';

import '../models/export_selection.dart';

class ExportSelectionTree extends StatelessWidget {
  const ExportSelectionTree({
    super.key,
    required this.descriptors,
    required this.selections,
    required this.onToggleSource,
    required this.onToggleChild,
    required this.sourceLabel,
    required this.childLabel,
  });

  final List<ExportSelectionDescriptor> descriptors;
  final Map<String, ExportNodeSelection> selections;
  final void Function(ExportSelectionDescriptor) onToggleSource;
  final void Function(ExportSelectionDescriptor, String) onToggleChild;
  final String Function(String) sourceLabel;
  final String Function(String, String) childLabel;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (final descriptor in descriptors)
        _SelectionNode(
          descriptor: descriptor,
          selection: selections[descriptor.id],
          onToggleSource: onToggleSource,
          onToggleChild: onToggleChild,
          sourceLabel: sourceLabel(descriptor.id),
          childLabel: (id) => childLabel(descriptor.id, id),
        ),
    ],
  );
}

class _SelectionNode extends StatelessWidget {
  const _SelectionNode({
    required this.descriptor,
    required this.selection,
    required this.onToggleSource,
    required this.onToggleChild,
    required this.sourceLabel,
    required this.childLabel,
  });

  final ExportSelectionDescriptor descriptor;
  final ExportNodeSelection? selection;
  final void Function(ExportSelectionDescriptor) onToggleSource;
  final void Function(ExportSelectionDescriptor, String) onToggleChild;
  final String sourceLabel;
  final String Function(String) childLabel;

  @override
  Widget build(BuildContext context) {
    final selectedChildren = switch (selection?.kind) {
      ExportNodeSelectionKind.all => descriptor.childIds,
      ExportNodeSelectionKind.explicit => selection!.childIds,
      null => const <String>{},
    };
    final parentValue = switch ((selection, descriptor.isCollection)) {
      (null, _) => false,
      (_, false) => true,
      (ExportNodeSelection(kind: ExportNodeSelectionKind.all), true) => true,
      (ExportNodeSelection(kind: ExportNodeSelectionKind.explicit), true)
          when selectedChildren.length == descriptor.childIds.length =>
        true,
      (_, true) => null,
    };
    final subtitle = switch (selection?.kind) {
      ExportNodeSelectionKind.all when descriptor.isCollection => <String>[
        context
            .t
            .settings
            .backup_and_restore
            .export_import
            .all_including_future,
      ],
      ExportNodeSelectionKind.explicit
          when descriptor.isCollection &&
              selectedChildren.length == descriptor.childIds.length =>
        <String>[
          context.t.settings.backup_and_restore.export_import.all_current,
          _selectedCountLabel(context, selectedChildren.length),
        ],
      ExportNodeSelectionKind.explicit when descriptor.isCollection => <String>[
        _selectedCountLabel(context, selectedChildren.length),
      ],
      _ => const <String>[],
    };
    final children = descriptor.childIds.toList()..sort();

    if (!descriptor.isCollection) {
      return CheckboxListTile(
        key: ValueKey(descriptor.id),
        value: selection != null,
        onChanged: (_) => onToggleSource(descriptor),
        title: Text(sourceLabel),
        controlAffinity: ListTileControlAffinity.leading,
      );
    }

    return ExpansionTile(
      key: ValueKey(descriptor.id),
      initiallyExpanded: selection != null,
      leading: Checkbox(
        tristate: true,
        value: parentValue,
        onChanged: (_) => onToggleSource(descriptor),
      ),
      title: Text(sourceLabel),
      subtitle: subtitle.isEmpty
          ? null
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [for (final line in subtitle) Text(line)],
            ),
      children: [
        for (final childId in children)
          CheckboxListTile(
            key: ValueKey('${descriptor.id}:$childId'),
            contentPadding: const EdgeInsetsDirectional.only(
              start: 32,
              end: 16,
            ),
            value: selectedChildren.contains(childId),
            onChanged: (_) => onToggleChild(descriptor, childId),
            title: Text(childLabel(childId)),
            controlAffinity: ListTileControlAffinity.leading,
          ),
      ],
    );
  }

  String _selectedCountLabel(BuildContext context, int selected) => context
      .t
      .settings
      .backup_and_restore
      .export_import
      .selected_count
      .replaceAll('{selected}', '$selected')
      .replaceAll('{total}', '${descriptor.childIds.length}');
}
