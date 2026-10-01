import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';

import '../../../../foundation/filesystem.dart';
import '../../../../foundation/picker.dart';
import '../clipboard/export_clipboard_service.dart';
import '../models/export_selection.dart';
import '../models/export_template.dart';
import '../models/import_action.dart';
import '../widgets/import_action_editor.dart';
import '../widgets/selection_tree.dart';
import 'export_flow_notifier.dart';

final exportClipboardServiceProvider = Provider<ExportClipboardService>((ref) {
  return ExportClipboardService(
    fs: ref.watch(appFileSystemProvider),
    clipboard: const AppExportClipboardPort(),
  );
});

class ExportFlowPage extends ConsumerWidget {
  const ExportFlowPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(exportFlowProvider);
    final notifier = ref.read(exportFlowProvider.notifier);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          context.t.settings.backup_and_restore.export_import.create_export,
        ),
      ),
      body: switch (state.status) {
        ExportFlowStatus.ready => _ExportReady(state: state),
        ExportFlowStatus.creating => const Center(
          child: CircularProgressIndicator(),
        ),
        _ => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              context
                  .t
                  .settings
                  .backup_and_restore
                  .export_import
                  .select_export_type,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            RadioGroup<bool>(
              groupValue: state.isFull,
              onChanged: (value) => (value ?? false)
                  ? notifier.useFullExport()
                  : notifier.useCustomExport(),
              child: Column(
                children: [
                  RadioListTile<bool>(
                    value: true,
                    title: Text(
                      context
                          .t
                          .settings
                          .backup_and_restore
                          .export_import
                          .full_export,
                    ),
                    subtitle: Text(
                      context
                          .t
                          .settings
                          .backup_and_restore
                          .export_import
                          .full_export_description,
                    ),
                  ),
                  RadioListTile<bool>(
                    value: false,
                    title: Text(
                      context
                          .t
                          .settings
                          .backup_and_restore
                          .export_import
                          .custom_export,
                    ),
                    subtitle: Text(
                      context
                          .t
                          .settings
                          .backup_and_restore
                          .export_import
                          .custom_export_description,
                    ),
                  ),
                ],
              ),
            ),
            if (!state.isFull) ...[
              const SizedBox(height: 12),
              const _TemplatePicker(),
              const Divider(),
              ExportSelectionTree(
                descriptors: notifier.descriptors,
                selections: state.nodes,
                onToggleSource: notifier.toggleSource,
                onToggleChild: notifier.toggleChild,
                sourceLabel: (id) => _sourceLabel(context, id),
                childLabel: (sourceId, childId) => _childLabel(
                  context,
                  ref.watch(exportSelectionLabelsProvider),
                  sourceId,
                  childId,
                ),
              ),
              _ImportDefaults(
                descriptors: notifier.descriptors,
                state: state,
                labels: ref.watch(exportSelectionLabelsProvider),
                onChanged: notifier.setItemRecommendedAction,
              ),
              SwitchListTile(
                value: state.includeCredentials,
                onChanged: state.nodes.containsKey('profiles')
                    ? notifier.setIncludeCredentials
                    : null,
                title: Text(
                  context
                      .t
                      .settings
                      .backup_and_restore
                      .export_import
                      .include_credentials,
                ),
                subtitle: Text(
                  context
                      .t
                      .settings
                      .backup_and_restore
                      .export_import
                      .include_credentials_description,
                ),
              ),
            ],
            if (state.error != null) ...[
              const SizedBox(height: 8),
              Text(
                context
                    .t
                    .settings
                    .backup_and_restore
                    .export_import
                    .export_failed
                    .replaceAll('{error}', state.error.toString()),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 20),
            if (!state.isFull)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: state.nodes.isEmpty
                          ? null
                          : () => _saveTemplate(context, ref),
                      child: Text(
                        context
                            .t
                            .settings
                            .backup_and_restore
                            .export_import
                            .save_template,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: state.nodes.isEmpty
                          ? null
                          : () => _saveAndExport(context, ref),
                      child: Text(
                        context
                            .t
                            .settings
                            .backup_and_restore
                            .export_import
                            .save_and_export,
                      ),
                    ),
                  ),
                ],
              )
            else
              FilledButton.icon(
                key: const ValueKey('create-full-export'),
                onPressed: () => _createExport(context, ref),
                icon: const Icon(Icons.archive_outlined),
                label: Text(
                  context
                      .t
                      .settings
                      .backup_and_restore
                      .export_import
                      .create_export,
                ),
              ),
          ],
        ),
      },
    );
  }

  Future<void> _createExport(BuildContext context, WidgetRef ref) async {
    final state = ref.read(exportFlowProvider);
    if (state.isFull) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(
            context
                .t
                .settings
                .backup_and_restore
                .export_import
                .private_confirmation_title,
          ),
          content: Text(
            context
                .t
                .settings
                .backup_and_restore
                .export_import
                .private_confirmation_body,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                context.t.settings.backup_and_restore.export_import.cancel,
              ),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(
                context.t.settings.backup_and_restore.export_import.kContinue,
              ),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    try {
      await ref.read(exportFlowProvider.notifier).createExport();
    } catch (_) {}
  }

  Future<String?> _promptTemplateName(BuildContext context) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          context.t.settings.backup_and_restore.export_import.name_template,
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            labelText: context
                .t
                .settings
                .backup_and_restore
                .export_import
                .template_name,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              context.t.settings.backup_and_restore.export_import.cancel,
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: Text(
              context.t.settings.backup_and_restore.export_import.save,
            ),
          ),
        ],
      ),
    );
    controller.dispose();
    return switch (result?.trim()) {
      null || '' => null,
      final name => name,
    };
  }

  Future<bool> _saveTemplate(BuildContext context, WidgetRef ref) async {
    final name = await _promptTemplateName(context);
    if (name == null) return false;
    final selection = ref.read(exportFlowProvider.notifier).selection();
    final flow = ref.read(exportFlowProvider);
    await ref
        .read(exportTemplatesProvider.notifier)
        .save(
          ExportTemplate(
            id: const Uuid().v4(),
            name: name,
            selection: selection,
            recommendedActions: flow.recommendedActions,
            itemRecommendedActions: flow.itemRecommendedActions,
          ),
        );
    if (context.mounted) {
      Kurumi.showSuccessToast(
        context,
        context.t.settings.backup_and_restore.export_import.saved_template,
      );
    }
    return true;
  }

  Future<void> _saveAndExport(BuildContext context, WidgetRef ref) async {
    if (await _saveTemplate(context, ref) && context.mounted) {
      await _createExport(context, ref);
    }
  }
}

class _ImportDefaults extends StatelessWidget {
  const _ImportDefaults({
    required this.descriptors,
    required this.state,
    required this.labels,
    required this.onChanged,
  });

  final List<ExportSelectionDescriptor> descriptors;
  final ExportFlowState state;
  final ExportSelectionLabels labels;
  final void Function(String, String, ImportAction?) onChanged;

  @override
  Widget build(BuildContext context) {
    final selectedItems = <(String, String)>[];
    for (final descriptor in descriptors.where((item) => item.isCollection)) {
      final selection = state.nodes[descriptor.id];
      final ids = switch (selection?.kind) {
        ExportNodeSelectionKind.all => descriptor.childIds,
        ExportNodeSelectionKind.explicit => selection!.childIds,
        null => const <String>{},
      };
      selectedItems.addAll(ids.map((id) => (descriptor.id, id)));
    }
    if (selectedItems.isEmpty) return const SizedBox.shrink();
    return ExpansionTile(
      title: Text(
        context.t.settings.backup_and_restore.export_import.import_defaults,
      ),
      subtitle: Text(
        context
            .t
            .settings
            .backup_and_restore
            .export_import
            .import_defaults_description,
      ),
      children: [
        for (final (sourceId, itemId) in selectedItems)
          ListTile(
            title: Text(_childLabel(context, labels, sourceId, itemId)),
            trailing: DropdownButton<ImportAction?>(
              value: state.itemRecommendedActions[sourceId]?[itemId],
              items: [
                DropdownMenuItem<ImportAction?>(
                  child: Text(
                    context
                        .t
                        .settings
                        .backup_and_restore
                        .export_import
                        .no_preference,
                  ),
                ),
                for (final action in const [
                  ImportAction.update,
                  ImportAction.merge,
                  ImportAction.copy,
                  ImportAction.skip,
                ])
                  DropdownMenuItem<ImportAction?>(
                    value: action,
                    child: Text(importActionLabel(context, action)),
                  ),
              ],
              onChanged: (action) => onChanged(sourceId, itemId, action),
            ),
          ),
      ],
    );
  }
}

class _TemplatePicker extends ConsumerWidget {
  const _TemplatePicker();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final templates = ref.watch(exportTemplatesProvider);
    return templates.when(
      loading: () => const LinearProgressIndicator(),
      error: (_, _) => const SizedBox.shrink(),
      data: (items) => items.isEmpty
          ? const SizedBox.shrink()
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context
                      .t
                      .settings
                      .backup_and_restore
                      .export_import
                      .saved_templates,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final template in items)
                      InputChip(
                        label: Text(template.name),
                        onPressed: () => ref
                            .read(exportFlowProvider.notifier)
                            .applyTemplate(template),
                        onDeleted: () => ref
                            .read(exportTemplatesProvider.notifier)
                            .delete(template.id),
                        deleteButtonTooltipMessage: context
                            .t
                            .settings
                            .backup_and_restore
                            .export_import
                            .delete_template,
                      ),
                  ],
                ),
              ],
            ),
    );
  }
}

class _ExportReady extends ConsumerWidget {
  const _ExportReady({required this.state});

  final ExportFlowState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final path = state.packagePath!;
    final clipboard = ref.watch(exportClipboardServiceProvider);
    return FutureBuilder<bool>(
      future: clipboard.canCopy(
        path,
        containsCredentials: state.includeCredentials,
      ),
      builder: (context, snapshot) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.check_circle_outline, size: 72),
            const SizedBox(height: 16),
            Text(
              context.t.settings.backup_and_restore.export_import.export_ready,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => _save(context, ref, path),
              icon: const Icon(Icons.save_alt),
              label: Text(
                context.t.settings.backup_and_restore.export_import.save,
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => SharePlus.instance.share(
                ShareParams(
                  files: [
                    XFile(
                      path,
                      mimeType: 'application/vnd.boorusama.export',
                    ),
                  ],
                ),
              ),
              icon: const Icon(Icons.share),
              label: Text(
                context.t.settings.backup_and_restore.export_import.share,
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: snapshot.data ?? false
                  ? () async {
                      await clipboard.copy(
                        path,
                        containsCredentials: state.includeCredentials,
                      );
                      if (context.mounted) {
                        Kurumi.showSuccessToast(
                          context,
                          context
                              .t
                              .settings
                              .backup_and_restore
                              .export_import
                              .copied,
                        );
                      }
                    }
                  : null,
              icon: const Icon(Icons.content_copy),
              label: Text(
                context.t.settings.backup_and_restore.export_import.copy_base64,
              ),
            ),
            if (snapshot.data == false) ...[
              const SizedBox(height: 8),
              Text(
                context
                    .t
                    .settings
                    .backup_and_restore
                    .export_import
                    .clipboard_unavailable,
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _save(BuildContext context, WidgetRef ref, String source) {
    return pickDirectoryPathToastOnError(
      context: context,
      onPick: (directory) async {
        final filename =
            'boorusama-${DateTime.now().toUtc().toIso8601String().replaceAll(':', '-')}.bsexport';
        await ref
            .read(appFileSystemProvider)
            .copyFile(source, p.join(directory, filename));
        if (context.mounted) {
          Kurumi.showSuccessToast(
            context,
            context.t.settings.backup_and_restore.export_import.saved,
          );
        }
      },
    );
  }
}

String _sourceLabel(BuildContext context, String id) => switch (id) {
  'profiles' =>
    context.t.settings.backup_and_restore.export_import.sources.profiles,
  'settings' =>
    context.t.settings.backup_and_restore.export_import.sources.settings,
  'favorite_tags' =>
    context.t.settings.backup_and_restore.export_import.sources.favorite_tags,
  'search_history' =>
    context.t.settings.backup_and_restore.export_import.sources.search_history,
  'downloads' =>
    context.t.settings.backup_and_restore.export_import.sources.downloads,
  'blacklisted_tags' =>
    context
        .t
        .settings
        .backup_and_restore
        .export_import
        .sources
        .blacklisted_tags,
  'bookmarks' =>
    context.t.settings.backup_and_restore.export_import.sources.bookmarks,
  'pinned_searches' =>
    context.t.settings.backup_and_restore.export_import.sources.pinned_searches,
  'following_feeds' =>
    context.t.settings.backup_and_restore.export_import.sources.following_feeds,
  _ => id,
};

String _childLabel(
  BuildContext context,
  ExportSelectionLabels labels,
  String sourceId,
  String childId,
) {
  if (sourceId == 'bookmarks' && childId == 'ungrouped') {
    return context
        .t
        .settings
        .backup_and_restore
        .export_import
        .sources
        .ungrouped;
  }
  return labels.children[childId] ?? childId;
}
