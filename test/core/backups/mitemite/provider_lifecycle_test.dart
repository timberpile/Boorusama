import 'dart:async';
import 'dart:io';
import 'dart:convert';

import 'package:boorusama/core/app_scope.dart';
import 'package:boorusama/core/backups/mitemite/name_dialog.dart';
import 'package:boorusama/core/backups/mitemite/page.dart';
import 'package:boorusama/core/backups/mitemite/collection_aliases.dart';
import 'package:boorusama/core/backups/mitemite/providers.dart';
import 'package:boorusama/core/boorus/engine/providers.dart';
import 'package:boorusama/core/boorus/engine/types.dart';
import 'package:boorusama/core/bookmarks/src/data/providers.dart';
import 'package:boorusama/core/bookmarks/src/pages/bookmark_group_browser_page.dart';
import 'package:boorusama/core/bookmarks/src/providers/bookmark_provider.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_library_state.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_mirror_state.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_group.dart';
import 'package:boorusama/core/cache/misc_data_store.dart';
import 'package:boorusama/core/configs/manage/providers.dart';
import 'package:boorusama/core/search/following_topics/src/providers/following_topics_notifier.dart';
import 'package:boorusama/core/search/following_topics/types.dart';
import 'package:boorusama/core/search/following_topics/src/types/following_mirror_state.dart';
import 'package:boorusama/foundation/platform.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';
import 'package:oktoast/oktoast.dart';
import 'package:boorusama/core/backups/mitemite/protocol.dart';
import 'package:boorusama/core/backups/mitemite/reading_state.dart';
import 'package:boorusama/core/backups/mitemite/storage.dart';
import 'package:boorusama/core/backups/mitemite/service.dart';
import 'package:boorusama/core/backups/sources/bookmark_backup_codec.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/bookmark_group_hive_object.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/bookmark_hive_object.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/unified_bookmark_group_repository.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/unified_bookmark_repository.dart';
import 'package:boorusama/core/bookmarks/src/services/bookmark_storage_migration.dart';
import 'package:boorusama/core/hive/hive_adapters.dart';
import 'package:boorusama/foundation/data_mutation_coordinator.dart';
import 'package:boorusama/foundation/filesystem.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

import '../../../support/boorusama_test_runtime.dart';

final _generationProvider = StateProvider((ref) => 0);

void main() {
  late _Library library;
  setUp(() async => library = await _Library.open());
  tearDown(() => library.close());

  test(
    'refresh never reattaches the bridge to the disposed previous service',
    () async {
      final source = _ServiceSource(library);
      final errors = <Object>[];
      final container = ProviderContainer(overrides: [source.override]);
      addTearDown(container.dispose);
      container.listen(
        miteMiteChangesProvider,
        (_, _) {},
        onError: (error, _) => errors.add(error),
        fireImmediately: true,
      );
      expect(container.read(miteMiteServiceProvider).isLoading, isTrue);
      final a = await source.complete(container);
      final before = container.read(miteMiteChangesProvider);
      _notifyService(a);
      expect(container.read(miteMiteChangesProvider), before + 1);

      container.invalidate(miteMiteServiceProvider);
      final pending = container.read(miteMiteServiceProvider);
      expect(pending.isRefreshing, isTrue);
      expect(pending.valueOrNull, same(a));
      expect(() => a.addListener(() {}), throwsFlutterError);
      await container.pump();
      expect(
        errors,
        isEmpty,
        reason: 'Previous async data is already disposed',
      );
      expect(() => container.read(miteMiteChangesProvider), returnsNormally);

      final b = await source.complete(container);
      final settled = container.read(miteMiteChangesProvider);
      _notifyService(b);
      expect(container.read(miteMiteChangesProvider), settled + 1);
      expect(errors, isEmpty);
    },
  );

  for (final reload in [false, true]) {
    test(
      'repeated ${reload ? 'dependency reloads' : 'refreshes'} exclude obsolete services and keep one bridge listener',
      () async {
        final source = _ServiceSource(library);
        final errors = <Object>[];
        final container = ProviderContainer(
          overrides: [
            source.override,
            miteMiteActivationProvider.overrideWith((_) => true),
          ],
        );
        // Watch the real graph, including projections with explicit dependencies.
        for (final provider in <ProviderListenable<Object?>>[
          miteMiteChangesProvider,
          publishedBookmarkRootsProvider,
          publishedFollowingRootsProvider,
          followingSyncPresentationProvider,
          syncCollectionAliasesProvider,
          miteMiteManagementViewProvider('publish'),
        ]) {
          container.listen<Object?>(
            provider,
            (_, _) {},
            onError: (e, _) => errors.add(e),
          );
        }
        expect(container.read(currentMiteMiteServiceProvider), isNull);
        var service = await source.complete(container);
        var labelChanges = 0;
        container.listen(
          syncCollectionAliasesProvider,
          (_, _) => labelChanges++,
        );
        for (var i = 0; i < 3; i++) {
          final before = container.read(miteMiteChangesProvider);
          _notifyService(service);
          expect(container.read(miteMiteChangesProvider), before + 1);
          expect(
            labelChanges,
            0,
            reason: 'Unchanged alias projection stays stable',
          );
          final old = service;
          if (reload) {
            container.read(_generationProvider.notifier).state++;
          } else {
            container.invalidate(miteMiteServiceProvider);
          }
          final pending = container.read(miteMiteServiceProvider);
          expect(pending.isReloading, reload);
          expect(pending.valueOrNull, same(old));
          expect(container.read(currentMiteMiteServiceProvider), isNull);
          expect(container.read(publishedBookmarkRootsProvider), isEmpty);
          expect(container.read(publishedFollowingRootsProvider), isEmpty);
          expect(container.read(syncCollectionAliasesProvider), isEmpty);
          expect(container.read(followingSyncPresentationProvider), isNull);
          expect(() => old.addListener(() {}), throwsFlutterError);
          await container.pump();
          expect(errors, isEmpty);
          service = await source.complete(container);
          expect(container.read(currentMiteMiteServiceProvider), same(service));
        }
        container.dispose();
        expect(source.disposed.toSet(), hasLength(4));
        expect(
          source.disposed,
          hasLength(4),
          reason: 'Only the source disposes each instance once',
        );
        expect(errors, isEmpty);
      },
    );
  }

  test(
    'failed replacement retains its error but never resurrects the old service',
    () async {
      final source = _ServiceSource(library);
      final container = ProviderContainer(overrides: [source.override]);
      addTearDown(container.dispose);
      container.listen(miteMiteChangesProvider, (_, _) {});
      final a = await source.complete(container);
      container.invalidate(miteMiteServiceProvider);
      final ready = container.read(miteMiteServiceProvider.future);
      final error = StateError('Controlled replacement failure');
      final failed = expectLater(ready, throwsA(same(error)));
      source.gates.last.completeError(error);
      await failed;
      await container.pump();
      final state = container.read(miteMiteServiceProvider);
      expect(state.error, same(error));
      expect(state.valueOrNull, same(a));
      expect(container.read(currentMiteMiteServiceProvider), isNull);
      expect(() => container.read(miteMiteChangesProvider), returnsNormally);
      container.invalidate(miteMiteServiceProvider);
      final b = await source.complete(container);
      expect(container.read(currentMiteMiteServiceProvider), same(b));
      final before = container.read(miteMiteChangesProvider);
      _notifyService(b);
      expect(container.read(miteMiteChangesProvider), before + 1);
    },
  );

  test('inactive root projections never create a service', () {
    final source = _ServiceSource(library);
    final container = ProviderContainer(
      overrides: [
        source.override,
        miteMiteActivationProvider.overrideWith((_) => false),
      ],
    );
    addTearDown(container.dispose);
    expect(container.read(publishedBookmarkRootsProvider), isEmpty);
    expect(container.read(publishedFollowingRootsProvider), isEmpty);
    expect(source.gates, isEmpty);
    expect(container.exists(miteMiteServiceProvider), isFalse);
  });

  test(
    'a child service override reaches the bridge and all scoped projections',
    () async {
      final parentSource = _ServiceSource(library);
      final childSource = _ServiceSource(library);
      final parent = ProviderContainer(
        overrides: [
          parentSource.override,
          miteMiteActivationProvider.overrideWith((_) => false),
        ],
      );
      final child = ProviderContainer(
        parent: parent,
        overrides: [childSource.override],
      );
      addTearDown(parent.dispose);
      addTearDown(child.dispose);
      final a = await parentSource.complete(parent);
      expect(a.collectionAliases, isEmpty);
      final aliasId = SyncCollectionId(
        publisher: library.identity.id,
        kind: 'bookmarks',
        source: _source,
      );
      await SyncCollectionAliases(library.preferences)
          .set(aliasId, 'Child alias');
      child.listen(miteMiteChangesProvider, (_, _) {});
      final b = await childSource.complete(child);
      b.publishedRoots = const {_root};
      b.publishedFollowingRoots = const {_source};
      b.receiverFollowing = FollowingMirrorSnapshot(
        mirrors: const FollowingMirrorState.empty(),
        topics: const [],
        organization: TopicOrganization(folders: const []),
        structureDigest: 'a' * 64,
      );
      expect(child.read(currentMiteMiteServiceProvider), same(b));
      expect(child.read(publishedBookmarkRootsProvider), {_root});
      expect(child.read(publishedFollowingRootsProvider), {_source});
      expect(child.read(syncCollectionAliasesProvider), {
        aliasId: 'Child alias',
      });
      expect(parent.read(syncCollectionAliasesProvider), isEmpty);
      expect(
        child.read(followingSyncPresentationProvider),
        b.receiverFollowing?.mirrors,
      );
      expect(
        () => child.read(miteMiteManagementViewProvider('publish')),
        returnsNormally,
      );
      expect(
        child.read(miteMiteManagementViewProvider('publish')),
        isNot(parent.read(miteMiteManagementViewProvider('publish'))),
      );
      final before = child.read(miteMiteChangesProvider);
      _notifyService(a);
      expect(child.read(miteMiteChangesProvider), before);
      _notifyService(b);
      expect(child.read(miteMiteChangesProvider), before + 1);
    },
  );

  for (final reload in [false, true]) {
    test(
      'production ownership survives ${reload ? 'dependency recomputation' : 'explicit invalidation'} and cancels obsolete initialization',
      () async {
        await library.preferences.put(
          'mitemite.v1.identity',
          jsonEncode(library.identity.localJson()),
        );
        final container = ProviderContainer(
          overrides: [
            ...library.productionOverrides,
            miscDataStoreProvider.overrideWith((ref) {
              ref.watch(_generationProvider);
              return _Preferences(library.preferences);
            }),
          ],
        );
        addTearDown(container.dispose);
        container.listen(miteMiteChangesProvider, (_, _) {});
        final a = await container.read(miteMiteServiceProvider.future);
        await container.pump();
        final entered = Completer<void>();
        final release = Completer<void>();
        final blocking = library.bookmarks.coordinator.runExclusive(() async {
          entered.complete();
          await release.future;
        });
        await entered.future;
        if (reload) {
          container.read(_generationProvider.notifier).state++;
        } else {
          container.invalidate(miteMiteServiceProvider);
        }
        final pending = container.read(miteMiteServiceProvider);
        expect(pending.valueOrNull, same(a));
        expect(pending.isReloading, reload);
        expect(container.read(currentMiteMiteServiceProvider), isNull);
        expect(() => a.addListener(() {}), throwsFlutterError);
        // Supersede another generation while real construction waits on identity.
        final obsolete = container.read(miteMiteServiceProvider.future);
        container.invalidate(miteMiteServiceProvider);
        final ready = container.read(miteMiteServiceProvider.future);
        release.complete();
        await blocking;
        final b = await ready;
        // Riverpod forwards an obsolete .future to its replacement, while the
        // production factory's current flag prevents late resource construction.
        expect(await obsolete, same(b));
        await container.pump();
        expect(b, isNot(same(a)));
        expect(b.identity.id, a.identity.id);
        expect(container.read(currentMiteMiteServiceProvider), same(b));
        final before = container.read(miteMiteChangesProvider);
        _notifyService(b);
        expect(container.read(miteMiteChangesProvider), before + 1);
        container.invalidate(miteMiteServiceProvider);
        expect(() => b.addListener(() {}), throwsFlutterError);
      },
    );
  }

  testWidgets(
    'obsolete startup work cannot start an operation on a disposed service',
    (tester) async {
      final a = library.service();
      final b = library.service();
      final services = [a, b];
      final container = ProviderContainer(
        overrides: [
          miteMiteServiceProvider.overrideWith((ref) {
            final service = services[ref.watch(_generationProvider)];
            ref.onDispose(service.dispose);
            return service;
          }),
          miteMiteActivationProvider.overrideWith((_) => true),
          bookmarkProvider.overrideWith(() => _SnapshotLibrary(_emptyLibrary)),
          followingTopicsProvider.overrideWith(_EmptyFollowing.new),
          booruConfigProvider.overrideWith(
            () => BooruConfigNotifier(initialConfigs: []),
          ),
          appPlatformProvider.overrideWithValue(AppPlatform.android),
        ],
      );
      addTearDown(container.dispose);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      // This callback runs after A attaches but before A's startup callback.
      tester.binding.addPostFrameCallback((_) {
        container.read(_generationProvider.notifier).state = 1;
        expect(container.read(currentMiteMiteServiceProvider), same(b));
      });
      var obsoleteStarted = false;
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MiteMiteLifecycle(
            child: Builder(
              builder: (_) {
                tester.binding.addPostFrameCallback(
                  (_) => obsoleteStarted = a.isReconciling,
                );
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      expect(
        obsoleteStarted,
        isFalse,
        reason: 'Post-frame startup belongs to its captured generation',
      );
      await tester.pump();
      await tester.pump();
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(minutes: 2));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'replacement and unmount cancel pending polls and isolate async sync completion',
    (tester) async {
      await library.preferences.put(
        'mitemite.v1.settings',
        jsonEncode({
          'version': 1,
          'location': '/shared',
          'name': 'Boorusama',
          'roots': [],
        }),
      );
      final openings = <Completer<MiteMiteStorage>>[];
      final obsoleteTransport = _ObsoleteStorage();
      final source = _ServiceSource(
        library,
        create: () => library.service(
          storageFor: (_) {
            final gate = Completer<MiteMiteStorage>();
            openings.add(gate);
            return gate.future;
          },
        ),
      );
      final container = ProviderContainer(
        overrides: [
          source.override,
          miteMiteActivationProvider.overrideWith((_) => true),
          bookmarkProvider.overrideWith(() => _SnapshotLibrary(_emptyLibrary)),
          followingTopicsProvider.overrideWith(_EmptyFollowing.new),
          booruConfigProvider.overrideWith(
            () => BooruConfigNotifier(initialConfigs: []),
          ),
          appPlatformProvider.overrideWithValue(AppPlatform.android),
        ],
      );
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      try {
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MiteMiteLifecycle(child: SizedBox()),
          ),
        );
        final a = (await tester.runAsync(
          () => source.complete(container, pump: false),
        ))!;
        await tester.pump();
        await _pumpUntil(tester, () => openings.isNotEmpty);
        expect(openings, hasLength(1));
        expect(a.isReconciling, isTrue);
        // Several polls coalesce into the held startup operation.
        await tester.pump(const Duration(minutes: 2));
        expect(openings, hasLength(1));
        (container.read(bookmarkProvider.notifier) as _SnapshotLibrary).replace(
          BookmarkLibraryState(
            bookmarks: const [],
            groups: [
              BookmarkGroup(
                id: _root,
                name: 'Local change',
                bookmarkIds: const {},
              ),
            ],
          ),
        );
        await _pumpUntil(tester, () => a.hasUnpublishedChanges);
        // Replace A while its local-change debounce and transport are pending.
        container.invalidate(miteMiteServiceProvider);
        await tester.pump();
        expect(container.read(currentMiteMiteServiceProvider), isNull);
        final b = (await tester.runAsync(
          () => source.complete(container, pump: false),
        ))!;
        await tester.pump();
        await _pumpUntil(tester, () => openings.length == 2);
        expect(b.hasUnpublishedChanges, isTrue);
        expect(
          openings,
          hasLength(2),
          reason: 'B starts once while A is still pending',
        );
        openings.first.complete(obsoleteTransport);
        await tester.pump();
        await _pumpUntil(tester, () => !a.isReconciling);
        expect(a.isReconciling, isFalse);
        expect(
          b.isReconciling,
          isTrue,
          reason: 'A completion cannot clear B work',
        );
        await tester.pumpWidget(const SizedBox());
        container.dispose();
        openings.last.complete(obsoleteTransport);
        await tester.pump();
        await tester.pump(const Duration(minutes: 2));
        expect(openings, hasLength(2));
        await _pumpUntil(tester, () => !b.isReconciling);
        expect(obsoleteTransport.calls, isEmpty);
        expect(b.isReconciling, isFalse);
        expect(tester.takeException(), isNull);
      } finally {
        for (final opening in openings) {
          if (!opening.isCompleted) opening.complete(obsoleteTransport);
        }
        await tester.pumpWidget(const SizedBox());
        container.dispose();
        await tester.pump();
      }
      expect(source.disposed, hasLength(2));
    },
  );

  testWidgets(
    'Bookmarks keeps received groups and aliases through a delayed replacement',
    (tester) async {
      final snapshot = (await tester.runAsync(library.receivedLibrary))!;
      final source = _ServiceSource(library);
      late ProviderContainer container;
      try {
        await tester.pumpWidget(
          _testApp(library, [
            source.override,
            bookmarkProvider.overrideWith(() => _SnapshotLibrary(snapshot)),
            miteMiteActivationProvider.overrideWith((_) => false),
          ], const BookmarkGroupBrowserPage()),
        );
        await tester.pump();
        container = ProviderScope.containerOf(
          tester.element(find.byType(BookmarkGroupBrowserPage)),
        );
        expect(tester.takeException(), isNull);
        final a = (await tester.runAsync(
          () => source.complete(container, pump: false),
        ))!;
        await tester.pumpAndSettle();
        expect(find.text('Private alias'), findsWidgets);
        expect(container.read(publishedBookmarkRootsProvider), {_source});
        final savedAliases = library.preferences.get(SyncCollectionAliases.key);
        container.invalidate(miteMiteServiceProvider);
        await tester.pump();
        expect(container.read(miteMiteServiceProvider).valueOrNull, same(a));
        expect(container.read(currentMiteMiteServiceProvider), isNull);
        expect(find.byType(ErrorWidget), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(container.read(syncCollectionAliasesProvider), isEmpty);
        expect(find.text('Received group'), findsWidgets);
        expect(
          library.preferences.get(SyncCollectionAliases.key),
          savedAliases,
        );
        expect(
          container.read(bookmarkProvider).requireValue.mirrors,
          snapshot.mirrors,
        );
        final b = (await tester.runAsync(
          () => source.complete(container, pump: false),
        ))!;
        await tester.pumpAndSettle();
        expect(find.text('Private alias'), findsWidgets);
        expect(container.read(publishedBookmarkRootsProvider), {_source});
        expect(b.publishedRoots, a.publishedRoots);
        expect(tester.takeException(), isNull);
        expect(find.byType(ErrorWidget), findsNothing);
        expect(
          await tester.runAsync(library.bookmarks.readMirrorState),
          snapshot.mirrors,
        );
      } finally {
        await tester.pumpWidget(const SizedBox());
        await tester.runAsync(library.close);
      }
      expect(source.disposed.toSet(), hasLength(2));
      expect(source.disposed, hasLength(2));
    },
  );

  testWidgets(
    'management shows replacement loading and failure without using previous data',
    (tester) async {
      final source = _ServiceSource(library);
      try {
        await tester.pumpWidget(
          _testApp(library, [
            source.override,
            bookmarkProvider.overrideWith(
              () => _SnapshotLibrary(_emptyLibrary),
            ),
          ], const MiteMitePage()),
        );
        final container = ProviderScope.containerOf(
          tester.element(find.byType(MiteMitePage)),
        );
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        await tester.runAsync(() => source.complete(container, pump: false));
        await tester.pumpAndSettle();
        expect(find.byType(CircularProgressIndicator), findsNothing);
        // Keep a real edit dialog open across service replacement.
        await tester.tap(find.byIcon(Icons.edit_outlined).first);
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), 'Obsolete rename');
        container.invalidate(miteMiteServiceProvider);
        await tester.pump();
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tap(find.widgetWithText(FilledButton, 'Save'));
        await tester.pump();
        final error = StateError('Controlled initialization failure');
        final failed = expectLater(
          container.read(miteMiteServiceProvider.future),
          throwsA(same(error)),
        );
        source.gates.last.completeError(error);
        await failed;
        await tester.pump();
        expect(container.read(miteMiteServiceProvider).error, same(error));
        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(find.byType(ErrorWidget), findsNothing);
        expect(tester.takeException(), isNull);
        container.invalidate(miteMiteServiceProvider);
        final b = (await tester.runAsync(
          () => source.complete(container, pump: false),
        ))!;
        await tester.pumpAndSettle();
        expect(
          b.name,
          'Boorusama',
          reason: 'A dialog cannot mutate its obsolete captured service',
        );
        expect(find.text('Obsolete rename'), findsNothing);
        expect(tester.takeException(), isNull);
      } finally {
        dismissAllToast();
        await tester.pumpWidget(const SizedBox());
        await tester.runAsync(library.close);
      }
    },
  );

  testWidgets('a device alias dialog cannot save to a replaced service', (
    tester,
  ) async {
    final source = _ServiceSource(library);
    try {
      await tester.pumpWidget(
        _testApp(
          library,
          [source.override],
          Consumer(
            builder: (context, ref, _) {
              return Scaffold(
                body: TextButton(
                  onPressed: () async {
                    final service = await ref.read(
                      miteMiteServiceProvider.future,
                    );
                    if (context.mounted) {
                      await editSyncDeviceAlias(
                        context,
                        service: service,
                        publisher: _root,
                        alias: null,
                      );
                    }
                  },
                  child: const Text('Edit alias'),
                ),
              );
            },
          ),
        ),
      );
      final container = ProviderScope.containerOf(
        tester.element(find.text('Edit alias')),
      );
      await tester.runAsync(() => source.complete(container, pump: false));
      await tester.tap(find.text('Edit alias'));
      await tester.runAsync(() => Future<void>(() {}));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Old device');
      container.invalidate(miteMiteServiceProvider);
      final b = (await tester.runAsync(
        () => source.complete(container, pump: false),
      ))!;
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();
      expect(b.receiverMirrors?.aliases[_root], isNull);
      expect(tester.takeException(), isNull);
    } finally {
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(library.close);
    }
  });
}

// One known service notification, independent of operation-specific notifications.
void _notifyService(MiteMiteService service) {
  service.notifyListeners();
}

class _ServiceSource {
  _ServiceSource(this.library, {this.create});
  final _Library library;
  final MiteMiteService Function()? create;
  final gates = <Completer<void>>[];
  final disposed = <MiteMiteService>[];

  Override get override => miteMiteServiceProvider.overrideWith((ref) async {
    ref.watch(_generationProvider);
    final gate = Completer<void>();
    gates.add(gate);
    var current = true;
    MiteMiteService? created;
    ref.onDispose(() {
      current = false;
      if (created case final service?) {
        disposed.add(service);
        service.dispose();
      }
    });
    await gate.future;
    if (!current) throw StateError('Obsolete test initialization');
    return created = create?.call() ?? library.service();
  });

  Future<MiteMiteService> complete(
    ProviderContainer container, {
    bool pump = true,
  }) async {
    final ready = container.read(miteMiteServiceProvider.future);
    gates.last.complete();
    final service = await ready.timeout(const Duration(seconds: 30));
    if (pump) {
      await container.pump();
    }
    return service;
  }
}

class _Library {
  _Library(this.directory, this.bookmarks, this.groups, this.identity);
  final Directory directory;
  final BookmarkHiveRepository bookmarks;
  final UnifiedBookmarkGroupRepository groups;
  final SyncSigningIdentity identity;
  final preferences = MemoryMiscDataStore();

  List<Override> get productionOverrides => [
    bookmarkRepoProvider.overrideWith((_) => bookmarks),
    bookmarkGroupRepoProvider.overrideWith((_) => groups),
    dataMutationCoordinatorProvider.overrideWithValue(bookmarks.coordinator),
    booruEngineRegistryProvider.overrideWithValue(BooruEngineRegistry()),
    appFileSystemProvider.overrideWithValue(const IoFileSystem()),
    appPlatformProvider.overrideWithValue(AppPlatform.android),
  ];

  MiteMiteService service({SyncStorageFactory? storageFor}) => MiteMiteService(
    preferences: preferences,
    store: bookmarks,
    groups: groups,
    fs: const IoFileSystem(),
    codec: BookmarkBackupCodec(),
    identity: identity,
    mutations: bookmarks.coordinator,
    storageFor:
        storageFor ??
        (_) => throw StateError('Inactive sync must not open transport'),
  );

  static Future<_Library> open() async {
    final directory = await Directory.systemTemp.createTemp('sync_lifecycle_');
    Hive.init(directory.path);
    if (!Hive.isAdapterRegistered(4)) {
      Hive.registerAdapter(BookmarkHiveObjectAdapter());
    }
    if (!Hive.isAdapterRegistered(5)) {
      Hive.registerAdapter(BookmarkGroupHiveObjectAdapter());
    }
    final metadata = await Hive.openBox<dynamic>('metadata');
    final bookmarks = BookmarkHiveRepository(
      await Hive.openBox<BookmarkHiveObject>('posts'),
      groupPayloadBox: await Hive.openBox<dynamic>('payloads'),
      metadataBox: metadata,
      coordinator: DataMutationCoordinator(),
    );
    final reader = await BookmarkStorageMigration(
      bookmarks: bookmarks,
      legacyGroups: await Hive.openBox<BookmarkGroupHiveObject>('legacy'),
      legacyOrganization: await Hive.openBox<dynamic>('organization'),
      metadata: metadata,
    ).open();
    return _Library(
      directory,
      bookmarks,
      UnifiedBookmarkGroupRepository(bookmarks: bookmarks, reader: reader),
      await SyncSigningIdentity.create(),
    );
  }

  Future<BookmarkLibraryState> receivedLibrary() async {
    final group = BookmarkGroup(
      id: _root,
      name: 'Received group',
      bookmarkIds: const {},
    );
    final mirrors = BookmarkMirrorState(
      epoch: 1,
      owners: {
        _root: BookmarkMirrorOwner(
          publisher: identity.id,
          source: _source,
          revision: 1,
          payloadDigest: 'a' * 64,
          groupDigest: bookmarkMirrorGroupDigest(group),
          reading: SyncGroupReadingState.empty(
            SyncCollectionId(
              publisher: identity.id,
              kind: 'bookmarks',
              source: _source,
            ),
          ).applyMembership(revision: 1, members: const {}).toJson(),
        ),
      },
      subscriptions: {
        identity.id: const {_source},
      },
      publisherNames: {identity.id: 'Publisher'},
    );
    await bookmarks.coordinator.runExclusive(
      () => bookmarks.commitMirrorOrganization(
        expected: const BookmarkMirrorState.empty(),
        next: mirrors,
        groups: [group],
      ),
    );
    await SyncCollectionAliases(preferences).set(
      SyncCollectionId(
        publisher: identity.id,
        kind: 'bookmarks',
        source: _source,
      ),
      'Private alias',
    );
    await preferences.put(
      'mitemite.v1.settings',
      jsonEncode({
        'version': 1,
        'location': null,
        'name': 'Boorusama',
        'roots': [_source],
      }),
    );
    return BookmarkLibraryState(
      bookmarks: const [],
      groups: [group],
      mirrors: mirrors,
    );
  }

  Future<void> close() async {
    await Hive.close();
    // ignore: avoid_slow_async_io
    if (await directory.exists()) await directory.delete(recursive: true);
  }
}

const _root = '11111111-1111-4111-8111-111111111111';
const _source = '22222222-2222-4222-8222-222222222222';
final _emptyLibrary = BookmarkLibraryState(
  bookmarks: const [],
  groups: const [],
);

class _SnapshotLibrary extends BookmarkNotifier {
  _SnapshotLibrary(this.snapshot);
  final BookmarkLibraryState snapshot;
  @override
  Future<BookmarkLibraryState> build() async => snapshot;
  void replace(BookmarkLibraryState next) => state = AsyncData(next);
}

class _EmptyFollowing extends FollowingTopicsNotifier {
  @override
  Future<FollowingTopicsState> build() async => FollowingTopicsState(
    topics: const [],
    refreshingIds: const {},
    batchCompleted: 0,
    batchTotal: 0,
    organization: TopicOrganization(folders: const []),
  );
}

class _Preferences implements MiscDataStore {
  _Preferences(this.delegate);
  final MiscDataStore delegate;
  @override
  String? get(String key) => delegate.get(key);
  @override
  Future<void> put(String key, String value) => delegate.put(key, value);
}

Widget _testApp(_Library library, List<Override> overrides, Widget child) =>
    BoorusamaAppScope(
      runtime: createTestBoorusamaRuntime(),
      additionalOverrides: [
        ...library.productionOverrides,
        miscDataStoreProvider.overrideWithValue(library.preferences),
        booruConfigProvider.overrideWith(
          () => BooruConfigNotifier(initialConfigs: []),
        ),
        ...overrides,
      ],
      child: MaterialApp(
        builder: (context, child) => KurumiTheme(
          data: KurumiThemeData.fromMaterial(Theme.of(context)),
          child: OKToast(child: child!),
        ),
        home: child,
      ),
    );

// Disposal while opening transport must stop before the first external I/O.
class _ObsoleteStorage implements MiteMiteStorage {
  final calls = <Invocation>[];
  @override
  dynamic noSuchMethod(Invocation invocation) {
    calls.add(invocation);
    throw StateError('Obsolete transport I/O');
  }
}

Future<void> _pumpUntil(WidgetTester tester, bool Function() complete) async {
  final guard = Stopwatch()..start();
  while (!complete()) {
    if (guard.elapsed > const Duration(seconds: 30)) {
      fail('Operation did not complete');
    }
    await tester.runAsync(() => Future<void>(() {}));
    await tester.pump();
  }
}
