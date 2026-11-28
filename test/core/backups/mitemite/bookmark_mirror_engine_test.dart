import 'package:boorusama/core/backups/export_import/package/export_package_exception.dart';

import 'dart:math';

import 'package:boorusama/core/bookmarks/src/widgets/bookmark_pool_card.dart';
import 'package:boorusama/core/posts/details/src/types/viewer_entry.dart';
import 'package:boorusama/core/posts/details/src/widgets/mixed_post_details_page.dart';
import 'package:boorusama/core/posts/details/src/widgets/post_details_item.dart';
import 'package:boorusama/boorus/danbooru/client_provider.dart';
import 'package:boorusama/core/images/booru_image.dart';
import 'package:boorusama/core/posts/listing/src/widgets/default_multi_selection_actions.dart';
import 'package:boorusama/core/widgets/multi_select_button.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:clock/clock.dart';
import 'package:dio/dio.dart';
import 'package:boorusama/core/backups/mitemite/relative_date.dart';

import 'package:boorusama/core/search/following_topics/src/providers/following_topics_notifier.dart';
import 'package:boorusama/core/search/following_topics/types.dart';
import 'package:boorusama/core/navigation/navigation_controller.dart';
import 'package:boorusama/core/backups/mitemite/notification_outbox.dart';
import 'package:boorusama/core/backups/mitemite/notification_intent.dart';
import 'package:boorusama/core/search/following_topics/src/pages/following_topics_page.dart';

import '../../../application/support/headless_app_harness.dart';
import '../../../application/support/fake_image_dio.dart';

import 'package:boorusama/core/bookmarks/src/data/providers.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/configs/manage/providers.dart';
import 'package:boorusama/core/settings/providers.dart';
import 'package:boorusama/core/settings/types.dart';
import 'package:boorusama/core/posts/listing/src/widgets/post_grid_config_icon_button.dart';
import 'package:boorusama/core/bookmarks/src/widgets/bookmark_scroll_view.dart';
import 'package:boorusama/core/bookmarks/src/widgets/bookmark_seen_filter.dart';
import 'package:selection_mode/selection_mode.dart';
import 'package:boorusama/boorus/pixiv/works/work_presentation.dart';
import 'package:boorusama/core/content/groups/group_source_provider.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/boorus/danbooru/pools/group_capability.dart';
import 'package:boorusama/core/content/types.dart';
import 'package:boorusama/core/bookmarks/src/types/content_group_bookmark.dart';
import 'package:boorusama/core/bookmarks/src/types/stored_group_snapshot.dart';
import 'package:boorusama/core/developer_options/providers.dart';
import 'package:boorusama/core/posts/listing/types.dart';

import 'dart:io';

import 'package:oktoast/oktoast.dart';

import 'package:boorusama/core/backups/mitemite/local_change_detection.dart';

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:boorusama/core/downloads/background/notification.dart';
import 'package:boorusama/core/downloads/background/providers.dart';
import 'package:boorusama/foundation/platform.dart';
import 'package:boorusama/foundation/permissions.dart';

import 'package:boorusama/boorus/pixiv/posts/post_codec.dart';
import 'package:boorusama/boorus/pixiv/works/bookmark_targets.dart';
import 'package:boorusama/boorus/pixiv/works/work_mapper.dart';
import 'package:boorusama/core/backups/mitemite/bookmark_mirror_engine.dart';
import 'package:boorusama/core/backups/mitemite/bookmark_package.dart';
import 'package:boorusama/core/backups/sources/bookmark_backup_schema.dart';
import 'package:boorusama/core/backups/mitemite/catalog.dart';
import 'package:boorusama/core/backups/mitemite/catalog_gate.dart';
import 'package:boorusama/core/backups/mitemite/protocol.dart';
import 'package:boorusama/core/backups/mitemite/publication.dart';
import 'package:boorusama/core/backups/mitemite/seen_state.dart';
import 'package:boorusama/core/backups/mitemite/receive_preparation.dart';
import 'package:boorusama/core/backups/mitemite/storage.dart';
import 'package:boorusama/core/backups/sources/bookmark_backup_codec.dart';
import 'package:boorusama/core/backups/sources/bookmark_backup_data.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/bookmark_group_hive_object.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/bookmark_hive_object.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/unified_bookmark_group_repository.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/unified_bookmark_repository.dart';
import 'package:boorusama/core/bookmarks/src/services/bookmark_library_service.dart';
import 'package:boorusama/core/bookmarks/src/services/bookmark_storage_migration.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_mirror_state.dart';
import 'package:boorusama/core/bookmarks/src/pages/bookmark_group_browser_page.dart';
import 'package:boorusama/core/bookmarks/src/widgets/bookmark_local_group_card.dart';
import 'package:boorusama/core/backups/mitemite/service.dart';
import 'package:boorusama/core/backups/mitemite/local_events.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_view.dart';
import 'package:boorusama/core/bookmarks/src/services/bookmark_seen_projection.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_grid_entry.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_record_fields.dart';
import 'package:boorusama/core/bookmarks/src/providers/local_providers.dart';
import 'package:boorusama/core/bookmarks/src/services/bookmark_series_projection.dart';
import 'package:boorusama/core/cache/misc_data_store.dart';
import 'package:boorusama/core/hive/hive_adapters.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/foundation/data_mutation_coordinator.dart';
import 'package:boorusama/foundation/filesystem.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';
import 'package:i18n/i18n.dart';
import 'package:boorusama/core/backups/mitemite/page.dart';
import 'package:boorusama/core/backups/mitemite/providers.dart';
import 'package:boorusama/core/backups/mitemite/notifications.dart';
import 'package:boorusama/core/bookmarks/src/providers/bookmark_profile_availability.dart';
import 'package:boorusama/core/bookmarks/src/providers/bookmark_provider.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_library_state.dart';
import 'package:hive_ce/hive.dart';

import '../../../boorus/pixiv/works/work_test_fixtures.dart';

void main() {
  late Directory directory;
  late BookmarkHiveRepository repository;
  late UnifiedBookmarkGroupRepository groups;
  late BookmarkLibraryService library;
  late SyncBookmarkMirrorEngine engine;
  late SyncSigningIdentity identity;
  late SyncPublicationWriter writer;
  late DirectoryMiteMiteStorage shared;
  late SyncCatalogGate gate;
  final codec = BookmarkBackupCodec(
    postDataCodec: (_) => const PixivPostCodec(),
  );
  const parent = '11111111-2222-4333-8444-555555555555';
  const child = '22222222-2222-4333-8444-555555555555';
  final at = DateTime.utc(2026, 11, 14);
  late Bookmark workRecord;
  late Bookmark pageRecord;

  Future<SyncRevision> publish(String id, List<Bookmark> records) async {
    final data = BookmarkBackupData.unified(
      records: records,
      groups: [
        BookmarkGroupBackup(
          id: id,
          name: id,
          bookmarkIds: records.map((record) => record.id).toList(),
          addedAt: {for (final record in records) record.id: at},
        ),
      ],
    );
    final package =
        await SyncBookmarkPackageBuilder(
          fs: const IoFileSystem(),
          codec: codec,
        ).build(
          collection: SyncCollectionId(
            publisher: identity.id,
            kind: 'bookmarks',
            source: id,
          ),
          data: data,
          appVersion: '4.6.1',
          createdAt: at,
        );
    return writer.publishRevision(package);
  }

  Future<VerifiedSyncCatalog> advertise(
    SyncRevision a,
    SyncRevision b, {
    SyncPublicationState parentState = SyncPublicationState.active,
    String childName = 'B',
    Set<String> direct = const {parent, child},
    bool siblings = false,
  }) async {
    final catalog = await writer.publishCatalog(
      name: 'Publisher',
      publicationRoots: {
        for (final source in direct)
          if (source != parent || parentState == SyncPublicationState.active)
            SyncCollectionId(
              publisher: identity.id,
              kind: 'bookmarks',
              source: source,
            ),
      },
      entries: [
        SyncCatalogEntry(
          id: a.collection,
          name: 'A',
          state: parentState,
          revision: a,
        ),
        SyncCatalogEntry(
          id: b.collection,
          name: childName,
          parent: siblings ? null : parent,
          state: SyncPublicationState.active,
          revision: b,
        ),
      ],
    );
    final bytes = await shared.read(catalog.path);
    return gate.verifyAndCheckpoint(
      publisher: identity.id,
      expectedSequence: catalog.sequence,
      bytes: bytes!,
    );
  }

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('sync_engine_');
    Hive.init('${directory.path}/local');
    if (!Hive.isAdapterRegistered(4)) {
      Hive.registerAdapter(BookmarkHiveObjectAdapter());
    }
    if (!Hive.isAdapterRegistered(5)) {
      Hive.registerAdapter(BookmarkGroupHiveObjectAdapter());
    }
    final coordinator = DataMutationCoordinator();
    final posts = await Hive.openBox<BookmarkHiveObject>('posts');
    final metadata = await Hive.openBox<dynamic>('metadata');
    repository = BookmarkHiveRepository(
      posts,
      groupPayloadBox: await Hive.openBox<dynamic>('payloads'),
      metadataBox: metadata,
      coordinator: coordinator,
      postDataCodec: (_) => const PixivPostCodec(),
    );
    final reader = await BookmarkStorageMigration(
      bookmarks: repository,
      legacyGroups: await Hive.openBox<BookmarkGroupHiveObject>('legacy'),
      legacyOrganization: await Hive.openBox<dynamic>('organization'),
      metadata: metadata,
    ).open();
    groups = UnifiedBookmarkGroupRepository(
      bookmarks: repository,
      reader: reader,
    );
    library = BookmarkLibraryService(
      bookmarkRepository: repository,
      groupRepository: groups,
      imageUrlResolver: (_) => const DefaultImageUrlResolver(),
    );
    await library.load();
    identity = await SyncSigningIdentity.create();
    final appStore = _Store();
    shared = DirectoryMiteMiteStorage('${directory.path}/shared');
    gate = SyncCatalogGate(store: appStore, mutations: coordinator);
    await gate.approvePublisher(
      publisher: identity.id,
      publicKey: identity.publicKey,
    );
    writer = SyncPublicationWriter(
      identity: identity,
      storage: shared,
      sequences: SyncPublicationSequences(
        store: appStore,
        mutations: coordinator,
      ),
    );
    engine = SyncBookmarkMirrorEngine(
      store: repository,
      groups: groups,
      gate: gate,
      preparation: SyncReceivePreparation(
        storage: shared,
        fs: const IoFileSystem(),
        codec: codec,
      ),
      now: () => at,
    );
    final access = workAccess();
    workRecord = PixivWorkBookmarkTarget(
      access: access,
      summary: pixivWorkSummary(work(), access),
    ).draft(currentAccess: access, at: at);
    pageRecord = PixivPageBookmarkTarget(
      access: access,
      post: pixivWorkPagePosts(work(), access)[2],
    ).draft(currentAccess: access, at: at).copyWith(id: 1);
  });
  tearDown(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  ProviderContainer realContainer(
    MiscDataStore preferences,
  ) => ProviderContainer(
    overrides: [
      bookmarkRepoProvider.overrideWith((_) => Future.sync(() => repository)),
      bookmarkGroupRepoProvider.overrideWith((_) => Future.sync(() => groups)),
      dataMutationCoordinatorProvider.overrideWithValue(
        repository.coordinator,
      ),
      miscDataStoreProvider.overrideWithValue(preferences),
      booruConfigProvider.overrideWith(
        () => BooruConfigNotifier(initialConfigs: []),
      ),
      settingsNotifierProvider.overrideWith(() => _SyncTestSettings()),
      bookmarkUrlResolverProvider.overrideWith(
        (_, _) => const DefaultImageUrlResolver(),
      ),
    ],
  );

  Future<void> pumpIO(
    WidgetTester tester,
    bool Function() done, {
    bool settle = true,
  }) async {
    final guard = Stopwatch()..start();
    while (guard.elapsed < const Duration(seconds: 30)) {
      await tester.runAsync(() => Future<void>(() {}));
      // A busy host can trigger cooperative yields even for this small library.
      // Advance the widget clock so its queued timers can finish the reload.
      await tester.pump(const Duration(milliseconds: 1));
      if (done()) {
        if (settle) await tester.pumpAndSettle();
        return;
      }
    }
    fail('Real Hive/service operation did not reach its completion condition');
  }

  void testManagementWidgets(String name, WidgetTesterCallback body) {
    testWidgets(name, (tester) async {
      try {
        await body(tester);
      } finally {
        // Toasts live in oktoast's global manager, beyond a route's lifetime.
        // Dismiss them explicitly while their overlay is still mounted.
        dismissAllToast();
        await tester.pumpWidget(const SizedBox());
        // Real Hive I/O can complete fake-zone continuations. Closing only in
        // package:test tearDown strands them after the widget clock has ended.
        // Drain both schedulers here, including when an assertion fails.
        var closed = false;
        final closing = Hive.close().whenComplete(() => closed = true);
        await pumpIO(tester, () => closed);
        await closing;
      }
    });
  }

  Widget managementApp(
    ProviderContainer container,
    MiteMiteService service,
    Widget child,
  ) => UncontrolledProviderScope(
    container: container,
    child: ProviderScope(
      overrides: [
        miteMiteServiceProvider.overrideWith((_) => Future.sync(() => service)),
      ],
      child: BooruLocalization(
        child: MaterialApp(
          builder: (context, child) => KurumiTheme(
            data: KurumiThemeData.fromMaterial(Theme.of(context)),
            child: child!,
          ),
          home: child,
        ),
      ),
    ),
  );

  List<Bookmark> fivePosts() {
    final access = workAccess();
    return [
      for (var i = 0; i < 5; i++)
        PixivPageBookmarkTarget(
          access: access,
          post: pixivWorkPagePosts(work(id: 200 + i), access).first,
        ).draft(currentAccess: access, at: at).copyWith(id: i),
    ];
  }

  Future<HeadlessAppHarness> bookmarkHome(
    WidgetTester tester,
    MiteMiteService service,
    MiscDataStore preferences, {
    List<Override> additionalOverrides = const [],
    List<BooruConfig>? profiles,
  }) async {
    final harness = await HeadlessAppHarness.mount(
      tester,
      viewportSize: const Size(320, 900),
      additionalOverrides: [
        booruConfigProvider.overrideWith(
          () => BooruConfigNotifier(
            initialConfigs: profiles ?? [workAccess().config!],
          ),
        ),
        booruGroupCapabilityProvider.overrideWith(
          (ref, type) => switch (type) {
            BooruType.pixiv => createPixivGroupCapability(ref),
            BooruType.danbooru => createDanbooruGroupCapability(ref),
            _ => null,
          },
        ),
        automaticMediaLoadingEnabledProvider.overrideWithValue(false),
        deterministicImageDioOverride(),
        deterministicFaviconDioOverride(),
        bookmarkRepoProvider.overrideWith((_) => Future.sync(() => repository)),
        bookmarkGroupRepoProvider.overrideWith(
          (_) => Future.sync(() => groups),
        ),
        dataMutationCoordinatorProvider.overrideWithValue(
          repository.coordinator,
        ),
        miscDataStoreProvider.overrideWithValue(preferences),
        bookmarkUrlResolverProvider.overrideWith(
          (_, _) => const DefaultImageUrlResolver(),
        ),
        miteMiteServiceProvider.overrideWith((_) => Future.sync(() => service)),
        ...additionalOverrides,
      ],
    );
    await harness.settle(tester);
    final shortcut = find.byKey(const Key('nav-shortcut-bookmarks'));
    await tester.tap(
      shortcut.evaluate().isNotEmpty ? shortcut : find.text('Bookmarks').first,
    );
    await pumpIO(
      tester,
      () => find.byType(BookmarkLocalGroupCard).evaluate().isNotEmpty,
    );
    return harness;
  }

  testManagementWidgets(
    'received SafeBooru Series opens at its saved site on a Danbooru receiver',
    (tester) async {
      final preferences = _Store();
      late MiteMiteService service;
      late String root;
      await tester.runAsync(() async {
        final series = ContentGroupBookmark(
          id: 0,
          snapshot: StoredGroupSnapshot(
            summary: ContentGroupSummary(
              reference: const ContentReferenceCodec().parse(
                engine: BooruType.danbooru,
                site: Uri.parse('https://safebooru.donmai.us'),
                kind: ContentKind.group,
                sourceKey: 'pool:42',
              ),
              title: 'Received Series',
              displayCategory: 'series',
              memberCount: 2,
              cover: GroupCover(
                thumbnail: Uri.parse('https://cdn.donmai.us/series.jpg'),
                visibility: GroupCoverVisibility(
                  tags: const {'cat'},
                  rating: 'general',
                  deleted: false,
                  banned: false,
                ),
              ),
            ),
          ),
          createdAt: at,
          observedAt: at,
          sourceProfileHint: '11111111-1111-4111-8111-111111111111',
        );
        await engine.receive(
          ticket: await advertise(
            await publish(parent, [series]),
            await publish(child, [series]),
          ),
          publisherKey: identity.publicKey,
          directRoots: {parent},
        );
        root = (await repository.readMirrorState()).localIdFor(
          identity.id,
          parent,
        )!;
        service = MiteMiteService(
          preferences: preferences,
          store: repository,
          groups: groups,
          fs: const IoFileSystem(),
          codec: codec,
          storageFor: (_) async => throw StateError('No live storage reads'),
          identity: await SyncSigningIdentity.create(),
          mutations: repository.coordinator,
        );
      });
      addTearDown(service.dispose);
      final requests = <Uri>[];
      final dio =
          Dio(
              BaseOptions(baseUrl: 'https://safebooru.donmai.us'),
            )
            ..interceptors.add(
              InterceptorsWrapper(
                onRequest: (options, handler) {
                  requests.add(options.uri);
                  expect(options.uri.host, 'safebooru.donmai.us');
                  if (options.path == '/posts.json') {
                    expect(options.queryParameters['tags'], 'id:101,102');
                  }
                  final data = switch (options.path) {
                    '/pools/42.json' => {
                      'id': 42,
                      'name': 'Received Series',
                      'category': 'series',
                      'post_count': 2,
                      'post_ids': [101, 102],
                    },
                    '/posts.json' => [
                      for (final id in [101, 102])
                        {
                          'id': id,
                          'rating': 'g',
                          'is_deleted': false,
                          'is_banned': false,
                          'tag_string': 'cat',
                          'file_ext': 'jpg',
                          'image_width': 100,
                          'image_height': 100,
                          'file_url': 'https://cdn.donmai.us/original/$id.jpg',
                          'large_file_url':
                              'https://cdn.donmai.us/sample/$id.jpg',
                          'preview_file_url':
                              'https://cdn.donmai.us/preview/$id.jpg',
                        },
                    ],
                    _ => null,
                  };
                  handler.resolve(
                    Response<dynamic>(
                      requestOptions: options,
                      statusCode: data == null ? 404 : 200,
                      data: data,
                    ),
                  );
                },
              ),
            );
      addTearDown(() => dio.close(force: true));
      final harness = await bookmarkHome(
        tester,
        service,
        preferences,
        profiles: [
          BooruConfig.fromJson({
            ...BooruConfig.empty.toJson(),
            'id': '22222222-2222-4222-8222-222222222222',
            'booruId': BooruType.danbooru.id,
            'booruIdHint': BooruType.danbooru.id,
            'url': 'https://danbooru.donmai.us',
          }),
        ],
        additionalOverrides: [
          danbooruDioProvider.overrideWith((_, auth) {
            expect(auth.anonymousReadScope, isNotNull);
            expect(Uri.parse(auth.url).host, 'safebooru.donmai.us');
            return dio;
          }),
        ],
      );
      final card = find.byKey(ValueKey(('bookmark-card', root)));
      await tester.ensureVisible(card);
      await tester.tap(card);
      await pumpIO(
        tester,
        () => find.byType(BookmarkPoolCard).evaluate().isNotEmpty,
      );
      await harness.settle(tester);
      final pool = tester
          .widget<BookmarkPoolCard>(find.byType(BookmarkPoolCard).first)
          .pool;
      expect(pool.origin.profileIdHint, isNull);
      final imageFinder = find.descendant(
        of: find.byType(BookmarkPoolCard).first,
        matching: find.byType(BooruImage),
      );
      expect(imageFinder, findsOneWidget);
      expect(
        tester.widget<BooruImage>(imageFinder).config.anonymousReadScope,
        isNotNull,
      );
      await tester.tap(find.byType(BookmarkPoolCard).first);
      await harness.settle(tester);
      final viewer = tester.widget<MixedPostDetailsPage>(
        find.byType(MixedPostDetailsPage),
      );
      final entry = viewer.entries![viewer.initialIndex] as GroupViewerEntry;
      expect(entry.contentReference.sourceKey, 'pool:42');
      expect(entry.contentReference.site.host, 'safebooru.donmai.us');
      expect(entry.source?.publicOrigin, isNotNull);
      final member = find.byWidgetPredicate(
        (widget) => widget is PostDetailsItem<Post> && widget.post?.id == 101,
      );
      final unavailable = find.text('Page unavailable');
      await pumpIO(
        tester,
        () => member.evaluate().isNotEmpty || unavailable.evaluate().isNotEmpty,
      );
      expect(unavailable, findsNothing, reason: 'API requests: $requests');
      expect(member, findsWidgets);
      expect(
        tester
            .widgetList<PostDetailsItem<Post>>(member)
            .map(
              (item) => item.post?.origin.sourceHost,
            ),
        everyElement('safebooru.donmai.us'),
      );
      expect(
        requests.map((uri) => (uri.host, uri.path)),
        containsAllInOrder([
          ('safebooru.donmai.us', '/pools/42.json'),
          ('safebooru.donmai.us', '/posts.json'),
        ]),
      );
    },
  );

  for (final received in [false, true]) {
    for (final kind in ['Posts', 'Works', 'Pools']) {
      for (final nested in [false, true]) {
        testManagementWidgets(
          'Timeline More supports ${received ? 'received' : 'local'} ${nested ? 'nested' : 'root'} $kind without Group actions',
          (tester) async {
            tester.platformDispatcher.textScaleFactorTestValue = 2;
            addTearDown(
              tester.platformDispatcher.clearTextScaleFactorTestValue,
            );
            final preferences = _Store();
            late MiteMiteService service;
            late String root;
            late String leaf;
            late ProviderContainer container;
            await tester.runAsync(() async {
              final workSource = workAccess();
              final records = switch (kind) {
                'Works' => [
                  workRecord,
                  if (received && !nested)
                    PixivWorkBookmarkTarget(
                      access: workSource,
                      summary: pixivWorkSummary(
                        work(id: 901),
                        workSource,
                      ),
                    ).draft(currentAccess: workSource, at: at).copyWith(id: 1),
                ],
                'Pools' => [
                  ContentGroupBookmark(
                    id: 0,
                    snapshot: StoredGroupSnapshot(
                      summary: ContentGroupSummary(
                        reference: const ContentReferenceCodec().parse(
                          engine: BooruType.danbooru,
                          site: Uri.parse('https://danbooru.donmai.us'),
                          kind: ContentKind.group,
                          sourceKey: 'pool:42',
                        ),
                        title: 'Saved Pool',
                        memberCount: 0,
                      ),
                    ),
                    createdAt: at,
                    observedAt: at,
                  ),
                ],
                _ => fivePosts(),
              };
              if (received) {
                await engine.receive(
                  ticket: await advertise(
                    await publish(parent, records),
                    await publish(child, records),
                  ),
                  publisherKey: identity.publicKey,
                  directRoots: {parent},
                );
                final state = await repository.readMirrorState();
                root = state.localIdFor(identity.id, parent)!;
                leaf = state.localIdFor(identity.id, child)!;
                if (kind == 'Works' && !nested) {
                  await engine.markSeen(root, {
                    syncBookmarkMemberKey(records.first),
                  });
                }
              } else {
                root = (await library.createGroup('Local root')).id;
                leaf = (await library.createGroup(
                  'Local child',
                  parentGroupId: root,
                )).id;
                await library.saveDraftsToGroup(records, root);
                await library.saveDraftsToGroup(records, leaf);
              }
              service = MiteMiteService(
                preferences: preferences,
                store: repository,
                groups: groups,
                fs: const IoFileSystem(),
                codec: codec,
                storageFor: (_) async =>
                    throw StateError('Timeline must not open shared storage'),
                identity: await SyncSigningIdentity.create(),
                mutations: repository.coordinator,
                onApplied: () =>
                    container.read(bookmarkProvider.notifier).refresh(),
              );
            });
            addTearDown(service.dispose);
            final harness = await bookmarkHome(tester, service, preferences);
            container = ProviderScope.containerOf(
              tester.element(find.byType(BookmarkGroupBrowserPage)),
            );
            expect(find.text('Local'), findsNothing);
            expect(
              find.byKey(const ValueKey(('bookmark-card', 'all'))),
              findsOneWidget,
            );
            final card = find.byKey(ValueKey(('bookmark-card', root)));
            await tester.ensureVisible(card);
            await tester.tap(card);
            await harness.settle(tester);
            if (nested) {
              final childCard = find.byKey(ValueKey(('bookmark-card', leaf)));
              await tester.ensureVisible(childCard);
              await tester.tap(childCard);
              await harness.settle(tester);
            }
            await pumpIO(tester, () {
              final buttons = find.byType(PostGridConfigIconButton).evaluate();
              if (buttons.isEmpty) return false;
              final controller =
                  (buttons.single.widget as PostGridConfigIconButton)
                      .postController;
              return !controller.loading && !controller.refreshing;
            }, settle: false);
            if (received && kind == 'Works' && !nested) {
              tester
                  .widget<BookmarkSeenFilterButton>(
                    find.byType(BookmarkSeenFilterButton),
                  )
                  .onSelected(BookmarkSeenFilter.unseen);
              await harness.settle(tester);
              await tester.runAsync(() async {
                final owner =
                    (await repository.readMirrorState()).owners[root]!;
                await engine.markSeen(
                  root,
                  SyncGroupSeenState.fromJson(owner.reading).members,
                );
              });
              var reloaded = false;
              Object? reloadError;
              unawaited(
                container
                    .read(bookmarkProvider.notifier)
                    .refresh()
                    .then(
                      (_) => reloaded = true,
                      onError: (Object error) {
                        reloadError = error;
                        reloaded = true;
                      },
                    ),
              );
              await pumpIO(tester, () => reloaded, settle: false);
              await pumpIO(tester, () {
                final controller = tester
                    .widget<PostGridConfigIconButton>(
                      find.byType(PostGridConfigIconButton),
                    )
                    .postController;
                return !controller.loading && !controller.refreshing;
              }, settle: false);
              expect(reloadError, isNull);
              await harness.settle(tester);
              expect(
                tester
                    .widget<PostGridConfigIconButton>(
                      find.byType(PostGridConfigIconButton),
                    )
                    .itemCount,
                0,
              );
              expect(
                find.descendant(
                  of: find.byType(PostGridConfigIconButton),
                  matching: find.byType(KurumiPopupMenuButton),
                ),
                findsNothing,
                reason: 'An empty filtered Timeline follows the ordinary empty-menu visibility rule',
              );
              tester
                  .widget<BookmarkSeenFilterButton>(
                    find.byType(BookmarkSeenFilterButton),
                  )
                  .onSelected(BookmarkSeenFilter.all);
              await harness.settle(tester);
              expect(
                tester
                    .widget<PostGridConfigIconButton>(
                      find.byType(PostGridConfigIconButton),
                    )
                    .itemCount,
                2,
                reason: 'Restoring All after an empty Unseen filter must restore the typed Timeline menu',
              );
            }
            final more = find.descendant(
              of: find.byType(PostGridConfigIconButton),
              matching: find.byType(KurumiPopupMenuButton),
            );
            expect(find.byType(BookmarkScrollView), findsOneWidget);
            if (received) {
              expect(
                find.byTooltip(Translations().mitemite.received_group),
                findsOneWidget,
              );
              expect(find.byIcon(Icons.sync_lock), findsNothing);
            }
            expect(more, findsOneWidget);
            await tester.ensureVisible(more);
            await tester.tap(more);
            await harness.settle(tester);
            expect(find.text('View Options'), findsOneWidget);
            expect(find.text('Select'), findsOneWidget);
            for (final label in [
              'Create Local Copy',
              'Unsubscribe',
              'Publish to MiteMite',
              'Rename',
              'Stop Publishing',
            ]) {
              expect(find.text(label), findsNothing);
            }
            if (kind != 'Posts') expect(find.text('Statistics'), findsNothing);
            await tester.ensureVisible(find.text('View Options'));
            await tester.tap(find.text('View Options'));
            await harness.settle(tester);
            expect(find.byType(PostGridActionSheet), findsOneWidget);
            if (received && kind == 'Works' && !nested) {
              final grid = find.byType(KurumiOptionDropDownButton<GridSize>);
              await tester.ensureVisible(grid);
              await tester.tap(grid);
              await harness.settle(tester);
              await tester.ensureVisible(find.text('Large').last);
              await tester.tap(find.text('Large').last);
              await harness.settle(tester);
              expect(
                container.read(imageListingSettingsProvider).gridSize,
                GridSize.large,
              );
            }
            await tester.binding.handlePopRoute();
            await harness.settle(tester);
            await tester.tap(more);
            await harness.settle(tester);
            await tester.ensureVisible(find.text('Select'));
            await tester.tap(find.text('Select'));
            await harness.settle(tester);
            expect(
              SelectionMode.of(
                tester.element(find.byType(PostGridConfigIconButton)),
              ).isActive,
              isTrue,
            );
            expect(
              more,
              findsNothing,
              reason: 'Normal selection toolbar owns actions',
            );
            if (received && !(kind == 'Works' && !nested)) {
              final selection = SelectionMode.of(
                tester.element(find.byType(PostGridConfigIconButton)),
              );
              selection.selectAll([0]);
              await harness.settle(tester);
              final actions = tester.widget<DefaultMultiSelectionActions>(
                find.byType(DefaultMultiSelectionActions),
              );
              final markSeen = actions.extraActions!(const <Post>[])
                  .whereType<MultiSelectButton>()
                  .singleWhere(
                    (button) =>
                        button.name == Translations().mitemite.mark_seen,
                  );
              markSeen.onPressed!();
              await pumpIO(tester, () => !selection.isActive);
              expect(selection.isActive, isFalse);
              expect(selection.selection, isEmpty);
            }
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }

  testManagementWidgets(
    'Bookmark device pencil edits only its alias offline, with cancel, blank fallback and reload',
    (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final preferences = _Store();
      late MiteMiteService service;
      late ProviderContainer container;
      late BookmarkLibraryState before;
      late String other;
      await tester.runAsync(() async {
        await engine.receive(
          ticket: await advertise(
            await publish(parent, fivePosts()),
            await publish(child, const []),
          ),
          publisherKey: identity.publicKey,
          directRoots: {parent},
        );
        final otherIdentity = await SyncSigningIdentity.create();
        other = otherIdentity.id;
        await gate.approvePublisher(
          publisher: other,
          publicKey: otherIdentity.publicKey,
        );
        await engine.setAlias(other, 'Independent device alias');
        before = await library.load();
        service = MiteMiteService(
          preferences: preferences,
          store: repository,
          groups: groups,
          fs: const IoFileSystem(),
          codec: codec,
          storageFor: (_) async =>
              throw StateError('Alias editor must work offline'),
          identity: await SyncSigningIdentity.create(),
          mutations: repository.coordinator,
          onApplied: () => container.read(bookmarkProvider.notifier).refresh(),
        );
        await service.gate.approvePublisher(
          publisher: identity.id,
          publicKey: identity.publicKey,
        );
      });
      addTearDown(service.dispose);
      final harness = await bookmarkHome(tester, service, preferences);
      container = ProviderScope.containerOf(
        tester.element(find.byType(BookmarkGroupBrowserPage)),
      );
      expect(find.text('Local'), findsNothing);
      expect(
        find.byKey(const ValueKey(('bookmark-card', 'all'))),
        findsOneWidget,
      );
      final edit = find.byKey(ValueKey(('bookmark-device-edit', identity.id)));
      await tester.ensureVisible(edit);
      expect(tester.getSize(edit), const Size(48, 48));
      await tester.tap(edit);
      await harness.settle(tester);
      expect(find.text('Device Alias'), findsOneWidget);
      expect(find.byType(MiteMitePage), findsNothing);
      await tester.enterText(find.byType(TextField), 'Cancelled');
      await tester.tap(find.text('Cancel'));
      await harness.settle(tester);
      expect(
        container
            .read(bookmarkProvider)
            .requireValue
            .mirrors
            .aliases[identity.id],
        isNull,
      );
      expect(find.text('Publisher'), findsOneWidget);
      await tester.tap(edit);
      await harness.settle(tester);
      await tester.showKeyboard(find.byType(TextField));
      tester.view.viewInsets = const FakeViewPadding(bottom: 250);
      addTearDown(tester.view.resetViewInsets);
      await tester.enterText(
        find.byType(TextField),
        '  My very long receiver-local publisher alias  ',
      );
      await tester.ensureVisible(find.text('Save'));
      await tester.tap(find.text('Save'));
      await pumpIO(
        tester,
        () =>
            !service.busy &&
            container
                    .read(bookmarkProvider)
                    .valueOrNull
                    ?.mirrors
                    .aliases[identity.id] ==
                'My very long receiver-local publisher alias',
      );
      tester.view.resetViewInsets();
      tester.testTextInput.hide();
      await harness.settle(tester);
      expect(
        find.text('My very long receiver-local publisher alias'),
        findsOneWidget,
      );
      var after = await tester.runAsync(library.load);
      expect(after!.mirrors.aliases[other], 'Independent device alias');
      expect(after.mirrors.owners, before.mirrors.owners);
      expect(after.mirrors.checkpoints, before.mirrors.checkpoints);
      expect(after.mirrors.subscriptions, before.mirrors.subscriptions);
      expect(after.mirrors.publisherNames, before.mirrors.publisherNames);
      expect(hasLocalSyncChanges(before, after), isFalse);
      await tester.tap(edit);
      await harness.settle(tester);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'My very long receiver-local publisher alias',
      );
      await tester.enterText(find.byType(TextField), '   ');
      await tester.tap(find.text('Save'));
      await pumpIO(
        tester,
        () =>
            !service.busy &&
            container
                    .read(bookmarkProvider)
                    .valueOrNull
                    ?.mirrors
                    .aliases[identity.id] ==
                null,
      );
      expect(find.text('Publisher'), findsOneWidget);
      after = await tester.runAsync(library.load);
      expect(after!.mirrors.aliases, {other: 'Independent device alias'});
      expect(service.gate.approvedKey(identity.id), identity.publicKey);
      expect(service.location, isNull);
      expect(service.hasUnpublishedChanges, isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  testManagementWidgets(
    'received Group aliases cover root, nested path and editor without enabling source edits',
    (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      late MiteMiteService service;
      late String localParent;
      late String localChild;
      late BookmarkMirrorState original;
      final parentId = SyncCollectionId(
        publisher: identity.id,
        kind: 'bookmarks',
        source: parent,
      );
      final childId = SyncCollectionId(
        publisher: identity.id,
        kind: 'bookmarks',
        source: child,
      );
      await tester.runAsync(() async {
        await engine.receive(
          ticket: await advertise(
            await publish(parent, [workRecord]),
            await publish(child, [pageRecord]),
          ),
          publisherKey: identity.publicKey,
          directRoots: {parent, child},
        );
        original = await repository.readMirrorState();
        localParent = original.localIdFor(identity.id, parent)!;
        localChild = original.localIdFor(identity.id, child)!;
        service = MiteMiteService(
          preferences: gate.store,
          store: repository,
          groups: groups,
          fs: const IoFileSystem(),
          codec: codec,
          storageFor: (_) async =>
              throw StateError('Alias UI must work offline'),
          identity: await SyncSigningIdentity.create(),
          mutations: repository.coordinator,
        );
        await service.setCollectionAlias(parentId, 'My Parent');
      });
      addTearDown(service.dispose);
      final harness = await bookmarkHome(tester, service, gate.store);
      final childCard = find.byKey(ValueKey(('bookmark-card', localChild)));
      await tester.ensureVisible(childCard);
      await tester.tap(
        find.descendant(of: childCard, matching: find.bySemanticsLabel('More')),
      );
      await harness.settle(tester);
      expect(find.text('Set Alias'), findsOneWidget);
      for (final text in ['Rename', 'Delete', 'Move', 'Publish to MiteMite']) {
        expect(find.text(text), findsNothing);
      }
      await tester.tap(find.text('Set Alias'));
      await harness.settle(tester);
      expect(find.text('Original Name: B'), findsOneWidget);
      await tester.showKeyboard(find.byType(TextField));
      tester.view.viewInsets = const FakeViewPadding(bottom: 250);
      addTearDown(tester.view.resetViewInsets);
      await tester.enterText(find.byType(TextField), '  My Child  ');
      await tester.ensureVisible(find.text('Save'));
      await tester.tap(find.text('Save'));
      await pumpIO(
        tester,
        () => service.collectionAliases[childId] == 'My Child',
      );
      tester.view.resetViewInsets();
      tester.testTextInput.hide();
      await harness.settle(tester);
      expect(find.text('My Child'), findsOneWidget);
      await tester.tap(find.byKey(ValueKey(('bookmark-card', localParent))));
      await harness.settle(tester);
      expect(find.text('My Parent'), findsOneWidget);
      expect(find.text('My Child'), findsOneWidget);
      await tester.tap(childCard);
      await harness.settle(tester);
      expect(find.text('My Child'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Go to ancestor'));
      await harness.settle(tester);
      expect(find.text('My Parent'), findsOneWidget);
      await tester.tap(find.text('My Parent'));
      await harness.settle(tester);
      await tester.tap(
        find.descendant(
          of: find.byKey(ValueKey(('bookmark-card', localChild))),
          matching: find.bySemanticsLabel('More'),
        ),
      );
      await harness.settle(tester);
      expect(find.text('Edit Alias'), findsOneWidget);
      await tester.tap(find.text('Edit Alias'));
      await harness.settle(tester);
      await tester.enterText(
        find.descendant(
          of: find.byType(KurumiDialog),
          matching: find.byType(TextField),
        ),
        '',
      );
      tester.testTextInput.hide();
      await tester.tap(find.text('Save'));
      await pumpIO(
        tester,
        () => !service.collectionAliases.containsKey(childId),
      );
      expect(find.text('B'), findsOneWidget);
      expect(await tester.runAsync(repository.readMirrorState), original);
      expect(
        (await tester.runAsync(library.load))!.groupsById[localChild]!.name,
        'B',
      );
      expect(tester.takeException(), isNull);
    },
  );

  test('receives overlapping legacy snapshots beyond the former aggregate memory budget', () async {
    final random = Random(192);
    final records = [
      for (var id = 1; id <= 192; id++)
        PostBookmark(
          id: id,
          booruId: BooruType.danbooru.id,
          createdAt: at,
          updatedAt: at,
          thumbnailUrl: 'https://media.example/$id.jpg',
          sampleUrl: 'https://media.example/$id.jpg',
          originalUrl: 'https://media.example/$id.jpg',
          sourceUrl: 'https://site.example',
          width: 100,
          height: 100,
          md5: '',
          tags: {
            for (var tag = 0; tag < 112; tag++)
              random.nextInt(1 << 32).toRadixString(16).padLeft(8, '0') * 52,
          },
          realSourceUrl: null,
          format: 'jpg',
          imageUrlResolver: const DefaultImageUrlResolver(),
          postId: id,
          metadata: const {},
        ),
    ];
    final revisions = [
      for (final id in [
        parent,
        child,
        '33333333-2222-4333-8444-555555555555',
        '44444444-2222-4333-8444-555555555555',
      ])
        await publish(id, records),
    ];
    final root = revisions.first.collection;
    final archive = (await shared.read(revisions.first.payloadPath))!;
    await expectLater(
      SyncBookmarkPackageValidator(
        fs: const IoFileSystem(),
        codec: codec,
      ).validate(
        collection: root,
        bytes: archive,
        maxPreparedBytes: 64 * 1024 * 1024,
      ),
      throwsA(isA<ExportPackageLimitException>()),
    );
    final catalog = await writer.publishCatalog(
      name: 'Publisher',
      publicationRoots: {root},
      entries: [
        for (final revision in revisions)
          SyncCatalogEntry(
            id: revision.collection,
            name: revision.collection.source,
            parent: revision.collection == root ? null : parent,
            state: SyncPublicationState.active,
            revision: revision,
          ),
      ],
    );
    final ticket = await gate.verifyAndCheckpoint(
      publisher: identity.id,
      expectedSequence: catalog.sequence,
      bytes: (await shared.read(catalog.path))!,
    );
    await engine.receive(
      ticket: ticket,
      publisherKey: identity.publicKey,
      directRoots: {parent},
    );
    final state = await repository.readMirrorState();
    final mirrors = (await groups.getGroups())
        .where((group) => state.isReceived(group.id))
        .toList();
    expect(mirrors, hasLength(revisions.length));
    expect(mirrors.first.bookmarkIds, hasLength(records.length));
    for (final group in mirrors) {
      expect(group.bookmarkIds, mirrors.first.bookmarkIds);
      expect(group.addedAt.values, everyElement(at));
    }
    expect(await repository.readAll(), hasLength(records.length));
  }, timeout: const Timeout(Duration(minutes: 3)));

  test('discovery notification preference persists independently of publication and relocation settings', () async {
    final preferences = _Store();
    MiteMiteService open() => MiteMiteService(
      preferences: preferences,
      store: repository,
      groups: groups,
      fs: const IoFileSystem(),
      codec: codec,
      identity: identity,
      mutations: repository.coordinator,
      storageFor: (_) async =>
          throw StateError('Preference must not open storage'),
    );
    final service = open();
    addTearDown(service.dispose);
    expect(service.discoveryNotifications, isTrue);
    await service.setDiscoveryNotifications(false);
    await service.rename('Receiver');
    final restored = open();
    addTearDown(restored.dispose);
    expect(restored.discoveryNotifications, isFalse);
    expect(restored.name, 'Receiver');
    expect(restored.configured, isFalse);
    expect(restored.publishedRoots, isEmpty);
    expect(restored.identity.id, identity.id);
  });

  test('committed notification intent baselines 100 existing Posts and deduplicates overlapping and sibling additions', () async {
    final access = workAccess();
    final initial = <Bookmark>[
      for (var i = 0; i < 100; i++)
        PixivPageBookmarkTarget(
          access: access,
          post: pixivWorkPagePosts(work(id: 1000 + i), access).first,
        ).draft(currentAccess: access, at: at).copyWith(id: i),
    ];
    final a = await publish(parent, initial);
    final b = await publish(child, initial);
    await engine.receive(
      ticket: await advertise(a, b),
      publisherKey: identity.publicKey,
      directRoots: {parent, child},
    );
    final first = (await repository.readMirrorState()).activity;
    expect(
      first.pendingPosts,
      isEmpty,
      reason: 'Initial import is a baseline despite 100 Unseen members',
    );
    final preferences = _Store();
    SyncLocalEvents open() => SyncLocalEvents(
      preferences: preferences,
      mutations: repository.coordinator,
      now: () => at,
    );
    await open().consume('bookmarks', first);
    final addition = bookmarkWithId(workRecord, 200);
    final newerA = await publish(parent, [...initial, addition]);
    final newerB = await publish(child, [...initial, addition]);
    final ticket = await advertise(newerA, newerB);
    await engine.receive(ticket: ticket, publisherKey: identity.publicKey);
    final committed = (await repository.readMirrorState()).activity;
    expect(committed.pendingPosts, hasLength(2));
    expect(
      committed.pendingPosts.map((record) => record.event.source).toSet(),
      {parent, child},
    );
    await open().consume('bookmarks', committed);
    final notice = open().pendingNotifications.single;
    expect(notice.kind, SyncNoticeKind.posts);
    expect(notice.postCount, 1);
    expect(notice.groupCount, 2);
    await engine.acknowledgePostNotifications(
      open().activityCursor('bookmarks'),
    );
    await open().acknowledgeNotification(notice);
    await engine.receive(ticket: ticket, publisherKey: identity.publicKey);
    await open().consume(
      'bookmarks',
      (await repository.readMirrorState()).activity,
    );
    expect(open().pendingNotifications, isEmpty);
    final removedA = await publish(parent, initial);
    final removedB = await publish(child, initial);
    await engine.receive(
      ticket: await advertise(removedA, removedB),
      publisherKey: identity.publicKey,
    );
    await open().consume(
      'bookmarks',
      (await repository.readMirrorState()).activity,
    );
    await engine.receive(
      ticket: await advertise(
        await publish(parent, [...initial, addition]),
        await publish(child, [...initial, addition]),
        childName: 'Renamed',
      ),
      publisherKey: identity.publicKey,
    );
    await open().consume(
      'bookmarks',
      (await repository.readMirrorState()).activity,
    );
    expect(
      open().pendingNotifications,
      isEmpty,
      reason: 'Removal, rename, retry and reappearance are not new arrivals',
    );
  });

  test('future descendants notify but independently added subscriptions baseline their existing members', () async {
    final a = await publish(parent, []);
    final b = await publish(child, [workRecord]);
    await engine.receive(
      ticket: await advertise(a, b, siblings: true),
      publisherKey: identity.publicKey,
      directRoots: {parent},
    );
    await engine.receive(
      ticket: await advertise(a, b, direct: {parent}),
      publisherKey: identity.publicKey,
    );
    final activity = (await repository.readMirrorState()).activity;
    expect(activity.pendingPosts.single.event.source, child);
    expect(activity.pendingPosts.single.event.notificationMembers, {
      syncBookmarkMemberKey(workRecord),
    });
  });

  testManagementWidgets(
    'Bookmark Subscribe shares a cancellable placeholder across Settings and home',
    (tester) async {
      final preferences = _Store();
      late MiteMiteService service;
      late ProviderContainer container;
      late _PausedImportStorage transport;
      await tester.runAsync(() async {
        final a = await publish(parent, [workRecord]);
        final b = await publish(child, [pageRecord]);
        await advertise(a, b, direct: {parent});
        transport = _PausedImportStorage(shared, a.payloadPath, b.payloadPath);
        final sharedContainer = realContainer(preferences);
        addTearDown(sharedContainer.dispose);
        container = ProviderContainer(
          parent: sharedContainer,
          overrides: [
            bookmarkProfileAvailabilityProvider.overrideWithValue(null),
          ],
        );
        final notifier = container.read(bookmarkProvider.notifier);
        await container.read(bookmarkProvider.future);
        service = MiteMiteService(
          preferences: preferences,
          store: repository,
          groups: groups,
          fs: const IoFileSystem(),
          codec: codec,
          identity: await SyncSigningIdentity.create(),
          mutations: repository.coordinator,
          storageFor: (_) async => transport,
          onApplied: notifier.refreshWithProgress,
        );
        await service.configure('${directory.path}/shared');
        await service.approve(
          service.devices.singleWhere((device) => device.id == identity.id),
        );
      });
      addTearDown(container.dispose);
      addTearDown(service.dispose);
      final home = ValueNotifier(false);
      addTearDown(home.dispose);
      await tester.pumpWidget(
        managementApp(
          container,
          service,
          ValueListenableBuilder<bool>(
            valueListenable: home,
            builder: (_, showHome, _) => showHome
                ? const BookmarkGroupBrowserPage()
                : const MiteMitePage(section: 'receive'),
          ),
        ),
      );
      await pumpIO(tester, () => find.text('Subscribe').evaluate().isNotEmpty);
      await tester.tap(find.text('Subscribe'));
      await pumpIO(tester, () => transport.entered.isCompleted, settle: false);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('0 of 2 groups checked'), findsOneWidget);
      final operation = service.bookmarkImports.values.single;

      home.value = true;
      final placeholder = find.byKey(
        ValueKey(('bookmark-import', operation.collection.key)),
      );
      await pumpIO(
        tester,
        () => placeholder.evaluate().isNotEmpty,
        settle: false,
      );
      expect(
        find.descendant(
          of: placeholder,
          matching: find.text('0 of 2 groups checked'),
        ),
        findsOneWidget,
      );
      await tester.tap(
        find.descendant(of: placeholder, matching: find.text('Cancel')),
      );
      await tester.pump();
      expect(operation.value.cancelling, isTrue);
      transport.resume.complete();
      await pumpIO(tester, () => service.bookmarkImports.isEmpty);
      expect(placeholder, findsNothing);
      expect(service.failure, isNull);
      expect(service.receiverMirrors?.subscriptions, isEmpty);

      home.value = false;
      await pumpIO(tester, () => find.text('Subscribe').evaluate().isNotEmpty);
      await tester.tap(find.text('Subscribe'));
      var sawSaving = false;
      final retry = service.bookmarkImports.values.single;
      retry.addListener(() {
        if (retry.value.saving) {
          sawSaving = true;
          expect(retry.value.groups, (checked: 2, total: 2));
          retry.cancel();
          expect(retry.value.cancelling, isFalse);
        }
      });
      await pumpIO(
        tester,
        () => transport.childEntered.isCompleted,
        settle: false,
      );
      try {
        expect(find.text('1 of 2 groups checked'), findsOneWidget);
        expect(
          tester
              .widgetList<LinearProgressIndicator>(
                find.byType(LinearProgressIndicator),
              )
              .map((bar) => bar.value),
          contains(0.5),
        );
      } finally {
        transport.resumeChild.complete();
      }
      await pumpIO(tester, () => service.bookmarkImports.isEmpty);
      expect(sawSaving, isTrue);
      expect(service.receiverMirrors!.subscriptions[identity.id], {parent});
      home.value = true;
      await pumpIO(
        tester,
        () => find.byType(BookmarkGroupBrowserPage).evaluate().isNotEmpty,
      );
      expect(placeholder, findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testManagementWidgets(
    'Subscriptions NEW stays through its first visit and late offers survive successful exit at 320dp enlarged text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
      });
      final preferences = _Store();
      late MiteMiteService service;
      late ProviderContainer container;
      late SyncRevision a;
      late SyncRevision b;
      await tester.runAsync(() async {
        a = await publish(parent, [workRecord]);
        b = await publish(child, [pageRecord]);
        await advertise(a, b, direct: {});
        service = MiteMiteService(
          preferences: preferences,
          store: repository,
          groups: groups,
          fs: const IoFileSystem(),
          codec: codec,
          identity: await SyncSigningIdentity.create(),
          mutations: repository.coordinator,
          storageFor: (path) async => DirectoryMiteMiteStorage(path),
        );
        await service.configure('${directory.path}/shared');
        await service.approve(
          service.devices.singleWhere((device) => device.id == identity.id),
        );
        await advertise(a, b, direct: {parent});
        await service.synchronize();
        container = realContainer(preferences);
        await container.read(bookmarkProvider.future);
      });
      addTearDown(container.dispose);
      addTearDown(service.dispose);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpWidget(
        managementApp(
          container,
          service,
          Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const MiteMitePage(section: 'receive'),
                  ),
                ),
                child: const Text('Open Subscriptions'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open Subscriptions'));
      await pumpIO(tester, () => find.text('NEW').evaluate().isNotEmpty);
      expect(find.text('NEW'), findsOneWidget);
      expect(service.events.unseenOffers, hasLength(1));
      await tester.runAsync(() async {
        for (final notice in service.events.pendingNotifications.toList()) {
          await service.events.acknowledgeNotification(notice);
        }
        await advertise(a, b, direct: {parent, child});
      });
      var synchronized = false;
      unawaited(service.synchronize().whenComplete(() => synchronized = true));
      await pumpIO(tester, () => synchronized);
      expect(find.text('NEW'), findsNWidgets(2));
      expect(service.events.unseenOffers, hasLength(2));
      Navigator.of(tester.element(find.byType(MiteMitePage))).pop();
      await tester.pumpAndSettle();
      await pumpIO(
        tester,
        () =>
            find.byType(MiteMitePage).evaluate().isEmpty &&
            !service.busy &&
            service.events.unseenOffers.length == 1,
      );
      expect(service.events.unseenOffers.values.single.source, child);
      expect(service.receiverMirrors?.subscriptions ?? {}, isEmpty);
      await tester.tap(find.text('Open Subscriptions'));
      await pumpIO(tester, () => find.text('NEW').evaluate().isNotEmpty);
      expect(find.text('NEW'), findsOneWidget);
      Navigator.of(tester.element(find.byType(MiteMitePage))).pop();
      await tester.pumpAndSettle();
      await pumpIO(
        tester,
        () => service.events.unseenOffers.isEmpty && !service.busy,
      );
      expect(tester.takeException(), isNull);
    },
  );

  for (final coldLaunch in [false, true]) {
    for (final destination in SyncNotificationDestination.values) {
      testManagementWidgets(
        'native MiteMite tap opens $destination through the production navigation owner (cold=$coldLaunch)',
        (tester) async {
          final firstPayload = SyncNotificationIntent(
            destination: destination,
            event: syncDigest(syncJsonBytes([destination.name, coldLaunch])),
          ).payload;
          const channel = MethodChannel(
            'dexterous.com/flutter/local_notifications',
          );
          AndroidFlutterLocalNotificationsPlugin.registerWith();
          final calls = <MethodCall>[];
          tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            channel,
            (call) async {
              calls.add(call);
              return switch (call.method) {
                'initialize' ||
                'areNotificationsEnabled' ||
                'requestNotificationsPermission' => true,
                'getNotificationAppLaunchDetails' =>
                  coldLaunch
                      ? {
                          'notificationLaunchedApp': true,
                          'notificationResponse': {
                            'notificationId': 1,
                            'notificationResponseType': 0,
                            'payload': firstPayload,
                          },
                        }
                      : null,
                _ => null,
              };
            },
          );
          addTearDown(
            () =>
                tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
                  channel,
                  null,
                ),
          );
          final native = DownloadNotifications.uninitialized(
            platform: AppPlatform.android,
          );
          addTearDown(native.dispose);
          final preferences = _Store();
          late MiteMiteService service;
          await tester.runAsync(() async {
            final a = await publish(parent, [workRecord]);
            final b = await publish(child, [pageRecord]);
            await advertise(a, b);
            service = MiteMiteService(
              preferences: preferences,
              store: repository,
              groups: groups,
              fs: const IoFileSystem(),
              codec: codec,
              identity: await SyncSigningIdentity.create(),
              mutations: repository.coordinator,
              storageFor: (path) async => DirectoryMiteMiteStorage(path),
            );
            await service.configure('${directory.path}/shared');
            await groups.createGroup('Notification Nested Caller', id: parent);
            if (coldLaunch) {
              await service.acknowledgeDiscoveries(
                service.events.pendingDiscoveries
                    .map((device) => device.key)
                    .toSet(),
              );
            }
          });
          addTearDown(service.dispose);
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.resumed,
          );
          final harness = await HeadlessAppHarness.mount(
            tester,
            appWrapper: (child) => MiteMiteNotifications(child: child),
            additionalOverrides: [
              bookmarkRepoProvider.overrideWith(
                (_) => Future.sync(() => repository),
              ),
              bookmarkGroupRepoProvider.overrideWith(
                (_) => Future.sync(() => groups),
              ),
              dataMutationCoordinatorProvider.overrideWithValue(
                repository.coordinator,
              ),
              deterministicImageDioOverride(),
              deterministicFaviconDioOverride(),
              miscDataStoreProvider.overrideWithValue(preferences),
              miteMiteActivationProvider.overrideWith((_) => true),
              miteMiteServiceProvider.overrideWith(
                (_) => Future.sync(() => service),
              ),
              downloadNotificationsProvider.overrideWithValue(native),
              appPlatformProvider.overrideWithValue(AppPlatform.android),
              deviceStoragePermissionProvider.overrideWith(_GrantedStorage.new),
            ],
          );
          await harness.settle(tester);
          if (!coldLaunch) {
            await pumpIO(
              tester,
              () => service.events.pendingDiscoveries.isEmpty && !service.busy,
              settle: false,
            );
            final shown = calls.where((call) => call.method == 'show');
            expect(shown, hasLength(2));
            final notice =
                shown
                        .singleWhere(
                          (call) =>
                              (call.arguments
                                  as Map)['platformSpecifics']['setAsGroupSummary'] ==
                              false,
                        )
                        .arguments
                    as Map;
            expect(notice['title'], 'Someone new showed up!');
            expect(notice['body'], 'A new device wants to join the fun! 👋');
            expect(
              shown.where(
                (call) =>
                    (call.arguments
                        as Map)['platformSpecifics']['setAsGroupSummary'] ==
                    false,
              ),
              hasLength(1),
              reason: 'One real discovery event and one silent routable group container',
            );
            expect(
              find.text(Translations().mitemite.new_device),
              findsNothing,
              reason: 'Discovery is not a foreground toast',
            );
            await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
              channel.name,
              const StandardMethodCodec().encodeMethodCall(
                MethodCall('didReceiveNotificationResponse', {
                  'notificationId': 1,
                  'notificationResponseType': 0,
                  'payload': firstPayload,
                }),
              ),
              (_) {},
            );
          }
          await pumpIO(
            tester,
            () => switch (destination) {
              SyncNotificationDestination.bookmarks =>
                find.byType(BookmarkGroupBrowserPage).evaluate().isNotEmpty,
              SyncNotificationDestination.following =>
                find.byType(FollowingTopicsPage).evaluate().isNotEmpty,
              SyncNotificationDestination.subscriptions ||
              SyncNotificationDestination.devices =>
                find.byType(MiteMitePage).evaluate().isNotEmpty,
            },
          );
          if (destination != SyncNotificationDestination.bookmarks) {
            if (destination != SyncNotificationDestination.following) {
              expect(
                tester.widget<MiteMitePage>(find.byType(MiteMitePage)).section,
                destination == SyncNotificationDestination.subscriptions
                    ? 'receive'
                    : 'devices',
              );
            }
            expect(service.gate.approvedKey(identity.id), isNull);
            expect(service.receiverMirrors?.subscriptions ?? {}, isEmpty);
            expect(find.text('A'), findsNothing);
            expect(tester.takeException(), isNull);
            return;
          }
          expect(find.text('Bookmark Groups'), findsOneWidget);
          expect(find.byType(MiteMitePage), findsNothing);
          expect(find.text('A'), findsNothing);
          expect(service.gate.approvedKey(identity.id), isNull);
          expect(service.receiverMirrors?.subscriptions ?? {}, isEmpty);
          await pumpIO(
            tester,
            () => find.text('Notification Nested Caller').evaluate().isNotEmpty,
          );
          final callerCard = find.ancestor(
            of: find.text('Notification Nested Caller'),
            matching: find.byType(BookmarkLocalGroupCard),
          );
          await tester.tapAt(tester.getRect(callerCard).center);
          await harness.settle(tester);
          expect(
            find.text('Bookmark Groups'),
            findsNothing,
            reason: 'The real browser keeps this Group in page state, not another Navigator route',
          );
          if (coldLaunch) {
            final container = ProviderScope.containerOf(
              tester.element(find.byType(BookmarkGroupBrowserPage)),
            );
            final controller = container.read(
              navigationControllerProvider.notifier,
            );
            expect(
              await harness.pumpUntilComplete(
                tester,
                controller.selectDestination(controller.browseDestination),
              ),
              isTrue,
            );
          }

          await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
            channel.name,
            const StandardMethodCodec().encodeMethodCall(
              const MethodCall('didReceiveNotificationResponse', {
                'notificationId': 0x14400000,
                'notificationResponseType': 0,
                'payload': 'mitemite:bookmarks',
              }),
            ),
            (_) {},
          );
          await pumpIO(
            tester,
            () => find.text('Bookmark Groups').evaluate().isNotEmpty,
          );
          expect(find.byType(BookmarkGroupBrowserPage), findsOneWidget);
          expect(find.byType(MiteMitePage), findsNothing);
          service.notifyListeners();
          await harness.settle(tester);
          expect(
            find.byType(MiteMitePage),
            findsNothing,
            reason: 'An already handled duplicate tap cannot reopen management after Back',
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  test('persistent Unseen subtree union deduplicates identities without sharing read flags', () async {
    final records = fivePosts();
    final a = await publish(parent, records);
    final b = await publish(child, [records.first, records.last]);
    await engine.receive(
      ticket: await advertise(a, b),
      publisherKey: identity.publicKey,
      directRoots: {parent, child},
    );
    var state = await library.load();
    final root = state.mirrors.localIdFor(identity.id, parent)!;
    final nested = state.mirrors.localIdFor(identity.id, child)!;
    expect(syncBookmarkUnseenMembers(state, root), hasLength(5));
    expect(syncBookmarkUnseenMembers(state, nested), hasLength(2));
    await engine.markSeen(root, {syncBookmarkMemberKey(records.first)});
    state = await library.load();
    expect(
      syncBookmarkUnseenMembers(state, root),
      hasLength(5),
      reason: 'The child still considers that identity Unseen.',
    );
    await engine.markSeen(nested, {syncBookmarkMemberKey(records.first)});
    await engine.markSeen(root, {
      syncBookmarkMemberKey(records[1]),
      syncBookmarkMemberKey(records[2]),
    });
    state = await library.load();
    expect(syncBookmarkUnseenMembers(state, root), hasLength(2));
    expect(syncBookmarkUnseenMembers(state, nested), hasLength(1));
    final restored = BookmarkLibraryState(
      bookmarks: state.items,
      groups: state.groups,
      records: state.records,
      mirrors: BookmarkMirrorState.fromJson(state.mirrors.toJson()),
    );
    expect(syncBookmarkUnseenMembers(restored, root), hasLength(2));
    await engine.receive(
      ticket: await advertise(a, b, childName: 'Renamed'),
      publisherKey: identity.publicKey,
    );
    expect(syncBookmarkUnseenMembers(await library.load(), root), hasLength(2));
    await engine.markSeen(root, records.map(syncBookmarkMemberKey).toSet());
    await engine.markSeen(nested, records.map(syncBookmarkMemberKey).toSet());
    expect(syncBookmarkUnseenMembers(await library.load(), root), isEmpty);
    expect(
      syncBookmarkUnseenMembers(await library.load(), 'unowned-local'),
      isEmpty,
    );
  });

  test('typed read projection retains Group provenance through filters, search and restart', () async {
    final records = [...fivePosts(), bookmarkWithId(workRecord, 20)];
    final a = await publish(parent, records);
    final b = await publish(child, [records.first, pageRecord]);
    await engine.receive(
      ticket: await advertise(a, b),
      publisherKey: identity.publicKey,
      directRoots: {parent, child},
    );
    final otherPublisher = await SyncSigningIdentity.create();
    final otherWriter = SyncPublicationWriter(
      identity: otherPublisher,
      storage: shared,
      sequences: SyncPublicationSequences(
        store: gate.store,
        mutations: repository.coordinator,
      ),
    );
    final otherCollection = SyncCollectionId(
      publisher: otherPublisher.id,
      kind: 'bookmarks',
      source: parent,
    );
    final otherPackage =
        await SyncBookmarkPackageBuilder(
          fs: const IoFileSystem(),
          codec: codec,
        ).build(
          collection: otherCollection,
          data: BookmarkBackupData.unified(
            records: [records.first],
            groups: [
              BookmarkGroupBackup(
                id: parent,
                name: 'Other publisher',
                bookmarkIds: [records.first.id],
                addedAt: {records.first.id: at},
              ),
            ],
          ),
          appVersion: '4.6.1',
          createdAt: at,
        );
    final otherRevision = await otherWriter.publishRevision(otherPackage);
    final otherCatalog = await otherWriter.publishCatalog(
      name: 'Other publisher',
      publicationRoots: {otherCollection},
      entries: [
        SyncCatalogEntry(
          id: otherCollection,
          name: 'Other publisher',
          state: SyncPublicationState.active,
          revision: otherRevision,
        ),
      ],
    );
    await gate.approvePublisher(
      publisher: otherPublisher.id,
      publicKey: otherPublisher.publicKey,
    );
    await engine.receive(
      ticket: await gate.verifyAndCheckpoint(
        publisher: otherPublisher.id,
        expectedSequence: otherCatalog.sequence,
        bytes: (await shared.read(otherCatalog.path))!,
      ),
      publisherKey: otherPublisher.publicKey,
      directRoots: {parent},
    );
    var state = await library.load();
    final foreignId = state.mirrors.localIdFor(otherPublisher.id, parent)!;
    final foreignBefore = state.mirrors.owners[foreignId]!;

    final root = state.mirrors.localIdFor(identity.id, parent)!;
    final nested = state.mirrors.localIdFor(identity.id, child)!;
    var projection = BookmarkSeenProjection(state, BookmarkView.group(root));
    expect(projection.showFilter(BookmarkSeenFilter.all), isFalse);
    final entries = selectBookmarkGridEntries(
      state: state,
      view: BookmarkView.group(root),
      selectedTags: [],
      sortType: BookmarkSortType.newest,
    );
    expect(entries.whereType<BookmarkNativeGroupEntry>(), hasLength(1));
    expect(entries.every(projection.isUnseen), isTrue);
    await engine.markSeen(root, {
      syncBookmarkMemberKey(records.first),
      syncBookmarkMemberKey(workRecord),
    });
    state = await library.load();
    projection = BookmarkSeenProjection(state, BookmarkView.group(root));
    expect(projection.showFilter(BookmarkSeenFilter.all), isTrue);
    final visible = visibleBookmarkGridEntries(
      entries,
      entries
          .whereType<BookmarkPostEntry>()
          .map((entry) => entry.bookmark.post)
          .toList(),
    );
    final filtered = visible.entries
        .where((entry) => projection.includes(entry, BookmarkSeenFilter.unseen))
        .toList();
    expect(filtered, hasLength(4));
    for (final entry in filtered.whereType<BookmarkPostEntry>()) {
      expect(
        entries
            .whereType<BookmarkPostEntry>()
            .toList()[visible.postIndices[entry.key]!]
            .key,
        entry.key,
      );
    }
    final firstLocal = state.items.singleWhere(
      (record) =>
          syncBookmarkMemberKey(record) == syncBookmarkMemberKey(records.first),
    );
    final firstEntry = BookmarkPostEntry(firstLocal);
    expect(
      BookmarkSeenProjection(
        state,
        BookmarkView.group(nested),
      ).isUnseen(firstEntry),
      isTrue,
    );
    final collapsed = BookmarkSeenProjection(state, BookmarkView.subtree(root));
    expect(
      collapsed.isUnseen(firstEntry),
      isTrue,
      reason: 'Combined view must retain the child Unseen membership when the root is Seen',
    );
    expect(
      collapsed.target(firstEntry)!.groupId,
      root,
      reason: 'The first captured target retains the stable root occurrence',
    );
    final captured = collapsed.target(firstEntry)!;
    expect(captured.isCurrent(state), isTrue);
    expect(collapsed.includes(firstEntry, BookmarkSeenFilter.unseen), isTrue);
    expect(captured.allTargets.map((t) => t.groupId).toSet(), {root, nested});
    final beforeReadEpoch = state.mirrors.epoch;
    await engine.markSeenTargets([captured]);
    state = await library.load();
    expect(
      state.mirrors.owners[foreignId],
      foreignBefore,
      reason: 'The same Post in a separately signed publisher remains independently Unseen',
    );

    expect(
      state.mirrors.epoch,
      beforeReadEpoch + 1,
      reason: 'All represented reading writes share one journal commit',
    );
    for (final id in [root, nested]) {
      expect(
        SyncGroupSeenState.fromJson(state.mirrors.owners[id]!.reading)
            .unseenMembers,
        isNot(contains(captured.member)),
      );
    }
    expect(
      BookmarkSeenProjection(
        state,
        BookmarkView.subtree(root),
      ).isUnseen(firstEntry),
      isFalse,
    );

    expect(
      BookmarkSeenProjection(state, const BookmarkView.all()).targets,
      isEmpty,
    );
    final search = selectBookmarkGridEntries(
      state: state,
      view: BookmarkView.group(root),
      selectedTags: ['no-match'],
      sortType: BookmarkSortType.oldest,
    );
    expect(search, isEmpty);
    expect(
      projection.showFilter(BookmarkSeenFilter.all),
      isTrue,
      reason: 'Visibility is based on complete membership',
    );
    final restored = BookmarkLibraryState(
      bookmarks: state.items,
      groups: state.groups,
      records: state.records,
      mirrors: BookmarkMirrorState.fromJson(state.mirrors.toJson()),
    );
    expect(
      BookmarkSeenProjection(restored, BookmarkView.group(root)).unseenIds,
      projection.unseenIds,
    );
    await engine.unsubscribe(identity.id, child);
    expect(captured.isCurrent(await library.load()), isTrue);
    await engine.unsubscribe(identity.id, parent);
    expect(captured.isCurrent(await library.load()), isFalse);
  });

  test(
    'stale combined reading targets cannot follow reparented or changed owners',
    () async {
      final a = await publish(parent, [pageRecord]);
      final b = await publish(child, [pageRecord]);
      await engine.receive(
        ticket: await advertise(a, b),
        publisherKey: identity.publicKey,
        directRoots: {parent, child},
      );
      var state = await library.load();
      final root = state.mirrors.localIdFor(identity.id, parent)!;
      final nested = state.mirrors.localIdFor(identity.id, child)!;
      final key = syncBookmarkMemberKey(pageRecord);
      await engine.markSeen(root, {key});
      state = await library.load();
      final entry = BookmarkPostEntry(state.items.single);
      final captured = BookmarkSeenProjection(
        state,
        BookmarkView.subtree(root),
      ).target(entry)!;
      expect(
        BookmarkSeenProjection(
          state,
          BookmarkView.subtree(root),
        ).isUnseen(entry),
        isTrue,
      );
      expect(
        BookmarkSeenProjection(state, BookmarkView.group(root)).isUnseen(entry),
        isFalse,
      );
      await engine.receive(
        ticket: await advertise(a, b, siblings: true),
        publisherKey: identity.publicKey,
      );
      final before = await repository.readMirrorState();
      await engine.markSeenTargets([
        captured,
        BookmarkSeenTarget(
          groupId: nested,
          publisher: parent,
          source: child,
          member: key,
        ),
        BookmarkSeenTarget(
          groupId: nested,
          publisher: identity.id,
          source: parent,
          member: key,
        ),
      ]);
      expect(await repository.readMirrorState(), before);
      expect(
        SyncGroupSeenState.fromJson(before.owners[nested]!.reading)
            .unseenMembers,
        contains(key),
      );
    },
  );

  testManagementWidgets(
    'opening a received Group preserves its five Unseen members and badge through real providers',
    (tester) async {
      late MiteMiteService service;
      late ProviderContainer container;
      late String root;
      final preferences = _Store();
      await tester.runAsync(() async {
        final a = await publish(parent, fivePosts());
        final b = await publish(child, const []);
        await engine.receive(
          ticket: await advertise(a, b),
          publisherKey: identity.publicKey,
          directRoots: {parent},
        );
        root = (await repository.readMirrorState()).localIdFor(
          identity.id,
          parent,
        )!;
        service = MiteMiteService(
          preferences: preferences,
          store: repository,
          groups: groups,
          fs: const IoFileSystem(),
          codec: codec,
          storageFor: (_) async =>
              throw StateError('Opening a Group must not open Sync transport'),
          identity: await SyncSigningIdentity.create(),
          mutations: repository.coordinator,
          onApplied: () => container.read(bookmarkProvider.notifier).refresh(),
        );
      });
      addTearDown(service.dispose);
      final harness = await HeadlessAppHarness.mount(
        tester,
        viewportSize: const Size(390, 844),
        additionalOverrides: [
          deterministicImageDioOverride(),
          deterministicFaviconDioOverride(),
          bookmarkRepoProvider.overrideWith(
            (_) => Future.sync(() => repository),
          ),
          bookmarkGroupRepoProvider.overrideWith(
            (_) => Future.sync(() => groups),
          ),
          dataMutationCoordinatorProvider.overrideWithValue(
            repository.coordinator,
          ),
          miscDataStoreProvider.overrideWithValue(preferences),
          bookmarkUrlResolverProvider.overrideWith(
            (_, _) => const DefaultImageUrlResolver(),
          ),
          miteMiteServiceProvider.overrideWith(
            (_) => Future.sync(() => service),
          ),
        ],
      );
      await harness.settle(tester);
      final shortcut = find.byKey(const Key('nav-shortcut-bookmarks'));
      await tester.tap(
        shortcut.evaluate().isNotEmpty
            ? shortcut
            : find.text('Bookmarks').first,
      );
      await pumpIO(
        tester,
        () =>
            find.byKey(ValueKey(('bookmark-card', root))).evaluate().isNotEmpty,
      );
      container = ProviderScope.containerOf(
        tester.element(find.byType(BookmarkGroupBrowserPage).first),
      );
      final card = find.byKey(ValueKey(('bookmark-card', root)));
      expect(tester.widget<BookmarkLocalGroupCard>(card).unseenCount, 5);
      final before = container.read(bookmarkProvider).requireValue.mirrors;
      await tester.ensureVisible(card);
      await tester.tap(card);
      await harness.settle(tester);
      expect(find.byType(BookmarkGroupBrowserPage), findsOneWidget);
      expect(container.read(bookmarkProvider).requireValue.mirrors, before);
      final stored = await tester.runAsync(repository.readMirrorState);
      expect(
        stored,
        before,
        reason: 'Rendering a Group never acknowledges arrivals or marks Posts Seen.',
      );
      await tester.tap(find.byTooltip('Back').first);
      await harness.settle(tester);
      expect(tester.widget<BookmarkLocalGroupCard>(card).unseenCount, 5);
      var seen = false;
      final marking = service
          .markSeen(root, {syncBookmarkMemberKey(fivePosts().first)})
          .whenComplete(() => seen = true);
      await pumpIO(tester, () => seen);
      await marking;
      expect(tester.widget<BookmarkLocalGroupCard>(card).unseenCount, 4);
    },
  );

  testManagementWidgets(
    'trust-first Receive exposes only direct roots and updates Subscribe through real provider',
    (tester) async {
      late MiteMiteService service;
      late ProviderContainer container;
      await tester.runAsync(() async {
        final a = await publish(parent, [workRecord]);
        final b = await publish(child, [pageRecord]);
        await advertise(a, b, direct: {parent});
        final preferences = _Store();
        container = realContainer(preferences);
        await container.read(bookmarkProvider.future);
        service = MiteMiteService(
          preferences: preferences,
          store: repository,
          groups: groups,
          fs: const IoFileSystem(),
          codec: codec,
          storageFor: (path) async => DirectoryMiteMiteStorage(path),
          identity: await SyncSigningIdentity.create(),
          mutations: repository.coordinator,
          onApplied: container.read(bookmarkProvider.notifier).refresh,
        );
        await service.configure('${directory.path}/shared');
      });
      addTearDown(container.dispose);
      addTearDown(service.dispose);
      await tester.pumpWidget(
        managementApp(
          container,
          service,
          const MiteMitePage(section: 'receive'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('A'), findsNothing);
      expect(find.text('B'), findsNothing);
      expect(find.textContaining('ID: ${identity.id}'), findsNothing);
      expect(find.textContaining('Key Fingerprint:'), findsNothing);
      await tester.tap(find.text('Trust Device'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Trust Device'));
      await pumpIO(
        tester,
        () => !service.busy && service.gate.approvedKey(identity.id) != null,
      );
      expect(find.text('A'), findsOneWidget);
      expect(
        find.text('B'),
        findsNothing,
        reason: 'Inherited children are not independent offers',
      );
      await tester.tap(find.text('Subscribe'));
      await pumpIO(
        tester,
        () =>
            !service.busy &&
            container
                    .read(bookmarkProvider)
                    .valueOrNull
                    ?.mirrors
                    .owners
                    .length ==
                2,
      );
      expect(find.text('Unsubscribe'), findsOneWidget);
      expect(
        container.read(bookmarkProvider).requireValue.localRecords,
        isEmpty,
      );
      expect(service.events.pendingDiscoveries, hasLength(1));
    },
  );

  testManagementWidgets(
    'context Publish confirms one Group and management never lists unrelated or inherited Groups',
    (tester) async {
      late MiteMiteService service;
      late ProviderContainer container;
      late String target;
      await tester.runAsync(() async {
        final pathParent = await library.createGroup('Parent path');
        target = (await library.createGroupWithSavedRecords(
          'Publish this',
          [],
          parentGroupId: pathParent.id,
          drafts: [workRecord],
        )).group.id;
        await library.createGroupWithSavedRecords(
          'Inherited child',
          [],
          parentGroupId: target,
          drafts: [pageRecord],
        );
        await library.createGroupWithSavedRecords('Not published', []);
        final preferences = _Store();
        container = realContainer(preferences);
        await container.read(bookmarkProvider.future);
        service = MiteMiteService(
          preferences: preferences,
          store: repository,
          groups: groups,
          fs: const IoFileSystem(),
          codec: codec,
          storageFor: (path) async => DirectoryMiteMiteStorage(path),
          identity: await SyncSigningIdentity.create(),
          mutations: repository.coordinator,
          onApplied: container.read(bookmarkProvider.notifier).refresh,
        );
        await service.configure('${directory.path}/outgoing');
      });
      addTearDown(container.dispose);
      addTearDown(service.dispose);
      final trigger = Consumer(
        builder: (context, ref, _) => Scaffold(
          body: TextButton(
            onPressed: () => publishBookmarkGroup(context, ref, target),
            child: const Text('Publish target'),
          ),
        ),
      );
      await tester.pumpWidget(managementApp(container, service, trigger));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Publish target'));
      await pumpIO(
        tester,
        () => find.byType(KurumiDialog).evaluate().isNotEmpty,
      );
      expect(find.textContaining('Publish “Publish this”'), findsOneWidget);
      expect(service.publishedRoots, isEmpty);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(service.publishedRoots, isEmpty);
      await tester.tap(find.text('Publish target'));
      await pumpIO(
        tester,
        () => find.byType(KurumiDialog).evaluate().isNotEmpty,
      );
      await tester.tap(
        find.descendant(
          of: find.byType(KurumiDialog),
          matching: find.byType(FilledButton),
        ),
      );
      await pumpIO(
        tester,
        () => !service.busy && service.publishedRoots.contains(target),
      );
      expect(service.publishedRoots, {target});
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        managementApp(
          container,
          service,
          const MiteMitePage(section: 'publish'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byIcon(Symbols.bookmarks), findsOneWidget);
      expect(find.text('Parent path'), findsOneWidget);
      expect(find.text('Publish this'), findsOneWidget);
      expect(find.text('Inherited child'), findsNothing);
      expect(find.text('Not published'), findsNothing);
      expect(find.byIcon(Icons.upload), findsNothing);
      expect(find.byIcon(Icons.stop_circle_outlined), findsNothing);
      expect(find.textContaining('All children'), findsNothing);
      expect(find.text('Stop Publishing'), findsNothing);
      await tester.tap(find.byType(KurumiPopupMenuButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Stop Publishing'));
      await tester.pumpAndSettle();
      expect(service.publishedRoots, {target});
      await tester.tap(find.widgetWithText(FilledButton, 'Stop Publishing'));
      await pumpIO(
        tester,
        () => !service.busy && service.publishedRoots.isEmpty,
      );
      expect(find.textContaining('No collections published'), findsOneWidget);
      expect(
        container
            .read(bookmarkProvider)
            .requireValue
            .groupsById
            .containsKey(target),
        isTrue,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );

  test('empty publishers are discoverable and queued publish intents keep both roots', () async {
    final a = (await library.createGroupWithSavedRecords('A local', [])).group;
    final b = (await library.createGroupWithSavedRecords(
      'B local',
      [],
      parentGroupId: a.id,
    )).group;
    final service = MiteMiteService(
      preferences: _Store(),
      store: repository,
      groups: groups,
      fs: const IoFileSystem(),
      codec: codec,
      storageFor: (path) async => DirectoryMiteMiteStorage(path),
      identity: identity,
      mutations: repository.coordinator,
    );
    addTearDown(service.dispose);
    await service.configure('${directory.path}/intents');
    final storage = DirectoryMiteMiteStorage('${directory.path}/intents');
    Future<SyncCatalog> latest() async {
      final entries = await storage.list('devices/${identity.id}/catalog');
      final seq =
          entries.map((name) => int.parse(name.split('.').first)).toList()
            ..sort();
      final bytes = await storage.read(
        'devices/${identity.id}/catalog/${seq.last}.json',
      );
      return SyncCatalog.fromJson(
        await verifySyncDocument(bytes!, identity.publicKey),
      );
    }

    expect((await latest()).publicationRoots, isEmpty);
    await Future.wait([service.publishGroup(a.id), service.publishGroup(b.id)]);
    expect(service.publishedRoots, {a.id, b.id});
    var catalog = await latest();
    expect(catalog.publicationRoots, hasLength(2));
    expect(catalog.entries, hasLength(2));
    await service.stopPublishingGroup(b.id);
    catalog = await latest();
    expect(catalog.offeredEntries.map((e) => e.id.source), [a.id]);
    expect(
      catalog.entries.where((e) => e.state == SyncPublicationState.active),
      hasLength(2),
    );
    expect(service.hasUnpublishedChanges, isFalse);
  });

  test('local alias and reading state never change source-owned definition or trigger outgoing changes', () async {
    final a = await publish(parent, [workRecord]);
    final b = await publish(child, [pageRecord]);
    await engine.receive(
      ticket: await advertise(a, b),
      publisherKey: identity.publicKey,
      directRoots: {parent},
    );
    final before = await library.load();
    await engine.setAlias(identity.id, 'My sender');
    final root = before.mirrors.localIdFor(identity.id, parent)!;
    await engine.markSeen(
      root,
      SyncGroupSeenState.fromJson(before.mirrors.owners[root]!.reading).members,
    );
    final after = await library.load();
    expect(after.mirrors.aliases[identity.id], 'My sender');
    expect(after.groupsById[root]!.name, 'A');
    expect(hasLocalSyncChanges(before, after), isFalse);
    await library.createGroupWithSavedRecords('Independent local', []);
    expect(hasLocalSyncChanges(after, await library.load()), isTrue);
    await engine.setAlias(identity.id, '');
    expect((await library.load()).mirrors.aliases, isEmpty);
  });

  for (final width in [390.0, 1024.0]) {
    testWidgets(
      'system Back pops one Sync route in the production Settings shell ($width)',
      (tester) async {
        final service = MiteMiteService(
          preferences: _Store(),
          store: repository,
          groups: groups,
          fs: const IoFileSystem(),
          codec: codec,
          storageFor: (_) async =>
              throw StateError('Navigation must not open transport'),
          identity: identity,
          mutations: repository.coordinator,
        );
        addTearDown(service.dispose);
        final harness = await HeadlessAppHarness.mount(
          tester,
          viewportSize: Size(width, 844),
          additionalOverrides: [
            miteMiteServiceProvider.overrideWith(
              (_) => Future.sync(() => service),
            ),
          ],
        );
        await harness.settle(tester);
        final menu = find.byKey(const Key('nav-menu-toggle'));
        if (menu.evaluate().isNotEmpty) {
          await tester.tap(menu.first);
          await harness.settle(tester);
        }
        await tester.tap(find.text('Settings').last);
        await harness.settle(tester);
        await tester.ensureVisible(find.text('MiteMite').first);
        await tester.tap(find.text('MiteMite').first);
        await harness.settle(tester);
        for (final section in [
          'Published',
          'Subscriptions',
          'Devices',
          'Activity',
        ]) {
          await tester.ensureVisible(find.text(section));
          await tester.tap(find.text(section));
          await harness.settle(tester);
          expect(
            tester.widget<MiteMitePage>(find.byType(MiteMitePage)).section,
            isNotNull,
          );
          await tester.binding.handlePopRoute();
          await harness.settle(tester);
          expect(find.byType(MiteMitePage), findsOneWidget);
          expect(
            tester.widget<MiteMitePage>(find.byType(MiteMitePage)).section,
            isNull,
            reason: 'System Back must pop the actual nested route, not its Settings category',
          );
        }
        await tester.tap(find.byTooltip('Device Name'));
        await harness.settle(tester);
        expect(find.byType(TextField), findsOneWidget);
        await tester.binding.handlePopRoute();
        await harness.settle(tester);
        expect(find.byType(TextField), findsNothing);
        expect(find.byType(MiteMitePage), findsOneWidget);
        await tester.binding.handlePopRoute();
        await harness.settle(tester);
        expect(find.byType(MiteMitePage), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testManagementWidgets(
    'device alias actions fit at 320dp enlarged text with keyboard open',
    (tester) async {
      tester.view.physicalSize = const Size(640, 1280);
      tester.view.devicePixelRatio = 2;
      tester.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.view.resetViewInsets();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
      });
      late MiteMiteService service;
      late ProviderContainer container;
      await tester.runAsync(() async {
        final a = await publish(parent, [workRecord]);
        final b = await publish(child, [pageRecord]);
        await advertise(a, b, direct: {parent});
        final preferences = _Store();
        container = realContainer(preferences);
        await container.read(bookmarkProvider.future);
        service = MiteMiteService(
          preferences: preferences,
          store: repository,
          groups: groups,
          fs: const IoFileSystem(),
          codec: codec,
          storageFor: (path) async => DirectoryMiteMiteStorage(path),
          identity: await SyncSigningIdentity.create(),
          mutations: repository.coordinator,
          onApplied: container.read(bookmarkProvider.notifier).refresh,
        );
        await service.configure('${directory.path}/shared');
        await service.approve(service.devices.single);
      });
      addTearDown(container.dispose);
      addTearDown(service.dispose);
      await tester.pumpWidget(
        managementApp(
          container,
          service,
          const MiteMitePage(section: 'devices'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Edit'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      await tester.showKeyboard(find.byType(TextField));
      tester.view.viewInsets = const FakeViewPadding(bottom: 520);
      await tester.pumpAndSettle();
      final keyboardTop =
          (tester.view.physicalSize.height - tester.view.viewInsets.bottom) /
          tester.view.devicePixelRatio;
      for (final label in ['Save', 'Cancel']) {
        final button = find.text(label);
        await tester.ensureVisible(button);
        await tester.pumpAndSettle();
        expect(
          tester.getBottomRight(button).dy,
          lessThanOrEqualTo(keyboardTop),
          reason: '$label must be reachable above the keyboard',
        );
      }
      await tester.enterText(find.byType(TextField), 'Narrow alias');
      await tester.ensureVisible(find.text('Save'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await pumpIO(
        tester,
        () =>
            !service.busy &&
            service.receiverMirrors?.aliases[identity.id] == 'Narrow alias',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testManagementWidgets(
    'committed subscription stays truthful when production display reload fails and retries offline',
    (tester) async {
      late MiteMiteService service;
      late ProviderContainer container;
      var failReload = true;
      var offline = false;
      await tester.runAsync(() async {
        final a = await publish(parent, [workRecord]);
        final b = await publish(child, [pageRecord]);
        await advertise(a, b, direct: {parent});
        final preferences = _Store();
        container = realContainer(preferences);
        await container.read(bookmarkProvider.future);
        service = MiteMiteService(
          preferences: preferences,
          store: repository,
          groups: groups,
          fs: const IoFileSystem(),
          codec: codec,
          storageFor: (path) async {
            if (offline) {
              throw StateError(
                'Shared folder must not be used for display retry',
              );
            }
            return DirectoryMiteMiteStorage(path);
          },
          identity: await SyncSigningIdentity.create(),
          mutations: repository.coordinator,
          onApplied: () async {
            if (failReload) {
              throw StateError('Injected consumer reload failure');
            }
            await container.read(bookmarkProvider.notifier).refresh();
          },
        );
        await service.configure('${directory.path}/shared');
        await service.approve(service.devices.single);
      });
      addTearDown(container.dispose);
      addTearDown(service.dispose);
      await tester.pumpWidget(
        managementApp(
          container,
          service,
          const MiteMitePage(section: 'receive'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Subscribe'));
      await pumpIO(
        tester,
        () => !service.busy && service.receiverMirrors?.owners.length == 2,
      );
      expect(service.failure, isNull);
      expect(service.reloadFailure, isA<StateError>());
      expect(
        container.read(bookmarkProvider).requireValue.mirrors.owners,
        isEmpty,
      );
      expect(find.text('Unsubscribe'), findsOneWidget);
      expect(find.text('Unsubscribe'), findsOneWidget);
      expect(
        find.text('Changes saved; display refresh pending'),
        findsOneWidget,
      );
      expect(
        service.events.history.any(
          (event) => event.kind == SyncEventKind.subscribed,
        ),
        isTrue,
      );
      expect(
        service.events.history.where(
          (event) => event.kind == SyncEventKind.received,
        ),
        hasLength(2),
      );
      await tester.runAsync(() async {
        final rootId = service.receiverMirrors!.localIdFor(
          identity.id,
          parent,
        )!;
        await expectLater(
          groups.renameGroup(rootId, 'Cannot edit'),
          throwsA(anything),
        );
      });
      offline = true;
      failReload = false;
      await tester.tap(find.text('Retry'));
      await pumpIO(
        tester,
        () => !service.busy && service.reloadFailure == null,
      );
      expect(
        container.read(bookmarkProvider).requireValue.mirrors.owners,
        hasLength(2),
      );
      expect(find.text('Unsubscribe'), findsOneWidget);
      expect(find.text('Changes saved; display refresh pending'), findsNothing);
      expect(service.failure, isNull);
    },
  );

  test('production receive callback preserves mirror authority in the notifier', () async {
    final a = await publish(parent, [workRecord]);
    final b = await publish(child, [pageRecord]);
    await advertise(a, b);
    final container = ProviderContainer(
      overrides: [
        bookmarkRepoProvider.overrideWith((_) => Future.sync(() => repository)),
        bookmarkGroupRepoProvider.overrideWith(
          (_) => Future.sync(() => groups),
        ),
        dataMutationCoordinatorProvider.overrideWithValue(
          repository.coordinator,
        ),
        miscDataStoreProvider.overrideWithValue(gate.store),
        booruConfigProvider.overrideWith(
          () => BooruConfigNotifier(initialConfigs: []),
        ),
        settingsNotifierProvider.overrideWith(() => _SyncTestSettings()),
        bookmarkUrlResolverProvider.overrideWith(
          (_, _) => const DefaultImageUrlResolver(),
        ),
      ],
    );
    addTearDown(container.dispose);
    final notifier = container.read(bookmarkProvider.notifier);
    await notifier.future;
    final service = MiteMiteService(
      preferences: gate.store,
      store: repository,
      groups: groups,
      fs: const IoFileSystem(),
      codec: codec,
      storageFor: (path) async => DirectoryMiteMiteStorage(path),
      identity: await SyncSigningIdentity.create(),
      mutations: repository.coordinator,
      onApplied: notifier.refresh,
    );
    addTearDown(service.dispose);
    await service.configure('${directory.path}/shared');
    await service.subscribe(identity.id, {parent});
    final durable = await repository.readMirrorState();
    expect(durable.owners, hasLength(2));
    void expectAuthority() {
      final visible = container.read(bookmarkProvider).requireValue;
      expect(
        visible.mirrors,
        durable,
        reason:
            'Production onApplied must publish the freshly committed ownership',
      );
      expect(visible.bookmarkIdsForView(const BookmarkView.all()), isEmpty);
      expect(visible.mirrors.subscriptions[identity.id], {parent});
    }

    expectAuthority();
    await notifier.refresh();
    expectAuthority();
    await service.synchronize();
    expectAuthority();
    final rootId = durable.localIdFor(identity.id, parent)!;
    await expectLater(
      notifier.renameGroup(rootId, 'Must remain source-owned'),
      throwsA(anything),
    );
    expectAuthority();
    await service.unsubscribe(identity.id, parent);
    expect(
      container.read(bookmarkProvider).requireValue.mirrors.owners,
      isEmpty,
    );
  });

  test(
    'two independent Hive libraries exchange Groups without publication echoes',
    () async {
      final metadata = await Hive.openBox<dynamic>('device_b_metadata');
      final other = BookmarkHiveRepository(
        await Hive.openBox<BookmarkHiveObject>('device_b_posts'),
        groupPayloadBox: await Hive.openBox<dynamic>('device_b_payloads'),
        metadataBox: metadata,
        coordinator: DataMutationCoordinator(),
        postDataCodec: (_) => const PixivPostCodec(),
      );
      final reader = await BookmarkStorageMigration(
        bookmarks: other,
        legacyGroups: await Hive.openBox<BookmarkGroupHiveObject>(
          'device_b_legacy',
        ),
        legacyOrganization: await Hive.openBox<dynamic>('device_b_folders'),
        metadata: metadata,
      ).open();
      final otherGroups = UnifiedBookmarkGroupRepository(
        bookmarks: other,
        reader: reader,
      );
      final otherLibrary = BookmarkLibraryService(
        bookmarkRepository: other,
        groupRepository: otherGroups,
        imageUrlResolver: (_) => const DefaultImageUrlResolver(),
      );
      await otherLibrary.load();
      final ga = (await library.createGroupWithSavedRecords(
        'A local',
        const [],
        drafts: [workRecord],
      )).group;
      final gb = (await otherLibrary.createGroupWithSavedRecords(
        'B local',
        const [],
        drafts: [pageRecord],
      )).group;
      var seenProjections = 0;
      var fullProjections = 0;
      Future<MiteMiteService> device(
        BookmarkHiveRepository store,
        UnifiedBookmarkGroupRepository organization, {
        bool measureSeen = false,
      }) async => MiteMiteService(
        preferences: _Store(),
        store: store,
        groups: organization,
        fs: const IoFileSystem(),
        codec: codec,
        storageFor: (location) async => DirectoryMiteMiteStorage(location),
        identity: await SyncSigningIdentity.create(),
        mutations: store.coordinator,
        onApplied: measureSeen ? () async => fullProjections++ : null,
        onBookmarkSeenApplied: measureSeen
            ? (source, before, revision, snapshot) async {
                expect(source, same(store));
                expect(revision, before + 1);
                expect(snapshot, await store.readMirrorState());
                seenProjections++;
              }
            : null,
      );
      final a = await device(repository, groups);
      final b = await device(other, otherGroups, measureSeen: true);
      addTearDown(a.dispose);
      addTearDown(b.dispose);
      final path = '${directory.path}/two_devices';
      await a.configure(path, deviceName: 'Device A');
      await a.publishRoots({ga.id});
      await b.configure(path, deviceName: 'Device B');
      await b.publishRoots({gb.id});
      await a.synchronize();
      await a.approve(a.devices.single);
      await b.synchronize();
      await b.approve(b.devices.single);
      await a.subscribe(b.identity.id, {gb.id});
      await b.subscribe(a.identity.id, {ga.id});
      final sa = await library.load();
      var sb = await otherLibrary.load();
      expect(sa.mirrors.owners, hasLength(1));
      expect(sb.mirrors.owners, hasLength(1));
      expect(sa.records, hasLength(2));
      expect(sb.records, hasLength(2));
      expect(sa.bookmarkIdsForView(const BookmarkView.all()), ga.bookmarkIds);
      expect(sb.bookmarkIdsForView(const BookmarkView.all()), gb.bookmarkIds);
      final storage = DirectoryMiteMiteStorage(path);
      final ca = await storage.list('devices/${a.identity.id}/catalog');
      final cb = await storage.list('devices/${b.identity.id}/catalog');
      await a.synchronize();
      await b.synchronize();
      await a.synchronize();
      expect(await storage.list('devices/${a.identity.id}/catalog'), ca);
      expect(await storage.list('devices/${b.identity.id}/catalog'), cb);
      final received = sb.mirrors.localIdFor(a.identity.id, ga.id)!;
      final reading = SyncGroupSeenState.fromJson(
        sb.mirrors.owners[received]!.reading,
      );
      final owner = sb.mirrors.owners[received]!;
      expect(owner.bookmarkBucketManifest, isNotNull);
      fullProjections = 0;
      final targets = [
        for (final key in reading.members)
          BookmarkSeenTarget(
            groupId: received,
            publisher: a.identity.id,
            source: ga.id,
            member: key,
          ),
      ];
      await b.markSeenTargets(targets);
      await b.markSeenTargets(targets);
      final seen = (await other.readMirrorState()).owners[received]!;
      expect(seen.bookmarkBucketManifest, owner.bookmarkBucketManifest);
      expect(seen.descriptorDigest, owner.descriptorDigest);
      expect(seenProjections, 1);
      expect(fullProjections, 0);
      await b.synchronize();
      expect(fullProjections, 0);
      await groups.renameGroup(ga.id, 'A renamed');
      await a.synchronize(trigger: SyncTrigger.localChange);
      await b.synchronize();
      sb = await otherLibrary.load();
      expect(sb.groupsById[received]!.name, 'A renamed');
      expect(
        SyncGroupSeenState.fromJson(sb.mirrors.owners[received]!.reading)
            .seenMembers,
        reading.members,
      );
      final extra = (await library.createGroupWithSavedRecords(
        'Second root',
        const [],
        drafts: [workRecord],
      )).group;
      await repository.commitOrganization(
        groups: [
          (await groups.getGroup(ga.id))!.copyWith(parentGroupId: extra.id),
        ],
      );
      await a.publishRoots({ga.id, extra.id});
      await b.synchronize();
      await b.subscribe(a.identity.id, {extra.id});
      expect((await otherGroups.getGroup(received))!.parentGroupId, isNotNull);
      await b.unsubscribe(a.identity.id, extra.id);
      expect((await otherGroups.getGroup(received))!.parentGroupId, isNull);
      final retained = (await other.readMirrorState()).owners[received]!;
      expect(retained.bookmarkBucketManifest, owner.bookmarkBucketManifest);
      final cache = Directory(
        '${other.bookmarkPublicationIndexPath}.received/${a.identity.id}',
      );
      expect(Directory('${cache.path}/${extra.id}').existsSync(), isFalse);
      expect(Directory('${cache.path}/${ga.id}').existsSync(), isTrue);
      await b.forget(a.identity.id);
      expect(cache.existsSync(), isFalse);
    },
  );

  for (final rollbackTombstone in [false, true]) {
    test(
      'tombstones bind skipped source revisions (stale tombstone=$rollbackTombstone)',
      () async {
        final old = await publish(parent, [workRecord]);
        final b = await publish(child, [pageRecord]);
        await engine.receive(
          ticket: await advertise(old, b),
          publisherKey: identity.publicKey,
          directRoots: {parent},
        );
        final middle = await publish(parent, [workRecord, pageRecord]);
        if (rollbackTombstone) {
          await engine.receive(
            ticket: await advertise(middle, b),
            publisherKey: identity.publicKey,
          );
        }
        var latest = middle;
        for (var i = 0; i < 3; i++) {
          latest = await publish(parent, [workRecord, pageRecord]);
        }
        final sequence = await writer.sequences.reserve(identity.id);
        final tombstone = SyncCatalog(
          publisher: identity.id,
          sequence: sequence,
          name: 'Publisher',
          entries: [
            SyncCatalogEntry(
              id: old.collection,
              name: 'A',
              state: SyncPublicationState.deleted,
              revision: rollbackTombstone ? old : latest,
            ),
            SyncCatalogEntry(
              id: b.collection,
              name: 'B',
              state: SyncPublicationState.active,
              revision: b,
              parent: parent,
            ),
          ],
        );
        final ticket = await gate.verifyAndCheckpoint(
          publisher: identity.id,
          expectedSequence: sequence,
          bytes: await identity.sign(tombstone.toJson()),
        );
        final before = await repository.readMirrorState();
        if (rollbackTombstone) {
          await expectLater(
            engine.receive(ticket: ticket, publisherKey: identity.publicKey),
            throwsA(isA<SyncReplayRejected>()),
          );
          expect(await repository.readMirrorState(), before);
        } else {
          await engine.receive(
            ticket: ticket,
            publisherKey: identity.publicKey,
          );
          final after = await repository.readMirrorState();
          expect(after.owners, isEmpty);
          expect(
            after.checkpoints['${identity.id}/$parent']!.revision,
            latest.revision,
          );
          // Middle was never applied; it is still older than the signed deletion.
          final next = await writer.sequences.reserve(identity.id);
          final revived = SyncCatalog(
            publisher: identity.id,
            sequence: next,
            name: 'Publisher',
            entries: [
              SyncCatalogEntry(
                id: middle.collection,
                name: 'A',
                state: SyncPublicationState.active,
                revision: middle,
              ),
              SyncCatalogEntry(
                id: b.collection,
                name: 'B',
                state: SyncPublicationState.active,
                revision: b,
                parent: parent,
              ),
            ],
          );
          final retry = await gate.verifyAndCheckpoint(
            publisher: identity.id,
            expectedSequence: next,
            bytes: await identity.sign(revived.toJson()),
          );
          await expectLater(
            engine.receive(ticket: retry, publisherKey: identity.publicKey),
            throwsA(isA<SyncReplayRejected>()),
          );
          expect(await repository.readMirrorState(), after);
        }
      },
    );
  }

  testManagementWidgets(
    'foreground polling waits one minute and leaves unchanged management lists stable',
    (tester) async {
      final transport = _PollStorage(shared);
      late MiteMiteService service;
      late BookmarkLibraryState snapshot;
      await tester.runAsync(() async {
        service = MiteMiteService(
          preferences: _Store(),
          store: repository,
          groups: groups,
          fs: const IoFileSystem(),
          codec: codec,
          storageFor: (_) async => transport,
          identity: await SyncSigningIdentity.create(),
          mutations: repository.coordinator,
        );
        await service.configure('${directory.path}/shared');
        snapshot = await library.load();
      });
      addTearDown(service.dispose);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            miteMiteActivationProvider.overrideWith((_) => true),
            miteMiteServiceProvider.overrideWith(
              (_) => Future.sync(() => service),
            ),
            bookmarkProvider.overrideWith(() => _SnapshotLibrary(snapshot)),
            followingTopicsProvider.overrideWith(_EmptyFollowing.new),
            booruConfigProvider.overrideWith(
              () => BooruConfigNotifier(initialConfigs: []),
            ),
            appPlatformProvider.overrideWithValue(AppPlatform.android),
          ],
          child: const MiteMiteLifecycle(child: SizedBox()),
        ),
      );
      await pumpIO(
        tester,
        () => transport.polls >= 2 && !service.isReconciling,
      );
      var maintenanceDone = false;
      unawaited(
        service.maintenanceCompletion.whenComplete(
          () => maintenanceDone = true,
        ),
      );
      await pumpIO(tester, () => maintenanceDone);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(MiteMiteLifecycle)),
      );
      var changes = 0;
      final subscription = container.listen(
        miteMiteManagementViewProvider('publish'),
        (_, _) => changes++,
      );
      addTearDown(subscription.close);
      final before = transport.polls;
      await tester.pump(const Duration(seconds: 59));
      expect(transport.polls, before);
      await tester.pump(const Duration(seconds: 1));
      await pumpIO(
        tester,
        () => transport.polls == before + 1 && !service.isReconciling,
      );
      expect(
        changes,
        0,
        reason: 'Operational timestamps do not rebuild Published',
      );
    },
  );

  test(
    'overlapping update requests coalesce while transport is deferred',
    () async {
      final paused = _PausedStorage(shared);
      var hold = false;
      final service = MiteMiteService(
        preferences: gate.store,
        store: repository,
        groups: groups,
        fs: const IoFileSystem(),
        codec: codec,
        storageFor: (_) async => hold ? paused : shared,
        identity: await SyncSigningIdentity.create(),
        mutations: repository.coordinator,
      );
      addTearDown(service.dispose);
      await service.configure('${directory.path}/shared');
      hold = true;
      final first = service.synchronize();
      await paused.entered.future;
      final second = service.synchronize();
      final third = service.synchronize();
      try {
        expect(identical(first, second), isTrue);
        expect(identical(first, third), isTrue);
      } finally {
        paused.resume.complete();
        await Future.wait([first, second, third]);
      }
    },
  );

  test('local preferences finish during scan while targeted writes queue safely', () async {
    final a = await publish(parent, [workRecord]);
    final b = await publish(child, [pageRecord]);
    await advertise(a, b);
    final paused = _PausedStorage(shared);
    var hold = false;
    final service = MiteMiteService(
      preferences: gate.store,
      store: repository,
      groups: groups,
      fs: const IoFileSystem(),
      codec: codec,
      storageFor: (_) async => hold ? paused : shared,
      identity: await SyncSigningIdentity.create(),
      mutations: repository.coordinator,
    );
    addTearDown(service.dispose);
    await service.configure('${directory.path}/shared');
    await service.subscribe(identity.id, {parent});
    final before = await repository.readMirrorState();
    final copy = await service.localCopy(
      before.localIdFor(identity.id, parent)!,
    );
    await service.publishGroup(copy.id);
    hold = true;
    final scanning = service.synchronize();
    await paused.entered.future;
    var stopCompleted = false;
    final stopped = service
        .stopPublishingGroup(copy.id)
        .then((_) => stopCompleted = true);
    final subscribed = service.subscribe(identity.id, {child});
    try {
      expect(service.isReconciling, isTrue);
      expect(
        service.isActionPending('publication:bookmarks:${copy.id}'),
        isTrue,
      );
      expect(
        service.isActionPending('subscription:bookmarks:${identity.id}'),
        isTrue,
      );
      expect(service.isActionPending('alias:${identity.id}'), isFalse);
      await service
          .setDiscoveryNotifications(false)
          .timeout(const Duration(seconds: 30));
      expect(service.discoveryNotifications, isFalse);
      expect(paused.resume.isCompleted, isFalse);
      expect(stopCompleted, isFalse);
      expect(service.publishedRoots, contains(copy.id));
    } finally {
      paused.resume.complete();
      await Future.wait<Object?>([scanning, stopped, subscribed]);
    }
    expect(service.publishedRoots, isEmpty);
    expect(service.hasPendingActions, isFalse);
    expect(service.isReconciling, isFalse);
    final after = await repository.readMirrorState();
    expect(after.subscriptions[identity.id], {parent, child});
    expect(after.owners, before.owners);
    expect(
      service.events.history.where(
        (e) => e.kind == SyncEventKind.stopped && e.source == copy.id,
      ),
      hasLength(1),
    );
    // Opposing explicit device commands remain ordered, not coalesced together.
    final target = service.devices.singleWhere((d) => d.id == identity.id);
    await Future.wait([service.forget(identity.id), service.approve(target)]);
    expect(service.gate.approvedKey(identity.id), identity.publicKey);
    expect((await repository.readMirrorState()).owners, isEmpty);
    expect((await library.load()).groupsById, contains(copy.id));
  });

  for (final scale in [1.0, 2.0]) {
    testWidgets('device identity and relative details fit 320px at ${scale}x', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 1500);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final snapshot = (await tester.runAsync(library.load))!;
      final service = MiteMiteService(
        preferences: gate.store,
        store: repository,
        groups: groups,
        fs: const IoFileSystem(),
        codec: codec,
        storageFor: (_) async => throw StateError('UI must not open transport'),
        identity: identity,
        mutations: repository.coordinator,
      );
      addTearDown(service.dispose);
      final now = DateTime.utc(2026, 11, 15, 12);
      service.name = 'My device with a long personal alias';
      service.lastSuccess = now.subtract(const Duration(minutes: 12));
      service.lastSync = now.subtract(const Duration(minutes: 2));
      service.failure = const SyncConflict();
      final app = ProviderScope(
        overrides: [
          miteMiteServiceProvider.overrideWith(
            (_) => Future.sync(() => service),
          ),
          bookmarkProvider.overrideWith(() => _SnapshotLibrary(snapshot)),
        ],
        child: BooruLocalization(
          child: MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(scale),
              ),
              child: KurumiTheme(
                data: KurumiThemeData.fromMaterial(Theme.of(context)),
                child: child!,
              ),
            ),
            home: const MiteMitePage(),
          ),
        ),
      );
      await withClock(Clock.fixed(now), () async {
        await tester.pumpWidget(app);
        await tester.pumpAndSettle();
        expect(find.text('This Device'), findsOneWidget);
        expect(find.text(service.name), findsOneWidget);
        expect(find.text('Ready'), findsNothing);
        expect(find.text('Updating…'), findsNothing);
        expect(find.text('Last Updated'), findsNothing);
        expect(find.text('Last Attempt'), findsNothing);
        final update = find.byWidgetPredicate(
          (widget) => widget is IconButton && widget.tooltip == 'Update Now',
        );
        expect(
          find.descendant(of: find.byType(KurumiAppBar), matching: update),
          findsOneWidget,
        );
        expect(tester.widget<IconButton>(update).onPressed, isNull);
        expect(tester.getRect(update).right, lessThanOrEqualTo(320));
        final device = tester.widget<ListTile>(
          find.ancestor(
            of: find.text('This Device'),
            matching: find.byType(ListTile),
          ),
        );
        expect(
          device.title,
          isA<Text>().having((t) => t.data, 'title', 'This Device'),
        );
        expect(find.text(Translations().mitemite.conflict), findsOneWidget);
        await tester.ensureVisible(find.text('Device Details'));
        await tester.tap(find.text('Device Details'));
        await tester.pumpAndSettle();
        expect(find.text('Last Updated'), findsOneWidget);
        expect(find.text('Last Attempt'), findsOneWidget);
        expect(find.text('12 minutes ago'), findsOneWidget);
        expect(find.text('2 minutes ago'), findsOneWidget);
        expect(find.byType(MiteMiteRelativeDate), findsNWidgets(2));
        expect(service.lastSuccess, now.subtract(const Duration(minutes: 12)));
        expect(service.lastSync, now.subtract(const Duration(minutes: 2)));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      });
    });
  }

  testWidgets(
    'Activity dates refresh without transport or saved-event changes',
    (
      tester,
    ) async {
      final snapshot = (await tester.runAsync(library.load))!;
      final service = MiteMiteService(
        preferences: gate.store,
        store: repository,
        groups: groups,
        fs: const IoFileSystem(),
        codec: codec,
        storageFor: (_) async =>
            throw StateError('Dates must not open transport'),
        identity: identity,
        mutations: repository.coordinator,
      );
      addTearDown(service.dispose);
      var now = DateTime.utc(2026, 11, 15, 12);
      final event = SyncEvent(
        kind: SyncEventKind.failed,
        at: now.subtract(const Duration(minutes: 3)),
        sourceKind: 'retention',
        failure: SyncFailureKind.retryableIo,
      );
      await tester.runAsync(() => service.events.record(event));
      final before = service.events.history;
      await withClock(Clock(() => now), () async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              miteMiteServiceProvider.overrideWith(
                (_) => Future.sync(() => service),
              ),
              bookmarkProvider.overrideWith(() => _SnapshotLibrary(snapshot)),
            ],
            child: BooruLocalization(
              child: MaterialApp(
                builder: (context, child) => KurumiTheme(
                  data: KurumiThemeData.fromMaterial(Theme.of(context)),
                  child: child!,
                ),
                home: const MiteMitePage(section: 'activity'),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.textContaining('3 minutes ago'), findsOneWidget);
        expect(find.text('Storage Maintenance Pending'), findsOneWidget);
        expect(
          find.textContaining(event.at.toLocal().toString()),
          findsNothing,
        );
        now = now.add(const Duration(minutes: 2));
        await tester.pump(const Duration(minutes: 1));
        expect(find.textContaining('5 minutes ago'), findsOneWidget);
        expect(
          find.textContaining(Translations().mitemite.storage_failed),
          findsOneWidget,
        );
        expect(service.events.history, before);
        expect(service.lastSync, isNull);
        await tester.pumpWidget(const SizedBox());
      });
    },
  );

  test('collection aliases preserve canonical data, overlap and offline restart, then prune only removed owners', () async {
    final a = await publish(parent, [workRecord]);
    final b = await publish(child, [pageRecord]);
    await advertise(a, b);
    final receiver = await SyncSigningIdentity.create();
    var offline = false;
    var opens = 0;
    MiteMiteService create() => MiteMiteService(
      preferences: gate.store,
      store: repository,
      groups: groups,
      fs: const IoFileSystem(),
      codec: codec,
      identity: receiver,
      mutations: repository.coordinator,
      storageFor: (_) async {
        opens++;
        if (offline) throw StateError('offline');
        return shared;
      },
    );
    var service = create();
    addTearDown(() => service.dispose());
    await service.configure('${directory.path}/shared');
    await service.subscribe(identity.id, {parent, child});
    final parentId = a.collection;
    final childId = b.collection;
    final before = await library.load();
    final localChild = before.mirrors.localIdFor(identity.id, child)!;
    final opened = opens;
    final history = service.events.history;
    await service.setCollectionAlias(parentId, 'My parent');
    await service.setCollectionAlias(childId, '  My child  ');
    expect(opens, opened);
    expect(service.events.history, history);
    expect(await repository.readMirrorState(), before.mirrors);
    expect((await library.load()).groupsById[localChild]!.name, 'B');
    expect(service.hasUnpublishedChanges, isFalse);
    await advertise(a, b, childName: 'Latest source name', siblings: true);
    await service.synchronize();
    expect(service.collectionAliases[childId], 'My child');
    final after = await library.load();
    expect(after.groupsById[localChild]!.name, 'Latest source name');
    expect(
      after.mirrors.owners[localChild]!.reading,
      before.mirrors.owners[localChild]!.reading,
    );
    final copy = await service.localCopy(localChild);
    expect(copy.name, contains('Latest source name'));
    expect(copy.name, isNot(contains('My child')));
    await expectLater(
      service.setCollectionAlias(
        SyncCollectionId(
          publisher: identity.id,
          kind: 'bookmarks',
          source: copy.id,
        ),
        'Wrong',
      ),
      throwsA(isA<SyncConflict>()),
    );
    offline = true;
    await service.setCollectionAlias(childId, 'Offline child');
    await expectLater(service.synchronize(), throwsStateError);
    expect(service.collectionAliases[childId], 'Offline child');
    service.dispose();
    service = create();
    expect(service.collectionAliases[childId], 'Offline child');
    await service.unsubscribe(identity.id, parent);
    expect(service.collectionAliases.containsKey(parentId), isFalse);
    expect(service.collectionAliases[childId], 'Offline child');
    await service.unsubscribe(identity.id, child);
    expect(service.collectionAliases, isEmpty);
    expect((await library.load()).groupsById, contains(copy.id));
    offline = false;
    await service.synchronize();
    await service.subscribe(identity.id, {parent});
    await service.setCollectionAlias(parentId, 'Forgotten');
    await service.forget(identity.id);
    expect(service.collectionAliases, isEmpty);
    await expectLater(
      service.setCollectionAlias(parentId, 'Untrusted'),
      throwsA(isA<SyncTrustRequired>()),
    );
  });

  testManagementWidgets(
    'Subscriptions keeps other Group buttons enabled while individual actions queue',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 900);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final entered = [Completer<void>(), Completer<void>()];
      final resume = [Completer<void>(), Completer<void>()];
      var hold = false;
      var opens = 0;
      late MiteMiteService service;
      late ProviderContainer container;
      await tester.runAsync(() async {
        final a = await publish(parent, [workRecord]);
        final b = await publish(child, [pageRecord]);
        await advertise(a, b, siblings: true);
        container = realContainer(gate.store);
        await container.read(bookmarkProvider.future);
        service = MiteMiteService(
          preferences: gate.store,
          store: repository,
          groups: groups,
          fs: const IoFileSystem(),
          codec: codec,
          storageFor: (_) async {
            if (hold) {
              final index = opens++;
              entered[index].complete();
              await resume[index].future;
            }
            return shared;
          },
          identity: await SyncSigningIdentity.create(),
          mutations: repository.coordinator,
          onApplied: () => container.read(bookmarkProvider.notifier).refresh(),
        );
        await service.configure('${directory.path}/shared');
        hold = true;
      });
      addTearDown(service.dispose);
      addTearDown(container.dispose);
      Finder button(String source) => find.descendant(
        of: find.byKey(ValueKey('sync-subscription:${identity.id}/$source')),
        matching: find.byType(TextButton),
      );
      try {
        await tester.pumpWidget(
          managementApp(
            container,
            service,
            const MiteMitePage(section: 'receive'),
          ),
        );
        await pumpIO(tester, () => button(parent).evaluate().isNotEmpty);
        await tester.ensureVisible(button(parent));
        await tester.tap(button(parent));
        await pumpIO(tester, () => entered[0].isCompleted, settle: false);
        expect(tester.widget<TextButton>(button(parent)).onPressed, isNotNull);
        expect(
          tester.widget<TextButton>(button(parent)).child,
          isA<Text>().having((t) => t.data, 'label', 'Cancel'),
        );
        expect(tester.widget<TextButton>(button(child)).onPressed, isNotNull);
        expect(
          tester.widget<TextButton>(button(child)).child,
          isA<Text>().having((t) => t.data, 'label', 'Subscribe'),
        );
        await tester.ensureVisible(button(child));
        await tester.tap(button(child));
        await tester.pump();
        expect(tester.widget<TextButton>(button(child)).onPressed, isNotNull);
        expect(
          entered[1].isCompleted,
          isFalse,
          reason: 'The second click queues behind the existing write lock',
        );
        resume[0].complete();
        await pumpIO(tester, () => entered[1].isCompleted, settle: false);
        expect(tester.widget<TextButton>(button(parent)).onPressed, isNotNull);
        expect(tester.widget<TextButton>(button(child)).onPressed, isNotNull);
        resume[1].complete();
        await pumpIO(tester, () => !service.hasPendingActions);
        final state = (await tester.runAsync(repository.readMirrorState))!;
        expect(state.subscriptions[identity.id], {parent, child});
        expect(tester.takeException(), isNull);
      } finally {
        for (final gate in resume) {
          if (!gate.isCompleted) gate.complete();
        }
        await pumpIO(tester, () => !service.hasPendingActions);
      }
    },
  );

  testWidgets(
    'management remains interactive through ten seconds of deferred scan',
    (tester) async {
      late _PausedStorage paused;
      late MiteMiteService service;
      late BookmarkLibraryState snapshot;
      late Future<void> updating;
      await tester.runAsync(() async {
        final a = await publish(parent, [workRecord]);
        final b = await publish(child, [pageRecord]);
        await advertise(a, b);
        paused = _PausedStorage(shared);
        var hold = false;
        service = MiteMiteService(
          preferences: gate.store,
          store: repository,
          groups: groups,
          fs: const IoFileSystem(),
          codec: codec,
          storageFor: (_) async => hold ? paused : shared,
          identity: await SyncSigningIdentity.create(),
          mutations: repository.coordinator,
        );
        addTearDown(service.dispose);
        await service.configure('${directory.path}/shared');
        await service.subscribe(identity.id, {parent});
        snapshot = await library.load();
        hold = true;
        updating = service.synchronize();
        await paused.entered.future;
      });
      Widget app(String? section) => ProviderScope(
        overrides: [
          miteMiteServiceProvider.overrideWith(
            (_) => Future.sync(() => service),
          ),
          bookmarkProvider.overrideWith(() => _SnapshotLibrary(snapshot)),
        ],
        child: BooruLocalization(
          child: MaterialApp(
            key: ValueKey(section),
            builder: (context, child) => KurumiTheme(
              data: KurumiThemeData.fromMaterial(Theme.of(context)),
              child: child!,
            ),
            home: MiteMitePage(section: section),
          ),
        ),
      );
      try {
        await tester.pumpWidget(app(null));
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pump(const Duration(seconds: 10));
        expect(find.text('This Device'), findsOneWidget);
        expect(find.text('Ready'), findsNothing);
        expect(find.text('Updating…'), findsNothing);
        final update = find.byWidgetPredicate(
          (widget) => widget is IconButton && widget.tooltip == 'Update Now',
        );
        expect(
          find.descendant(of: find.byType(KurumiAppBar), matching: update),
          findsOneWidget,
        );
        expect(tester.widget<IconButton>(update).onPressed, isNotNull);
        await tester.tap(update);
        await tester.pump(const Duration(milliseconds: 400));
        expect(paused.resume.isCompleted, isFalse);
        final naming = find.byWidgetPredicate(
          (w) => w is IconButton && w.tooltip == 'Device Name',
        );
        expect(tester.widget<IconButton>(naming).onPressed, isNotNull);
        await tester.tap(naming);
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.text('Device Name'), findsWidgets);
        expect(find.byType(TextField), findsOneWidget);
        await tester.enterText(find.byType(TextField), 'Cancelled During Scan');
        await tester.tap(find.text('Cancel'));
        await tester.pump(const Duration(milliseconds: 400));
        expect(service.name, 'Boorusama');
        expect(paused.resume.isCompleted, isFalse);
        await tester.tap(find.text('Device Details'));
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.text(service.identity.id), findsOneWidget);
        for (final section in ['publish', 'receive', 'devices']) {
          await tester.pumpWidget(app(section));
          await tester.pump(const Duration(milliseconds: 400));
          expect(find.text('Updating…'), findsNothing);
          if (section == 'receive') {
            expect(find.widgetWithText(TextButton, 'Edit'), findsNothing);
            expect(find.text('Forget Device'), findsNothing);
            expect(find.byType(SelectableText), findsNothing);
          }
          if (section == 'devices') {
            final edit = find.widgetWithText(TextButton, 'Edit');
            await tester.ensureVisible(edit);
            expect(tester.widget<TextButton>(edit).onPressed, isNotNull);
            await tester.tap(edit);
            await tester.pump(const Duration(milliseconds: 400));
            expect(find.text('Device Alias'), findsOneWidget);
            await tester.tap(find.text('Cancel'));
            await tester.pump(const Duration(milliseconds: 400));
          }
          expect(paused.resume.isCompleted, isFalse);
        }
        expect(tester.takeException(), isNull);
      } finally {
        paused.resume.complete();
        await tester.runAsync(() => updating);
        await tester.pumpWidget(const SizedBox());
      }
    },
  );

  testWidgets(
    'setup entry and device naming fit narrow enlarged text with keyboard',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 760);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final state = (await tester.runAsync(library.load))!;
      final service = MiteMiteService(
        preferences: gate.store,
        store: repository,
        groups: groups,
        fs: const IoFileSystem(),
        codec: codec,
        storageFor: (_) async =>
            throw StateError('Opening UI must not access transport'),
        identity: identity,
        mutations: repository.coordinator,
      );
      addTearDown(service.dispose);
      Widget app(String? section) => ProviderScope(
        overrides: [
          miteMiteServiceProvider.overrideWith(
            (_) => Future.sync(() => service),
          ),
          bookmarkProvider.overrideWith(() => _SnapshotLibrary(state)),
        ],
        child: BooruLocalization(
          child: MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(1.7)),
              child: KurumiTheme(
                data: KurumiThemeData.fromMaterial(Theme.of(context)),
                child: child!,
              ),
            ),
            home: MiteMitePage(section: section),
          ),
        ),
      );
      await tester.pumpWidget(app('publish'));
      await tester.pumpAndSettle();
      expect(
        find.text(Translations().mitemite.choose_folder),
        findsOneWidget,
      );
      expect(service.configured, isFalse);
      expect(service.failure, isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(app(null));
      await tester.pumpAndSettle();
      final fingerprint = syncDigest(service.identity.publicKey);
      expect(find.text(fingerprint), findsNothing);
      expect(find.text(service.identity.id), findsNothing);
      await tester.ensureVisible(find.text('Device Details'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Device Details'));
      await tester.pumpAndSettle();
      expect(find.text(fingerprint), findsOneWidget);
      expect(find.text('Last Updated'), findsOneWidget);
      expect(find.text('Last Attempt'), findsOneWidget);
      expect(find.text('Never'), findsNWidgets(2));
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      final copyId = find.byTooltip('Copy: ID');
      await tester.ensureVisible(copyId);
      await tester.pumpAndSettle();
      await tester.tap(copyId);
      await tester.pump();
      expect(copied, service.identity.id);
      await tester.ensureVisible(find.text('Device Details'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Device Details'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byTooltip(Translations().mitemite.device_name),
        -250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip(Translations().mitemite.device_name));
      await tester.pumpAndSettle();
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      await tester.enterText(find.byType(TextField), 'My local device');
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text(Translations().generic.action.save));
      final renamed = Completer<void>();
      void changed() {
        if (service.name == 'My local device' &&
            !service.busy &&
            !renamed.isCompleted) {
          renamed.complete();
        }
      }

      service.addListener(changed);
      await tester.tap(find.text(Translations().generic.action.save));
      await tester.pumpAndSettle();
      // Hive's coordinator was opened outside FakeAsync. Alternate event-loop
      // completion and frame pumping until both scheduler domains are drained.
      for (var turn = 0; turn < 100 && !renamed.isCompleted; turn++) {
        await tester.runAsync(() => Future<void>(() {}));
        await tester.pump();
      }
      expect(
        renamed.isCompleted,
        isTrue,
        reason: 'Save must complete its coordinated preference write',
      );
      service.removeListener(changed);
      tester.view.resetViewInsets();
      await tester.pumpAndSettle();
      expect(service.name, 'My local device');
      expect(find.text('This Device'), findsOneWidget);
      expect(find.text('My local device'), findsOneWidget);
      expect(service.configured, isFalse);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  test(
    'Subscribe only adds roots even when a caller supplies a stale subset',
    () async {
      final a = await publish(parent, [workRecord]);
      final b = await publish(child, [pageRecord]);
      final ticket = await advertise(a, b);
      await engine.receive(
        ticket: ticket,
        publisherKey: identity.publicKey,
        directRoots: {parent},
      );
      final before = await repository.readMirrorState();
      await engine.receive(
        ticket: ticket,
        publisherKey: identity.publicKey,
        directRoots: {child},
      );
      final after = await repository.readMirrorState();
      expect(after.subscriptions[identity.id], {parent, child});
      expect(
        after.localIdFor(identity.id, parent),
        before.localIdFor(identity.id, parent),
      );
      expect(after.owners, hasLength(2));
    },
  );

  test('source revision high-water survives unsubscribe and rejects resurrection rollback', () async {
    final a = await publish(parent, [workRecord]);
    final b = await publish(child, [pageRecord]);
    await engine.receive(
      ticket: await advertise(a, b),
      publisherKey: identity.publicKey,
      directRoots: {parent},
    );
    final newer = await publish(parent, [workRecord, pageRecord]);
    await engine.receive(
      ticket: await advertise(newer, b),
      publisherKey: identity.publicKey,
    );
    await engine.unsubscribe(identity.id, parent);
    final before = await repository.readMirrorState();
    expect(before.owners, isEmpty);
    expect(
      before.checkpoints['${identity.id}/$parent']!.revision,
      newer.revision,
    );
    final sequence = await writer.sequences.reserve(identity.id);
    final stale = SyncCatalog(
      publisher: identity.id,
      sequence: sequence,
      name: 'Publisher',
      entries: [
        SyncCatalogEntry(
          id: a.collection,
          name: 'A',
          state: SyncPublicationState.active,
          revision: a,
        ),
        SyncCatalogEntry(
          id: b.collection,
          name: 'B',
          state: SyncPublicationState.active,
          revision: b,
          parent: parent,
        ),
      ],
    );
    final ticket = await gate.verifyAndCheckpoint(
      publisher: identity.id,
      expectedSequence: sequence,
      bytes: await identity.sign(stale.toJson()),
    );
    await expectLater(
      engine.receive(
        ticket: ticket,
        publisherKey: identity.publicKey,
        directRoots: {parent},
      ),
      throwsA(isA<SyncReplayRejected>()),
    );
    expect(await repository.readMirrorState(), before);
  });

  test(
    'disposed service cannot apply a transport scan after replacement',
    () async {
      final a = await publish(parent, [workRecord]);
      final b = await publish(child, [pageRecord]);
      await advertise(a, b);
      final receiver = await SyncSigningIdentity.create();
      final paused = _PausedStorage(shared);
      var reloads = 0;
      MiteMiteService service(MiteMiteStorage storage) => MiteMiteService(
        preferences: gate.store,
        store: repository,
        groups: groups,
        fs: const IoFileSystem(),
        codec: codec,
        storageFor: (_) async => storage,
        identity: receiver,
        mutations: repository.coordinator,
        onApplied: () async {
          reloads++;
        },
      );
      final old = service(paused);
      final pending = old.configure('${directory.path}/shared');
      final rejected = expectLater(pending, throwsStateError);
      await paused.entered.future;
      old.dispose();
      final replacement = service(shared);
      addTearDown(replacement.dispose);
      paused.resume.complete();
      await rejected;
      expect(reloads, 0);
      expect((await repository.readMirrorState()).owners, isEmpty);
      await replacement.synchronize();
      expect(replacement.devices.single.id, identity.id);
    },
  );

  test('overlap, offline unsubscribe, independent reading, local copy and Forget preserve ownership', () async {
    final a = await publish(parent, [workRecord]);
    final b = await publish(child, [workRecord, pageRecord]);
    final ticket = await advertise(a, b);
    await engine.receive(
      ticket: ticket,
      publisherKey: identity.publicKey,
      directRoots: {child},
    );
    var state = await library.load();
    final bId = state.mirrors.localIdFor(identity.id, child)!;
    expect(bId, isNot(child));
    expect(state.localBookmarkIds, isEmpty);
    await engine.receive(
      ticket: ticket,
      publisherKey: identity.publicKey,
      directRoots: {parent, child},
    );
    state = await library.load();
    final aId = state.mirrors.localIdFor(identity.id, parent)!;
    expect(state.mirrors.owners, hasLength(2));
    expect(state.records, hasLength(2));
    expect(state.groupsById[bId]!.parentGroupId, aId);
    expect(state.mirrors.subscriptions[identity.id], {parent, child});
    final before = SyncGroupSeenState.fromJson(
      state.mirrors.owners[bId]!.reading,
    );
    await engine.acknowledgeArrival(bId, before.revision);
    var reading = SyncGroupSeenState.fromJson(
      (await repository.readMirrorState()).owners[bId]!.reading,
    );
    expect(reading.arrivals, isEmpty);
    expect(reading.unseenMembers, hasLength(2));
    await engine.markSeen(bId, {reading.members.first});
    reading = SyncGroupSeenState.fromJson(
      (await repository.readMirrorState()).owners[bId]!.reading,
    );
    expect(reading.unseenMembers, hasLength(1));
    expect(
      SyncGroupSeenState.fromJson(
        (await repository.readMirrorState()).owners[aId]!.reading,
      ).unseenMembers,
      hasLength(1),
    );
    await engine.unsubscribe(identity.id, child);
    expect((await library.load()).groupsById[bId]!.parentGroupId, aId);
    await engine.receive(
      ticket: ticket,
      publisherKey: identity.publicKey,
      directRoots: {parent, child},
    );
    await engine.unsubscribe(identity.id, parent);
    state = await library.load();
    expect(state.mirrors.owners.keys, {bId});
    expect(state.groupsById[bId]!.parentGroupId, isNull);
    final copy = await engine.createLocalCopy(bId);
    await groups.renameGroup(copy.id, 'Editable copy');
    await engine.forgetDevice(identity.id);
    state = await library.load();
    expect(state.mirrors.owners, isEmpty);
    expect(state.groupsById[copy.id]!.name, 'Editable copy');
    expect(
      state.bookmarkIdsForView(const BookmarkView.all()),
      copy.bookmarkIds,
    );
    expect(state.records, hasLength(2));
  });

  test('missing new payload and stale prepared catalog never delete usable mirrors', () async {
    final a = await publish(parent, [workRecord]);
    final b = await publish(child, [workRecord, pageRecord]);
    final first = await advertise(a, b);
    await engine.receive(
      ticket: first,
      publisherKey: identity.publicKey,
      directRoots: {parent},
    );
    final before = await repository.readMirrorState();
    final updated = await publish(child, [pageRecord]);
    final newer = await advertise(a, updated);
    final path = File('${shared.root.path}/${updated.payloadPath}');
    final bytes = await path.readAsBytes();
    await path.delete();
    await expectLater(
      engine.receive(ticket: newer, publisherKey: identity.publicKey),
      throwsA(isA<SyncRevisionUnavailable>()),
    );
    expect(await repository.readMirrorState(), before);
    await expectLater(
      engine.receive(ticket: first, publisherKey: identity.publicKey),
      throwsA(isA<SyncReplayRejected>()),
    );
    expect(await repository.readMirrorState(), before);
    await path.writeAsBytes(bytes);
    await engine.receive(ticket: newer, publisherKey: identity.publicKey);
    final state = await library.load();
    expect(state.records, hasLength(2));
    expect(
      state
          .groupsById[state.mirrors.localIdFor(identity.id, child)]!
          .bookmarkIds,
      hasLength(1),
    );
  });

  const unsupportedBookmarkSchema = kBookmarksBackupVersion + 1;
  for (final schema in [
    kRemoteBookmarksBackupVersion,
    kBookmarksBackupVersion,
    unsupportedBookmarkSchema,
  ]) {
    test(
      'same applied bytes cannot bypass schema or descriptor checks: $schema',
      () async {
        final a = await publish(parent, [workRecord]);
        final b = await publish(child, [pageRecord]);
        final first = await advertise(a, b);
        await engine.receive(
          ticket: first,
          publisherKey: identity.publicKey,
          directRoots: {parent},
        );
        final before = await repository.readMirrorState();
        final changed = SyncRevision.fromJson({
          ...b.toJson(),
          'schema': schema,
          'semanticHash': 'f' * 64,
        });
        final catalog = SyncCatalog(
          publisher: identity.id,
          sequence: await writer.sequences.reserve(identity.id),
          name: 'Publisher',
          entries: [
            SyncCatalogEntry(
              id: a.collection,
              name: 'A',
              state: SyncPublicationState.active,
              revision: a,
            ),
            SyncCatalogEntry(
              id: b.collection,
              name: 'Changed',
              parent: parent,
              state: SyncPublicationState.active,
              revision: changed,
            ),
          ],
        );
        final bytes = await identity.sign(catalog.toJson());
        final ticket = await gate.verifyAndCheckpoint(
          publisher: identity.id,
          expectedSequence: catalog.sequence,
          bytes: bytes,
        );
        await expectLater(
          engine.receive(ticket: ticket, publisherKey: identity.publicKey),
          throwsA(
            schema == unsupportedBookmarkSchema
                ? isA<SyncUpdateRequired>()
                : isA<SyncReplayRejected>(),
          ),
        );
        expect(await repository.readMirrorState(), before);
      },
    );
  }

  test('a new cross-root member enlarges the atomic unit before shared snapshot metadata can change', () async {
    final a = await publish(parent, []);
    final b = await publish(child, [pageRecord]);
    await engine.receive(
      ticket: await advertise(a, b, siblings: true),
      publisherKey: identity.publicKey,
      directRoots: {parent, child},
    );
    final before = await repository.readMirrorState();
    final beforeRecord = (await library.load()).items.single;
    final access = workAccess();
    final changed = PixivPageBookmarkTarget(
      access: access,
      post: (pageRecord as PostBookmark).post.withDetailFacts(
        const PostDetailFacts(description: 'Coupled update'),
      ),
    ).draft(currentAccess: access, at: at).copyWith(id: 1);
    final nextA = await publish(parent, [changed]);
    final nextB = await publish(child, [changed]);
    final ticket = await advertise(nextA, nextB, siblings: true);
    final bytes = (await shared.read(nextB.payloadPath))!;
    await shared.deleteOwnedRevision(nextB.payloadPath, owner: identity.id);
    await expectLater(
      engine.receive(ticket: ticket, publisherKey: identity.publicKey),
      throwsA(anything),
    );
    expect(await repository.readMirrorState(), before);
    expect(
      (await library.load()).items.single.post.detailFacts.description,
      beforeRecord.post.detailFacts.description,
    );
    final root = (await groups.getGroups()).singleWhere(
      (group) => group.id == before.localIdFor(identity.id, parent),
    );
    expect(root.bookmarkIds, isEmpty);
    await shared.writeImmutable(nextB.payloadPath, bytes);
    await engine.receive(ticket: ticket, publisherKey: identity.publicKey);
    final after = await library.load();
    expect(after.items.single.id, beforeRecord.id);
    expect(after.items.single.post.detailFacts.description, 'Coupled update');
    expect(
      (await groups.getGroups())
          .singleWhere((group) => group.id == root.id)
          .bookmarkIds,
      {beforeRecord.id},
    );
  });

  test('signed newer snapshot refreshes received-only content with stable local identity', () async {
    final a = await publish(parent, [workRecord]);
    final b = await publish(child, [pageRecord]);
    await engine.receive(
      ticket: await advertise(a, b),
      publisherKey: identity.publicKey,
      directRoots: {child},
    );
    final before = (await library.load()).items.single;
    final access = workAccess();
    final changed = PixivPageBookmarkTarget(
      access: access,
      post: (pageRecord as PostBookmark).post.withDetailFacts(
        const PostDetailFacts(description: 'Updated source snapshot'),
      ),
    ).draft(currentAccess: access, at: at).copyWith(id: 1);
    final next = await publish(child, [changed]);
    await engine.receive(
      ticket: await advertise(a, next),
      publisherKey: identity.publicKey,
    );
    final after = (await library.load()).items.single;
    expect(after.id, before.id);
    expect(after.post.detailFacts.description, 'Updated source snapshot');
  });

  test(
    'verified deleted tombstone removes only uncovered mirror data',
    () async {
      final a = await publish(parent, [workRecord]);
      final b = await publish(child, [pageRecord]);
      await engine.receive(
        ticket: await advertise(a, b),
        publisherKey: identity.publicKey,
        directRoots: {parent, child},
      );
      final childId = (await repository.readMirrorState()).localIdFor(
        identity.id,
        child,
      );
      await engine.receive(
        ticket: await advertise(
          a,
          b,
          parentState: SyncPublicationState.deleted,
        ),
        publisherKey: identity.publicKey,
      );
      final state = await library.load();
      expect(state.mirrors.owners.keys, {childId});
      expect(state.records, hasLength(1));
      final sequence = await writer.sequences.reserve(identity.id);
      final stale = SyncCatalog(
        publisher: identity.id,
        sequence: sequence,
        name: 'Publisher',
        entries: [
          SyncCatalogEntry(
            id: a.collection,
            name: 'A',
            state: SyncPublicationState.active,
            revision: a,
          ),
          SyncCatalogEntry(
            id: b.collection,
            name: 'B',
            state: SyncPublicationState.active,
            revision: b,
            parent: parent,
          ),
        ],
      );
      final ticket = await gate.verifyAndCheckpoint(
        publisher: identity.id,
        expectedSequence: sequence,
        bytes: await identity.sign(stale.toJson()),
      );
      await expectLater(
        engine.receive(ticket: ticket, publisherKey: identity.publicKey),
        throwsA(isA<SyncReplayRejected>()),
      );
      expect(await repository.readMirrorState(), state.mirrors);
    },
  );

  test(
    'discovery, trusted subscription and relocation use real repositories',
    () async {
      final a = await publish(parent, [workRecord]);
      final b = await publish(child, [pageRecord]);
      await advertise(a, b);
      final receiverIdentity = await SyncSigningIdentity.create();
      final preferences = gate.store;
      final service = MiteMiteService(
        preferences: preferences,
        store: repository,
        groups: groups,
        fs: const IoFileSystem(),
        codec: codec,
        storageFor: (path) async => DirectoryMiteMiteStorage(path),
        identity: receiverIdentity,
        mutations: repository.coordinator,
        now: () => at,
      );
      addTearDown(service.dispose);
      await service.configure('${directory.path}/shared');
      expect(service.devices.single.id, identity.id);
      await service.subscribe(identity.id, {parent});
      final before = await repository.readMirrorState();
      final relocated = '${directory.path}/relocated';
      await service.configure(relocated);
      expect(await repository.readMirrorState(), before);
      expect(service.gate.approvedKey(identity.id), identity.publicKey);
      expect(service.identity.id, receiverIdentity.id);
      final copy = await service.localCopy(
        before.localIdFor(identity.id, child)!,
      );
      await service.publishRoots({copy.id});
      final catalogFiles = await DirectoryMiteMiteStorage(relocated)
          .list('devices/${receiverIdentity.id}/catalog');
      expect(catalogFiles, isNotEmpty);
      final count = catalogFiles.length;
      await service.synchronize();
      expect(
        (await DirectoryMiteMiteStorage(relocated)
                .list('devices/${receiverIdentity.id}/catalog'))
            .length,
        count,
      );
      final catalogFile = File(
        '$relocated/v1/devices/${receiverIdentity.id}/catalog/${catalogFiles.last}',
      );
      await catalogFile.writeAsString('{');
      await service.synchronize(trigger: SyncTrigger.audit);
      final repaired = await DirectoryMiteMiteStorage(relocated)
          .list('devices/${receiverIdentity.id}/catalog');
      expect(repaired, hasLength(2));
      expect(
        repaired
            .map((file) => int.parse(file.split('.').first))
            .reduce((a, b) => a > b ? a : b),
        greaterThan(int.parse(catalogFiles.last.split('.').first)),
      );
      // The corrupt immutable winner is superseded at a fresh sequence before
      // retention removes it as an obsolete incomplete catalog.
      expect(catalogFile.existsSync(), isFalse);
      await service.forget(identity.id);
      expect((await library.load()).groupsById.containsKey(copy.id), isTrue);
    },
  );

  test(
    'verified parent withdrawal retains an independently subscribed child',
    () async {
      final a = await publish(parent, [workRecord]);
      final b = await publish(child, [pageRecord]);
      final first = await advertise(a, b);
      await engine.receive(
        ticket: first,
        publisherKey: identity.publicKey,
        directRoots: {parent, child},
      );
      final bId = (await repository.readMirrorState()).localIdFor(
        identity.id,
        child,
      )!;
      final stopped = await advertise(
        a,
        b,
        parentState: SyncPublicationState.withdrawn,
        childName: 'Renamed B',
      );
      await engine.receive(ticket: stopped, publisherKey: identity.publicKey);
      final state = await library.load();
      expect(state.mirrors.owners.keys, {bId});
      expect(state.groupsById[bId]!.name, 'Renamed B');
      expect(state.groupsById[bId]!.parentGroupId, isNull);
      expect(state.records, hasLength(1));
    },
  );
}

final class _GrantedStorage extends DeviceStoragePermissionNotifier {
  @override
  Future<DeviceStoragePermissionState> build() async =>
      const DeviceStoragePermissionState(
        storagePermission: PermissionStatus.granted,
        isNotificationRead: true,
      );
}

final class _Store implements MiscDataStore {
  final values = <String, String>{};
  @override
  String? get(String key) => values[key];
  @override
  Future<void> put(String key, String value) async {
    values[key] = value;
  }
}

class _PausedStorage implements MiteMiteStorage {
  _PausedStorage(this.delegate);
  final MiteMiteStorage delegate;
  final entered = Completer<void>();
  final resume = Completer<void>();
  @override
  Future<List<String>> list(String path) async {
    if (path == 'devices' && !entered.isCompleted) {
      entered.complete();
      await resume.future;
    }
    return delegate.list(path);
  }

  @override
  Future<Uint8List?> read(String path, {int maxBytes = miteMiteMaxBytes}) =>
      delegate.read(path, maxBytes: maxBytes);
  @override
  Future<void> writeImmutable(String path, Uint8List bytes) =>
      delegate.writeImmutable(path, bytes);
  @override
  Future<void> deleteOwnedRevision(String path, {required String owner}) =>
      delegate.deleteOwnedRevision(path, owner: owner);
  @override
  Future<void> deleteOwnedDirectory(String path, {required String owner}) =>
      delegate.deleteOwnedDirectory(path, owner: owner);
}

class _PausedImportStorage extends _PausedStorage {
  _PausedImportStorage(super.delegate, this.payload, this.childPayload);
  final String payload;
  final String childPayload;
  final childEntered = Completer<void>();
  final resumeChild = Completer<void>();

  @override
  Future<List<String>> list(String path) => delegate.list(path);

  @override
  Future<Uint8List?> read(
    String path, {
    int maxBytes = miteMiteMaxBytes,
  }) async {
    if (path == payload && !entered.isCompleted) {
      entered.complete();
      await resume.future;
    } else if (path == childPayload && !childEntered.isCompleted) {
      childEntered.complete();
      await resumeChild.future;
    }
    return delegate.read(path, maxBytes: maxBytes);
  }
}

class _SnapshotLibrary extends BookmarkLibraryNotifier {
  _SnapshotLibrary(this.snapshot);
  final BookmarkLibraryState snapshot;
  @override
  Future<BookmarkLibraryState> build() async => snapshot;
}

class _SyncTestSettings extends SettingsNotifier {
  _SyncTestSettings() : super(Settings.defaultSettings);
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

class _PollStorage implements MiteMiteStorage {
  _PollStorage(this.delegate);
  final MiteMiteStorage delegate;
  var polls = 0;
  @override
  Future<List<String>> list(String path) {
    if (path == 'devices') polls++;
    return delegate.list(path);
  }

  @override
  Future<Uint8List?> read(String path, {int maxBytes = miteMiteMaxBytes}) =>
      delegate.read(path, maxBytes: maxBytes);
  @override
  Future<void> writeImmutable(String path, Uint8List bytes) =>
      delegate.writeImmutable(path, bytes);
  @override
  Future<void> deleteOwnedRevision(String path, {required String owner}) =>
      delegate.deleteOwnedRevision(path, owner: owner);
  @override
  Future<void> deleteOwnedDirectory(String path, {required String owner}) =>
      delegate.deleteOwnedDirectory(path, owner: owner);
}
