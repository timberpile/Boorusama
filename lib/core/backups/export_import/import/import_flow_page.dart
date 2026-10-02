import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';

import '../../../configs/manage/providers.dart';
import '../../sources/providers.dart';
import '../export/export_flow_notifier.dart';
import '../models/import_action.dart';
import '../widgets/import_action_editor.dart';
import 'import_flow_notifier.dart';
import 'import_issue_message.dart';
import 'import_plan.dart';
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
      appBar: AppBar(title: Text(strings.review_import)),
      body: switch (state.status) {
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
        ImportFlowStatus.complete => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle_outline, size: 72),
              const SizedBox(height: 12),
              Text(
                strings.import_complete,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ],
          ),
        ),
        ImportFlowStatus.error => Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            strings.invalid_export.replaceAll(
              '{error}',
              state.error.toString(),
            ),
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
        ImportFlowStatus.review => _ReviewImport(state: state),
      },
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
        source.id: source.displayName,
    };
    final localLabels = ref.watch(exportSelectionLabelsProvider).children;
    final profileNames = {
      for (final profile in ref.watch(booruConfigProvider))
        profile.id: profile.name,
    };
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          strings.import_summary.replaceAll(
            '{count}',
            '${proposed.sources.length}',
          ),
          style: Theme.of(context).textTheme.titleLarge,
        ),
        if (state.createdAt case final createdAt?)
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: Text(strings.export_details),
            subtitle: Text(
              strings.export_details_summary
                  .replaceAll('{version}', state.exporterVersion ?? '—')
                  .replaceAll('{date}', createdAt.toLocal().toString()),
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
            itemLabel: (id) => state.itemLabels[id] ?? localLabels[id] ?? id,
            targetLabel: (id) => localLabels[id] ?? id,
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
          if (!mapping.providedByImport &&
              (!mapping.isResolved || mapping.createdFromReference))
            _ProfileMappingTile(
              mapping: mapping,
              profileNames: profileNames,
              onChanged: (profileId) => ref
                  .read(importFlowProvider.notifier)
                  .chooseProfileMapping(
                    ProfileReferenceKey.fromReference(mapping.reference),
                    profileId,
                  ),
              onCreate: () => ref
                  .read(importFlowProvider.notifier)
                  .createProfileFor(
                    ProfileReferenceKey.fromReference(mapping.reference),
                  ),
            ),
        if (state.alreadyPresentSearches > 0)
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: Text(
              strings.already_present.replaceAll(
                '{count}',
                '${state.alreadyPresentSearches}',
              ),
            ),
          ),
        if (preflight.sourceSummaries.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            strings.planned_changes,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          for (final source in resolved.sources)
            if (preflight.sourceSummaries[source.id] case final summary?)
              if (_hasReviewedEffect(source, summary))
                ListTile(
                  leading: const Icon(Icons.fact_check_outlined),
                  title: Text(sourceNames[source.id] ?? source.id),
                  subtitle: Text(
                    _plannedChangeDescription(
                      source,
                      summary,
                      containsCredentials: state.containsCredentials,
                      summaryTemplate: strings.planned_change_summary,
                      credentialsReplaced: strings.profile_credentials_replaced,
                      credentialsPreserved:
                          strings.profile_credentials_preserved,
                      bookmarkOrphanPolicy: strings.bookmark_orphan_policy,
                      ungroupedRemovalPolicy: strings.ungrouped_removal_policy,
                    ),
                  ),
                ),
        ],
        const SizedBox(height: 16),
        if (preflight.warnings.isEmpty && preflight.errors.isEmpty)
          ListTile(
            leading: const Icon(Icons.check_circle_outline),
            title: Text(strings.all_checks_passed),
          ),
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
                  itemLabels: {...localLabels, ...state.itemLabels},
                ),
              ),
            ),
          CheckboxListTile(
            value: !preflight.errors.any(
              (issue) => issue.code == 'warnings_not_acknowledged',
            ),
            onChanged: (value) => ref
                .read(importFlowProvider.notifier)
                .acknowledgeWarnings(value ?? false),
            title: Text(strings.acknowledge_warnings),
          ),
        ],
        if (preflight.errors.isNotEmpty) ...[
          Text(strings.errors, style: Theme.of(context).textTheme.titleMedium),
          for (final issue in preflight.errors)
            if (issue.code != 'warnings_not_acknowledged')
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
                    itemLabels: {...localLabels, ...state.itemLabels},
                  ),
                ),
              ),
        ],
        const SizedBox(height: 20),
        FilledButton(
          key: const ValueKey('apply-import'),
          onPressed: preflight.isValid
              ? () => ref.read(importFlowProvider.notifier).apply(context)
              : null,
          child: Text(strings.apply_import),
        ),
      ],
    );
  }
}

bool _hasReviewedEffect(
  ResolvedImportSource source,
  PlannedChangeSummary summary,
) =>
    source.action != ImportAction.skip ||
    summary.created > 0 ||
    summary.updated > 0 ||
    summary.deleted > 0 ||
    summary.unchanged > 0;

String _plannedChangeDescription(
  ResolvedImportSource source,
  PlannedChangeSummary summary, {
  required bool containsCredentials,
  required String summaryTemplate,
  required String credentialsReplaced,
  required String credentialsPreserved,
  required String bookmarkOrphanPolicy,
  required String ungroupedRemovalPolicy,
}) {
  final base = summaryTemplate
      .replaceAll('{created}', '${summary.created}')
      .replaceAll('{updated}', '${summary.updated}')
      .replaceAll('{deleted}', '${summary.deleted}')
      .replaceAll('{preserved}', '${summary.preserved}')
      .replaceAll('{unchanged}', '${summary.unchanged}');
  final details = <String>[base];
  if (source.id == 'profiles' && (summary.created > 0 || summary.updated > 0)) {
    if (containsCredentials) {
      details.add(credentialsReplaced);
    } else if (summary.updated > 0) {
      details.add(credentialsPreserved);
    }
  }
  if (source.id == 'bookmarks' &&
      source.items.any(
        (item) =>
            item.id.startsWith('group:') && item.action == ImportAction.update,
      )) {
    details.add(bookmarkOrphanPolicy);
  }
  if (source.id == 'bookmarks' &&
      source.items.any(
        (item) => item.id == 'ungrouped' && item.action == ImportAction.update,
      )) {
    details.add(ungroupedRemovalPolicy);
  }
  return details.join('\n');
}

class _ProfileMappingTile extends StatelessWidget {
  const _ProfileMappingTile({
    required this.mapping,
    required this.profileNames,
    required this.onChanged,
    required this.onCreate,
  });

  final ProfileDependencyMapping mapping;
  final Map<int, String> profileNames;
  final ValueChanged<int> onChanged;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      title: Text(mapping.reference.name),
      subtitle: Text(
        '${mapping.reference.booruType} · ${mapping.reference.url}',
      ),
      trailing: Wrap(
        spacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (mapping.candidateIds.isNotEmpty && !mapping.createdFromReference)
            DropdownButton<int>(
              value: mapping.candidateIds.contains(mapping.profileId)
                  ? mapping.profileId
                  : null,
              hint: Text(
                context.t.settings.backup_and_restore.export_import.target,
              ),
              items: [
                for (final id in mapping.candidateIds)
                  DropdownMenuItem(
                    value: id,
                    child: Text(profileNames[id] ?? '$id'),
                  ),
              ],
              onChanged: (value) {
                if (value != null) onChanged(value);
              },
            ),
          if (mapping.createdFromReference)
            Text(
              context.t.settings.backup_and_restore.export_import.new_profile,
            )
          else
            TextButton(
              onPressed: onCreate,
              child: Text(
                context
                    .t
                    .settings
                    .backup_and_restore
                    .export_import
                    .create_profile,
              ),
            ),
        ],
      ),
    ),
  );
}
