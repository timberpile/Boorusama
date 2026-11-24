import 'dart:async';

import 'package:boorusama/core/analytics/providers.dart';
import 'package:boorusama/core/backups/auto/providers.dart';
import 'package:boorusama/core/backups/auto/repo_io.dart';
import 'package:boorusama/core/backups/auto/types.dart';
import 'package:boorusama/core/settings/providers.dart';
import 'package:boorusama/core/settings/types.dart';
import 'package:boorusama/core/settings/src/types/settings_repository.dart';
import 'package:boorusama/foundation/loggers.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/boorusama_test_runtime.dart';

class _Repository extends Fake implements AutoBackupRepository {
  final entered = <String, Completer<void>>{};
  final replies = <String, Completer<String>>{};
  @override
  Future<String> getBackupDirectoryPath(String? path) {
    entered.putIfAbsent(path!, Completer<void>.new).complete();
    return replies.putIfAbsent(path, Completer<String>.new).future;
  }

  Future<void> started(String path) =>
      entered.putIfAbsent(path, Completer<void>.new).future;
  void finish(String path, {bool valid = true}) {
    final reply = replies[path]!;
    if (valid) {
      reply.complete(path);
    } else {
      reply.completeError(
        PlatformException(
          code: 'backup_folder_access_required',
          details: {'stage': 'verify_folder_write'},
        ),
      );
    }
  }
}

class _FailedSave extends Fake implements SettingsRepository {
  @override
  Future<bool> save(Settings setting) async => false;
}

void main() {
  test(
    'failed settings write preserves folder and diagnostic without validating',
    () async {
      final repo = _Repository();
      final container = _container(repo, settingsRepository: _FailedSave());
      addTearDown(container.dispose);
      final before = container
          .read(settingsProvider)
          .autoBackup
          .userSelectedPath;
      final diagnostic = container
          .read(autoBackupFailureProvider.notifier)
          .report(
            PlatformException(code: 'backup_folder_access_required'),
          );
      expect(
        await container
            .read(autoBackupDirectoryRecoveryProvider)
            .selectDirectory('new'),
        isFalse,
      );
      expect(
        container.read(settingsProvider).autoBackup.userSelectedPath,
        before,
      );
      expect(container.read(autoBackupFailureProvider), same(diagnostic));
      expect(repo.entered, isEmpty);
    },
  );
  for (final valid in [true, false]) {
    for (final unrelated in [false, true]) {
      test(
        'validated directory recovery valid=$valid unrelated=$unrelated',
        () async {
          final repo = _Repository();
          final container = _container(repo);
          addTearDown(container.dispose);
          final failure = container.read(autoBackupFailureProvider.notifier);
          final before = failure.report(
            unrelated
                ? StateError('fixture')
                : PlatformException(code: 'backup_folder_access_required'),
          );
          final operation = container
              .read(autoBackupDirectoryRecoveryProvider)
              .selectDirectory('new');
          await repo.started('new');
          expect(container.read(autoBackupFailureProvider), same(before));
          repo.finish('new', valid: valid);
          expect(await operation, valid);
          final after = container.read(autoBackupFailureProvider);
          if (unrelated) {
            expect(after, same(before));
          } else if (valid) {
            expect(after, isNull);
          } else {
            expect(after?.requiresFolderAccess, isTrue);
            expect(after?.stage, 'verify_folder_write');
          }
          expect(
            container.read(settingsProvider).autoBackup.userSelectedPath,
            'new',
          );
        },
      );
    }
  }

  for (final succeeds in [true, false]) {
    test(
      'newer access diagnostic survives stale directory validation succeeds=$succeeds',
      () async {
        final repo = _Repository();
        final container = _container(repo);
        addTearDown(container.dispose);
        final failure = container.read(autoBackupFailureProvider.notifier);
        failure.report(
          PlatformException(
            code: 'backup_folder_access_required',
            details: {'stage': 'check_persisted_permission'},
          ),
        );
        final pending = container
            .read(autoBackupDirectoryRecoveryProvider)
            .selectDirectory('new');
        await repo.started('new');
        final newer = failure.report(
          PlatformException(
            code: 'backup_folder_access_required',
            details: {'stage': 'verify_folder_write'},
          ),
        );
        repo.finish('new', valid: succeeds);
        await pending;
        expect(container.read(autoBackupFailureProvider), same(newer));
        expect(newer.stage, 'verify_folder_write');
      },
    );
  }

  test(
    'older backup and directory completions cannot overwrite recovered access',
    () async {
      final repo = _Repository();
      final container = _container(repo);
      addTearDown(container.dispose);
      final failure = container.read(autoBackupFailureProvider.notifier);
      failure.report(PlatformException(code: 'backup_folder_access_required'));
      final oldBackup = failure.revision;
      final recovery = container.read(autoBackupDirectoryRecoveryProvider);
      final first = recovery.selectDirectory('first');
      await repo.started('first');
      final second = recovery.selectDirectory('second');
      await repo.started('second');
      repo.finish('second');
      expect(await second, isTrue);
      repo.finish('first', valid: false);
      expect(await first, isFalse);
      failure.report(
        PlatformException(code: 'backup_folder_access_required'),
        revision: oldBackup,
      );
      expect(container.read(autoBackupFailureProvider), isNull);
      expect(
        container.read(settingsProvider).autoBackup.userSelectedPath,
        'second',
      );
    },
  );

  test('a new unrelated failure during validation is retained', () async {
    final repo = _Repository();
    final container = _container(repo);
    addTearDown(container.dispose);
    final failure = container.read(autoBackupFailureProvider.notifier);
    failure.report(PlatformException(code: 'backup_folder_access_required'));
    final pending = container
        .read(autoBackupDirectoryRecoveryProvider)
        .selectDirectory('new');
    await repo.started('new');
    final newer = failure.report(StateError('fixture'));
    repo.finish('new');
    await pending;
    expect(container.read(autoBackupFailureProvider), same(newer));
  });
}

ProviderContainer _container(
  _Repository repo, {
  SettingsRepository? settingsRepository,
}) => ProviderContainer(
  overrides: [
    autoBackupRepositoryProvider.overrideWithValue(repo),
    settingsNotifierProvider.overrideWith(
      () => SettingsNotifier(Settings.defaultSettings),
    ),
    settingsRepoProvider.overrideWithValue(
      settingsRepository ?? MemorySettingsRepository(),
    ),
    loggerProvider.overrideWithValue(
      ConsoleLogger(options: const ConsoleLoggerOptions.defaults()),
    ),
    analyticsProvider.overrideWith((_) => Future.value()),
  ],
);
