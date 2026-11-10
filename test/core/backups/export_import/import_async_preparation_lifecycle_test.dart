import 'dart:async';
import 'dart:io';

import 'package:boorusama/core/backups/export_import/import/import_flow_notifier.dart';
import 'package:boorusama/core/backups/export_import/models/export_selection.dart';
import 'package:boorusama/core/backups/export_import/package/export_package_writer.dart';
import 'package:boorusama/core/backups/export_import/sources/legacy_json_source_adapter.dart';
import 'package:boorusama/core/backups/preparation/version_checking.dart';
import 'package:boorusama/core/backups/sources/bookmark_backup_codec.dart';
import 'package:boorusama/core/backups/sources/bookmark_backup_data.dart';
import 'package:boorusama/core/backups/sources/bookmark_backup_worker.dart';
import 'package:boorusama/core/backups/sources/json_source.dart';
import 'package:boorusama/core/backups/sources/providers.dart';
import 'package:boorusama/core/backups/types/backup_registry.dart';
import 'package:boorusama/core/backups/utils/json_handler.dart';
import 'package:boorusama/core/backups/export_import/models/import_action.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/configs/manage/providers.dart';
import 'package:boorusama/core/debug/src/logging/app_logger.dart';
import 'package:boorusama/foundation/filesystem.dart';
import 'package:boorusama/foundation/loggers.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurumi/material.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'superseded profile capture cannot replace current package sources',
    () async {
      final repository = _GatedProfileRepository();
      final currentEntered = Completer<void>();
      final currentRelease = Completer<void>();
      final sources = Provider(
        (ref) => [
          _FixtureSource<List<int>>(
            ref,
            id: 'test_value',
            getData: () async => [2],
            onParsed: (data) async {
              if (data.single == 2) {
                currentEntered.complete();
                await currentRelease.future;
              }
            },
            handler: ListHandler<int>(
              parser: (row) => row['value'] as int,
              encoder: (value) => {'value': value},
            ),
          ),
          _FixtureSource<List<BooruConfig>>(
            ref,
            id: 'profiles',
            getData: () async => [],
            handler: ListHandler<BooruConfig>(
              parser: BooruConfig.fromJson,
              encoder: (profile) => profile.toJson(),
            ),
          ),
        ],
      );
      final directory = await Directory.systemTemp.createTemp(
        'import-late-capture-',
      );
      final fs = _FileSystem(directory.path);
      final container = ProviderContainer(
        overrides: [
          loggerProvider.overrideWithValue(AppLogger()),
          appFileSystemProvider.overrideWithValue(fs),
          booruConfigRepoProvider.overrideWithValue(repository),
          booruConfigProvider.overrideWith(
            () => BooruConfigNotifier(initialConfigs: []),
          ),
          backupRegistryProvider.overrideWith((ref) {
            final registry = BackupRegistry();
            for (final source in ref.read(sources)) {
              registry.register(source);
            }
            return registry;
          }),
          exportImportSourcesProvider.overrideWith(
            (ref) => [
              for (final source in ref.read(sources))
                LegacyJsonSourceAdapter(
                  source: source,
                  descriptor: ExportSelectionDescriptor.leaf(id: source.id),
                ),
            ],
          ),
        ],
      );
      final subscription = container.listen(importFlowProvider, (_, _) {});
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('disk_space_2'),
            (_) async => 100000.0,
          );
      try {
        Future<String> package(int value) => ExportPackageWriter(fs: fs).write(
          ExportPackageBuild(
            createdAt: DateTime.utc(2026),
            appVersion: '1.0.0',
            sources: [
              ExportPackageSourceBuild(
                id: 'test_value',
                schemaVersion: 1,
                parts: [
                  ExportPackagePartBuild(
                    path: 'sources/value.json',
                    write: (path) => fs.writeString(
                      path,
                      '{"version":1,"incoming":true,"data":[{"value":$value}]}',
                    ),
                  ),
                ],
              ),
            ],
          ),
          '${directory.path}/incoming-$value.bsexport',
        );
        final oldPath = await package(1);
        final currentPath = await package(2);
        final notifier = container.read(importFlowProvider.notifier);
        final oldLoad = notifier.load(oldPath);
        await repository.entered.future.timeout(const Duration(seconds: 30));
        final currentLoad = notifier.load(currentPath);
        await currentEntered.future.timeout(const Duration(seconds: 30));
        repository.release.complete();
        await oldLoad;
        expect(notifier.dependencyPlanningRuns, 0);
        expect(notifier.sourceProjectionRuns, 0);
        currentRelease.complete();
        await currentLoad;
        expect(
          container.read(importFlowProvider).status,
          ImportFlowStatus.review,
        );
        expect(
          container.read(importFlowProvider).preflight!.summary.hasMutations,
          isFalse,
        );
        final current = container
            .read(importFlowProvider)
            .resolved!
            .sources
            .single;
        notifier.replaceSource(current.copyWith(action: ImportAction.skip));
        await notifier.previewComplete;
        notifier.replaceSource(current);
        await notifier.previewComplete;
        expect(
          container.read(importFlowProvider).preflight!.summary.hasMutations,
          isFalse,
        );
      } finally {
        if (!repository.release.isCompleted) repository.release.complete();
        if (!currentRelease.isCompleted) currentRelease.complete();
        subscription.close();
        container.dispose();
        await fs.deletionComplete(fs.stagingPath!);
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('disk_space_2'),
              null,
            );
        await directory.delete(recursive: true);
      }
    },
  );
  for (final disposed in [false, true]) {
    for (final fail in [false, true]) {
      test(
        '${disposed ? 'disposed' : 'superseded'} import ignores ${fail ? 'failed' : 'completed'} async preparation and cleans staging',
        () async {
          final entered = Completer<void>();
          final release = Completer<void>();
          final sourceProvider = Provider<_GatedSource>(
            (ref) => _GatedSource(ref, entered, release, fail),
          );
          await (() async {
            final directory = await Directory.systemTemp.createTemp(
              'import-worker-lifecycle-',
            );
            final fs = _FileSystem(directory.path);
            final published = <ImportFlowStatus>[];
            final container = ProviderContainer(
              overrides: [
                loggerProvider.overrideWithValue(AppLogger()),
                appFileSystemProvider.overrideWithValue(fs),
                backupRegistryProvider.overrideWith(
                  (ref) => BackupRegistry()..register(ref.read(sourceProvider)),
                ),
                exportImportSourcesProvider.overrideWith(
                  (ref) => [
                    LegacyJsonSourceAdapter(
                      source: ref.read(sourceProvider),
                      descriptor: const ExportSelectionDescriptor.leaf(
                        id: 'bookmarks',
                      ),
                    ),
                  ],
                ),
              ],
            );
            final subscription = container.listen(
              importFlowProvider,
              (_, next) => published.add(next.status),
            );
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
                .setMockMethodCallHandler(
                  const MethodChannel('disk_space_2'),
                  (_) async => 100000.0,
                );
            try {
              final path = await ExportPackageWriter(fs: fs).write(
                ExportPackageBuild(
                  createdAt: DateTime.utc(2026, 11, 9),
                  appVersion: '1.0.0',
                  sources: [
                    ExportPackageSourceBuild(
                      id: 'bookmarks',
                      schemaVersion: 10,
                      parts: [
                        ExportPackagePartBuild(
                          path: 'sources/bookmarks.json',
                          write: (path) => fs.writeString(
                            path,
                            '{"version":10,"data":[],"organizationSchema":"nestedGroups","groups":[]}',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                '${directory.path}/incoming.bsexport',
              );
              final load = container
                  .read(importFlowProvider.notifier)
                  .load(path);
              await entered.future.timeout(const Duration(seconds: 30));
              if (disposed) {
                subscription.close();
                container.dispose();
              } else {
                await container
                    .read(importFlowProvider.notifier)
                    .load('${directory.path}/missing.bsexport');
              }
              await fs.stagingDeleted.future.timeout(
                const Duration(seconds: 30),
              );
              release.complete();
              await expectLater(load, completes);
              expect(published, [
                ImportFlowStatus.checking,
                if (!disposed) ImportFlowStatus.error,
              ]);
              expect(Directory(fs.stagingPath!).existsSync(), isFalse);
            } finally {
              if (!release.isCompleted) release.complete();
              subscription.close();
              container.dispose();
              TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
                  .setMockMethodCallHandler(
                    const MethodChannel('disk_space_2'),
                    null,
                  );
              await directory.delete(recursive: true);
            }
          })();
        },
      );
    }
  }
}

class _GatedProfileRepository implements BooruConfigRepository {
  final entered = Completer<void>();
  final release = Completer<void>();
  var reads = 0;

  @override
  Future<List<BooruConfig>> getAll() async {
    if (reads++ == 0) {
      entered.complete();
      await release.future;
    }
    return [];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FixtureSource<T> extends JsonBackupSource<T> {
  _FixtureSource(
    Ref ref, {
    required String id,
    required Future<T> Function() getData,
    required JsonHandler<T> handler,
    this.onParsed,
  }) : super(
         id: id,
         priority: 0,
         version: 1,
         appVersion: null,
         dataGetter: getData,
         executor: (_, _) async {},
         handler: handler,
         ref: ref,
       );

  final Future<void> Function(T)? onParsed;

  @override
  AsyncImportDecoder<T>? get asyncImportDecoder => onParsed == null
      ? null
      : (encoded) async {
          final metadata = converter.decode(data: encoded);
          final parsed = handler.parse(metadata);
          if (metadata.extraFields['incoming'] == true) await onParsed!(parsed);
          return (metadata: metadata, parsed: parsed);
        };

  @override
  String get displayName => id;

  @override
  Widget buildTile(BuildContext context) => const SizedBox.shrink();
}

class _GatedSource extends JsonBackupSource<BookmarkBackupData> {
  _GatedSource(Ref ref, this.entered, this.release, this.fail)
    : super(
        id: 'bookmarks',
        priority: 2,
        version: 10,
        appVersion: null,
        dataGetter: () async =>
            throw StateError('A disposed load must not capture local state'),
        executor: (_, _) async =>
            throw StateError('Preparation must not execute an import'),
        handler: BookmarkBackupCodec(),
        ref: ref,
      );

  final Completer<void> entered;
  final Completer<void> release;
  final bool fail;

  @override
  AsyncImportDecoder<BookmarkBackupData> get asyncImportDecoder =>
      (encoded) async {
        final decoded = await BookmarkBackupWorker(
          handler as BookmarkBackupCodec,
        ).decode(encoded);
        entered.complete();
        await release.future;
        if (fail) throw const FormatException('Controlled late worker failure');
        return decoded;
      };

  @override
  String get displayName => 'Bookmarks';

  @override
  Widget buildTile(BuildContext context) => const SizedBox.shrink();
}

class _FileSystem extends IoFileSystem {
  _FileSystem(this.root);
  final String root;
  String? stagingPath;
  final stagingDeleted = Completer<void>();
  final _deletions = <String, Completer<void>>{};

  Future<void> deletionComplete(String path) =>
      _deletions.putIfAbsent(path, Completer<void>.new).future;

  @override
  Future<String?> getTemporaryPath() async => root;

  @override
  Future<String> createTempDirectory(String prefix) async {
    final path = (await Directory(root).createTemp(prefix)).path;
    if (prefix == 'boorusama_import_') stagingPath = path;
    return path;
  }

  @override
  Future<void> deleteDirectory(String path, {bool recursive = false}) async {
    await super.deleteDirectory(path, recursive: recursive);
    _deletions.putIfAbsent(path, Completer<void>.new).complete();
    if (path == stagingPath && !stagingDeleted.isCompleted) {
      stagingDeleted.complete();
    }
  }
}
