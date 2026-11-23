import 'dart:convert';
import 'dart:io';

import 'package:boorusama/core/backups/export_import/import/import_journal.dart';
import 'package:boorusama/core/backups/export_import/import/import_recovery_gate.dart';
import 'package:boorusama/core/bookmarks/providers.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/bookmark_group_hive_object.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/bookmark_group_repository_factory_hive.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/factory.dart';
import 'package:boorusama/core/bookmarks/src/services/bookmark_storage_migration.dart';
import 'package:boorusama/core/bookmarks/types.dart';
import 'package:boorusama/core/boorus/engine/providers.dart';
import 'package:boorusama/core/boorus/engine/types.dart';
import 'package:boorusama/core/debug/src/logging/app_logger.dart';
import 'package:boorusama/core/hive/hive_adapters.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/settings/providers.dart';
import 'package:boorusama/core/settings/types.dart';
import 'package:boorusama/foundation/filesystem.dart';
import 'package:boorusama/foundation/info/package_info.dart';
import 'package:boorusama/foundation/loggers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:path/path.dart' as p;

const _fixture =
    'test/fixtures/released_upgrade/v4.6.1-timberpile.3/interrupted-import';
const _groupId = '550e8400-e29b-41d4-a716-446655440030';
const _profileId = '550e8400-e29b-41d4-a716-446655440017';
const _transactionId = 'released-rollback';
const _metadata = 'favorites_content_metadata';

void main() {
  late Directory root;
  late _RecoveryFileSystem fs;
  late ImportJournalStore journal;
  ProviderContainer? container;

  ProviderContainer boot() {
    Hive.init(root.path);
    return container = ProviderContainer(
      overrides: [
        loggerProvider.overrideWithValue(AppLogger()),
        appVersionProvider.overrideWithValue(null),
        appFileSystemProvider.overrideWithValue(fs),
        booruEngineRegistryProvider.overrideWith(
          (ref) => BooruEngineRegistry(),
        ),
        bookmarkRepositoryFactoryProvider.overrideWithValue(
          HiveBookmarkRepositoryFactory(fs: fs),
        ),
        bookmarkGroupRepositoryFactoryProvider.overrideWithValue(
          const HiveBookmarkGroupRepositoryFactory(),
        ),
        bookmarkUrlResolverProvider.overrideWith(
          (ref, id) => const DefaultImageUrlResolver(),
        ),
        settingsProvider.overrideWithValue(Settings.defaultSettings),
      ],
    );
  }

  Future<void> close() async {
    container?.dispose();
    container = null;
    await Hive.close();
  }

  Future<void> expectRestored(ProviderContainer app) async {
    final repository = unifiedBookmarkStorage(
      await app.read(bookmarkRepoProvider.future),
    )!;
    final groups = await app.read(bookmarkGroupRepoProvider.future);
    final post = (await repository.readAll()).single as PostBookmark;
    expect(post.id, 12);
    expect(post.postId, 42);
    expect(post.post.origin.profileIdHint, _profileId);
    expect(post.post.origin.sourceHost, contains('gelbooru.example'));
    expect(post.tags, {'cat_fixture'});
    final archive = (await groups.getGroup(_groupId))!;
    expect(archive.name, 'Archive');
    expect(archive.parentGroupId, isNull);
    expect(archive.bookmarkIds, {post.id});
    expect(archive.addedAt, {post.id: post.createdAt});
    expect((await groups.getGroups()).map((g) => g.id).toSet(), {
      _groupId,
      defaultBookmarkGroupId,
    });
    expect(await groups.getRecentGroupIds(), [_groupId]);
  }

  setUp(() async {
    root = await Directory.systemTemp.createTemp('released-import-recovery-');
    fs = _RecoveryFileSystem(root.path);
    journal = ImportJournalStore(
      fs: fs,
      rootPath: '${root.path}/import_transactions',
    );
    if (!Hive.isAdapterRegistered(4)) {
      Hive.registerAdapter(BookmarkHiveObjectAdapter());
      Hive.registerAdapter(BookmarkGroupHiveObjectAdapter());
    }
    for (final file in Directory(
      _fixture,
    ).listSync(recursive: true).whereType<File>()) {
      final target = p.join(root.path, p.relative(file.path, from: _fixture));
      await Directory(p.dirname(target)).create(recursive: true);
      await file.copy(target);
    }
  });

  tearDown(() async {
    await close();
    await root.delete(recursive: true);
  });

  test(
    'verified released recovery restores the preimage before activation',
    () async {
      final app = boot();
      final pending = await journal.read(_transactionId);
      expect(pending.state, ImportJournalState.applying);
      expect(pending.currentSourceId, 'bookmarks');
      final originalFiles = {
        for (final name in ['bookmark_groups.hive', 'bookmark_folders.hive'])
          File(p.join(root.path, name)): await File(p.join(root.path, name))
              .readAsBytes(),
      };
      final legacyGroups = await Hive.openBox<BookmarkGroupHiveObject>(
        'bookmark_groups',
      );
      final staleId = legacyGroups
          .get(_groupId)!
          .bookmarkIds
          .singleWhere((id) => id != 12);
      final metadata = await Hive.openBox<dynamic>(_metadata);
      final activations = <Object?>[];
      final subscription = metadata
          .watch(key: BookmarkStorageMigration.activeKey)
          .listen((event) => activations.add(event.value));
      addTearDown(subscription.cancel);

      final recovery = await app.read(importRecoveryProvider.future);
      expect(recovery.failures, isEmpty);
      expect(recovery.recoveredTransactionIds, [_transactionId]);
      expect(await journal.pending(), isEmpty);
      await expectRestored(app);
      final activation = Hive.box<dynamic>(_metadata)
          .get(BookmarkStorageMigration.activeKey);
      expect(activation, isNotNull);
      expect(activations, [activation]);
      await subscription.cancel();
      final repository = unifiedBookmarkStorage(
        await app.read(bookmarkRepoProvider.future),
      )!;
      final reserved = (await repository.reserveIds(1)).single;
      expect(reserved, greaterThan(staleId));
      for (final entry in originalFiles.entries) {
        expect(await entry.key.readAsBytes(), entry.value);
      }

      for (var i = 0; i < 2; i++) {
        await close();
        final reopened = boot();
        final result = await reopened.read(importRecoveryProvider.future);
        expect(result.recoveredTransactionIds, isEmpty);
        expect(result.failures, isEmpty);
        await expectRestored(reopened);
        final storage = unifiedBookmarkStorage(
          await reopened.read(bookmarkRepoProvider.future),
        )!;
        expect((await storage.reserveIds(1)).single, reserved + i + 1);
        expect(
          Hive.box<dynamic>(_metadata).get(BookmarkStorageMigration.activeKey),
          activation,
        );
      }
    },
  );

  test(
    'malformed released membership without a pending import remains rejected',
    () async {
      await fs.deleteDirectory(
        journal.transactionPath(_transactionId),
        recursive: true,
      );
      final raw = File(p.join(root.path, 'bookmark_groups.hive'));
      final before = await raw.readAsBytes();
      final app = boot();
      expect((await app.read(importRecoveryProvider.future)).failures, isEmpty);
      await expectLater(
        app.read(bookmarkRepoProvider.future),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            'Legacy Group references an absent Post',
          ),
        ),
      );
      expect(await raw.readAsBytes(), before);
      expect(
        Hive.box<dynamic>(_metadata)
            .containsKey(BookmarkStorageMigration.activeKey),
        isFalse,
      );
    },
  );

  test(
    'a bad rollback hash leaves the released boxes and journal in place',
    () async {
      final payload = File(
        '${journal.rollbackPath(_transactionId, 'bookmarks')}.data',
      );
      await payload.writeAsString(' ', mode: FileMode.append);
      final raw = File(p.join(root.path, 'bookmark_groups.hive'));
      final before = await raw.readAsBytes();
      final result = await boot().read(importRecoveryProvider.future);
      expect(
        result.failures[_transactionId].toString(),
        contains('Rollback payload failed verification'),
      );
      expect(
        (await journal.read(_transactionId)).state,
        ImportJournalState.recoveryRequired,
      );
      expect(await raw.readAsBytes(), before);
      expect(Hive.isBoxOpen(_metadata), isFalse);
    },
  );

  test(
    'recovery retries after a staged hierarchy sync is interrupted',
    () async {
      fs.interruptHierarchySync = true;
      final first = await boot().read(importRecoveryProvider.future);
      expect(
        first.failures[_transactionId].toString(),
        contains('Interrupted hierarchy sync'),
      );
      expect(
        Hive.box<dynamic>(_metadata)
            .containsKey(BookmarkStorageMigration.activeKey),
        isFalse,
      );
      expect(
        (await journal.read(_transactionId)).state,
        ImportJournalState.recoveryRequired,
      );
      await close();

      final reopened = boot();
      final retry = await reopened.read(importRecoveryProvider.future);
      expect(retry.failures, isEmpty);
      expect(retry.recoveredTransactionIds, [_transactionId]);
      await expectRestored(reopened);
      await reopened.read(importRecoveryProvider.notifier).retry();
      expect(
        reopened
            .read(importRecoveryProvider)
            .requireValue
            .recoveredTransactionIds,
        isEmpty,
      );
      expect(await journal.pending(), isEmpty);
    },
  );

  test(
    'a durable active generation survives an interrupted outer recovery commit',
    () async {
      fs.interruptRecoveryCommit = true;
      await expectLater(
        boot().read(importRecoveryProvider.future),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'Interrupted outer recovery commit',
          ),
        ),
      );
      final active = Hive.box<dynamic>(_metadata)
          .get(BookmarkStorageMigration.activeKey);
      expect(active, isNotNull);
      expect(
        (await journal.read(_transactionId)).state,
        ImportJournalState.rollingBack,
      );
      await close();

      final reopened = boot();
      final result = await reopened.read(importRecoveryProvider.future);
      expect(result.failures, isEmpty);
      expect(result.recoveredTransactionIds, [_transactionId]);
      expect(await journal.pending(), isEmpty);
      await expectRestored(reopened);
      expect(
        Hive.box<dynamic>(_metadata).get(BookmarkStorageMigration.activeKey),
        active,
      );
    },
  );
}

class _RecoveryFileSystem extends IoFileSystem {
  _RecoveryFileSystem(this.root);

  final String root;
  var interruptHierarchySync = false;
  var interruptRecoveryCommit = false;

  @override
  Future<String> getAppStoragePath() async => root;

  @override
  Future<void> writeString(
    String path,
    String content, {
    bool flush = false,
  }) async {
    if (interruptRecoveryCommit &&
        p.basename(path) == 'journal.json.tmp' &&
        (jsonDecode(content) as Map)['state'] ==
            ImportJournalState.recovered.name) {
      interruptRecoveryCommit = false;
      throw StateError('Interrupted outer recovery commit');
    }
    await super.writeString(path, content, flush: flush);
  }

  @override
  Future<void> syncFile(String path) async {
    if (interruptHierarchySync &&
        p.basename(path) == 'bookmark_groups_hierarchy_v2.hive') {
      interruptHierarchySync = false;
      throw StateError('Interrupted hierarchy sync');
    }
    await super.syncFile(path);
  }
}
