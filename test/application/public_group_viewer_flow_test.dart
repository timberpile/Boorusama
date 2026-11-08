import 'package:flutter/widgets.dart';
import 'package:boorusama/core/router.dart';
import 'package:boorusama/core/posts/links/boorusama_group_link.dart';
import 'package:boorusama/boorus/danbooru/posts/post/providers.dart';

import 'dart:async';

import 'package:boorusama/boorus/danbooru/pools/group_capability.dart';
import 'package:boorusama/boorus/danbooru/pools/details/src/pool_detail_page.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/bookmarks/src/providers/bookmark_provider.dart';
import 'package:boorusama/core/bookmarks/src/providers/bookmark_profile_availability.dart';
import 'package:boorusama/core/bookmarks/src/pages/bookmark_page.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_library_state.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_group.dart';
import 'package:boorusama/core/bookmarks/src/types/content_group_bookmark.dart';
import 'package:boorusama/core/bookmarks/src/types/stored_group_snapshot.dart';
import 'package:boorusama/core/bookmarks/src/widgets/bookmark_pool_card.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/configs/manage/providers.dart';
import 'package:boorusama/core/content/anonymous_access_provider.dart';
import 'package:boorusama/core/content/anonymous_read_scope.dart';
import 'package:boorusama/core/content/anonymous_source_policy.dart';
import 'package:boorusama/core/content/groups/group_source_provider.dart';
import 'package:boorusama/core/content/content_media_access.dart';
import 'package:boorusama/core/content/content_access_provider.dart';
import 'package:boorusama/core/content/types.dart';
import 'package:boorusama/core/posts/listing/widgets.dart';
import 'package:boorusama/core/posts/post/providers.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/posts/details/src/widgets/progressive_post_image.dart';
import 'package:boorusama/core/posts/details/widgets.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foundation/foundation.dart';

import '../support/fakes/test_post.dart';
import 'support/app_flow_driver.dart';
import 'support/app_flow_finders.dart';
import 'support/fake_booru_backend.dart';
import 'support/fake_image_dio.dart';
import 'support/headless_app_harness.dart';

const _site = 'https://safebooru.donmai.us';
final _enabled = StateProvider<bool>((ref) => true);

class _Profiles extends BooruConfigNotifier {
  _Profiles() : super(initialConfigs: []);
  void replace(List<BooruConfig> profiles) => state = profiles;
}

class _Bookmarks extends BookmarkLibraryNotifier {
  _Bookmarks(this.library);
  final BookmarkLibraryState library;
  @override
  BookmarkLibraryState build() => library;
}

void main() {
  testWidgets('root Group link opens public member and returns to Pool', (
    tester,
  ) async {
    final f = await _Fixture.mount(tester);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(Navigator).first),
      listen: false,
    );
    final reference = const ContentReferenceCodec().parse(
      engine: BooruType.danbooru,
      site: Uri.parse(_site),
      kind: ContentKind.group,
      sourceKey: 'pool:42',
    );
    container
        .read(routerProvider)
        .go(BoorusamaGroupLink.fromReference(reference).uri.toString());
    await f.harness.pumpUntilFound(tester, find.byType(PoolDetailContent));
    await f.harness.pumpUntilFound(tester, postTile(101));
    await tester.tap(postTile(101));
    await f.harness.pumpUntil(
      tester,
      () => tester
          .widgetList<PostDetailsPageScaffold>(postDetailsScaffold())
          .any((w) => w.controller?.currentPost.value.id == 101),
    );
    await f.harness.pumpUntilFound(
      tester,
      find.byType(RawProgressivePostImage),
    );
    final media = ProviderScope.containerOf(
      tester.element(find.byType(RawProgressivePostImage).first),
      listen: false,
    );
    final key = media.read(currentContentAccessKeyProvider);
    expect(key, isNotNull);
    expect(key!.profileId, isNull);
    expect(
      media
          .read(contentAccessContextProvider(key))
          ?.config
          ?.anonymousReadScope
          ?.isCurrent,
      isTrue,
    );
    expect(f.privateRequests, 0);
    await tester.binding.handlePopRoute();
    await f.harness.pumpUntilFound(tester, find.byType(PoolDetailContent));
    expect(tester.takeException(), isNull);
  });

  testWidgets('public saved Pool opens its real member viewer and Back', (
    tester,
  ) async {
    final f = await _Fixture.mount(tester);
    await f.open(tester);
    final gallery = tester.widget<PostGrid<Post>>(
      find.descendant(
        of: find.byType(PoolDetailContent),
        matching: find.byType(PostGrid<Post>),
      ),
    );
    await f.harness.pumpUntil(
      tester,
      () => gallery.controller.items.length == 2,
    );
    expect(gallery.controller.items.map((p) => p.id), [101, 102]);
    expect(
      find.textContaining('Public Pool description', findRichText: true),
      findsOneWidget,
    );
    expect(find.byTooltip('Download'), findsNothing);
    await tester.tap(postTile(101));
    await f.harness.settle(tester);
    await f.harness.pumpUntil(
      tester,
      () => tester
          .widgetList<PostDetailsPageScaffold>(postDetailsScaffold())
          .any((scaffold) => scaffold.controller?.currentPost.value.id == 101),
    );
    await f.harness.pumpUntilFound(
      tester,
      find.byType(RawProgressivePostImage),
    );
    final mediaContainer = ProviderScope.containerOf(
      tester.element(find.byType(RawProgressivePostImage).first),
      listen: false,
    );
    final mediaKey = mediaContainer.read(currentContentAccessKeyProvider);
    expect(mediaKey, isNotNull);
    expect(mediaKey!.profileId, isNull);
    expect(
      mediaContainer
          .read(contentAccessContextProvider(mediaKey))
          ?.config
          ?.anonymousReadScope
          ?.isCurrent,
      isTrue,
    );
    await tester.binding.handlePopRoute();
    await f.harness.pumpUntilFound(tester, find.byType(PoolDetailContent));
    expect(
      f.apiPaths.where((path) => path == '/pools/42.json'),
      hasLength(1),
      reason: 'all API paths: ${f.apiPaths}',
    );
    expect(f.apiPaths, ['/pools/42.json']);
    expect(f.privateRequests, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('public Group remains public when a matching profile appears', (
    tester,
  ) async {
    final f = await _Fixture.mount(tester);
    await f.open(tester);
    await f.harness.pumpUntilFound(tester, postTile(101));
    await tester.tap(postTile(101));
    await f.harness.pumpUntilFound(
      tester,
      find.byType(RawProgressivePostImage),
    );
    final profiles = ProviderScope.containerOf(
      tester.element(find.byType(RawProgressivePostImage).first),
      listen: false,
    ).read(booruConfigProvider.notifier) as _Profiles;
    profiles.replace([f.privateConfig]);
    await f.harness.settle(tester);
    final media = ProviderScope.containerOf(
      tester.element(find.byType(RawProgressivePostImage).first),
      listen: false,
    );
    final key = media.read(currentContentAccessKeyProvider);
    expect(key?.profileId, isNull);
    expect(
      media
          .read(contentAccessContextProvider(key!))
          ?.config
          ?.anonymousReadScope
          ?.isCurrent,
      isTrue,
    );
    expect(find.byTooltip('Download'), findsNothing);
    expect(f.privateRequests, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('revoking public access during metadata leaves Back available', (
    tester,
  ) async {
    final f = await _Fixture.mount(tester, holdMetadata: true);
    await f.openCard(tester);
    await f.apiStarted.future;
    f.container.read(_enabled.notifier).state = false;
    await f.harness.settle(tester);
    f.gate!.complete();
    await f.harness.settle(tester);
    await tester.binding.handlePopRoute();
    await f.harness.pumpUntilFound(tester, find.byType(BookmarkPage));
    expect(tester.takeException(), isNull);
  });
}

class _Fixture {
  _Fixture(this.backend, this.gate);
  final FakeBooruBackend backend;
  final Completer<void>? gate;
  final apiStarted = Completer<void>();
  late final HeadlessAppHarness harness;
  late ProviderContainer container;
  var apiRequests = 0;
  final apiPaths = <String>[];
  var privateRequests = 0;
  BooruConfig? publicConfig;
  BooruConfig get privateConfig => BooruConfig.fromJson({
    ...backend.config.toJson(),
    'url': _site,
    'apiKey': 'private-fixture',
  });
  static Future<_Fixture> mount(
    WidgetTester tester, {
    bool holdMetadata = false,
  }) async {
    final backend = FakeBooruBackend();
    final f = _Fixture(backend, holdMetadata ? Completer<void>() : null);
    final reference = const ContentReferenceCodec().parse(
      engine: BooruType.danbooru,
      site: Uri.parse(_site),
      kind: ContentKind.group,
      sourceKey: 'pool:42',
    );
    final saved = ContentGroupBookmark(
      id: 42,
      snapshot: StoredGroupSnapshot(
        summary: ContentGroupSummary(
          reference: reference,
          title: 'Saved Pool',
          memberCount: 2,
        ),
      ),
      createdAt: DateTime.utc(2020),
      observedAt: DateTime.utc(2026),
    );
    final library = BookmarkLibraryState(
      bookmarks: [],
      groups: [
        BookmarkGroup(
          id: defaultBookmarkGroupId,
          name: 'Default',
          bookmarkIds: const {42},
        ),
      ],
      records: [saved],
    );
    final source = const AnonymousSourcePolicy().resolve(
      BooruType.danbooru,
      Uri.parse(_site),
    )!;
    final apiDio = Dio(BaseOptions(baseUrl: _site))
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) async {
            f.apiRequests++;
            f.apiPaths.add(options.path);
            if (!f.apiStarted.isCompleted) f.apiStarted.complete();
            await f.gate?.future;
            handler.resolve(
              Response<dynamic>(
                requestOptions: options,
                statusCode: 200,
                data: {
                  'id': 42,
                  'name': 'Saved Pool',
                  'description': 'Public Pool description',
                  'post_count': 2,
                  'post_ids': [101, 102],
                },
              ),
            );
          },
        ),
      );
    final runtime = backend.createRuntime();
    f.harness = await HeadlessAppHarness.mount(
      tester,
      booruBackend: backend,
      runtime: runtime,
      additionalOverrides: [
        bookmarkProvider.overrideWith(() => _Bookmarks(library)),
        booruConfigProvider.overrideWith(_Profiles.new),
        booruGroupCapabilityProvider.overrideWith(
          (ref, type) => type == BooruType.danbooru
              ? createDanbooruGroupCapability(ref)
              : null,
        ),
        anonymousContentAccessProvider.overrideWith((ref, requested) {
          final enabled = ref.watch(_enabled);
          if (!enabled || requested != source) return null;
          final key = ContentAccessKey(
            engine: source.engine,
            siteNamespace: source.site.host,
            authEpoch: 1,
            policyEpoch: 1,
          );
          final scope = AnonymousReadScope(
            source: source,
            key: key,
            current: () => ref.read(_enabled),
            createDio: () => apiDio,
          );
          ref.onDispose(scope.dispose);
          final config = BooruConfig.fromJson({
            ...BooruConfig.empty.toJson(),
            'id': '00000000-0000-4000-8000-000000000000',
            'url': _site,
            'booruId': BooruType.danbooru.id,
            'booruIdHint': BooruType.danbooru.id,
          });
          final actor = config.copyWith(anonymousReadScope: scope);
          f.publicConfig = actor;
          return ContentAccessContext.anonymous(config: actor, scope: scope);
        }),
        danbooruPostRepoProvider.overrideWith((ref, search) {
          final actor = f.publicConfig!;
          expect(search.auth, actor.auth);
          return ref.read(originAwarePostRepoProvider(actor));
        }),
        originAwarePostRepoProvider.overrideWith((ref, config) {
          if (config.anonymousReadScope == null) f.privateRequests++;
          return _Posts(config);
        }),
        deterministicImageDioOverride(),
        deterministicFaviconDioOverride(),
      ],
    );
    addTearDown(() => apiDio.close(force: true));
    return f;
  }

  Future<void> openCard(WidgetTester tester) async {
    await AppFlowDriver(tester: tester, harness: harness).openBookmarks();
    container = ProviderScope.containerOf(
      tester.element(find.byType(BookmarkPage)),
      listen: false,
    );
    expect(container.read(bookmarkProvider).requireValue.pools, hasLength(1));
    expect(container.read(bookmarkProfileAvailabilityProvider)?.collectionIds, {
      '42',
    });
    await harness.pumpUntilFound(tester, find.byType(BookmarkPoolCard));
    await tester.tap(find.byType(BookmarkPoolCard));
    await harness.settle(tester);
  }

  Future<void> open(WidgetTester tester) async {
    await openCard(tester);
    await harness.pumpUntilFound(tester, find.byType(PoolDetailContent));
  }
}

class _Posts implements PostRepository<Post> {
  _Posts(this.config);
  final BooruConfig config;
  @override
  PostsOrError<Post> getPosts(
    String tags,
    int page, {
    int? limit,
    PostFetchOptions? options,
  }) => TaskEither.right(
    PostResult<Post>(
      posts: [
        for (final id in [101, 102])
          TestPost(
            id: id,
            origin: postOriginFromConfig(config),
            thumbnailImageUrl: 'https://cdn.donmai.us/sample/$id.jpg',
            sampleImageUrl: 'https://cdn.donmai.us/sample/$id.jpg',
            originalImageUrl: 'https://cdn.donmai.us/sample/$id.jpg',
          ),
      ],
      total: 2,
    ),
  );
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
