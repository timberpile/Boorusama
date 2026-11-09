import 'dart:async';

import 'package:booru_clients/pixiv.dart';
import 'package:boorusama/boorus/pixiv/client_provider.dart';
import 'package:boorusama/boorus/pixiv/favorites/page.dart';
import 'package:boorusama/boorus/pixiv/explore/widgets.dart';
import 'package:boorusama/boorus/pixiv/pixiv.dart';
import 'package:boorusama/boorus/pixiv/works/favorites_session.dart';
import 'package:boorusama/boorus/pixiv/works/search_page.dart';
import 'package:boorusama/boorus/pixiv/works/work_listing.dart';
import 'package:boorusama/boorus/pixiv/works/work_mapper.dart';
import 'package:boorusama/boorus/pixiv/works/work_source.dart';
import 'package:boorusama/boorus/registry.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/boorus/engine/providers.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/content/capabilities.dart';
import 'package:boorusama/core/content/content_access_provider.dart';
import 'package:boorusama/core/content/groups/group_source_provider.dart';
import 'package:boorusama/core/content/types.dart';
import 'package:boorusama/core/content/widgets/native_content_grid.dart';
import 'package:boorusama/core/posts/details/routes.dart';
import 'package:boorusama/core/posts/details/src/types/viewer_entry.dart';
import 'package:boorusama/core/posts/listing/src/widgets/post_grid_item.dart';
import 'package:boorusama/core/posts/listing/src/widgets/post_grid_prefetch.dart';
import 'package:boorusama/core/posts/pools/pool_grid_item.dart';
import 'package:boorusama/core/router.dart';
import 'package:boorusama/core/blacklists/providers.dart';
import 'package:boorusama/core/blacklists/types.dart';
import 'package:boorusama/core/blacklists/src/data/providers.dart';
import 'package:boorusama/boorus/pixiv/works/bookmark_targets.dart';
import 'package:boorusama/core/bookmarks/src/widgets/bookmark_native_group_card.dart';
import 'package:boorusama/core/images/booru_image.dart';
import 'package:boorusama/core/search/search/routes.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kurumi/material.dart';

import '../../../core/posts/details/progressive_image_test_utils.dart';
import '../../../core/search/following_topics/following_topic_test_utils.dart';
import 'work_test_fixtures.dart';
import '../../../support/fakes/memory_repositories.dart';

final _sourceOwnerRef = Provider((ref) => ref);

class Client extends PixivClient {
  Client._(Dio dio) : super(accessToken: 'fixture', dio: dio);
  factory Client() {
    final dio = Dio(BaseOptions(baseUrl: kPixivApiBaseUrl));
    final client = Client._(dio);
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (request, handler) async {
          client.reads.add((
            path: request.path,
            query: Map.of(request.queryParameters),
          ));
          if (request.path == '/v1/search/illust' ||
              request.path == '/v1/illust/ranking' ||
              request.path == '/v2/illust/follow' ||
              request.path == '/v1/illust/recommended') {
            handler.resolve(
              Response<dynamic>(
                requestOptions: request,
                statusCode: 200,
                data: {
                  'illusts': [
                    _wireWork(switch (request.path) {
                      '/v2/illust/follow' => 130,
                      '/v1/illust/recommended' => 140,
                      _ => 120,
                    }),
                  ],
                },
              ),
            );
            return;
          }
          if (request.path != '/v1/user/bookmarks/illust') {
            handler.reject(DioException(requestOptions: request));
            return;
          }
          final privacy = request.queryParameters['restrict'] == 'private'
              ? PixivBookmarkVisibility.private
              : PixivBookmarkVisibility.public;
          client.bookmarks.add((
            user: request.queryParameters['user_id'] as int,
            privacy: privacy,
            cursor: request.queryParameters['max_bookmark_id'] as String?,
            token: request.cancelToken,
          ));
          final data =
              privacy == PixivBookmarkVisibility.public &&
                  client.delayedPublic != null
              ? await client.delayedPublic!.future
              : <String, dynamic>{
                  'illusts': [
                    _wireWork(
                      privacy == PixivBookmarkVisibility.private ? 220 : 120,
                    ),
                  ],
                };
          handler.resolve(
            Response<dynamic>(
              requestOptions: request,
              statusCode: 200,
              data: data,
            ),
          );
        },
      ),
    );
    return client;
  }
  var detailCalls = 0;
  PixivIllustDto? detail;
  final reads = <({String path, Map<String, dynamic> query})>[];
  final bookmarks =
      <
        ({
          int user,
          PixivBookmarkVisibility privacy,
          String? cursor,
          CancelToken? token,
        })
      >[];
  Completer<Map<String, dynamic>>? delayedPublic;
  @override
  Future<PixivIllustDto?> getIllustDetail({required int illustId}) async {
    detailCalls++;
    return detail ?? work(id: illustId);
  }
}

Map<String, dynamic> _wireWork(int id) => {
  'id': id,
  'title': 'Work $id',
  'type': 'manga',
  'user': {'id': 7, 'name': 'Fixture'},
  'page_count': 1,
  'visible': true,
  'tags': <Object>[],
  'x_restrict': 0,
  'image_urls': {'square_medium': 'https://i.pximg.net/thumb/$id.jpg'},
  'meta_single_page': {
    'original_image_url': 'https://i.pximg.net/original/$id.jpg',
  },
};

FollowingTopicHarness harness(
  BooruConfig config,
  Client client, {
  Set<String> blacklist = const {},
}) {
  final components = createBooruRegistry();
  final db = BooruDb(
    boorus: {BooruType.pixiv: components.parseFromConfig('pixiv')},
  );
  final h = FollowingTopicHarness(
    profiles: [config],
    stubBlacklist: false,
    overrides: [
      booruEngineRegistryProvider.overrideWith(
        (ref) =>
            ref.watch(booruInitEngineProvider((db: db, registry: components))),
      ),
      pixivClientProvider.overrideWith((_, _) => client),
      globalBlacklistedTagRepoProvider.overrideWith((ref) async {
        final repository = MemoryGlobalBlacklistedTagRepository();
        await repository.replaceAll([
          for (final (index, tag) in blacklist.indexed)
            BlacklistedTag(
              id: index,
              name: tag,
              isActive: true,
              createdDate: DateTime.utc(2026),
              updatedDate: DateTime.utc(2026),
            ),
        ]);
        return repository;
      }),
    ],
  );
  h.container.read(selectedTestProfileProvider.notifier).select(config);
  return h;
}

void main() {
  for (final viewport in [
    (size: const Size(800, 600), scale: 1.0),
    (size: const Size(320, 720), scale: 1.5),
  ]) {
    testWidgets(
      'Explore builds all three feeds with the production blacklist chain at $viewport',
      (tester) async {
        tester.view.physicalSize = viewport.size;
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = viewport.scale;
        addTearDown(tester.view.reset);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final client = Client();
        final h = harness(workAccess().config!, client, blacklist: {'blocked'});
        addTearDown(h.dispose);
        await h.pump(tester, const PixivExplorePage());
        await tester.runAsync(
          () => pumpUntil(
            tester,
            () => find.text('Work 120').evaluate().isNotEmpty,
            reason: 'Explore ranking with registered policy',
          ),
        );
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('Following'));
        await tester.runAsync(
          () => pumpUntil(
            tester,
            () => find.text('Work 130').evaluate().isNotEmpty,
            reason: 'Explore following with registered policy',
          ),
        );
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('Recommended'));
        await tester.runAsync(
          () => pumpUntil(
            tester,
            () => find.text('Work 140').evaluate().isNotEmpty,
            reason: 'Explore recommended with registered policy',
          ),
        );
        expect(tester.takeException(), isNull);
        expect(
          client.reads.map((r) => r.path),
          containsAll([
            '/v1/illust/ranking',
            '/v2/illust/follow',
            '/v1/illust/recommended',
          ]),
        );
      },
    );
  }

  testWidgets(
    'native listing applies translated blacklist before seeding and preserves terminal raw continuation',
    (tester) async {
      final config = workAccess().config!;
      final h = harness(config, Client(), blacklist: {'translated_tag'});
      addTearDown(h.dispose);
      var reads = 0;
      await h.pump(
        tester,
        Scaffold(
          body: PixivWorkGrid(
            config: config,
            queryIdentity: 'translated-filter',
            fetchPage: (_) async {
              reads++;
              return PixivIllustListResult(
                illusts: [
                  work(
                    tags: [
                      {'name': 'native', 'translated_name': 'Translated Tag'},
                    ],
                  ),
                  work(id: 121),
                ],
                hasMore: false,
              );
            },
          ),
        ),
      );
      await tester.runAsync(
        () => pumpUntil(
          tester,
          () => find.text('Work 121').evaluate().isNotEmpty,
          reason: 'filtered native list',
        ),
      );
      expect(find.text('Work 120'), findsNothing);
      final controller =
          tester
                  .widget<PostGridPrefetch>(find.byType(PostGridPrefetch))
                  .controller
              as NativeContentController;
      expect(controller.hasMore, isFalse);
      expect(controller.errors.value, isNull);
      expect(reads, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'saved Work covers do not treat unknown or malformed tags as complete empty',
    (tester) async {
      final config = workAccess().config!;
      final access = workAccess();
      final client = Client();
      final h = harness(config, client, blacklist: {'blocked'});
      addTearDown(h.dispose);
      for (final observation in [
        work(omitTags: true),
        work(tags: [null]),
        work(
          tags: [
            {'name': 'blocked'},
          ],
        ),
      ]) {
        final record = PixivWorkBookmarkTarget(
          access: access,
          summary: pixivWorkSummary(observation, access),
          details: pixivWorkDetails(observation, access),
        ).draft(currentAccess: access, at: DateTime.utc(2026));
        await h.pump(
          tester,
          Scaffold(
            body: SizedBox.square(
              dimension: 200,
              child: BookmarkNativeGroupCover(bookmark: record),
            ),
          ),
        );
        await h.container.read(blacklistTagsProvider(config.filter).future);
        await tester.pump();
        expect(
          find.byType(BooruImage),
          findsNothing,
          reason: 'An incomplete observation cannot authorize a blacklisted saved cover',
        );
        expect(tester.takeException(), isNull);
      }
      final allowed = work(tags: []);
      final record = PixivWorkBookmarkTarget(
        access: access,
        summary: pixivWorkSummary(allowed, access),
        details: pixivWorkDetails(allowed, access),
      ).draft(currentAccess: access, at: DateTime.utc(2026));
      await h.pump(
        tester,
        Scaffold(
          body: SizedBox.square(
            dimension: 200,
            child: BookmarkNativeGroupCover(bookmark: record),
          ),
        ),
      );
      expect(
        h.container.read(contentProfileAccessProvider(config.id)),
        isNotNull,
      );
      await tester.runAsync(
        () => pumpUntil(
          tester,
          () => find.byType(BooruImage).evaluate().isNotEmpty,
          reason: 'complete-empty saved Work cover policy',
        ),
      );
      expect(
        find.byType(BooruImage),
        findsOneWidget,
        reason:
            'An observed complete empty tag set can authorize this same cover',
      );
      expect(client.detailCalls, 0);
    },
  );

  for (final raw in ['', 'cat']) {
    testWidgets(
      'registered Search composes Always Include Tags for "$raw" and refreshes after settings change',
      (tester) async {
        BooruConfig configured(String tag) => BooruConfig.fromJson({
          ...workAccess().config!.toJson(),
          'alwaysIncludeTags': '["$tag"]',
        });
        final config = configured('wolf');
        final client = Client();
        final h = harness(config, client);
        addTearDown(h.dispose);
        final builder = createPixiv().createBuilder();
        await h.pump(
          tester,
          Builder(
            builder: (context) =>
                builder.searchPageBuilder(context, SearchParams(query: raw)),
          ),
        );
        await tester.runAsync(
          () => pumpUntil(
            tester,
            () => client.reads.any((read) => read.path == '/v1/search/illust'),
            reason: 'composed native search',
          ),
        );
        final first = client.reads
            .where((read) => read.path == '/v1/search/illust')
            .last;
        expect((first.query['word'] as String).split(' ').toSet(), {
          if (raw.isNotEmpty) raw,
          'wolf',
        });
        expect(
          client.reads.where((read) => read.path == '/v1/illust/ranking'),
          isEmpty,
        );
        h.container
            .read(selectedTestProfileProvider.notifier)
            .select(configured('fox'));
        await tester.pump();
        await tester.runAsync(
          () => pumpUntil(
            tester,
            () => client.reads.any(
              (read) =>
                  (read.query['word'] as String?)?.contains('fox') ?? false,
            ),
            reason: 'changed native search settings',
          ),
        );
        final last = client.reads
            .where((read) => read.path == '/v1/search/illust')
            .last;
        expect((last.query['word'] as String).split(' ').toSet(), {
          if (raw.isNotEmpty) raw,
          'fox',
        });
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'registered portable Work source enforces current rating and blacklist before seed or reads',
    (tester) async {
      final config = BooruConfig.fromJson({
        ...workAccess().config!.toJson(),
        'ratingFilter': BooruConfigRatingFilter.hideExplicit.index,
      });
      final client = Client();
      final h = harness(config, client, blacklist: {'blocked'});
      addTearDown(h.dispose);
      await h.pump(tester, const SizedBox());
      final hold = h.container.listen(
        contentProfileAccessProvider(config.id),
        (_, _) {},
      );
      addTearDown(hold.close);
      await h.container.read(blacklistTagsProvider(config.filter).future);
      await tester.pump();
      final access = h.container.read(contentProfileAccessProvider(config.id))!;
      final source = h.container
          .read(booruEngineRegistryProvider)
          .getGroupCapability(BooruType.pixiv)!
          .createSource(h.container.read(_sourceOwnerRef), access);
      addTearDown(source.dispose);
      final reference = pixivWorkReference(access, 120);
      for (final denied in [
        work(xRestrict: 1),
        work(
          tags: [
            {'name': 'blocked'},
          ],
        ),
        work(omitTags: true),
        work(tags: [null]),
      ]) {
        client.detail = denied;
        expect(
          () => (source as PixivWorkSource).seedWork(denied),
          throwsStateError,
        );
        source.invalidate(reference);
        expect((await source.loadSummary(reference).run()).isLeft(), isTrue);
        expect((await source.loadDetails(reference).run()).isLeft(), isTrue);
        expect(
          (await source
                  .loadMembers(GroupMemberQuery(reference: reference))
                  .run())
              .isLeft(),
          isTrue,
        );
      }
      client.detail = work();
      source.invalidate(reference);
      expect((await source.loadDetails(reference).run()).isRight(), isTrue);
    },
  );

  testWidgets(
    'production registry routes Search and Favorites to native Work capabilities',
    (tester) async {
      final config = workAccess().config!;
      final client = Client();
      final h = harness(config, client);
      addTearDown(h.dispose);
      final components = createPixiv();
      await h.pump(
        tester,
        Builder(
          builder: (context) {
            final builder = components.createBuilder();
            expect(
              builder.searchPageBuilder(context, const SearchParams()),
              isA<PixivWorkSearchPage>(),
            );
            expect(
              builder.favoritesPageBuilder!(context),
              isA<PixivFavoritesPage>(),
            );
            return const SizedBox();
          },
        ),
      );
      final capability = h.container
          .read(booruEngineRegistryProvider)
          .getGroupCapability(BooruType.pixiv)!;
      expect(
        capability.presentation.layoutFor(
          pixivWorkSummary(work(), workAccess()),
        ),
        GroupLayout.mediaPager,
      );
      expect(
        capability.presentation.supports(
          pixivWorkSummary(work(), workAccess()),
        ),
        isTrue,
      );
      expect(client.detailCalls, 0);
    },
  );

  testWidgets(
    'ordinary Work grid keeps one multi-Page card, real Ugoira Post and exact mixed navigation',
    (tester) async {
      final config = workAccess().config!;
      final client = Client();
      final h = harness(config, client);
      addTearDown(h.dispose);
      DetailsRouteContext? opened;
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => Scaffold(
              body: PixivWorkGrid(
                config: config,
                queryIdentity: 'fixture',
                fetchPage: (_) async => PixivIllustListResult(
                  illusts: [
                    work(pages: [page(120, 0), null, page(120, 2)]),
                    work(id: 121, type: 'ugoira'),
                  ],
                ),
              ),
            ),
          ),
          GoRoute(
            path: '/details',
            builder: (_, state) {
              opened = state.extra! as DetailsRouteContext;
              return const Scaffold(body: Text('Opened native fixture'));
            },
          ),
        ],
      );
      h.router = router;
      addTearDown(router.dispose);
      await tester.pumpWidget(
        h.wrap(
          MaterialApp.router(
            routerConfig: router,
            theme: ThemeData(),
            builder: themeBuilder,
          ),
        ),
      );
      await tester.runAsync(
        () => pumpUntil(
          tester,
          () => find.text('Work 120').evaluate().isNotEmpty,
          reason: 'registered Work listing',
        ),
      );
      expect(find.byType(PoolGridItem), findsOneWidget);
      expect(find.byType(PostGridItem), findsOneWidget);
      final controller =
          tester
                  .widget<PostGridPrefetch>(find.byType(PostGridPrefetch))
                  .controller
              as NativeContentController;
      expect(controller.entries.whereType<GroupContentEntry>(), hasLength(1));
      expect(controller.entries.whereType<PostContentEntry>(), hasLength(1));
      final access = h.container.read(contentProfileAccessProvider(config.id))!;
      final source = h.container.read(contentGroupSourceProvider(access.key));
      final members = (await tester.runAsync(
        () => source
            .loadMembers(
              GroupMemberQuery(
                reference: pixivWorkReference(access, 120),
              ),
            )
            .run(),
      ))!.fold((error) => throw error, (value) => value);
      expect(members.page.items.map((member) => member.sourcePosition), [
        0,
        1,
        2,
      ]);
      expect(
        members.page.items[1].availability,
        MemberAvailability.unavailable,
      );
      expect(
        client.detailCalls,
        0,
        reason: 'native listing seeds the real shared envelope',
      );
      await tester.tap(
        find.descendant(
          of: find.byType(PoolGridItem),
          matching: find.byType(InkWell),
        ),
      );
      await tester.runAsync(
        () => pumpUntil(
          tester,
          () => opened != null,
          reason: 'mixed native route',
        ),
      );
      expect(opened, isNotNull);
      expect(opened!.useMixedViewer, isTrue);
      expect(opened!.entries, hasLength(2));
      expect(opened!.entries!.first, isA<GroupViewerEntry>());
      expect(opened!.entries![1], isA<PostViewerEntry>());
      expect(opened!.entries!.first.source!.config.id, config.id);
    },
  );

  testWidgets(
    'filtered empty native source batch preserves server continuation without retry loop',
    (tester) async {
      final config = workAccess().config!;
      final h = harness(config, Client());
      addTearDown(h.dispose);
      final pages = <int>[];
      await h.pump(
        tester,
        Scaffold(
          body: PixivWorkGrid(
            config: config,
            queryIdentity: 'filtered',
            fetchPage: (page) async {
              pages.add(page);
              return PixivIllustListResult(
                illusts: [work(visible: page != 1)],
                hasMore: page == 1,
              );
            },
          ),
        ),
      );
      await tester.runAsync(
        () => pumpUntil(
          tester,
          () =>
              pages.length == 2 && find.text('Work 120').evaluate().isNotEmpty,
          reason: 'empty continuing batch followed by terminal Work',
        ),
      );
      final controller =
          tester
                  .widget<PostGridPrefetch>(find.byType(PostGridPrefetch))
                  .controller
              as NativeContentController;
      expect(controller.hasMore, isFalse);
      expect(pages, [1, 2]);
      expect(controller.entries, hasLength(1));
    },
  );

  testWidgets(
    'ordinary Favorites privacy switch cancels public read before showing private native Works',
    (tester) async {
      final config = BooruConfig.fromJson({
        ...workAccess().config!.toJson(),
        'apiKey': 'fixture-refresh',
        'passHash': '{"userId":"7"}',
      });
      final client = Client()
        ..delayedPublic = Completer<Map<String, dynamic>>();
      final h = harness(config, client);
      addTearDown(h.dispose);
      await h.pump(tester, const PixivFavoritesPage());
      await tester.runAsync(
        () => pumpUntil(
          tester,
          () => client.bookmarks.isNotEmpty,
          reason: 'public Favorites dispatch',
        ),
      );
      final publicToken = client.bookmarks.single.token!;
      await tester.tap(find.text('Private'));
      await tester.pump();
      await tester.runAsync(
        () => pumpUntil(
          tester,
          () => find.text('Work 220').evaluate().isNotEmpty,
          reason: 'private Favorites native listing',
        ),
      );
      expect(publicToken.isCancelled, isTrue);
      client.delayedPublic!.complete({
        'illusts': [_wireWork(999)],
      });
      await tester.pump();
      await tester.pump();
      expect(find.text('Work 999'), findsNothing);
      expect(client.bookmarks.map((read) => read.privacy), [
        PixivBookmarkVisibility.public,
        PixivBookmarkVisibility.private,
      ]);
      expect(
        client.bookmarks.every((read) => read.user == 7 && read.cursor == null),
        isTrue,
      );
    },
  );

  test('Favorites cursor session preserves filtered continuation and rejects late refreshed replies', () async {
    final requests = <String?>[];
    final delayed = Completer<PixivBookmarkPage>();
    final tokens = <CancelToken>[];
    var round = 0;
    final session = PixivWorkFavoritesSession((cursor, token) {
      requests.add(cursor);
      tokens.add(token);
      round++;
      if (round == 2) return delayed.future;
      return Future.value(
        PixivBookmarkPage(
          round == 1 ? [work(visible: false)] : [work(id: 220)],
          nextBookmarkId: round == 1 ? '900' : null,
        ),
      );
    });
    addTearDown(session.dispose);
    final first = await session.fetch(1);
    expect(first.hasMore, isTrue);
    final old = session.fetch(2);
    final revoked = expectLater(old, throwsStateError);
    final fresh = await session.fetch(1);
    expect(fresh.illusts.single.id, 220);
    expect(tokens[1].isCancelled, isTrue);
    delayed.complete(PixivBookmarkPage([work(id: 999)], nextBookmarkId: '800'));
    await revoked;
    expect((await session.fetch(2)).illusts, isEmpty);
    expect(requests, [null, '900', null]);
  });
}
