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
import 'package:boorusama/core/debug/src/logging/app_logger.dart';
import 'package:boorusama/foundation/filesystem.dart';
import 'package:boorusama/foundation/loggers.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurumi/material.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
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
    if (path == stagingPath && !stagingDeleted.isCompleted) {
      stagingDeleted.complete();
    }
  }
}
