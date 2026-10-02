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
import '../models/export_item_presentation.dart';
import '../models/export_template.dart';
import '../models/import_action.dart';
import '../widgets/import_action_editor.dart';
import '../widgets/import_recommendation_tree.dart';
import '../widgets/selection_tree.dart';
import '../widgets/private_export_confirmation.dart';
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
    final presentation = _localizedPresentation(
      context,
      ref.watch(exportSelectionPresentationProvider),
    );
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
                onToggleNode: notifier.toggleNode,
                sourceLabel: (id) => _sourceLabel(context, id),
                presentation: presentation,
              ),
              _ImportDefaults(
                descriptors: notifier.descriptors,
                state: state,
                presentation: presentation,
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
                      key: const ValueKey('create-custom-export'),
                      onPressed: state.nodes.isEmpty
                          ? null
                          : () => _createExport(context, ref),
                      child: Text(
                        context
                            .t
                            .settings
                            .backup_and_restore
                            .export_import
                            .create_export,
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
      final confirmed = await confirmPrivateExport(context);
      if (!confirmed) return;
    }
    try {
      await ref.read(exportFlowProvider.notifier).createExport();
    } catch (_) {}
  }

  Future<String?> _promptTemplateSave(BuildContext context) =>
      showDialog<String>(
        context: context,
        builder: (_) => const _TemplateSaveDialog(),
      );

  Future<void> _saveTemplate(BuildContext context, WidgetRef ref) async {
    final name = await _promptTemplateSave(context);
    if (name == null) return;
    final selection = ref.read(exportFlowProvider.notifier).selection();
    final flow = ref.read(exportFlowProvider);
    await ref
        .read(exportTemplatesProvider.notifier)
        .save(
          ExportTemplate(
            id: const Uuid().v4(),
            name: name,
            selection: selection,
            includeCredentials: flow.includeCredentials,
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
  }
}

class _TemplateSaveDialog extends StatefulWidget {
  const _TemplateSaveDialog();

  @override
  State<_TemplateSaveDialog> createState() => _TemplateSaveDialogState();
}

class _TemplateSaveDialogState extends State<_TemplateSaveDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      context.t.settings.backup_and_restore.export_import.name_template,
    ),
    content: TextField(
      controller: _controller,
      autofocus: true,
      decoration: InputDecoration(
        labelText:
            context.t.settings.backup_and_restore.export_import.template_name,
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(
          context.t.settings.backup_and_restore.export_import.cancel,
        ),
      ),
      TextButton(
        onPressed: () => _submit(context),
        child: Text(
          context.t.settings.backup_and_restore.export_import.save,
        ),
      ),
    ],
  );

  void _submit(BuildContext context) {
    final name = _controller.text.trim();
    if (name.isEmpty) return;
    Navigator.pop(context, name);
  }
}

class _ImportDefaults extends StatelessWidget {
  const _ImportDefaults({
    required this.descriptors,
    required this.state,
    required this.presentation,
    required this.onChanged,
  });

  final List<ExportSelectionDescriptor> descriptors;
  final ExportFlowState state;
  final ExportSelectionPresentation presentation;
  final void Function(String, String, ImportAction?) onChanged;

  @override
  Widget build(BuildContext context) {
    if (!descriptors.any(
      (descriptor) =>
          descriptor.isCollection && state.nodes.containsKey(descriptor.id),
    )) {
      return const SizedBox.shrink();
    }
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
        ImportRecommendationTree(
          descriptors: descriptors,
          selections: state.nodes,
          presentation: presentation,
          sourceLabel: (id) => _sourceLabel(context, id),
          itemBuilder: (context, sourceId, itemId, item) =>
              KurumiSettingsTile<_ImportDefaultChoice>(
                title: ImportItemLabel(item: item),
                selectedOption: _ImportDefaultChoice.fromAction(
                  state.itemRecommendedActions[sourceId]?[itemId],
                ),
                items: _ImportDefaultChoice.values,
                onChanged: (choice) =>
                    onChanged(sourceId, itemId, choice.action),
                optionBuilder: (choice) => Text(
                  switch (choice.action) {
                    final action? => importActionLabel(context, action),
                    null =>
                      context
                          .t
                          .settings
                          .backup_and_restore
                          .export_import
                          .no_preference,
                  },
                ),
              ),
        ),
      ],
    );
  }
}

enum _ImportDefaultChoice {
  automatic(null),
  update(ImportAction.update),
  merge(ImportAction.merge),
  copy(ImportAction.copy),
  skip(ImportAction.skip);

  const _ImportDefaultChoice(this.action);

  factory _ImportDefaultChoice.fromAction(ImportAction? action) =>
      switch (action) {
        ImportAction.update => update,
        ImportAction.merge => merge,
        ImportAction.copy => copy,
        ImportAction.skip => skip,
        _ => automatic,
      };

  final ImportAction? action;
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
                Text(
                  context
                      .t
                      .settings
                      .backup_and_restore
                      .export_import
                      .templates_local_only,
                  style: Theme.of(context).textTheme.bodySmall,
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
            const SizedBox(height: 12),
            ExportReadySummary(
              state: state,
              descriptors: ref.read(exportFlowProvider.notifier).descriptors,
              sourceLabel: (id) => _sourceLabel(context, id),
              onEdit: ref.read(exportFlowProvider.notifier).editSelection,
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

class ExportReadySummary extends StatelessWidget {
  const ExportReadySummary({
    super.key,
    required this.state,
    required this.descriptors,
    required this.sourceLabel,
    required this.onEdit,
  });

  final ExportFlowState state;
  final List<ExportSelectionDescriptor> descriptors;
  final String Function(String) sourceLabel;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final strings = context.t.settings.backup_and_restore.export_import;
    return Column(
      children: [
        Text(
          state.isFull ? strings.full_export : strings.custom_export,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        if (state.isFull)
          Text(strings.full_export_description, textAlign: TextAlign.center)
        else
          for (final descriptor in descriptors)
            if (state.nodes[descriptor.id] case final selection?)
              Text(
                _selectionSummary(
                  context,
                  descriptor,
                  selection,
                  sourceLabel(descriptor.id),
                ),
              ),
        TextButton.icon(
          onPressed: onEdit,
          icon: const Icon(Icons.edit_outlined),
          label: Text(strings.edit_selection),
        ),
      ],
    );
  }

  String _selectionSummary(
    BuildContext context,
    ExportSelectionDescriptor descriptor,
    ExportNodeSelection selection,
    String label,
  ) {
    final strings = context.t.settings.backup_and_restore.export_import;
    if (!descriptor.isCollection) {
      return strings.source_selected
          .replaceAll('{source}', label)
          .replaceAll('{selection}', strings.selected);
    }
    if (selection.kind == ExportNodeSelectionKind.all) {
      return strings.source_selected
          .replaceAll('{source}', label)
          .replaceAll('{selection}', strings.all_including_future);
    }
    return strings.source_selected_count
        .replaceAll('{source}', label)
        .replaceAll('{count}', '${selection.childIds.length}');
  }
}

String _sourceLabel(BuildContext context, String id) => switch (id) {
  'profiles' =>
    context.t.settings.backup_and_restore.export_import.sources.profiles,
  'settings' =>
    context.t.settings.backup_and_restore.export_import.sources.settings,
  'favorite_tags' =>
    context.t.settings.backup_and_restore.export_import.sources.favorite_tags,
  'search_histories' =>
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

ExportSelectionPresentation _localizedPresentation(
  BuildContext context,
  ExportSelectionPresentation presentation,
) => ExportSelectionPresentation(
  items: {
    ...presentation.items,
    'ungrouped': ExportItemPresentation(
      label:
          context.t.settings.backup_and_restore.export_import.sources.ungrouped,
    ),
    'home': ExportItemPresentation(label: context.t.pinned_searches.home),
  },
);
