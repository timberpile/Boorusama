import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:boorusama/core/backups/auto/repo_io.dart';
import 'package:boorusama/core/backups/auto/types.dart';
import 'package:boorusama/core/backups/export_import/export/export_flow_notifier.dart';
import 'package:boorusama/core/backups/export_import/export/export_service.dart';
import 'package:boorusama/core/backups/export_import/models/export_selection.dart';
import 'package:boorusama/core/backups/export_import/package/export_package_reader.dart';
import 'package:boorusama/core/backups/export_import/package/export_package_writer.dart';
import 'package:boorusama/core/backups/export_import/sources/export_import_source.dart';
import 'package:boorusama/core/backups/sources/providers.dart';
import 'package:boorusama/core/backups/zip/providers.dart';
import 'package:boorusama/core/search/following_topics/providers.dart';
import 'package:boorusama/core/search/following_topics/src/types/topic_organization.dart';
import 'package:boorusama/core/settings/providers.dart';
import 'package:boorusama/core/settings/src/types/settings.dart';
import 'package:boorusama/foundation/filesystem.dart';
import 'package:boorusama/foundation/loggers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  // Keep the production catalog, notifiers, service, package writer and reader.
  // Only repository loading and source payloads are replaced at their boundary.
  // Removing either production readiness await must break its corresponding
  // manifest assertion: the unresolved source must not be treated as absent.
  for (final automatic in [false, true]) {
    test(
      'cold full export includes late source (automatic=$automatic)',
      () async {
        final harness = await _Harness.create(hasLegacyFeeds: true);
        addTearDown(harness.dispose);
        var finished = false;
        final operation = harness.export(automatic).then((path) {
          finished = true;
          return path;
        });
        addTearDown(() async {
          harness.finishLoading();
          await operation;
        });
        await harness.container.pump();
        expect(finished, isFalse);
        if (!automatic) expect(harness.fs.createdExportDirectories, 0);
        harness.finishLoading();
        final staged = await const ExportPackageReader(fs: IoFileSystem())
            .stage(await operation);
        addTearDown(staged.dispose);
        expect(staged.manifest.sources.map((source) => source.id).toSet(), {
          'settings',
          'following_feeds',
        });
      },
    );

    test('empty loaded feed catalog is valid (automatic=$automatic)', () async {
      final harness = await _Harness.create(hasLegacyFeeds: false);
      addTearDown(harness.dispose);
      harness.finishLoading();
      final staged = await const ExportPackageReader(fs: IoFileSystem())
          .stage(await harness.export(automatic));
      addTearDown(staged.dispose);
      expect(staged.manifest.sources.map((source) => source.id).toSet(), {
        'settings',
      });
    });
  }

  test(
    'failed readiness does not rotate backups or advance backup time',
    () async {
      final harness = await _Harness.create(hasLegacyFeeds: true);
      addTearDown(harness.dispose);
      final before = harness.container.read(settingsProvider).autoBackup;
      final backupDirectory = await harness.repository.getBackupDirectoryPath(
        harness.directory.path,
      );
      final oldPath = p.join(backupDirectory, 'previous.bsexport');
      await File(oldPath).writeAsString('previous recovery copy');
      await harness.repository.saveManifest(
        backupDirectory,
        AutoBackupManifest(
          backups: [
            AutoBackupEntry(
              fileName: 'previous.bsexport',
              createdAt: DateTime.utc(2024),
              fileSize: await File(oldPath).length(),
            ),
          ],
        ),
      );
      final operation = harness.container
          .read(backupProvider.notifier)
          .performManualAutoBackup(before);
      await harness.container.pump();
      harness.ready.completeError(StateError('following storage unavailable'));
      await operation;
      expect(harness.container.read(backupProvider).status, BackupStatus.error);
      expect(
        harness.container.read(settingsProvider).autoBackup.lastBackupTime,
        DateTime.utc(2024),
      );
      expect(await File(oldPath).readAsString(), 'previous recovery copy');
      final manifest = await harness.repository.loadManifest(backupDirectory);
      expect(manifest.backups.map((entry) => entry.fileName), [
        'previous.bsexport',
      ]);
    },
  );

  test(
    'a full export cannot silently drop a source lost during directory setup',
    () async {
      final harness = await _Harness.create(hasLegacyFeeds: true);
      addTearDown(harness.dispose);
      harness.finishLoading();
      final following = harness.container.read(
        followingTopicsProvider.notifier,
      ) as _Following;
      harness.fs.onCreateExportDirectory = following.fail;
      await expectLater(harness.export(false), throwsStateError);
      expect(
        harness.container.read(exportFlowProvider).status,
        ExportFlowStatus.error,
      );
    },
  );

  test('settings-only custom export does not wait for Following', () async {
    final harness = await _Harness.create(hasLegacyFeeds: true);
    addTearDown(harness.dispose);
    final notifier = harness.container.read(exportFlowProvider.notifier);
    notifier.useCustomExport();
    notifier.toggleSource(const ExportSelectionDescriptor.leaf(id: 'settings'));
    final staged = await const ExportPackageReader(fs: IoFileSystem())
        .stage(await notifier.createExport());
    addTearDown(staged.dispose);
    expect(harness.ready.isCompleted, isFalse);
    expect(staged.manifest.sources.map((source) => source.id), ['settings']);
  });
}

class _Harness {
  _Harness(
    this.directory,
    this.ready,
    this.container,
    this.repository,
    this.fs,
    this.subscriptions,
  );

  static Future<_Harness> create({required bool hasLegacyFeeds}) async {
    final directory = await Directory.systemTemp.createTemp('rca001_');
    final ready = Completer<FollowingTopicsState>();
    final fs = _FileSystem(directory.path);
    final repository = AutoBackupRepositoryIo(fs);
    final settings = AutoBackupSettings(
      userSelectedPath: directory.path,
      maxBackups: 1,
      lastBackupTime: DateTime.utc(2024),
    );
    final container = ProviderContainer(
      overrides: [
        appFileSystemProvider.overrideWithValue(fs),
        loggerProvider.overrideWithValue(const _Logger()),
        followingTopicsProvider.overrideWith(() => _Following(ready.future)),
        settingsNotifierProvider.overrideWith(
          () => _Settings(
            Settings.defaultSettings.copyWith(autoBackup: settings),
          ),
        ),
        // Model only the production conditional-source boundary. A separate
        // released-Hive acceptance test must verify its actual legacy-feed data.
        exportImportSourcesProvider.overrideWith(
          (ref) => [
            _Source('settings'),
            if (hasLegacyFeeds && ref.watch(followingTopicsProvider).hasValue)
              _Source('following_feeds'),
          ],
        ),
        exportServiceProvider.overrideWith(
          (ref) => ExportService(
            sources: () => ref.read(exportImportSourcesProvider),
            writer: ExportPackageWriter(fs: fs),
            appVersion: 'audit-test',
          ),
        ),
        autoBackupRepositoryProvider.overrideWithValue(repository),
      ],
    );
    final subscriptions = <ProviderSubscription<dynamic>>[
      container.listen(backupProvider, (_, _) {}, fireImmediately: true),
      container.listen(exportFlowProvider, (_, _) {}, fireImmediately: true),
    ];
    return _Harness(directory, ready, container, repository, fs, subscriptions);
  }

  final _FileSystem fs;
  final Directory directory;
  final Completer<FollowingTopicsState> ready;
  final ProviderContainer container;
  final AutoBackupRepositoryIo repository;
  final List<ProviderSubscription<dynamic>> subscriptions;

  void finishLoading() {
    if (!ready.isCompleted)
      ready.complete(
        FollowingTopicsState(
          topics: const [],
          refreshingIds: const {},
          batchCompleted: 0,
          batchTotal: 0,
          organization: TopicOrganization(folders: const []),
        ),
      );
  }

  Future<String> export(bool automatic) async {
    if (!automatic)
      return container.read(exportFlowProvider.notifier).createExport();
    await container
        .read(backupProvider.notifier)
        .performManualAutoBackup(
          container.read(settingsProvider).autoBackup,
        );
    final state = container.read(backupProvider);
    expect(state.status, BackupStatus.completed);
    return state.exportResult!.filePath;
  }

  Future<void> dispose() async {
    finishLoading();
    for (final subscription in subscriptions) subscription.close();
    container.dispose();
    await directory.delete(recursive: true);
  }
}

class _Following extends FollowingTopicsNotifier {
  _Following(this.loaded);
  final Future<FollowingTopicsState> loaded;
  void fail() => state = AsyncError(
    StateError('Following unavailable'),
    StackTrace.current,
  );
  @override
  Future<FollowingTopicsState> build() => loaded;
}

class _Settings extends SettingsNotifier {
  _Settings(super.initialSettings);
  @override
  Future<bool> updateWith(Settings Function(Settings) selector) async {
    state = selector(state);
    return true;
  }
}

class _FileSystem extends IoFileSystem {
  _FileSystem(this.root);
  int createdExportDirectories = 0;
  void Function()? onCreateExportDirectory;
  final String root;
  @override
  Future<String> createTempDirectory(String prefix) async {
    if (prefix == 'boorusama_export_') {
      createdExportDirectories++;
      onCreateExportDirectory?.call();
    }
    return (await Directory(root).createTemp(prefix)).path;
  }
}

class _Source implements ExportImportSource {
  _Source(this.id);
  @override
  final String id;
  @override
  int get priority => 0;
  @override
  int get schemaVersion => 1;
  @override
  ExportSelectionDescriptor get selectionDescriptor =>
      ExportSelectionDescriptor.leaf(id: id);
  @override
  Future<ExportSourceSnapshot> capture(ExportSourceRequest request) async =>
      ExportSourceSnapshot.json(
        sourceId: id,
        schemaVersion: 1,
        json: jsonEncode({'source': id}),
      );
}

class _Logger implements Logger {
  const _Logger();
  @override
  String getDebugName() => 'RCA-001 test';
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
