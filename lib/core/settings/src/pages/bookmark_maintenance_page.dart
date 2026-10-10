import 'performance_diagnostics_page.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';

import '../../../bookmarks/src/providers/bookmark_hydration_provider.dart';
import '../../../bookmarks/src/providers/bookmark_provider.dart';
import '../../../bookmarks/src/services/bookmark_hydration_service.dart';
import '../widgets/bookmark_hydration_log.dart';
import '../widgets/settings_page_scaffold.dart';

class AdvancedDataSettingsPage extends StatelessWidget {
  const AdvancedDataSettingsPage({super.key});

  @override
  Widget build(BuildContext context) => SettingsPageScaffold(
    title: Text(context.t.bookmark.maintenance.advanced),
    children: [
      ListTile(
        title: Text(context.t.performance_diagnostics.title),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const PerformanceDiagnosticsPage(),
          ),
        ),
      ),
      ListTile(
        title: Text(context.t.bookmark.maintenance.title),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const BookmarkMaintenancePage(),
          ),
        ),
      ),
    ],
  );
}

class BookmarkMaintenancePage extends ConsumerWidget {
  const BookmarkMaintenancePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = context.t.bookmark.maintenance;
    final library = ref.watch(bookmarkProvider);
    final progress = ref.watch(bookmarkHydrationProvider);
    final candidates = library.valueOrNull?.items
        .where(needsBookmarkHydration)
        .length;
    final summary = strings.result
        .replaceAll('{0}', '${progress.updated}')
        .replaceAll('{1}', '${progress.skipped}')
        .replaceAll('{2}', '${progress.failed}');
    return SettingsPageScaffold(
      title: Text(strings.title),
      children: [
        ListTile(
          title: Text(strings.hydrate),
          subtitle: Text(strings.description),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (candidates != null && !progress.running)
                Text(strings.candidates.replaceAll('{0}', '$candidates')),
              if (library.hasError) Text(strings.error),
              if (progress.running && progress.rateLimitedSites.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  strings.rate_limited.replaceAll(
                    '{sites}',
                    progress.rateLimitedSites.join(', '),
                  ),
                ),
              ],
              if (progress.running) ...[
                LinearProgressIndicator(
                  value: progress.total == 0
                      ? null
                      : progress.processed / progress.total,
                ),
                const SizedBox(height: 12),
                Text(
                  strings.progress
                      .replaceAll('{0}', '${progress.processed}')
                      .replaceAll('{1}', '${progress.total}'),
                ),
                Text(summary),
                if (progress.retryAt case final retryAt?) ...[
                  const SizedBox(height: 12),
                  Text(
                    strings.retry_waiting
                        .replaceAll('{0}', '${progress.failed}')
                        .replaceAll(
                          '{1}',
                          retryAt.toLocal().toString().split('.').first,
                        ),
                  ),
                ] else if (progress.retryPass > 0) ...[
                  const SizedBox(height: 12),
                  Text(
                    strings.retrying
                        .replaceAll('{0}', '${progress.failed}')
                        .replaceAll('{1}', '${progress.retryPass}'),
                  ),
                ],
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () =>
                      ref.read(bookmarkHydrationProvider.notifier).cancel(),
                  child: Text(context.t.generic.action.cancel),
                ),
              ] else ...[
                if (progress.total > 0) ...[
                  const SizedBox(height: 12),
                  if (progress.cancelled) Text(strings.cancelled),
                  Text(summary),
                ],
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: candidates == null || candidates == 0
                      ? null
                      : () async {
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: Text(strings.hydrate),
                              content: SingleChildScrollView(
                                child: Text(
                                  strings.confirm.replaceAll(
                                    '{0}',
                                    '$candidates',
                                  ),
                                ),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                  child: Text(
                                    context.t.generic.action.cancel,
                                  ),
                                ),
                                FilledButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: Text(strings.start),
                                ),
                              ],
                            ),
                          );
                          if (confirmed != true || !context.mounted) return;
                          try {
                            await ref
                                .read(bookmarkHydrationProvider.notifier)
                                .start();
                          } catch (_) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(strings.error)),
                              );
                            }
                          }
                        },
                  child: Text(strings.hydrate),
                ),
              ],
            ],
          ),
        ),
        BookmarkHydrationLog(entries: progress.logEntries),
      ],
    );
  }
}
