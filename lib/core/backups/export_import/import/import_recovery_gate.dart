import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';

import '../../../../foundation/filesystem.dart';
import '../../sources/providers.dart';
import 'import_flow_notifier.dart';
import 'import_journal.dart';
import 'import_recovery_service.dart';
import 'import_transaction.dart';

final importRecoveryProvider =
    AsyncNotifierProvider<ImportRecoveryNotifier, ImportRecoveryResult>(
      ImportRecoveryNotifier.new,
    );

class ImportRecoveryNotifier extends AsyncNotifier<ImportRecoveryResult> {
  @override
  Future<ImportRecoveryResult> build() => _recover();

  Future<void> retry() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_recover);
  }

  Future<ImportRecoveryResult> _recover() async {
    final fs = ref.read(appFileSystemProvider);
    final root = await fs.getAppStoragePath();
    final store = ImportJournalStore(
      fs: fs,
      rootPath: '$root/import_transactions',
    );
    final sources = {
      for (final source in ref.read(backupRegistryProvider).getAllSources())
        source.id: PackageTransactionSource(
          source: source,
          incomingPath: null,
          fs: fs,
          ref: ref,
          credentialsIncluded: true,
        ),
    };
    return ImportRecoveryService(
      store: store,
      transaction: ImportTransaction(store: store, fs: fs),
      sources: () => sources,
    ).recoverPending();
  }
}

class ImportRecoveryGate extends ConsumerWidget {
  const ImportRecoveryGate({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recovery = ref.watch(importRecoveryProvider);
    return switch (recovery) {
      AsyncData(:final value) when value.failures.isEmpty => child,
      AsyncData(:final value) => _RecoveryApp(
        failureCount: value.failures.length,
        onRetry: ref.read(importRecoveryProvider.notifier).retry,
      ),
      AsyncError() => _RecoveryApp(
        failureCount: 1,
        onRetry: ref.read(importRecoveryProvider.notifier).retry,
      ),
      _ => const _RecoveryLoadingApp(),
    };
  }
}

class _RecoveryLoadingApp extends StatelessWidget {
  const _RecoveryLoadingApp();

  @override
  Widget build(BuildContext context) => MaterialApp(
    localizationsDelegates: context.localizationDelegates,
    supportedLocales: context.supportedLocales,
    locale: context.locale,
    home: const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    ),
  );
}

class _RecoveryApp extends StatelessWidget {
  const _RecoveryApp({required this.failureCount, required this.onRetry});

  final int failureCount;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final strings = context.t.settings.backup_and_restore.export_import;
    return MaterialApp(
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.restore, size: 64),
                const SizedBox(height: 16),
                Text(
                  strings.recovery_required,
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  strings.recovery_required_description.replaceAll(
                    '{count}',
                    '$failureCount',
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: onRetry,
                  child: Text(context.t.generic.action.retry),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
