import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:boorusama/core/backups/export_import/export/export_service.dart';
import 'package:boorusama/core/backups/export_import/import/import_flow_notifier.dart';
import 'package:boorusama/core/backups/export_import/import/import_journal.dart';
import 'package:boorusama/core/backups/export_import/import/import_plan.dart';
import 'package:boorusama/core/backups/export_import/import/import_preflight.dart';
import 'package:boorusama/core/backups/export_import/import/import_progress.dart';
import 'package:boorusama/core/backups/export_import/import/import_recovery_gate.dart';
import 'package:boorusama/core/backups/export_import/import/import_transaction.dart';
import 'package:boorusama/core/backups/export_import/models/export_selection.dart';
import 'package:boorusama/core/backups/export_import/models/import_action.dart';
import 'package:boorusama/core/backups/export_import/package/bookmark_transfer_format.dart';
import 'package:boorusama/core/backups/export_import/package/export_package_reader.dart';
import 'package:boorusama/core/backups/export_import/package/export_package_writer.dart';
import 'package:boorusama/core/backups/sources/bookmark_backup_data.dart';
import 'package:boorusama/core/backups/export_import/sources/legacy_json_source_adapter.dart';
import 'package:boorusama/core/backups/sources/bookmark_transfer_database.dart';
import 'package:boorusama/core/backups/sources/bookmark_transfer_import.dart';
import 'package:boorusama/core/backups/sources/providers.dart';
import 'package:boorusama/core/backups/types/backup_registry.dart';
import 'package:boorusama/core/bookmarks/providers.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/bookmark_group_repository_factory_hive.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/factory.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/repository.dart';
import 'package:boorusama/core/bookmarks/src/data/stored_bookmark_codec.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_mirror_state.dart';
import 'package:boorusama/core/bookmarks/types.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/boorus/engine/providers.dart';
import 'package:boorusama/core/boorus/engine/types.dart';
import 'package:boorusama/core/configs/config/src/data/booru_config_repository_hive.dart';
import 'package:boorusama/core/configs/manage/providers.dart';
import 'package:boorusama/core/debug/src/logging/app_logger.dart';
import 'package:boorusama/core/hive/hive_adapters.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/settings/providers.dart';
import 'package:boorusama/core/settings/src/types/settings.dart';
import 'package:boorusama/foundation/data_mutation_coordinator.dart';
import 'package:boorusama/foundation/filesystem.dart';
import 'package:boorusama/foundation/info/package_info.dart';
import 'package:boorusama/foundation/loggers.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foundation/performance.dart';
import 'package:hive_ce/hive.dart';

import 'import_transaction_test_utils.dart';

const _groupId = '11111111-1111-4111-8111-111111111111';
const _childId = '22222222-2222-4222-8222-222222222222';
const _emptyId = '33333333-3333-4333-8333-333333333333';
const _codec = StoredBookmarkCodec();
final _added = DateTime.utc(
  2024,
  4,
  21,
  17,
  18,
  19,
  123,
  456,
).toIso8601String();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'streamed exports round trip through normal import and cold reopen',
    () async {
      await _roundTrip(1025, hierarchy: true);
    },
  );
  test('streamed group Copy preserves nested and shared memberships', () async {
    await _roundTrip(17, hierarchy: true, action: ImportAction.configureItems);
  });
  test(
    'a later source failure restores the streamed Bookmark preimage',
    () async {
      await _roundTrip(17, hierarchy: true, failure: _Failure.laterSource);
    },
  );
  test('startup recovers an interrupted streamed Bookmark write', () async {
    await _roundTrip(17, hierarchy: true, failure: _Failure.interrupted);
  });
  test(
    'a full disk during preimage capture leaves the library intact',
    () async {
      await _roundTrip(17, hierarchy: true, failure: _Failure.disk);
    },
  );

  for (final version in [6, 7]) {
    test(
      'a v$version child-only import preserves locally owned parent memberships',
      () async {
        final (directory, container, store) = await _localLibrary();
        final ids = await store.reserveIds(2);
        await store.upsertAll([_post(ids.first, 10), _post(ids.last, 11)]);
        final groups = [
          BookmarkGroup(
            id: defaultBookmarkGroupId,
            name: 'Default',
            bookmarkIds: const {},
          ),
          BookmarkGroup(id: _groupId, name: 'Parent', bookmarkIds: const {}),
          BookmarkGroup(
            id: _childId,
            name: 'Child',
            parentGroupId: _groupId,
            bookmarkIds: const {},
          ),
        ];
        await store.writeTransferOrganization(
          definitions: groups,
          changed: groups.map((g) => g.id).toSet(),
          members: (id) => [
            if (id == _groupId) (ids.first, _added),
            if (id == _childId) (ids.last, _added),
          ],
        );
        final path =
            await ExportService(
              sources: () {
                final source =
                    container.read(exportImportSourcesProvider).single
                        as BookmarkPackageSource;
                return [
                  if (version == 6)
                    LegacyJsonSourceAdapter(
                      source: source.source,
                      descriptor: source.descriptor,
                      scopeBuilder: source.scopeBuilder,
                    )
                  else
                    source,
                ];
              },
              writer: ExportPackageWriter(fs: _FileSystem(directory.path)),
              appVersion: '1.0',
            ).createPackage(
              ExportRequest(
                selection: ExportSelection.custom(const {
                  'bookmarks': ExportNodeSelection.explicit('bookmarks', {
                    'group:$_childId',
                  }),
                }),
                outputPath: '${directory.path}/child',
              ),
            );
        final listener = container.listen(importFlowProvider, (_, _) {});
        addTearDown(listener.close);
        final flow = container.read(importFlowProvider.notifier);
        await flow.load(path);
        expect(container.read(importFlowProvider).preflight!.isValid, isTrue);
        await flow.apply(null);
        expect(
          container.read(importFlowProvider).status,
          ImportFlowStatus.complete,
        );
        expect((await store.read(ids.first) as PostBookmark?)?.postId, 10);
        final parent = (await (await store.openOrganization()).getGroups())
            .singleWhere((g) => g.id == _groupId);
        expect(parent.addedAt, {ids.first: DateTime.parse(_added)});
      },
    );
  }

  test(
    'updating the last group keeps an explicitly imported ungrouped post',
    () async {
      final (directory, container, store) = await _localLibrary();
      final ids = await store.reserveIds(2);
      await store.commitOrganization(
        records: [_post(ids.first, 11), _post(ids.last, 22)],
        groups: [
          BookmarkGroup(
            id: _groupId,
            name: 'Group',
            bookmarkIds: ids.toSet(),
            addedAt: {for (final id in ids) id: DateTime.utc(2020)},
          ),
        ],
      );
      final rows = {
        BookmarkTransferTable.groups: jsonEncode({
          'id': _groupId,
          'name': 'Group',
          'position': 0,
        }),
        BookmarkTransferTable.bookmarks: jsonEncode(
          _codec.encodeForTransfer(_post(17, 11)),
        ),
        BookmarkTransferTable.memberships: '',
      };
      final path = await ExportPackageWriter(fs: _FileSystem(directory.path))
          .write(
            ExportPackageBuild(
              appVersion: '1',
              createdAt: DateTime.utc(2026),
              sources: [
                ExportPackageSourceBuild(
                  id: 'bookmarks',
                  schemaVersion: 7,
                  parts: [
                    for (final entry in rows.entries)
                      ExportPackagePartBuild(
                        path: bookmarkTransferPartPath(entry.key, 0),
                        write: (path) => File(path).writeAsString(
                          entry.value.isEmpty ? '' : '${entry.value}\n',
                        ),
                      ),
                  ],
                ),
              ],
            ),
            '${directory.path}/ungrouped',
          );
      final source = await container.read(_preparedBookmarkSource(path).future);
      final resolution = ResolvedImportSource(
        id: 'bookmarks',
        action: ImportAction.configureItems,
        items: const [
          ResolvedImportItem(
            id: 'group:$_groupId',
            action: ImportAction.update,
          ),
          ResolvedImportItem(id: 'ungrouped', action: ImportAction.merge),
        ],
      );
      expect((await source.plannedChanges(resolution))?.deleted, 1);
      await source.apply(resolution);
      final groups = await (await store.openOrganization()).getGroups();
      expect(groups.singleWhere((g) => g.isDefault).bookmarkIds, {ids.first});
      expect(groups.singleWhere((g) => g.id == _groupId).bookmarkIds, isEmpty);
      expect((await store.read(ids.first) as PostBookmark?)?.postId, 11);
      expect(await store.read(ids.last), isNull);
    },
  );

  test('rollback restores shared metadata after its local membership was removed', () async {
    final (directory, _, store) = await _localLibrary();
    final id = (await store.reserveIds(1)).single;
    final original = _post(id, 11);
    final received = await _receivePost(store, original);
    final local = BookmarkGroup(
      id: defaultBookmarkGroupId,
      name: 'Default',
      bookmarkIds: {id},
      addedAt: {id: DateTime.parse(_added)},
    );
    await store.commitOrganization(groups: [local]);
    final previous = BookmarkTransferDatabase(
      '${directory.path}/preimage.sqlite',
    );
    await previous.capture(store, _codec, cancelled: () => false);
    // Replace can update a shared record and then remove its local membership.
    await store.upsertAll([
      _codec.decode(_codec.encode(original)..['sourceUrl'] = null),
    ]);
    await store.commitOrganization(groups: [local.copyWith(bookmarkIds: {})]);
    await BookmarkTransferImport.restore(previous, _codec, store);
    expect(_codec.encode((await store.read(id))!), _codec.encode(original));
    expect(
      await (await store.openOrganization()).getGroups(),
      containsAll([local, received]),
    );
  });

  test('review rejects metadata changes to a received-only post', () async {
    final (directory, container, store) = await _localLibrary();
    final id = (await store.reserveIds(1)).single;
    final original = _post(id, 11);
    await _receivePost(store, original);
    final path =
        await ExportService(
          sources: () => container.read(exportImportSourcesProvider),
          writer: ExportPackageWriter(fs: _FileSystem(directory.path)),
          appVersion: '1.0',
        ).createPackage(
          ExportRequest(
            selection: ExportSelection.custom(const {
              'bookmarks': ExportNodeSelection.all('bookmarks'),
            }),
            outputPath: '${directory.path}/received',
          ),
        );
    final local = BookmarkGroup(
      id: defaultBookmarkGroupId,
      name: 'Default',
      bookmarkIds: {id},
      addedAt: {id: DateTime.parse(_added)},
    );
    await store.commitOrganization(groups: [local]);
    await store.upsertAll([
      _codec.decode(_codec.encode(original)..['updatedAt'] = _added),
    ]);
    await store.commitOrganization(groups: [local.copyWith(bookmarkIds: {})]);
    final source = await container.read(_preparedBookmarkSource(path).future);
    await expectLater(
      source.plannedChanges(
        ResolvedImportSource(
          id: 'bookmarks',
          action: ImportAction.replace,
          items: const [],
        ),
      ),
      throwsFormatException,
    );
  });

  final benchmarkPosts = int.tryParse(
    Platform.environment['BOOKMARK_STREAM_BENCHMARK_POSTS'] ?? '',
  );
  if (benchmarkPosts != null) {
    test('streamed bookmark transfer benchmark', () async {
      await _roundTrip(benchmarkPosts, hierarchy: false, benchmark: true);
    }, timeout: const Timeout(Duration(minutes: 90)));
  }
}

Future<BookmarkGroup> _receivePost(
  BookmarkHiveRepository store,
  PostBookmark original,
) async {
  final id = original.id;
  final received = BookmarkGroup(
    id: _childId,
    name: 'Received',
    bookmarkIds: {id},
    addedAt: {id: DateTime.parse(_added)},
  );
  final before = await store.readMirrorState();
  await store.commitMirrorOrganization(
    expected: before,
    next: BookmarkMirrorState(
      epoch: before.epoch + 1,
      owners: {
        received.id: BookmarkMirrorOwner(
          publisher: _groupId,
          source: _emptyId,
          revision: 1,
          payloadDigest: 'a' * 64,
          groupDigest: bookmarkMirrorGroupDigest(received),
        ),
      },
    ),
    groups: [received],
    records: [original],
  );
  return received;
}

Future<(Directory, ProviderContainer, BookmarkHiveRepository)>
_localLibrary() async {
  final directory = await Directory.systemTemp.createTemp('bookmark-review-');
  Hive.init(directory.path);
  if (!Hive.isAdapterRegistered(4)) {
    Hive.registerAdapter(BookmarkHiveObjectAdapter());
    Hive.registerAdapter(BookmarkGroupHiveObjectAdapter());
  }
  final container = await _container(directory.path);
  addTearDown(() async {
    container.dispose();
    await Hive.close();
    await directory.delete(recursive: true);
  });
  final store = await container.read(
    bookmarkRepoProvider.future,
  ) as BookmarkHiveRepository;
  return (directory, container, store);
}

Future<void> _roundTrip(
  int count, {
  required bool hierarchy,
  bool benchmark = false,
  _Failure? failure,
  ImportAction action = ImportAction.replace,
}) async {
  final directory = await Directory.systemTemp.createTemp(
    'bookmark-stream-transfer-',
  );
  final sourceDir = await Directory('${directory.path}/before').create();
  final targetDir = await Directory('${directory.path}/after').create();
  addTearDown(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });
  if (!Hive.isAdapterRegistered(4)) {
    Hive.registerAdapter(BookmarkHiveObjectAdapter());
  }
  if (!Hive.isAdapterRegistered(5)) {
    Hive.registerAdapter(BookmarkGroupHiveObjectAdapter());
  }
  if (benchmark) {
    stdout.writeln('seeding posts=$count fixture=${directory.path}');
  }

  Hive.init(sourceDir.path);
  final sourceContainer = await _container(sourceDir.path);
  final source = await sourceContainer.read(
    bookmarkRepoProvider.future,
  ) as BookmarkHiveRepository;
  const seedBatch = 2048;
  for (var first = 0; first < count; first += seedBatch) {
    final size = count - first < seedBatch ? count - first : seedBatch;
    final ids = await source.reserveIds(size);
    await source.upsertAll([
      for (var i = 0; i < size; i++) _post(ids[i], first + i + 1),
    ]);
  }
  final definitions = [
    BookmarkGroup(
      id: defaultBookmarkGroupId,
      name: 'Default',
      bookmarkIds: const {},
    ),
    BookmarkGroup(
      id: _groupId,
      name: 'Large',
      bookmarkIds: const {},
      position: 2,
    ),
    if (hierarchy)
      BookmarkGroup(
        id: _childId,
        name: 'Shared',
        parentGroupId: _groupId,
        bookmarkIds: const {},
        position: 1,
      ),
    if (hierarchy)
      BookmarkGroup(
        id: _emptyId,
        name: 'Empty',
        parentGroupId: _groupId,
        bookmarkIds: const {},
        position: 2,
      ),
  ];
  await source.writeTransferOrganization(
    definitions: definitions,
    changed: definitions.map((group) => group.id).toSet(),
    members: (groupId) sync* {
      if (groupId == _groupId) {
        for (var id = 0; id < count; id++) {
          yield (id, _added);
        }
      }
      if (groupId == _childId) yield (count - 1, _added);
    },
  );
  final fs = _FileSystem(directory.path);
  final timer = Stopwatch()..start();
  final export = ExportService(
    sources: () => sourceContainer.read(exportImportSourcesProvider),
    writer: ExportPackageWriter(fs: fs),
    appVersion: '1.0.0',
  );
  final path = await export.createPackage(
    ExportRequest(
      selection: ExportSelection.custom(const {
        'bookmarks': ExportNodeSelection.all('bookmarks'),
      }),
      outputPath: '${directory.path}/transfer',
      recommendedActions: {'bookmarks': action},
    ),
  );
  final bytes = await File(path).length();
  if (benchmark) {
    stdout.writeln(
      'export posts=$count ms=${timer.elapsedMilliseconds} archiveBytes=$bytes rss=${ProcessInfo.currentRss}',
    );
  }
  sourceContainer.dispose();
  await Hive.close();

  if (!benchmark) {
    final staged = await ExportPackageReader(fs: fs).stage(path);
    try {
      final manifest = staged.manifest.sources.single;
      expect(manifest.schemaVersion, 7);
      expect(
        bookmarkTransferParts(manifest)!.keys,
        BookmarkTransferTable.values,
      );
    } finally {
      await staged.dispose();
    }
  }

  Hive.init(targetDir.path);
  final target = await _container(
    targetDir.path,
    denyRollbackCopy: failure == _Failure.disk,
  );
  if (failure != null) {
    final store = await target.read(
      bookmarkRepoProvider.future,
    ) as BookmarkHiveRepository;
    final id = (await store.reserveIds(1)).single;
    await store.upsertAll([_post(id, 10001)]);
    await store.writeTransferOrganization(
      definitions: [
        BookmarkGroup(
          id: defaultBookmarkGroupId,
          name: 'Default',
          bookmarkIds: const {},
        ),
      ],
      changed: {defaultBookmarkGroupId},
      members: (_) => [(id, _added)],
    );
  }
  if (failure == null && !benchmark) await target.read(bookmarkProvider.future);
  final progress = <ImportProgressValue>[];
  final listener = target.listen(importFlowProvider, (before, after) {
    final sample = after.progress;
    if (sample != null && sample != before?.progress) progress.add(sample);
  });
  final flow = target.read(importFlowProvider.notifier);
  try {
    timer.reset();
    await flow.load(path);
    final state = target.read(importFlowProvider);
    expect(state.status, ImportFlowStatus.review, reason: '${state.error}');
    expect(
      state.preflight!.isValid,
      isTrue,
      reason: '${state.preflight!.errors}',
    );
    if (failure == null && !benchmark) {
      for (final phase in [
        ImportProgressPhase.extracting,
        ImportProgressPhase.verifying,
        ImportProgressPhase.reading,
      ]) {
        final samples = progress.where((sample) => sample.phase == phase);
        expect(samples.first.completed, 0);
        expect(samples.last.completed, samples.last.total);
        expect(samples.last.total, greaterThan(0));
      }
      expect(progress.last.phase, ImportProgressPhase.preparing);
    }
    progress.clear();
    final summary = state.preflight!.sourceSummaries['bookmarks']!;
    expect(summary.entitySummaries['bookmark']!.created, count);
    expect(summary.previewRows.length, lessThan(12));
    expect(
      summary.previewRows
          .singleWhere((row) => row.category == 'bookmark_metadata')
          .counts
          .added,
      count,
    );
    if (benchmark) {
      final disk = await _size(targetDir);
      stdout.writeln(
        'review posts=$count ms=${timer.elapsedMilliseconds} diskBytes=$disk rss=${ProcessInfo.currentRss}',
      );
      performanceRecorder.start();
    }
    timer.reset();
    if (failure == null || failure == _Failure.disk) {
      await flow.apply(null);
    } else {
      final wrapper = await target.read(_preparedBookmarkSource(path).future);
      final token = await wrapper.revisionToken();
      final plan = buildValidatedPlan(['bookmarks']);
      final transaction = ImportTransaction(
        store: ImportJournalStore(
          fs: wrapper.fs,
          rootPath: '${targetDir.path}/import_transactions',
        ),
        fs: wrapper.fs,
      );
      await expectLater(
        _failImport(
          failure: failure,
          plan: ValidatedImportPlan(
            plan: plan.plan,
            summary: plan.summary,
            revisionTokens: {'bookmarks': token},
          ),
          transaction: transaction,
          sources: {'bookmarks': wrapper},
        ),
        throwsStateError,
      );
    }
    final finished = target.read(importFlowProvider);
    if (benchmark) {
      performanceRecorder.stop();
      final spans = performanceRecorder.snapshot()['events']! as List;
      for (final span in spans.whereType<Map<String, Object?>>()) {
        if (span['op'].toString().startsWith('bookmarkTransfer')) {
          stdout.writeln(jsonEncode(span));
        }
      }
      stdout.writeln(
        'apply and refresh posts=$count ms=${timer.elapsedMilliseconds} rss=${ProcessInfo.currentRss} peakRss=${ProcessInfo.maxRss} refreshFailed=${finished.bookmarkRefreshFailed}',
      );
      performanceRecorder.clear();
    }
    if (failure == null) {
      expect(
        finished.status,
        ImportFlowStatus.complete,
        reason: '${finished.error}',
      );
      expect(finished.bookmarkRefreshFailed, isFalse);
      if (!benchmark) {
        final phases = progress.map((sample) => sample.phase);
        expect(
          phases,
          containsAllInOrder([
            ImportProgressPhase.checkpoint,
            ImportProgressPhase.verifyingCheckpoint,
            ImportProgressPhase.preparing,
            ImportProgressPhase.saving,
            ImportProgressPhase.memberships,
            ImportProgressPhase.committing,
            ImportProgressPhase.loadingLibrary,
            ImportProgressPhase.indexingLibrary,
            ImportProgressPhase.publishingLibrary,
          ]),
        );
        expect(
          phases.where(
            (phase) => phase == ImportProgressPhase.publishingLibrary,
          ),
          hasLength(1),
        );
        final saved = progress.lastWhere(
          (sample) => sample.phase == ImportProgressPhase.saving,
        );
        expect(saved.completed, count);
        expect(saved.total, count);
        final indexed = progress.lastWhere(
          (sample) => sample.phase == ImportProgressPhase.indexingLibrary,
        );
        expect(indexed.completed, indexed.total);
      }
    } else if (failure == _Failure.disk) {
      expect(finished.status, ImportFlowStatus.error);
      expect(finished.error, isA<FileSystemException>());
      expect(progress.last.phase, ImportProgressPhase.restoring);
      expect(
        progress.map((sample) => sample.phase),
        isNot(contains(ImportProgressPhase.saving)),
      );
    }
  } finally {
    listener.close();
    target.dispose();
    await Hive.close();
  }

  if (failure == _Failure.interrupted) {
    final restarted = await _container(targetDir.path);
    try {
      final result = await restarted.read(importRecoveryProvider.future);
      expect(result.failures, isEmpty);
    } finally {
      restarted.dispose();
      await Hive.close();
    }
  }
  final reopened = await const HiveBookmarkRepositoryFactory().create(
    storage: BookmarkStorageContext(coordinator: DataMutationCoordinator()),
  ) as BookmarkHiveRepository;
  if (failure != null) {
    final restored = (await reopened.readAll()).single as PostBookmark;
    expect(restored.id, 0);
    expect(restored.postId, 10001);
    final groups = await reopened.openOrganization();
    final defaultGroup = (await groups.getGroups()).single;
    expect(defaultGroup.bookmarkIds, {0});
    expect(defaultGroup.addedAt[0]!.toIso8601String(), _added);
    expect(
      (await reopened.reserveIds(1)).single,
      failure == _Failure.disk ? 1 : greaterThan(count),
    );
    return;
  }
  var records = 0;
  var memberships = 0;
  var shared = 0;
  await reopened.visitTransferRecords((record) async {
    records++;
    final post = record as PostBookmark;
    final actual = _codec.encodeForTransfer(post);
    final expected = _codec.encodeForTransfer(_post(post.id, post.id + 1));
    if (jsonEncode(actual) != jsonEncode(expected)) {
      expect(actual, expected, reason: 'Bookmark ${post.id}');
    }
  });
  await reopened.visitTransferGroups((group) async {
    if (group.id == _groupId) {
      expect(group.name, 'Large');
      expect(group.position, 2);
      for (final id in group.bookmarkIds) {
        memberships++;
        expect(group.addedAt![id], _added);
      }
    }
    if (group.id == _childId) {
      expect(group.parentGroupId, _groupId);
      expect(group.bookmarkIds.single, count - 1);
      shared++;
    }
    if (group.id == _emptyId) {
      expect(group.parentGroupId, _groupId);
      expect(group.bookmarkIds, isEmpty);
    }
  });
  expect(records, count);
  expect(memberships, count);
  expect(shared, hierarchy ? 1 : 0);
  if (benchmark) {
    stdout.writeln(
      'verified posts=$records memberships=$memberships peakRss=${ProcessInfo.maxRss}',
    );
  }
}

Future<int> _size(Directory directory) async {
  var bytes = 0;
  await for (final entry in directory.list(recursive: true)) {
    if (entry is File) bytes += await entry.length();
  }
  return bytes;
}

Future<ProviderContainer> _container(
  String root, {
  bool denyRollbackCopy = false,
}) async {
  final profiles = HiveBooruConfigRepository(
    box: await Hive.openBox<String>('booru_configs'),
  );
  return ProviderContainer(
    overrides: [
      loggerProvider.overrideWithValue(AppLogger()),
      dataMutationCoordinatorProvider.overrideWithValue(
        DataMutationCoordinator(),
      ),
      booruEngineRegistryProvider.overrideWith((_) => BooruEngineRegistry()),
      bookmarkRepositoryFactoryProvider.overrideWithValue(
        const HiveBookmarkRepositoryFactory(),
      ),
      bookmarkGroupRepositoryFactoryProvider.overrideWithValue(
        const HiveBookmarkGroupRepositoryFactory(),
      ),
      bookmarkUrlResolverProvider.overrideWith(
        (_, _) => const DefaultImageUrlResolver(),
      ),
      booruConfigRepoProvider.overrideWithValue(profiles),
      booruConfigProvider.overrideWith(
        () => BooruConfigNotifier(initialConfigs: []),
      ),
      appFileSystemProvider.overrideWithValue(
        _FileSystem(root, denyRollbackCopy: denyRollbackCopy),
      ),
      appVersionProvider.overrideWithValue(null),
      settingsNotifierProvider.overrideWith(
        () => _SettingsNotifier(Settings.defaultSettings),
      ),
      backupRegistryProvider.overrideWith(
        (ref) => BackupRegistry()
          ..register(ref.read(bookmarksBackupSourceProvider))
          ..register(ref.read(booruConfigsBackupSourceProvider)),
      ),
      exportImportSourcesProvider.overrideWith(
        (ref) => [
          BookmarkPackageSource(
            source: ref.read(bookmarksBackupSourceProvider),
            descriptor: const ExportSelectionDescriptor.collection(
              id: 'bookmarks',
            ),
            scopeBuilder: (selection) =>
                selection.kind == ExportNodeSelectionKind.all
                ? const BookmarkExportScope.all()
                : BookmarkExportScope.selected(
                    groupIds: selection.childIds.map(
                      (key) => key.substring('group:'.length),
                    ),
                  ),
          ),
        ],
      ),
    ],
  );
}

enum _Failure { laterSource, interrupted, disk }

final _preparedBookmarkSource =
    FutureProvider.family<PackageTransactionSource, String>(
      (ref, path) async {
        final fs = ref.read(appFileSystemProvider);
        final package = await ExportPackageReader(fs: fs).stage(path);
        ref.onDispose(package.dispose);
        final incoming = BookmarkTransferDatabase(
          '${package.directoryPath}/incoming.sqlite',
        );
        final previous = BookmarkTransferDatabase(
          '${package.directoryPath}/previous.sqlite',
        );
        await incoming.stage(
          package: package,
          parts: bookmarkTransferParts(package.manifest.sources.single)!,
          codec: _codec,
          cancelled: () => false,
        );
        final source = PackageTransactionSource(
          source: ref.read(bookmarksBackupSourceProvider),
          incomingPath: null,
          fs: fs,
          ref: ref,
          credentialsIncluded: false,
          streamedBookmarks: BookmarkTransferImport(
            incoming: incoming,
            previous: previous,
            codec: _codec,
          ),
        );
        await source.prepare(null);
        await source.captureLocalSnapshot();
        return source;
      },
    );

Future<void> _failImport({
  required _Failure failure,
  required ValidatedImportPlan plan,
  required ImportTransaction transaction,
  required Map<String, ImportTransactionSource> sources,
}) async {
  final fs = transaction.fs;
  if (failure == _Failure.laterSource) {
    const later = 'later';
    final injected = buildValidatedPlan([later]);
    final failedPlan = ValidatedImportPlan(
      plan: ResolvedImportPlan(
        sources: [...plan.plan.sources, ...injected.plan.sources],
      ),
      revisionTokens: {...plan.revisionTokens, ...injected.revisionTokens},
      summary: plan.summary,
    );
    return transaction.execute(
      transactionId: 'failing-later-source',
      plan: failedPlan,
      sources: {
        ...sources,
        later: FakeImportSource(later, fs, failApply: true),
      },
    );
  }

  const id = 'interrupted-bookmark-transfer';
  const bookmarks = 'bookmarks';
  final source = sources[bookmarks]!;
  var journal = await transaction.store.create(id, plan);
  final rollbackPath = '${transaction.store.rollbackPath(id, bookmarks)}.data';
  await source.captureRollback(rollbackPath);
  await fs.syncFile(rollbackPath);
  final hash = await sha256.bind(fs.openRead(rollbackPath)).first;
  journal = journal.copyWith(
    state: ImportJournalState.applying,
    currentSourceId: bookmarks,
    rollbackHashes: {bookmarks: hash.toString()},
  );
  await transaction.store.write(journal);
  await source.apply(
    plan.plan.sources.firstWhere((source) => source.id == bookmarks),
  );
  await source.durableSync();
  throw StateError('Simulated process interruption before commit');
}

PostBookmark _post(int id, int postId) => PostBookmark(
  id: id,
  postId: postId,
  createdAt: DateTime.utc(2020, 3, 4),
  updatedAt: DateTime.utc(2021, 2, 3),
  thumbnailUrl: 'https://images.example.test/thumb/$postId.jpg',
  sampleUrl: 'https://images.example.test/sample/$postId.jpg',
  originalUrl: 'https://images.example.test/image/$postId.jpg',
  sourceUrl: 'https://danbooru.donmai.us/posts/$postId',
  booruId: BooruType.danbooru.id,
  width: 1280,
  height: 960,
  md5: 'fixture-$postId',
  tags: {for (var i = 0; i < 42; i++) 'tag_${(postId * (i + 11)) % 131071}_$i'},
  realSourceUrl: 'https://artist.example.test/image/$postId',
  format: 'jpg',
  imageUrlResolver: const DefaultImageUrlResolver(),
  metadata: const {},
);

final class _FileSystem extends IoFileSystem {
  const _FileSystem(this.root, {this.denyRollbackCopy = false});
  final String root;
  final bool denyRollbackCopy;

  @override
  Future<StreamSink<List<int>>> openWrite(String path) {
    _checkRollbackSpace(path);
    return super.openWrite(path);
  }

  @override
  Future<void> copyFile(String source, String destination) {
    _checkRollbackSpace(destination);
    return super.copyFile(source, destination);
  }

  void _checkRollbackSpace(String destination) {
    if (denyRollbackCopy && destination.endsWith('/bookmarks.data')) {
      throw FileSystemException(
        'No space left',
        destination,
        const OSError('', 28),
      );
    }
  }

  @override
  Future<String> getAppStoragePath() async => root;

  @override
  Future<String?> getTemporaryPath() async => null;

  @override
  Future<String> createTempDirectory(String prefix) async =>
      (await Directory(root).createTemp(prefix)).path;
}

final class _SettingsNotifier extends SettingsNotifier {
  _SettingsNotifier(super.initialSettings);
}
