import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:boorusama/boorus/danbooru/pools/bookmarks.dart';
import 'package:boorusama/boorus/danbooru/pools/group_capability.dart';
import 'package:boorusama/core/blacklists/providers.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/bookmark_group_hive_object.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/bookmark_group_repository_hive.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/bookmark_hive_object.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/unified_bookmark_repository.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/unified_bookmark_group_repository.dart';
import 'package:boorusama/core/bookmarks/providers.dart';
import 'package:boorusama/core/bookmarks/src/providers/pool_bookmark_provider.dart';
import 'package:boorusama/core/bookmarks/src/widgets/bookmark_pool_card.dart';
import 'package:boorusama/core/bookmarks/types.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/configs/manage/providers.dart';
import 'package:boorusama/core/content/anonymous_access_provider.dart';
import 'package:boorusama/core/content/anonymous_read_scope.dart';
import 'package:boorusama/core/content/anonymous_source_policy.dart';
import 'package:boorusama/core/content/groups/group_source_provider.dart';
import 'package:boorusama/core/content/types.dart';
import 'package:boorusama/core/hive/hive_adapters.dart';
import 'package:boorusama/core/posts/post/providers.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/posts/related/related_family.dart';
import 'package:boorusama/core/posts/related/related_posts_order.dart';
import 'package:boorusama/foundation/data_mutation_coordinator.dart';
import 'package:dio/dio.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foundation/foundation.dart';
import 'package:hive_ce/hive.dart';
import 'package:oktoast/oktoast.dart';

import '../core/bookmarks/pool_bookmark_test_utils.dart';
import 'support/app_flow_driver.dart';
import 'support/fake_booru_backend.dart';
import 'support/fake_image_dio.dart';
import 'support/headless_app_harness.dart';

const _site = 'https://safebooru.donmai.us';
final _allowed = StateProvider<bool>((ref) => true);

class _Profiles extends BooruConfigNotifier {
  _Profiles() : super(initialConfigs: []);
  void replace(List<BooruConfig> values) => state = values;
}

void main() {
  testWidgets(
    'public Pool refresh preserves identity, membership and Added date',
    (tester) async {
      final f = await _Fixture.mount(tester);
      final before = f.container
          .read(bookmarkProvider)
          .requireValue
          .pools
          .single;
      final beforeRecord = f.container
          .read(bookmarkProvider)
          .requireValue
          .byId[before.bookmarkId]!;
      await f.refresh(tester);
      await f.harness.pumpUntil(
        tester,
        () =>
            f.container
                .read(bookmarkProvider)
                .valueOrNull
                ?.pools
                .single
                .tags
                .contains('refreshed') ??
            false,
      );
      final state = f.container.read(bookmarkProvider).requireValue;
      final after = state.pools.single;
      final record = state.byId[after.bookmarkId] as ContentGroupBookmark;
      expect(after.bookmarkId, before.bookmarkId);
      expect(after.identity, before.identity);
      expect(after.groupIds, before.groupIds);
      expect(after.addedAt, before.addedAt);
      expect(
        record.createdAt,
        (beforeRecord as ContentGroupBookmark).createdAt,
      );
      expect(record.sourceProfileHint, isNull);
      expect(record.reference.sourceKey, 'pool:10');
      expect(f.container.read(booruConfigProvider), isEmpty);
      expect(f.metadataRequests, 1);
      expect(f.privateRequests, 0);
      dismissAllToast(showAnim: false);
      await tester.pump(const Duration(seconds: 6));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('revoking public scope during Pool metadata rejects the update', (
    tester,
  ) async {
    final f = await _Fixture.mount(tester, holdMetadata: true);
    final before = f.container.read(bookmarkProvider).requireValue.pools.single;
    await f.refresh(tester);
    await f.harness.pumpUntil(tester, () => f.started.isCompleted);
    f.container.read(_allowed.notifier).state = false;
    final profiles =
        f.container.read(booruConfigProvider.notifier) as _Profiles;
    profiles.replace([f.privateConfig]);
    await tester.pump();
    f.gate!.complete();
    await f.harness.settle(tester);
    await tester.pump();
    final after = f.container.read(bookmarkProvider).requireValue.pools.single;
    expect(after, before);
    expect(f.privateRequests, 0);
    dismissAllToast(showAnim: false);
    await tester.pump(const Duration(seconds: 6));
    expect(tester.takeException(), isNull);
  });

  testWidgets('public Related refresh keeps saved order and membership', (
    tester,
  ) async {
    final f = await _Fixture.mount(tester, related: true);
    final id = f.container
        .read(bookmarkProvider)
        .requireValue
        .pools
        .single
        .bookmarkId!;
    await f.harness.pumpUntilComplete(
      tester,
      f.container
          .read(bookmarkProvider.notifier)
          .setRelatedOrder(id, RelatedPostsOrder.newest),
    );
    final before = f.container.read(bookmarkProvider).requireValue.pools.single;
    final savedBefore =
        f.container.read(bookmarkProvider).requireValue.byId[id]
            as RelatedBookmark;
    expect(savedBefore.preferredOrder, RelatedPostsOrder.newest);
    await f.refresh(tester);
    await f.harness.pumpUntil(
      tester,
      () =>
          f.container
              .read(bookmarkProvider)
              .valueOrNull
              ?.pools
              .single
              .observedAt
              .isAfter(before.observedAt) ??
          false,
    );
    final state = f.container.read(bookmarkProvider).requireValue;
    final after = state.pools.single;
    final savedAfter = state.byId[id] as RelatedBookmark;
    expect(after.bookmarkId, id);
    expect(after.identity, before.identity);
    expect(after.groupIds, before.groupIds);
    expect(after.addedAt, before.addedAt);
    expect(savedAfter.createdAt, savedBefore.createdAt);
    expect(savedAfter.preferredOrder, RelatedPostsOrder.newest);
    expect(savedAfter.sourceProfileHint, isNull);
    expect(savedAfter.reference.sourceKey, 'related:10');
    expect(f.queries, contains('parent:10'));
    expect(f.container.read(booruConfigProvider), isEmpty);
    expect(f.privateRequests, 0);
    dismissAllToast(showAnim: false);
    await tester.pump(const Duration(seconds: 6));
    expect(tester.takeException(), isNull);
  });
}

class _Fixture {
  _Fixture(this.backend, this.gate);
  final FakeBooruBackend backend;
  final Completer<void>? gate;
  final started = Completer<void>();
  late HeadlessAppHarness harness;
  late ProviderContainer container;
  int metadataRequests = 0;
  int privateRequests = 0;
  final queries = <String>[];
  BooruConfig get privateConfig => BooruConfig.fromJson({
    ...backend.config.toJson(),
    'url': _site,
    'apiKey': 'private-fixture',
  });
  static Future<_Fixture> mount(
    WidgetTester tester, {
    bool holdMetadata = false,
    bool related = false,
  }) async {
    final backend = FakeBooruBackend();
    final f = _Fixture(backend, holdMetadata ? Completer<void>() : null);
    Hive.init('/public-refresh-memory');
    if (!Hive.isAdapterRegistered(4))
      Hive.registerAdapter(BookmarkHiveObjectAdapter());
    if (!Hive.isAdapterRegistered(5))
      Hive.registerAdapter(BookmarkGroupHiveObjectAdapter());
    final rows = await Hive.openBox<BookmarkHiveObject>(
      'posts',
      bytes: Uint8List(0),
    );
    final payloads = await Hive.openBox<dynamic>(
      'payloads',
      bytes: Uint8List(0),
    );
    final metadata = await Hive.openBox<dynamic>(
      'metadata',
      bytes: Uint8List(0),
    );
    const groupName = 'groups_unified_v2';
    const organizationName = 'organization_unified_v2';
    final groupRows = await Hive.openBox<BookmarkGroupHiveObject>(
      groupName,
      bytes: Uint8List(0),
    );
    final organization = await Hive.openBox<dynamic>(
      organizationName,
      bytes: Uint8List(0),
    );
    final coordinator = DataMutationCoordinator();
    final posts = BookmarkHiveRepository(
      rows,
      groupPayloadBox: payloads,
      metadataBox: metadata,
      coordinator: coordinator,
      postDataCodec: (_) => const EmptyPostDataCodec('test'),
      syncBoxes: (_) async {},
    );
    await metadata.put('activeOrganization', {
      'version': 2,
      'generation': {'groups': groupName, 'organization': organizationName},
    });
    await IOOverrides.runZoned(
      posts.readAll,
      createFile: (path) {
        if (path == '/public-refresh-memory/$groupName.hive' ||
            path == '/public-refresh-memory/$organizationName.hive')
          return _PresentFile();
        throw StateError('Unexpected fixture filesystem path');
      },
    );
    final groups = UnifiedBookmarkGroupRepository(
      bookmarks: posts,
      reader: BookmarkGroupRepositoryHive(
        groupRows,
        organizationBox: organization,
      ),
    );
    addTearDown(Hive.close);
    await groups.createGroup('Pool target', id: poolGroupA);
    final origin = PostOrigin.fromSource(
      booruType: BooruType.danbooru,
      booruId: BooruType.danbooru.id,
      source: _site,
    );
    final pool = testPool().copyWith(
      origin: origin,
      sourceSite: () => Uri.parse(_site),
    );
    await groups.writePoolBookmarks([
      if (related)
        RelatedCollectionBookmark(
          family: RelatedFamilyReference(origin: origin, anchorId: 10),
          localId: poolGroupB,
          sourceSite: Uri.parse(_site),
          createdAt: DateTime.utc(2020),
          observedAt: DateTime.utc(2021),
          groupIds: {poolGroupA},
        )
      else
        pool,
    ]);
    final source = const AnonymousSourcePolicy().resolve(
      BooruType.danbooru,
      Uri.parse(_site),
    )!;
    final dio = Dio(BaseOptions(baseUrl: _site))
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) async {
            f.metadataRequests++;
            if (!f.started.isCompleted) f.started.complete();
            await f.gate?.future;
            handler.resolve(
              Response<dynamic>(
                requestOptions: options,
                statusCode: 200,
                data: {
                  'id': 10,
                  'name': 'Updated Pool',
                  'category': 'series',
                  'post_count': 2,
                  'post_ids': [101, 102],
                },
              ),
            );
          },
        ),
      );
    final runtime = backend.createRuntime(bookmarkRepository: posts);
    f.harness = await HeadlessAppHarness.mount(
      tester,
      booruBackend: backend,
      runtime: runtime,
      additionalOverrides: [
        booruConfigProvider.overrideWith(_Profiles.new),
        dataMutationCoordinatorProvider.overrideWithValue(coordinator),
        bookmarkGroupRepoProvider.overrideWith((_) async => groups),
        booruGroupCapabilityProvider.overrideWith(
          (ref, type) => type == BooruType.danbooru
              ? createDanbooruGroupCapability(ref)
              : null,
        ),
        poolBookmarkCapabilityProvider.overrideWith(
          (ref, _) => DanbooruPoolBookmarks(ref),
        ),
        blacklistTagsProvider.overrideWith((_, _) async => <String>{}),
        anonymousContentAccessProvider.overrideWith((ref, requested) {
          if (!ref.watch(_allowed) || requested != source) return null;
          final key = ContentAccessKey(
            engine: source.engine,
            siteNamespace: source.site.host,
            authEpoch: 1,
            policyEpoch: 1,
          );
          final scope = AnonymousReadScope(
            source: source,
            key: key,
            current: () => ref.read(_allowed),
            createDio: () => dio,
          );
          ref.onDispose(scope.dispose);
          final config = BooruConfig.fromJson({
            ...BooruConfig.empty.toJson(),
            'id': '00000000-0000-4000-8000-000000000000',
            'url': _site,
            'booruId': BooruType.danbooru.id,
            'booruIdHint': BooruType.danbooru.id,
          });
          return ContentAccessContext.anonymous(
            config: config.copyWith(anonymousReadScope: scope),
            scope: scope,
          );
        }),
        originAwarePostRepoProvider.overrideWith((ref, config) {
          if (config.anonymousReadScope == null) f.privateRequests++;
          return _Posts(config, f.queries);
        }),
        deterministicImageDioOverride(),
        deterministicFaviconDioOverride(),
      ],
    );
    addTearDown(() => dio.close(force: true));
    await AppFlowDriver(tester: tester, harness: f.harness).openBookmarks();
    await f.harness.pumpUntilFound(tester, find.byType(BookmarkPoolCard));
    f.container = ProviderScope.containerOf(
      tester.element(find.byType(BookmarkPoolCard)),
      listen: false,
    );
    return f;
  }

  Future<void> refresh(WidgetTester tester) async {
    await tester.tap(
      find.byType(BookmarkPoolCard),
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
    await harness.pumpUntilFound(tester, find.text('Refresh metadata'));
    await tester.tap(find.text('Refresh metadata'));
  }
}

class _Posts implements PostRepository<Post> {
  _Posts(this.config, this.queries);
  final BooruConfig config;
  final List<String> queries;
  @override
  PostsOrError<Post> getPosts(
    String tags,
    int page, {
    int? limit,
    PostFetchOptions? options,
  }) {
    queries.add(tags);
    return TaskEither.right(
      PostResult<Post>(
        posts: [
          (tags == 'parent:10'
                  ? testRelatedPost(10)
                  : testPoolPost(1, tags: {'refreshed'}).post)
              .copyWith(origin: postOriginFromConfig(config)),
        ],
        total: 1,
      ),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _PresentFile implements File {
  @override
  Future<bool> exists() async => true;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
