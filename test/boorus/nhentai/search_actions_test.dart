import 'package:booru_clients/nhentai.dart';
import 'package:boorusama/boorus/nhentai/availability.dart';
import 'package:boorusama/boorus/nhentai/client_provider.dart';
import 'package:boorusama/boorus/nhentai/favorites/account.dart';
import 'package:boorusama/boorus/nhentai/favorites/cache.dart';
import 'package:boorusama/boorus/nhentai/galleries/listing.dart';
import 'package:boorusama/boorus/nhentai/galleries/source.dart';
import 'package:boorusama/boorus/nhentai/search/page.dart';
import 'package:boorusama/boorus/nhentai/tags/store.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/cache/providers.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/configs/manage/providers.dart';
import 'package:boorusama/core/content/anonymous_source_policy.dart';
import 'package:boorusama/core/content/content_access_provider.dart';
import 'package:boorusama/core/content/nhentai_public_transport.dart';
import 'package:boorusama/core/content/types.dart';
import 'package:boorusama/core/content/widgets/native_content_configuration_header.dart';
import 'package:boorusama/core/posts/favorites/widgets.dart';
import 'package:boorusama/core/posts/listing/types.dart';
import 'package:boorusama/core/posts/listing/src/widgets/timeline_toolbar.dart';
import 'package:boorusama/core/search/search/routes.dart';
import 'package:boorusama/core/search/selected_tags/types.dart';
import 'package:boorusama/core/settings/types.dart';
import 'package:boorusama/core/themes/colors/providers.dart';
import 'package:boorusama/core/themes/colors/src/utils.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';

import '../../core/search/following_topics/following_topic_test_utils.dart';
import '../../support/fakes/memory_repositories.dart'
    show MemoryPersistentCacheStore;
import 'fixtures.dart';
import 'tag_store_test.dart' show Cache;

void main() {
  testWidgets('Favorites pages update the thumbnail cache on demand', (
    tester,
  ) async {
    final config = galleryAccess().config!.copyWith(
      apiKey: 'synthetic-gallery-api-key',
    );
    final access = ContentAccessContext.profile(
      config: config,
      authEpoch: 1,
      policyEpoch: 1,
    );
    final requests = <(String, String, int?)>[];
    final dio = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (request, handler) {
            final page = int.tryParse(
              request.uri.queryParameters['page'] ?? '',
            );
            requests.add((request.method, request.uri.path, page));
            handler.resolve(
              Response(
                requestOptions: request,
                statusCode: 200,
                data: {
                  'result': [
                    {'id': 100 + (page ?? 0), 'english_title': 'Gallery $page'},
                  ],
                  'num_pages': 2,
                  'total': 2,
                  'per_page': 1,
                },
              ),
            );
          },
        ),
      );
    final tags = NhentaiTagCache(
      store: NhentaiPersistentTagStore(Cache()),
      lookup: (_, _) async => [],
      catalog: (_, _, _, _) async => throw StateError('unexpected preload'),
    );
    final source = NhentaiGallerySource(
      access: access,
      fetchGallery: (_) async => throw StateError('unexpected Gallery read'),
      mediaPolicy: () async => galleryPolicy(),
    );
    final publicDio = Dio();
    publicDio.httpClientAdapter = NhentaiPublicTransport(
      dio: publicDio,
      source: const AnonymousSourcePolicy(nhentaiEnabled: true)
          .resolve(BooruType.nhentai, Uri.parse(config.url))!,
      current: () => true,
    );
    addTearDown(() => dio.close(force: true));
    addTearDown(() => publicDio.close(force: true));
    addTearDown(tags.dispose);
    addTearDown(source.dispose);
    final harness = FollowingTopicHarness(
      profiles: [config],
      listingSettings: Settings.defaultSettings.listing.copyWith(
        pageMode: PageMode.paginated,
      ),
      overrides: [
        currentReadOnlyBooruConfigProvider.overrideWithValue(config),
        contentProfileAccessProvider.overrideWith(() => _ProfileAccess(access)),
        contentAccessContextProvider(access.key).overrideWithValue(access),
        persistentCacheStoreProvider.overrideWithValue(
          MemoryPersistentCacheStore(),
        ),
        nhentaiAccountClientProvider(access.key).overrideWithValue(
          NhentaiAccountClient(dio: dio),
        ),
        nhentaiDioProvider(config.auth).overrideWithValue(publicDio),
        nhentaiGalleryListingProvider(access.key).overrideWithValue(
          NhentaiGalleryListing(
            source: source,
            blacklist: const {},
            cache: tags,
            current: () => true,
          ),
        ),
      ],
    );
    addTearDown(harness.dispose);
    final provider = nhentaiFavoriteCacheProvider(nhentaiFavoriteOwner(access));
    await harness.pump(tester, const NhentaiFavoritesPage());
    final heart = find.byType(QuickFavoriteButton).hitTestable();
    expect(tester.widget<QuickFavoriteButton>(heart).isFaved, isTrue);
    expect(harness.container.read(provider).ids, {101});
    expect(requests, [('GET', '/api/v2/favorites', 1)]);

    await tester.tap(find.byTooltip('Next Page'));
    await tester.pumpAndSettle();
    expect(tester.widget<QuickFavoriteButton>(heart).isFaved, isTrue);
    expect(harness.container.read(provider).ids, {101, 102});
    expect(requests, [
      ('GET', '/api/v2/favorites', 1),
      ('GET', '/api/v2/favorites', 2),
    ]);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('nhentai search keeps Follow and Share reachable at 320dp', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const query = 'artist:"vanilla cream"';
    final access = galleryAccess();
    final config = access.config!;
    final queries = <String>[];
    final dio = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (request, handler) {
            queries.add(request.uri.queryParameters['query']!);
            handler.resolve(
              Response(
                requestOptions: request,
                statusCode: 200,
                data: {'result': [], 'num_pages': 0, 'total': 0},
              ),
            );
          },
        ),
      );
    final anonymousSource = const AnonymousSourcePolicy(nhentaiEnabled: true)
        .resolve(BooruType.nhentai, Uri.parse(config.url))!;
    dio.httpClientAdapter = NhentaiPublicTransport(
      dio: dio,
      source: anonymousSource,
      current: () => true,
    );
    final cache = NhentaiTagCache(
      store: NhentaiPersistentTagStore(Cache()),
      lookup: (_, _) async => [],
      catalog: (_, _, _, _) async => throw StateError('unexpected preload'),
    );
    final source = NhentaiGallerySource(
      access: access,
      fetchGallery: (_) async => throw StateError('unexpected Gallery read'),
      mediaPolicy: () async => galleryPolicy(),
    );
    addTearDown(() => dio.close(force: true));
    addTearDown(cache.dispose);
    addTearDown(source.dispose);
    final harness = FollowingTopicHarness(
      profiles: [config],
      supported: false,
      overrides: [
        currentReadOnlyBooruConfigProvider.overrideWithValue(config),
        nhentaiAvailableProvider.overrideWithValue(true),
        booruChipColorsProvider.overrideWithValue(
          BooruChipColors.colorScheme(
            ColorScheme.fromSeed(seedColor: Colors.blue),
          ),
        ),
        contentProfileAccessProvider.overrideWith(() => _ProfileAccess(access)),
        contentAccessContextProvider(access.key).overrideWithValue(access),
        nhentaiDioProvider(config.auth).overrideWithValue(dio),
        nhentaiGalleryListingProvider(access.key).overrideWithValue(
          NhentaiGalleryListing(
            source: source,
            blacklist: const {},
            cache: cache,
            current: () => true,
          ),
        ),
      ],
    );
    addTearDown(harness.dispose);
    await harness.pump(
      tester,
      Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(2)),
          child: NhentaiSearchPage(
            params: SearchParams(
              tags: SearchTagSet.fromList(const [query]),
              queryType: QueryType.list,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(queries, [query]);
    expect(find.text('0 Posts'), findsOneWidget);
    final toolbar = find.byType(TimelineToolbar);
    final follow = find.descendant(
      of: toolbar,
      matching: find.byTooltip('Follow'),
    );
    expect(follow.hitTestable(), findsOneWidget);
    final overflow = find
        .descendant(
          of: find.byType(NativeContentConfigurationHeader),
          matching: find.byType(KurumiPopupMenuButton),
        )
        .last;
    expect(tester.getSize(overflow), const Size.square(48));
    await tester.tap(overflow);
    await tester.pumpAndSettle();
    expect(find.text('Share'), findsOneWidget);
    await tester.tapAt(const Offset(20, 30));
    await tester.pumpAndSettle();
    expect(find.text('Share'), findsNothing);
    await tester.tap(follow);
    await settle(tester);
    await tester.tap(find.text('Home'));
    await tester.tap(find.widgetWithText(FilledButton, 'Done'));
    await tester.pumpAndSettle();
    final topic = (await harness.repository.getAll()).single;
    expect(topic.profileId, config.id);
    expect(topic.query, query);
    expect(topic.queryStructure?.typedTags, [query]);
    expect(find.byTooltip('Following'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

class _ProfileAccess extends ContentProfileAccess {
  _ProfileAccess(this.access);

  final ContentAccessContext access;

  @override
  ContentAccessContext build(String profileId) => access;
}
