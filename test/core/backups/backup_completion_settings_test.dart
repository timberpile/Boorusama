import 'dart:async';
import 'dart:io';

import 'package:boorusama/core/analytics/providers.dart';
import 'package:boorusama/core/backups/sources/settings_source.dart';
import 'package:boorusama/core/settings/src/types/settings_repository.dart';
import 'package:boorusama/foundation/applock/applock.dart';
import 'package:boorusama/foundation/info/package_info.dart';

import 'package:boorusama/core/backups/auto/providers.dart';
import 'package:boorusama/core/backups/auto/service.dart';
import 'package:boorusama/core/backups/auto/types.dart';
import 'package:boorusama/core/backups/zip/providers.dart';
import 'package:boorusama/core/backups/zip/types.dart';
import 'package:boorusama/core/search/following_topics/providers.dart';
import 'package:boorusama/core/search/following_topics/src/types/topic_organization.dart';
import 'package:boorusama/core/settings/providers.dart';
import 'package:boorusama/core/settings/src/data/setting_repository_hive.dart';
import 'package:boorusama/core/settings/src/types/settings.dart';
import 'package:boorusama/foundation/loggers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

void main() {
  test(
    'restore sees the preceding queued lock edit and propagates a failed save',
    () async {
      final repository = _ControlledSettings();
      final container = ProviderContainer(
        overrides: [
          appVersionProvider.overrideWithValue(null),
          analyticsProvider.overrideWith((ref) => null),
          loggerProvider.overrideWithValue(const _Logger()),
          settingsRepoProvider.overrideWithValue(repository),
          settingsNotifierProvider.overrideWith(
            () => SettingsNotifier(Settings.defaultSettings),
          ),
        ],
      );
      addTearDown(container.dispose);
      final source = container.read(Provider(SettingsBackupSource.new));
      final lockEdit = container
          .read(settingsNotifierProvider.notifier)
          .updateWith(
            (s) => s.copyWith(
              appLockType: AppLockType.pin,
              appLockTimeoutSeconds: 61,
            ),
          );
      await repository.started.future;
      final incoming = Settings.defaultSettings.copyWith(
        downloadPath: '/restored',
      );
      final restore = source.executor(incoming, null);
      repository.release.complete();
      expect(await lockEdit, isTrue);
      await restore;
      final saved = container.read(settingsProvider);
      expect(saved.appLockType, AppLockType.pin);
      expect(saved.appLockTimeoutSeconds, 61);
      expect(saved.downloadPath, '/restored');
      repository.fail = true;
      await expectLater(
        source.executor(Settings.defaultSettings, null),
        throwsStateError,
      );
      expect(container.read(settingsProvider), saved);
    },
  );
  // These assertions exercise the production completion selector. Restoring
  // its captured `settings.copyWith` must overwrite a real newer preference
  // and fail, independently of package/filesystem details.
  for (final changeDestination in [false, true]) {
    test(
      'completion preserves current settings, moved=$changeDestination',
      () async {
        final initial = AutoBackupSettings(
          enabled: true,
          userSelectedPath: '/backup/original',
          maxBackups: 1,
          frequency: AutoBackupFrequency.daily,
          lastBackupTime: DateTime.utc(2024),
        );
        final directory = await Directory.systemTemp.createTemp(
          'backup-settings-',
        );
        Hive.init(directory.path);
        addTearDown(() async {
          await Hive.close();
          await directory.delete(recursive: true);
        });
        final repository = SettingsRepositoryHive(Hive.openBox('settings'));
        final initialSettings = Settings.defaultSettings.copyWith(
          autoBackup: initial,
        );
        await repository.save(initialSettings);
        final service = _PausedBackup();
        final container = ProviderContainer(
          overrides: [
            autoBackupServiceProvider.overrideWithValue(service),
            loggerProvider.overrideWithValue(const _Logger()),
            followingTopicsProvider.overrideWith(_ReadyFollowing.new),
            analyticsProvider.overrideWith((ref) => null),
            settingsRepoProvider.overrideWithValue(repository),
            settingsNotifierProvider.overrideWith(
              () => SettingsNotifier(initialSettings),
            ),
          ],
        );
        addTearDown(container.dispose);
        final subscription = container.listen(backupProvider, (_, _) {});
        addTearDown(subscription.close);
        final operation = container
            .read(backupProvider.notifier)
            .performManualAutoBackup(initial);
        addTearDown(() async {
          if (!service.result.isCompleted) service.complete();
          await operation;
        });
        await service.started.future;
        final updated = initial.copyWith(
          frequency: AutoBackupFrequency.weekly,
          maxBackups: 30,
          enabled: false,
          userSelectedPath: () => changeDestination
              ? '/backup/new-location'
              : initial.userSelectedPath,
          lastBackupTime: () =>
              changeDestination ? null : initial.lastBackupTime,
        );
        await container
            .read(settingsNotifierProvider.notifier)
            .updateWith(
              (s) => s.copyWith(autoBackup: updated),
            );
        service.complete();
        await operation;
        final live = container.read(settingsProvider).autoBackup;
        await Hive.close();
        final reopened = SettingsRepositoryHive(Hive.openBox('settings'));
        final saved = (await reopened.load().run()).fold(
          (error) => throw StateError('Cannot reopen settings: $error'),
          (value) => value.autoBackup,
        );
        expect(saved, live);
        expect(saved.frequency, AutoBackupFrequency.weekly);
        expect(saved.maxBackups, 30);
        expect(saved.enabled, isFalse);
        expect(
          saved.userSelectedPath,
          changeDestination ? '/backup/new-location' : '/backup/original',
        );
        if (changeDestination) {
          expect(saved.lastBackupTime, isNull);
        } else {
          expect(saved.lastBackupTime!.isAfter(DateTime.utc(2024)), isTrue);
        }
      },
    );
  }
}

class _PausedBackup implements AutoBackupService {
  final started = Completer<void>();
  final result = Completer<BulkExportResult>();

  @override
  Future<BulkExportResult> performBackup(
    AutoBackupSettings settings, {
    void Function(double progress)? onProgress,
  }) {
    started.complete();
    return result.future;
  }

  void complete() => result.complete(
    const BulkExportResult(
      success: true,
      exported: ['settings'],
      failed: [],
      skipped: [],
      filePath: '/backup/original/completed.bsexport',
    ),
  );

  // The notifier only calls performBackup. Any new dependency must be modeled
  // explicitly rather than silently accepted by this controlled boundary.
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('Unexpected AutoBackupService member');
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

class _Logger implements Logger {
  const _Logger();
  @override
  String getDebugName() => 'RCA-002 test';
  @override
  void debug(String serviceName, String message, {String? sensitiveMessage}) {}
  @override
  void error(String serviceName, String message, {String? sensitiveMessage}) {}
  @override
  void info(String serviceName, String message, {String? sensitiveMessage}) {}
  @override
  void verbose(
    String serviceName,
    String message, {
    String? sensitiveMessage,
  }) {}
  @override
  void warn(String serviceName, String message, {String? sensitiveMessage}) {}
}

class _ControlledSettings implements SettingsRepository {
  final started = Completer<void>();
  final release = Completer<void>();
  var fail = false;

  @override
  Future<bool> save(Settings setting) async {
    if (!started.isCompleted) started.complete();
    await release.future;
    return !fail;
  }

  @override
  SettingsOrError load() =>
      throw UnsupportedError('Settings were initialized directly');
}
