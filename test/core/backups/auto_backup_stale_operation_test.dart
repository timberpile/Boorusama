import 'dart:async';

import 'package:boorusama/core/analytics/providers.dart';
import 'package:boorusama/core/backups/auto/providers.dart';
import 'package:boorusama/core/backups/auto/repo_io.dart';
import 'package:boorusama/core/backups/auto/service.dart';
import 'package:boorusama/core/backups/auto/types.dart';
import 'package:boorusama/core/backups/zip/providers.dart';
import 'package:boorusama/core/backups/zip/types.dart';
import 'package:boorusama/core/search/following_topics/providers.dart';
import 'package:boorusama/core/search/following_topics/src/types/topic_organization.dart';
import 'package:boorusama/core/settings/providers.dart';
import 'package:boorusama/core/settings/types.dart';
import 'package:boorusama/foundation/loggers.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/boorusama_test_runtime.dart';

class _Service extends Fake implements AutoBackupService {
  final entered = Completer<void>();
  final reply = Completer<BulkExportResult>();
  @override
  Future<BulkExportResult> performBackup(
    AutoBackupSettings settings, {
    void Function(double)? onProgress,
  }) {
    entered.complete();
    return reply.future;
  }
}

class _Directory extends Fake implements AutoBackupRepository {
  @override
  Future<String> getBackupDirectoryPath(String? path) async => path!;
}

class _ReadyFollowing extends FollowingTopicsNotifier {
  @override
  Future<FollowingTopicsState> build() async => FollowingTopicsState(
    topics: const [],
    refreshingIds: const {},
    batchCompleted: 0,
    batchTotal: 0,
    organization: TopicOrganization(folders: const []),
  );
}

void main() {
  for (final outcome in [
    'stale error',
    'newer error',
    'generic errors',
    'success',
  ]) {
    testWidgets(
      'old backup $outcome cannot resurrect error or restore the old directory',
      (tester) async {
        final service = _Service();
        final old = Settings.defaultSettings.autoBackup.copyWith(
          userSelectedPath: () => 'old',
        );
        final settings = Settings.defaultSettings.copyWith(autoBackup: old);
        final container = ProviderContainer(
          overrides: [
            autoBackupServiceProvider.overrideWithValue(service),
            autoBackupRepositoryProvider.overrideWithValue(_Directory()),
            followingTopicsProvider.overrideWith(_ReadyFollowing.new),
            settingsNotifierProvider.overrideWith(
              () => SettingsNotifier(settings),
            ),
            settingsRepoProvider.overrideWithValue(
              MemorySettingsRepository(settings),
            ),
            loggerProvider.overrideWithValue(
              ConsoleLogger(options: const ConsoleLoggerOptions.defaults()),
            ),
            analyticsProvider.overrideWith((_) => Future.value()),
          ],
        );
        addTearDown(container.dispose);
        final subscription = container.listen(backupProvider, (_, _) {});
        addTearDown(subscription.close);
        final pending = container
            .read(backupProvider.notifier)
            .performManualAutoBackup(old);
        await service.entered.future;
        expect(
          await container
              .read(autoBackupDirectoryRecoveryProvider)
              .selectDirectory('new'),
          isTrue,
        );
        final newer = (outcome == 'newer error' || outcome == 'generic errors')
            ? container
                  .read(autoBackupFailureProvider.notifier)
                  .report(StateError('newer'))
            : null;
        if (outcome == 'success') {
          service.reply.complete(
            const BulkExportResult(
              success: true,
              exported: [],
              failed: [],
              skipped: [],
              filePath: 'fake',
            ),
          );
        } else {
          service.reply.completeError(
            outcome == 'generic errors'
                ? StateError('old')
                : PlatformException(
                    code: 'backup_folder_access_required',
                    details: {'stage': 'check_persisted_permission'},
                  ),
          );
        }
        await tester.pump();
        await tester.pump(const Duration(seconds: 2));
        await pending;
        expect(container.read(autoBackupFailureProvider), same(newer));
        expect(
          container.read(backupProvider).status,
          isNot(BackupStatus.error),
        );
        expect(container.read(backupProvider).error, isNull);
        expect(
          container.read(settingsProvider).autoBackup.userSelectedPath,
          'new',
        );
      },
    );
  }
}
