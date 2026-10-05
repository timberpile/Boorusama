import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';

import '../import/import_plan.dart';
import '../models/export_item_presentation.dart';
import '../models/export_selection.dart';
import '../models/import_action.dart';
import 'import_recommendation_tree.dart';

class ImportActionEditor extends StatelessWidget {
  const ImportActionEditor({
    super.key,
    required this.proposed,
    required this.resolved,
    required this.onChanged,
    required this.sourceLabel,
    required this.itemLabel,
    required this.targetLabel,
    this.itemTree,
    this.itemPresentation = const ExportSelectionPresentation(items: {}),
  });

  final ProposedImportSource proposed;
  final ResolvedImportSource resolved;
  final ValueChanged<ResolvedImportSource> onChanged;
  final String Function(String) sourceLabel;
  final String Function(String) itemLabel;
  final String Function(String) targetLabel;
  final ExportSelectionDescriptor? itemTree;
  final ExportSelectionPresentation itemPresentation;

  @override
  Widget build(BuildContext context) {
    final resolvedItems = {for (final item in resolved.items) item.id: item};
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        children: [
          KurumiSettingsTile<ImportAction>(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            title: Text(sourceLabel(proposed.id)),
            selectedOption: resolved.action,
            items: proposed.availableActions.toList(),
            onChanged: (action) => onChanged(
              resolved.copyWith(action: action),
            ),
            optionBuilder: (action) => Text(
              importActionLabel(context, action),
            ),
          ),
          if (resolved.action == ImportAction.configureItems)
            if (itemTree case final tree?)
              ImportItemTree(
                descriptor: tree,
                itemIds: proposed.items.map((item) => item.id).toSet(),
                presentation: itemPresentation,
                fallbackPresentation: (id) => ExportItemPresentation(
                  label: itemLabel(id),
                ),
                itemBuilder: (context, itemId, presentation) =>
                    _buildItemAction(
                      proposedById[itemId]!,
                      resolvedItems,
                      presentation,
                    ),
              )
            else
              for (final item in proposed.items)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: _buildItemAction(
                    item,
                    resolvedItems,
                    ExportItemPresentation(label: itemLabel(item.id)),
                  ),
                ),
        ],
      ),
    );
  }

  Map<String, ProposedImportItem> get proposedById => {
    for (final item in proposed.items) item.id: item,
  };

  Widget _buildItemAction(
    ProposedImportItem item,
    Map<String, ResolvedImportItem> resolvedItems,
    ExportItemPresentation presentation,
  ) => _ItemActionTile(
    proposed: item,
    resolved:
        resolvedItems[item.id] ??
        ResolvedImportItem(id: item.id, action: item.defaultAction),
    itemTitle: ImportItemLabel(item: presentation),
    targetLabel: targetLabel,
    onChanged: (updated) => onChanged(
      resolved.copyWith(
        items: [
          for (final current in resolved.items)
            if (current.id == updated.id) updated else current,
        ],
      ),
    ),
  );
}

class _ItemActionTile extends StatelessWidget {
  const _ItemActionTile({
    required this.proposed,
    required this.resolved,
    required this.itemTitle,
    required this.targetLabel,
    required this.onChanged,
  });

  final ProposedImportItem proposed;
  final ResolvedImportItem resolved;
  final Widget itemTitle;
  final String Function(String) targetLabel;
  final ValueChanged<ResolvedImportItem> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 4, bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        KurumiSettingsTile<ImportAction>(
          title: itemTitle,
          selectedOption: resolved.action,
          items: proposed.availableActions.toList(),
          onChanged: (action) => onChanged(
            ResolvedImportItem(
              id: resolved.id,
              action: action,
              targetId:
                  (proposed.targetRequiredActions.contains(action) ||
                          action == ImportAction.mergeIntoTarget) &&
                      proposed.compatibleTargetIds.contains(resolved.targetId)
                  ? resolved.targetId
                  : null,
            ),
          ),
          optionBuilder: (action) => Text(
            importActionLabel(context, action),
          ),
        ),
        if (resolved.action == ImportAction.mergeIntoTarget ||
            proposed.targetRequiredActions.contains(resolved.action)) ...[
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue:
                proposed.compatibleTargetIds.contains(resolved.targetId)
                ? resolved.targetId
                : null,
            decoration: InputDecoration(
              labelText:
                  context.t.settings.backup_and_restore.export_import.target,
            ),
            items: [
              for (final id in proposed.compatibleTargetIds)
                DropdownMenuItem(value: id, child: Text(targetLabel(id))),
            ],
            onChanged: (target) => onChanged(
              ResolvedImportItem(
                id: resolved.id,
                action: resolved.action,
                targetId: target,
              ),
            ),
          ),
        ],
      ],
    ),
  );
}

String importActionLabel(
  BuildContext context,
  ImportAction action,
) => switch (action) {
  ImportAction.replace =>
    context.t.settings.backup_and_restore.export_import.replace,
  ImportAction.configureItems =>
    context.t.settings.backup_and_restore.export_import.configure_items,
  ImportAction.skip => context.t.settings.backup_and_restore.export_import.skip,
  ImportAction.update =>
    context.t.settings.backup_and_restore.export_import.update,
  ImportAction.merge =>
    context.t.settings.backup_and_restore.export_import.merge,
  ImportAction.mergeIntoTarget =>
    context.t.settings.backup_and_restore.export_import.merge_into,
  ImportAction.copy => context.t.settings.backup_and_restore.export_import.copy,
};
