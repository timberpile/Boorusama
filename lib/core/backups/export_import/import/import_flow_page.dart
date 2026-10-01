import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';

import '../../sources/providers.dart';
import '../export/export_flow_notifier.dart';
import '../widgets/import_action_editor.dart';
import 'import_flow_notifier.dart';

class ImportFlowPage extends ConsumerStatefulWidget {
  const ImportFlowPage({super.key, required this.packagePath});

  final String packagePath;

  @override
  ConsumerState<ImportFlowPage> createState() => _ImportFlowPageState();
}

class _ImportFlowPageState extends ConsumerState<ImportFlowPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(importFlowProvider.notifier).load(widget.packagePath),
    );
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
    final labels = ref.watch(exportSelectionLabelsProvider).children;
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
        const SizedBox(height: 12),
        for (final source in proposed.sources)
          ImportActionEditor(
            proposed: source,
            resolved: resolvedById[source.id]!,
            onChanged: ref.read(importFlowProvider.notifier).replaceSource,
            sourceLabel: (id) => sourceNames[id] ?? id,
            itemLabel: (id) => labels[id] ?? id,
            targetLabel: (id) => labels[id] ?? id,
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
              title: Text(_issueText(issue.code, issue.sourceId)),
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
                title: Text(_issueText(issue.code, issue.sourceId)),
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

String _issueText(String code, String sourceId) => '$sourceId: $code';
