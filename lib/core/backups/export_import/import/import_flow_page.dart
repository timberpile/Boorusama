import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';

import '../../../configs/manage/providers.dart';
import '../../sources/providers.dart';
import '../export/export_flow_notifier.dart';
import '../models/export_item_presentation.dart';
import '../models/import_action.dart';
import '../widgets/import_action_editor.dart';
import '../widgets/import_change_preview.dart';
import 'import_flow_notifier.dart';
import 'import_issue_message.dart';
import 'import_preflight.dart';
import 'profile_dependency_planner.dart';

class ImportFlowPage extends ConsumerStatefulWidget {
  const ImportFlowPage({
    super.key,
    required this.packagePath,
    this.disposeInput,
  });

  final String packagePath;
  final Future<void> Function()? disposeInput;

  @override
  ConsumerState<ImportFlowPage> createState() => _ImportFlowPageState();
}

class _ImportFlowPageState extends ConsumerState<ImportFlowPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      try {
        await ref.read(importFlowProvider.notifier).load(widget.packagePath);
      } finally {
        await widget.disposeInput?.call();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(importFlowProvider);
    final strings = context.t.settings.backup_and_restore.export_import;
    return Scaffold(
      appBar: KurumiAppBar(title: Text(strings.review_import)),
      body: SafeArea(
        child: switch (state.status) {
          ImportFlowStatus.idle || ImportFlowStatus.checking => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 12),
                Text(strings.review_import),
              ],
            ),
          ),
          ImportFlowStatus.importing => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 12),
                Text(strings.importing),
              ],
            ),
          ),
          ImportFlowStatus.complete => ImportCompletionView(
            summary: state.preflight?.summary,
            bookmarkRefreshFailed: state.bookmarkRefreshFailed,
            onDone: () => Navigator.of(context).maybePop(),
          ),
          ImportFlowStatus.error => ImportErrorView(
            onChooseAnother: () => Navigator.of(context).maybePop(),
          ),
          ImportFlowStatus.review => _ReviewImport(state: state),
        },
      ),
    );
  }
}

class _ReviewImport extends ConsumerWidget {
  const _ReviewImport({required this.state});

  final ImportFlowState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = context.t.settings.backup_and_restore.export_import;
    final proposed = state.proposed!;
    final resolved = state.resolved!;
    final preflight = state.preflight!;
    final resolvedById = {
      for (final source in resolved.sources) source.id: source,
    };
    final sourceNames = {
      for (final source in ref.read(backupRegistryProvider).getAllSources())
        source.id: _localizedSourceLabel(context, source.id),
    };
    final localLabels = ref.watch(exportSelectionLabelsProvider).children;
    final names = {
      for (final profile in ref.watch(booruConfigProvider))
        profile.id: profile.name,
      ...state.profileNames,
    };
    final profileNames = {
      for (final (index, entry) in names.entries.indexed)
        entry.key: names.values.where((name) => name == entry.value).length > 1
            ? '${entry.value} (${index + 1})'
            : entry.value,
    };
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
      children: [
        Text(
          strings.import_category_count(n: proposed.sources.length),
          style: Theme.of(context).textTheme.titleLarge,
        ),
        if (state.createdAt case final createdAt?)
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: Text(strings.export_details),
            subtitle: Text(
              strings.export_details_summary
                  .replaceAll('{version}', state.exporterVersion ?? '—')
                  .replaceAll('{date}', _formatExportDate(context, createdAt)),
            ),
          ),
        if (state.containsCredentials)
          ListTile(
            leading: Icon(
              Icons.lock_outline,
              color: Theme.of(context).colorScheme.error,
            ),
            title: Text(strings.credentials_warning_title),
            subtitle: Text(strings.credentials_warning_description),
          ),
        const SizedBox(height: 12),
        for (final source in proposed.sources)
          ImportActionEditor(
            proposed: source,
            resolved: resolvedById[source.id]!,
            onChanged: ref.read(importFlowProvider.notifier).replaceSource,
            sourceLabel: (id) => sourceNames[id] ?? id,
            itemLabel: (id) => _localizedItemLabel(
              context,
              id,
              state.itemLabels[id] ?? localLabels[id],
            ),
            targetLabel: (id) => localLabels[id] ?? id,
            itemTree: state.itemPresentations[source.id]?.descriptor,
            itemPresentation: _localizedImportPresentation(
              context,
              state.itemPresentations[source.id]?.presentation ??
                  const ExportSelectionPresentation(items: {}),
            ),
          ),
        if (resolved.sources.any(
          (source) => source.action == ImportAction.replace,
        ))
          ListTile(
            leading: const Icon(Icons.sync_alt),
            title: Text(strings.replace_explanation_title),
            subtitle: Text(strings.replace_explanation),
          ),
        for (final mapping in state.profileMappings)
          if (mapping.candidateIds.length > 1)
            _ProfileMappingTile(
              mapping: mapping,
              profileNames: profileNames,
              onChanged: (profileId) => ref
                  .read(importFlowProvider.notifier)
                  .chooseProfileMapping(
                    mapping.siteKey,
                    profileId,
                  ),
            ),
        if (state.alreadyPresentSearches > 0)
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: Text(
              strings.searches_already_present(n: state.alreadyPresentSearches),
            ),
          ),
        if (state.planRefreshed)
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: Text(strings.preview_refreshed),
          ),
        if (preflight.sourceSummaries.isNotEmpty)
          ImportChangePreview(
            rows: [
              for (final summary in preflight.sourceSummaries.values)
                ...summary.previewRows,
            ],
            sourceNames: sourceNames,
            profileNames: profileNames,
          ),
        const SizedBox(height: 16),
        if (preflight.warnings.isEmpty && preflight.errors.isEmpty)
          ListTile(
            leading: const Icon(Icons.check_circle_outline),
            title: Text(strings.all_checks_passed),
          ),
        ImportReviewValidation(
          preflight: preflight,
          profileSelectors: {
            for (final mapping in state.profileMappings)
              if (mapping.candidateIds.length > 1) mapping.siteKey,
          },
          sourceNames: sourceNames,
          itemLabels: {...localLabels, ...state.itemLabels},
          onWarningsAcknowledged: ref
              .read(importFlowProvider.notifier)
              .acknowledgeWarnings,
          onApply: () => ref.read(importFlowProvider.notifier).apply(context),
          onDone: () => Navigator.of(context).maybePop(),
        ),
      ],
    );
  }
}

class ImportReviewValidation extends StatelessWidget {
  const ImportReviewValidation({
    super.key,
    required this.preflight,
    this.profileSelectors = const {},
    required this.sourceNames,
    required this.itemLabels,
    required this.onWarningsAcknowledged,
    required this.onApply,
    required this.onDone,
  });

  final ImportPreflightResult preflight;
  final Set<ProfileSiteKey> profileSelectors;
  final Map<String, String> sourceNames;
  final Map<String, String> itemLabels;
  final ValueChanged<bool> onWarningsAcknowledged;
  final VoidCallback onApply;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final strings = context.t.settings.backup_and_restore.export_import;
    final visibleErrors = preflight.errors
        .where(
          (issue) =>
              issue.code != 'warnings_not_acknowledged' &&
              !(issue.code == 'unresolved_profile_dependency' &&
                  issue.profileDependency != null &&
                  profileSelectors.contains(
                    ProfileSiteKey.fromReference(
                      issue.profileDependency!.reference,
                    ),
                  )),
        )
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (preflight.warnings.isNotEmpty) ...[
          Text(
            strings.warnings,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          for (final issue in preflight.warnings)
            ListTile(
              leading: const Icon(Icons.warning_amber),
              title: Text(
                importIssueMessage(
                  context,
                  issue,
                  sourceNames: sourceNames,
                  itemLabels: itemLabels,
                ),
              ),
            ),
          if (preflight.requiresWarningAcknowledgement)
            CheckboxListTile(
              value: !preflight.errors.any(
                (issue) => issue.code == 'warnings_not_acknowledged',
              ),
              onChanged: (value) => onWarningsAcknowledged(value ?? false),
              title: Text(strings.acknowledge_warnings),
            ),
        ],
        if (visibleErrors.isNotEmpty) ...[
          Text(strings.errors, style: Theme.of(context).textTheme.titleMedium),
          for (final issue in visibleErrors)
            ListTile(
              leading: Icon(
                Icons.error_outline,
                color: Theme.of(context).colorScheme.error,
              ),
              title: Text(
                importIssueMessage(
                  context,
                  issue,
                  sourceNames: sourceNames,
                  itemLabels: itemLabels,
                ),
              ),
            ),
        ],
        const SizedBox(height: 20),
        if (preflight.isValid && !preflight.summary.hasMutations) ...[
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: Text(strings.nothing_to_import),
          ),
          FilledButton(onPressed: onDone, child: Text(strings.done)),
        ] else
          FilledButton(
            key: const ValueKey('apply-import'),
            onPressed: preflight.isValid ? onApply : null,
            child: Text(strings.apply_import),
          ),
      ],
    );
  }
}

class ImportCompletionView extends StatelessWidget {
  const ImportCompletionView({
    super.key,
    required this.onDone,
    this.summary,
    this.bookmarkRefreshFailed = false,
  });

  final VoidCallback onDone;
  final PlannedChangeSummary? summary;
  final bool bookmarkRefreshFailed;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle_outline, size: 72),
          const SizedBox(height: 12),
          Text(
            context.t.settings.backup_and_restore.export_import.import_complete,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          if (summary case final summary? when summary.hasMutations) ...[
            const SizedBox(height: 8),
            Text(
              plannedChangeCountLabels(
                summary,
                createdTemplate: context
                    .t
                    .settings
                    .backup_and_restore
                    .export_import
                    .completed_created_count,
                updatedTemplate: context
                    .t
                    .settings
                    .backup_and_restore
                    .export_import
                    .completed_updated_count,
                deletedTemplate: context
                    .t
                    .settings
                    .backup_and_restore
                    .export_import
                    .completed_deleted_count,
              ).join(' · '),
              textAlign: TextAlign.center,
            ),
          ],
          if (bookmarkRefreshFailed) ...[
            const SizedBox(height: 12),
            Text(
              context
                  .t
                  .settings
                  .backup_and_restore
                  .export_import
                  .bookmark_refresh_failed,
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: onDone,
            child: Text(
              context.t.settings.backup_and_restore.export_import.done,
            ),
          ),
        ],
      ),
    ),
  );
}

class ImportErrorView extends StatelessWidget {
  const ImportErrorView({super.key, required this.onChooseAnother});

  final VoidCallback onChooseAnother;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.error_outline,
            size: 72,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: 12),
          Text(
            context
                .t
                .settings
                .backup_and_restore
                .export_import
                .invalid_export_title,
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            context
                .t
                .settings
                .backup_and_restore
                .export_import
                .invalid_export_description,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: onChooseAnother,
            child: Text(
              context
                  .t
                  .settings
                  .backup_and_restore
                  .export_import
                  .choose_another_export,
            ),
          ),
        ],
      ),
    ),
  );
}

List<String> plannedSourceChangeLabels(
  PlannedChangeSummary summary, {
  required String createdTemplate,
  required String updatedTemplate,
  required String deletedTemplate,
  required Map<String, String Function(int)> entityNouns,
  required String homeArrangementLabel,
}) {
  if (summary.entitySummaries.isEmpty) {
    return plannedChangeCountLabels(
      summary,
      createdTemplate: createdTemplate,
      updatedTemplate: updatedTemplate,
      deletedTemplate: deletedTemplate,
    );
  }
  final labels = <String>[];
  for (final entity in const [
    'bookmark',
    'bookmark-group',
    'pinned-search',
    'pinned-folder',
    'pinned-home',
    'feed',
    'feed-search',
    'profile',
  ]) {
    final changes = summary.entitySummaries[entity];
    if (changes == null) continue;
    final noun = entityNouns[entity];
    for (final (count, template) in [
      (changes.created, createdTemplate),
      (changes.updated, updatedTemplate),
      (changes.deleted, deletedTemplate),
    ]) {
      if (count == 0) continue;
      final name = entity == 'pinned-home'
          ? homeArrangementLabel
          : '$count ${noun?.call(count) ?? entity}';
      labels.add(template.replaceAll('{count}', name));
    }
  }
  return labels;
}

List<String> plannedChangeCountLabels(
  PlannedChangeSummary summary, {
  required String createdTemplate,
  required String updatedTemplate,
  required String deletedTemplate,
}) => [
  if (summary.created > 0)
    createdTemplate.replaceAll('{count}', '${summary.created}'),
  if (summary.updated > 0)
    updatedTemplate.replaceAll('{count}', '${summary.updated}'),
  if (summary.deleted > 0)
    deletedTemplate.replaceAll('{count}', '${summary.deleted}'),
];

String _formatExportDate(BuildContext context, DateTime createdAt) {
  final local = createdAt.toLocal();
  final localizations = MaterialLocalizations.of(context);
  return '${localizations.formatMediumDate(local)} '
      '${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(local))}';
}

String _localizedItemLabel(
  BuildContext context,
  String id,
  String? fallback,
) => id == 'ungrouped'
    ? context.t.bookmark.groups.default_group
    : fallback ?? id;

ExportSelectionPresentation _localizedImportPresentation(
  BuildContext context,
  ExportSelectionPresentation presentation,
) => ExportSelectionPresentation(
  items: {
    ...presentation.items,
    'ungrouped': ExportItemPresentation(
      label: context.t.bookmark.groups.default_group,
    ),
    'home': ExportItemPresentation(label: context.t.pinned_searches.home),
  },
);

String _localizedSourceLabel(BuildContext context, String id) => switch (id) {
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

class _ProfileMappingTile extends StatelessWidget {
  const _ProfileMappingTile({
    required this.mapping,
    required this.profileNames,
    required this.onChanged,
  });

  final ProfileDependencyMapping mapping;
  final Map<String, String> profileNames;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final strings = context.t.settings.backup_and_restore.export_import;
    final site = mapping.siteKey.site;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(site, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Semantics(
              label: '${strings.target}: $site',
              child: DropdownButton<String>(
                isExpanded: true,
                itemHeight: null,
                value: mapping.candidateIds.contains(mapping.profileId)
                    ? mapping.profileId
                    : null,
                hint: Text(strings.issues.select_profile_target),
                items: [
                  for (final id in mapping.candidateIds)
                    DropdownMenuItem(
                      value: id,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(profileNames[id] ?? id),
                      ),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) onChanged(value);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
