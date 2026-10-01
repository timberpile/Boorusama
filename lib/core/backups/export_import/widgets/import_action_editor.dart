import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';

import '../import/import_plan.dart';
import '../models/import_action.dart';

class ImportActionEditor extends StatelessWidget {
  const ImportActionEditor({
    super.key,
    required this.proposed,
    required this.resolved,
    required this.onChanged,
    required this.sourceLabel,
    required this.itemLabel,
    required this.targetLabel,
  });

  final ProposedImportSource proposed;
  final ResolvedImportSource resolved;
  final ValueChanged<ResolvedImportSource> onChanged;
  final String Function(String) sourceLabel;
  final String Function(String) itemLabel;
  final String Function(String) targetLabel;

  @override
  Widget build(BuildContext context) {
    final resolvedItems = {for (final item in resolved.items) item.id: item};
    return Card(
      child: ExpansionTile(
        initiallyExpanded: true,
        title: Text(sourceLabel(proposed.id)),
        trailing: DropdownButton<ImportAction>(
          value: resolved.action,
          items: [
            for (final action in proposed.availableActions)
              DropdownMenuItem(
                value: action,
                child: Text(importActionLabel(context, action)),
              ),
          ],
          onChanged: (action) {
            if (action != null) onChanged(resolved.copyWith(action: action));
          },
        ),
        children: resolved.action == ImportAction.configureItems
            ? [
                for (final item in proposed.items)
                  _ItemActionTile(
                    proposed: item,
                    resolved:
                        resolvedItems[item.id] ??
                        ResolvedImportItem(
                          id: item.id,
                          action: item.defaultAction,
                        ),
                    itemLabel: itemLabel,
                    targetLabel: targetLabel,
                    onChanged: (updated) => onChanged(
                      resolved.copyWith(
                        items: [
                          for (final current in resolved.items)
                            if (current.id == updated.id) updated else current,
                        ],
                      ),
                    ),
                  ),
              ]
            : const [],
      ),
    );
  }
}

class _ItemActionTile extends StatelessWidget {
  const _ItemActionTile({
    required this.proposed,
    required this.resolved,
    required this.itemLabel,
    required this.targetLabel,
    required this.onChanged,
  });

  final ProposedImportItem proposed;
  final ResolvedImportItem resolved;
  final String Function(String) itemLabel;
  final String Function(String) targetLabel;
  final ValueChanged<ResolvedImportItem> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(itemLabel(proposed.id)),
        const SizedBox(height: 6),
        DropdownButtonFormField<ImportAction>(
          initialValue: resolved.action,
          items: [
            for (final action in proposed.availableActions)
              DropdownMenuItem(
                value: action,
                child: Text(importActionLabel(context, action)),
              ),
          ],
          onChanged: (action) {
            if (action != null) {
              onChanged(
                resolved.copyWith(
                  action: action,
                  targetId: action == ImportAction.mergeIntoTarget
                      ? resolved.targetId
                      : null,
                ),
              );
            }
          },
        ),
        if (resolved.action == ImportAction.mergeIntoTarget) ...[
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
