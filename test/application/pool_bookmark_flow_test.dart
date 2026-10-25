import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:booru_clients/danbooru.dart' as api;
import 'package:boorusama/boorus/danbooru/client_provider.dart';
import 'package:boorusama/boorus/danbooru/pools/bookmarks.dart';
import 'package:boorusama/boorus/danbooru/pools/details/src/pool_detail_page.dart';
import 'package:boorusama/boorus/danbooru/pools/pool/types.dart';
import 'package:boorusama/core/blacklists/providers.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/bookmark_group_hive_object.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/bookmark_group_repository_hive.dart';
import 'package:boorusama/core/bookmarks/src/providers/bookmark_provider.dart';
import 'package:boorusama/core/bookmarks/src/providers/pool_bookmark_provider.dart';
import 'package:boorusama/core/bookmarks/src/widgets/bookmark_group_picker.dart';
import 'package:boorusama/core/bookmarks/src/widgets/bookmark_multi_selection.dart';
import 'package:boorusama/core/bookmarks/src/widgets/bookmark_pool_card.dart';
import 'package:boorusama/core/bookmarks/src/widgets/bookmark_scroll_view.dart';
import 'package:boorusama/core/bookmarks/src/widgets/bookmark_search_bar.dart';
import 'package:boorusama/core/bookmarks/src/widgets/pool_bookmark_button.dart';
import 'package:boorusama/core/bookmarks/providers.dart';
import 'package:boorusama/core/bookmarks/types.dart';
import 'package:boorusama/core/configs/manage/providers.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/posts/listing/widgets.dart';
import 'package:boorusama/core/posts/post/providers.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/router.dart';
import 'package:boorusama/core/widgets/multi_select_button.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurumi/material.dart';
import 'package:oktoast/oktoast.dart';
import 'package:selection_mode/selection_mode.dart';

import '../core/bookmarks/pool_bookmark_test_utils.dart';
import '../core/search/following_topics/topic_test_utils.dart';
import '../support/fakes/memory_repositories.dart';
import 'support/app_flow_driver.dart';
import 'support/app_flow_finders.dart';
import 'support/fake_booru_backend.dart';
import 'support/fake_image_dio.dart';
import 'support/headless_app_harness.dart';

void main() {
  testWidgets('re-adding a Pool supersedes an older removal Undo', (
    tester,
  ) async {
    final setup = await _mount(tester, seedReference: true);
    final notifier = setup.container.read(bookmarkProvider.notifier);
    final library = await setup.harness.pumpUntilComplete(
      tester,
      setup.container.read(bookmarkProvider.future),
    );
    final saved = library.pools.single;
    final removal = await setup.harness.pumpUntilComplete(
      tester,
      notifier.removePostsFromGroup(
        setup.harness.booruBackend.config.auth,
        const [],
        poolGroupA,
        poolLocalIds: {saved.localId},
      ),
    );
    expect(setup.container.read(bookmarkProvider).requireValue.pools, isEmpty);
    await setup.harness.pumpUntilComplete(
      tester,
      notifier.togglePoolTarget(saved, groupId: poolGroupA),
    );
    final rejected = await setup.harness.pumpUntilComplete(
      tester,
      notifier
          .undoRemoval(removal)
          .then((_) => false, onError: (Object _) => true),
    );
    expect(rejected, isTrue);
    final current = setup.container
        .read(bookmarkProvider)
        .requireValue
        .pools
        .single;
    expect(current.localId, saved.localId);
    expect(current.groupIds, {poolGroupA});
    expect(setup.posts.bookmarks, isEmpty);
  });

  testWidgets(
    'rapid refreshes coalesce an active Series lookup and reuse its scoped result',
    (tester) async {
      final setup = await _mount(tester, seedPosts: true, holdSeries: true);
      final harness = setup.harness;
      await AppFlowDriver(tester: tester, harness: harness).openBookmarks();
      await harness.pumpUntil(
        tester,
        () => setup.adapter.membershipRequested.isCompleted,
      );
      final grid = tester.widget<PostGrid<Post>>(
        find
            .descendant(
              of: find.byType(BookmarkScrollView),
              matching: find.byType(PostGrid<Post>),
            )
            .first,
      );
      for (var i = 0; i < 3; i++) {
        await harness.pumpUntilComplete(tester, grid.controller.refresh());
      }
      expect(
        setup.adapter.requests.where((r) => r.path == '/pools.json'),
        hasLength(1),
      );
      setup.adapter.seriesGate!.complete();
      await harness.settle(tester);
      await harness.pumpUntilComplete(tester, grid.controller.refresh());
      await harness.pumpUntilFound(
        tester,
        find.byWidgetPredicate((w) => w is BookmarkPoolCard && w.projected),
      );
      expect(
        setup.adapter.requests.where((r) => r.path == '/pools.json'),
        hasLength(1),
      );
      expect(grid.controller.items, hasLength(3));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'bounded indexing can finish across frames before saving one reference',
    (tester) async {
      final setup = await _mount(tester, holdIndex: true);
      final harness = setup.harness;
      unawaited(
        setup.container
            .read(routerProvider)
            .push(
              '/danbooru/pools/10',
              extra: (pool: _pool(), config: harness.booruBackend.config),
            ),
      );
      await harness.pumpUntilFound(tester, find.byType(PoolBookmarkButton));
      await harness.settle(tester);
      await tester.tap(find.byType(PoolBookmarkButton));
      await harness.pumpUntil(
        tester,
        () => harness.booruBackend.requests
            .whereType<FakeBooruPostRequest>()
            .any((r) => r.query == 'pool:10' && r.pending),
      );
      await tester.pump();
      await tester.pump();
      expect(
        setup.container.read(bookmarkProvider).requireValue.pools,
        isEmpty,
      );
      setup.indexGate!.completeSuccess(
        PostResult(posts: harness.booruBackend.posts, total: 2),
      );
      await harness.pumpUntil(
        tester,
        () =>
            setup.container.read(bookmarkProvider).valueOrNull?.pools.length ==
            1,
        description: 'completed asynchronous Pool bookmark',
      );
      expect(setup.posts.bookmarks, isEmpty);
      await _drainNotifications(tester);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'explicit refresh replaces a stored tag union without bookmarking members',
    (tester) async {
      final setup = await _mount(tester, seedReference: true);
      final harness = setup.harness;
      await AppFlowDriver(tester: tester, harness: harness).openBookmarks();
      await harness.pumpUntilFound(tester, find.byType(BookmarkPoolCard));
      await harness.settle(tester);
      await tester.tap(
        find.byType(BookmarkPoolCard),
        kind: PointerDeviceKind.mouse,
        buttons: kSecondaryMouseButton,
      );
      await harness.pumpUntilFound(tester, find.text('Refresh metadata'));
      await tester.tap(find.text('Refresh metadata'));
      await harness.pumpUntil(
        tester,
        () =>
            setup.container
                .read(bookmarkProvider)
                .valueOrNull
                ?.pools
                .single
                .tags
                .contains('cat') ??
            false,
      );
      final saved = setup.container
          .read(bookmarkProvider)
          .requireValue
          .pools
          .single;
      expect(saved.tags, containsAll(['cat', 'landscape']));
      expect(saved.tags, isNot(contains('alpha')));
      expect(saved.groupIds, {poolGroupA});
      expect(saved.localId, testPool().localId);
      expect(setup.posts.bookmarks, isEmpty);
      await _drainNotifications(tester);
      expect(tester.takeException(), isNull);
    },
  );

  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'Pool Bookmark uses the shared picker and stays one selectable entry at ${scale}x',
      (tester) async {
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final setup = await _mount(tester);
        final harness = setup.harness;
        final container = setup.container;
        unawaited(
          container
              .read(routerProvider)
              .push(
                '/danbooru/pools/10',
                extra: (pool: _pool(), config: harness.booruBackend.config),
              ),
        );
        await harness.pumpUntilFound(tester, find.byType(PoolBookmarkButton));
        await harness.settle(tester);
        await tester.longPress(find.byType(PoolBookmarkButton));
        await harness.pumpUntilFound(tester, find.byType(BookmarkGroupPicker));
        expect(tester.takeException(), isNull);
        await harness.settle(tester);
        await tester.scrollUntilVisible(
          find.text('Pool target'),
          100,
          scrollable: find
              .descendant(
                of: find.byType(BookmarkGroupPicker),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await harness.settle(tester);
        await tester.tap(find.text('Pool target'));
        await harness.pumpUntil(
          tester,
          () => container.read(bookmarkProvider).valueOrNull?.pools.length == 1,
        );
        expect(setup.posts.bookmarks, isEmpty);
        final saved = container
            .read(bookmarkProvider)
            .requireValue
            .pools
            .single;
        expect(saved.groupIds, {poolGroupA});
        expect(saved.total, 20);
        expect(saved.coverage, PoolTagCoverage.partial);
        expect(saved.tags, containsAll(['cat', 'landscape']));
        await AppFlowDriver(tester: tester, harness: harness).goBack();
        await AppFlowDriver(tester: tester, harness: harness).openBookmarks();
        await harness.pumpUntilFound(tester, find.byType(BookmarkPoolCard));
        expect(find.text('Series · 20'), findsOneWidget);
        await harness.settle(tester);
        expect(tester.takeException(), isNull);
        await tester.longPress(find.byType(BookmarkPoolCard));
        await harness.settle(tester);
        final selection = SelectionMode.of(
          tester.element(find.byType(BookmarkPoolCard)),
        );
        expect(selection.selection, {0});
        expect(find.text('Download'), findsNothing);
        expect(setup.posts.bookmarks, isEmpty);
        selection.disable();
        await harness.settle(tester);

        final beforeMetadata = setup.adapter.requests.length;
        final field = find
            .descendant(
              of: find.byType(BookmarkSearchBar),
              matching: find.byType(TextField),
            )
            .first;
        await tester.tap(field);
        await tester.enterText(field, 'cat -landscape');
        harness.keyboard.sync();
        expect(harness.keyboard.isShown, isTrue);
        expect(tester.takeException(), isNull);
        await tester.testTextInput.receiveAction(TextInputAction.search);
        await harness.pumpUntil(
          tester,
          () => find.byType(BookmarkPoolCard).evaluate().isEmpty,
        );
        expect(setup.adapter.requests, hasLength(beforeMetadata));
        expect(
          container.read(bookmarkProvider).requireValue.pools,
          hasLength(1),
        );
      },
    );
  }

  testWidgets(
    'a Pool card opens the full remote Pool under its origin while another profile is active',
    (tester) async {
      final setup = await _mount(
        tester,
        initialOtherProfile: true,
        seedReference: true,
      );
      final harness = setup.harness;
      await AppFlowDriver(tester: tester, harness: harness).openBookmarks();
      await harness.pumpUntilFound(tester, find.byType(BookmarkPoolCard));
      await harness.settle(tester);
      await tester.tap(find.byType(BookmarkPoolCard));
      await harness.pumpUntilFound(tester, find.byType(PoolDetailPage));
      final page = tester.widget<PoolDetailPage>(find.byType(PoolDetailPage));
      expect(page.pool.id, 10);
      expect(page.pool.postIds, hasLength(20));
      final scoped = ProviderScope.containerOf(
        tester.element(find.byType(PoolDetailPage)),
        listen: false,
      );
      expect(
        scoped.read(currentReadOnlyBooruConfigProvider).id,
        harness.booruBackend.config.id,
      );
      final detail = setup.adapter.requests
          .where((r) => r.path == '/pools/10.json')
          .single;
      expect(detail.uri.host, Uri.parse(harness.booruBackend.config.url).host);
      expect(
        detail.uri.host,
        isNot(Uri.parse(harness.booruBackend.configB.url).host),
      );
      expect(setup.posts.bookmarks, isEmpty);
      await _drainNotifications(tester);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'wired Series projection expands Posts for selection and preserves an explicit reference',
    (tester) async {
      final setup = await _mount(tester, seedReference: true, seedPosts: true);
      final harness = setup.harness;
      await AppFlowDriver(tester: tester, harness: harness).openBookmarks();
      await harness.pumpUntilFound(tester, find.byType(BookmarkPoolCard));
      await harness.pumpUntil(
        tester,
        () => setup.adapter.membershipRequested.isCompleted,
        description: 'bounded Series metadata request',
      );
      await harness.settle(tester);
      final grid = tester.widget<PostGrid<Post>>(
        find
            .descendant(
              of: find.byType(BookmarkScrollView),
              matching: find.byType(PostGrid<Post>),
            )
            .first,
      );
      await harness.pumpUntilComplete(tester, grid.controller.refresh());
      await harness.settle(tester);
      final projected = find.byWidgetPredicate(
        (w) => w is BookmarkPoolCard && w.projected,
      );
      await harness.pumpUntilFound(tester, projected);
      expect(find.byType(BookmarkPoolCard), findsNWidgets(2));
      expect(grid.controller.items, hasLength(3));
      await tester.longPress(projected);
      await harness.settle(tester);
      expect(find.byType(BookmarkPoolCard), findsOneWidget);
      final selection = SelectionMode.of(
        tester.element(find.byType(BookmarkPoolCard)),
      );
      expect(selection.selection, hasLength(1));
      final helpIcon = find
          .descendant(
            of: find.byType(BookmarkScrollView),
            matching: find.byIcon(Icons.info_outline),
          )
          .first;
      Focus.of(tester.element(helpIcon)).requestFocus();
      await tester.pump();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await harness.settle(tester);
      expect(selection.selection, hasLength(4));
      await tester.tap(find.byType(MultiSelectPopupButton).first);
      await harness.pumpUntilFound(
        tester,
        find.byType(BookmarkMultiSelectionMenu),
      );
      final menu = tester.widget<BookmarkMultiSelectionMenu>(
        find.byType(BookmarkMultiSelectionMenu),
      );
      expect(menu.posts, hasLength(3));
      expect(menu.pools, hasLength(1));
      expect(setup.posts.bookmarks, hasLength(3));
      await tester.tap(find.text('Remove from'));
      await harness.pumpUntilFound(tester, find.text('Pool target'));
      await harness.settle(tester);
      await tester.tap(find.text('Pool target'));
      await harness.pumpUntil(tester, () {
        final state = setup.container.read(bookmarkProvider).valueOrNull;
        return state != null && state.items.isEmpty && state.pools.isEmpty;
      });
      expect(selection.isActive, isFalse);
      await harness.pumpUntilFound(tester, find.text('Undo'));
      await tester.tap(find.text('Undo'));
      await harness.pumpUntil(tester, () {
        final state = setup.container.read(bookmarkProvider).valueOrNull;
        return state?.items.length == 3 && state?.pools.length == 1;
      });
      await harness.settle(tester);
      await _drainNotifications(tester);
      expect(tester.takeException(), isNull);
    },
  );
}

DanbooruPool _pool() => DanbooruPool(
  id: 10,
  postIds: [for (var id = 101; id <= 120; id++) id],
  category: DanbooruPoolCategory.series,
  description: '',
  postCount: 20,
  name: 'Series_10',
  createdAt: DateTime.utc(2000),
  updatedAt: DateTime.utc(2026),
);

Future<
  ({
    HeadlessAppHarness harness,
    ProviderContainer container,
    MemoryBookmarkRepository posts,
    _PoolAdapter adapter,
    FakeBooruPostGate? indexGate,
  })
>
_mount(
  WidgetTester tester, {
  bool initialOtherProfile = false,
  bool seedReference = false,
  bool seedPosts = false,
  bool holdIndex = false,
  bool holdSeries = false,
}) async {
  final backend = FakeBooruBackend();
  final indexGate = holdIndex
      ? backend.enqueuePostGate(
          siteUrl: backend.config.url,
          query: 'pool:10',
          page: 1,
        )
      : null;
  if (!holdIndex)
    backend.enqueuePosts(page: 1, query: 'pool:10', posts: backend.posts);
  backend.enqueuePosts(
    page: 1,
    query: 'pool:10 order:created_at',
    posts: [backend.posts.first],
  );
  backend.enqueuePosts(
    page: 1,
    query: 'pool:10 order:created_at_asc',
    posts: [backend.posts.last],
  );
  backend.enqueuePosts(
    page: 1,
    query: 'id:${[for (var id = 101; id <= 120; id++) id].join(',')}',
    posts: backend.posts,
  );
  final posts = MemoryBookmarkRepository();
  final groups = BookmarkGroupRepositoryHive(
    MemoryBox<BookmarkGroupHiveObject>(),
    organizationBox: MemoryBox<dynamic>(),
  );
  await groups.createGroup('Pool target', id: poolGroupA);
  if (seedReference)
    await groups.writePoolBookmarks([
      testPool().copyWith(origin: postOriginFromConfig(backend.config)),
    ]);
  if (seedPosts) {
    final bookmarks = [
      for (var id = 101; id <= 103; id++)
        (() {
          final old = testPoolPost(id);
          final post = old.post.copyWith(
            origin: postOriginFromConfig(backend.config),
          );
          return old.copyWith(
            post: post,
            snapshot: const StoredPostCodec().encode(post),
          );
        })(),
    ];
    await posts.addBookmarkWithBookmarks(bookmarks);
    await groups.addBookmarks(poolGroupA, bookmarks.map((b) => b.id).toSet());
  }
  final adapter = _PoolAdapter(holdSeries: holdSeries);
  final runtime = backend.createRuntime(
    configs: [backend.config, backend.configB],
    initialConfig: initialOtherProfile ? backend.configB : backend.config,
    bookmarkRepository: posts,
  );
  final harness = await HeadlessAppHarness.mount(
    tester,
    runtime: runtime,
    booruBackend: backend,
    phone: TestPhone.smallPortrait,
    additionalOverrides: [
      deterministicImageDioOverride(),
      deterministicFaviconDioOverride(),
      bookmarkGroupRepoProvider.overrideWith((_) async => groups),
      blacklistTagsProvider.overrideWith((_, _) async => <String>{}),
      poolBookmarkCapabilityProvider.overrideWith(
        (ref, _) => DanbooruPoolBookmarks(ref),
      ),
      danbooruClientProvider.overrideWith((ref, config) {
        final dio = Dio(BaseOptions(baseUrl: config.url))
          ..httpClientAdapter = adapter;
        ref.onDispose(dio.close);
        return api.DanbooruClient(baseUrl: config.url, dio: dio);
      }),
    ],
  );
  await harness.pumpUntilFound(
    tester,
    postTile(initialOtherProfile ? 201 : 101),
  );
  final container = ProviderScope.containerOf(
    tester.element(find.byType(PostGrid<Post>).first),
    listen: false,
  );
  return (
    harness: harness,
    container: container,
    posts: posts,
    adapter: adapter,
    indexGate: indexGate,
  );
}

class _PoolAdapter implements HttpClientAdapter {
  _PoolAdapter({bool holdSeries = false})
    : seriesGate = holdSeries ? Completer<void>() : null;
  final Completer<void>? seriesGate;
  final requests = <RequestOptions>[];
  final membershipRequested = Completer<void>();
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final json = {
      'id': 10,
      'name': 'Series_10',
      'category': 'series',
      'post_count': 20,
      'post_ids': [for (var id = 101; id <= 120; id++) id],
      'created_at': '2000-01-01T00:00:00Z',
      'updated_at': '2026-01-01T00:00:00Z',
    };
    if (options.path == '/pools.json') {
      if (!membershipRequested.isCompleted) membershipRequested.complete();
      await seriesGate?.future;
      return ResponseBody.fromString(
        jsonEncode([json]),
        200,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );
    }
    if (options.path.endsWith('.json'))
      return ResponseBody.fromString(
        jsonEncode(json),
        200,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );
    return ResponseBody.fromString(
      '<div id="description"></div>',
      200,
      headers: {
        Headers.contentTypeHeader: ['text/html'],
      },
    );
  }

  @override
  void close({bool force = false}) {
    if (seriesGate != null && !seriesGate!.isCompleted) seriesGate!.complete();
  }
}

Future<void> _drainNotifications(WidgetTester tester) async {
  dismissAllToast(showAnim: false);
  // Drain notification lifetimes using the widget's controlled clock.
  await tester.pump(const Duration(seconds: 6));
}
