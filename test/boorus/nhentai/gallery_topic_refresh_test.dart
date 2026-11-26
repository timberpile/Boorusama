import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:booru_clients/nhentai.dart';
import 'package:boorusama/boorus/danbooru/danbooru_repository.dart';
import 'package:boorusama/boorus/nhentai/availability.dart';
import 'package:boorusama/boorus/nhentai/client_provider.dart';
import 'package:boorusama/boorus/nhentai/galleries/followed_search.dart';
import 'package:boorusama/boorus/nhentai/galleries/listing.dart';
import 'package:boorusama/boorus/nhentai/galleries/source.dart';
import 'package:boorusama/boorus/nhentai/tags/store.dart';
import 'package:boorusama/boorus/nhentai/nhentai_repository.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/boorus/engine/providers.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/content/anonymous_source_policy.dart';
import 'package:boorusama/core/content/content_access_provider.dart';
import 'package:boorusama/core/content/nhentai_public_transport.dart';
import 'package:boorusama/core/content/types.dart';
import 'package:boorusama/core/http/client/coordination.dart';
import 'package:boorusama/core/search/following_topics/providers.dart';
import 'package:boorusama/core/search/following_topics/src/data/hive/following_topic_repository_hive.dart';
import 'package:boorusama/core/search/following_topics/src/providers/following_topic_refresh_source_provider.dart';
import 'package:boorusama/core/search/following_topics/src/providers/search_refresh_coordinator.dart';
import 'package:boorusama/core/search/following_topics/src/services/search_refresh_scheduler.dart';
import 'package:boorusama/core/search/following_topics/src/widgets/following_topic_card.dart';
import 'package:boorusama/core/search/following_topics/types.dart';
import 'package:boorusama/core/tags/tag/providers.dart';
import 'package:boorusama/core/themes/colors/providers.dart';
import 'package:boorusama/core/themes/colors/types.dart';
import 'package:clock/clock.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';

import '../../core/search/following_topics/following_topic_test_utils.dart';
import 'fixtures.dart';
import 'tag_store_test.dart' show Cache;

const _query = 'artist:"vanilla cream" -language:japanese';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('a checked Gallery topic omits the unavailable upload date', (
    tester,
  ) async {
    final fixture = _Fixture();
    addTearDown(fixture.dispose);
    final topic = await tester.runAsync(() async {
      final topic = await fixture.seed();
      fixture.transport.respondWith([100]);
      await fixture.notifier.refresh(topic.id);
      return fixture.harness.repository.getById(topic.id);
    });
    expect(topic!.highestSeenPostId, 100);
    await fixture.harness.pump(
      tester,
      Scaffold(
        body: FollowingTopicCard(
          topic: topic,
          config: fixture.config.auth,
          ownerCaption: 'nhentai',
          refreshing: false,
          onOpen: null,
          onAction: (_) {},
        ),
      ),
    );
    expect(find.text('nhentai'), findsOneWidget);
    expect(find.textContaining('Last Post:'), findsNothing);
    expect(find.text('vanilla cream'), findsOneWidget);
    expect(find.text('-japanese'), findsOneWidget);
    expect(find.text('artist:"vanilla cream"'), findsNothing);
    expect(
      tester
          .widgetList<KurumiRawCompactChip>(find.byType(KurumiRawCompactChip))
          .first
          .backgroundColor,
      fixture.palette.fromColor(Colors.purple)?.backgroundColor,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final concurrent in [false, true]) {
    test(
      'Gallery covers reuse the ${concurrent ? 'in-flight' : 'completed'} check',
      () async {
        final fixture = _Fixture(
          loadImages: true,
          includedTags: ['language:"english"'],
        );
        addTearDown(fixture.dispose);
        final topic = await fixture.seed();
        fixture.transport.respondWith([101]);
        final arrived = Completer<void>();
        final release = Completer<void>();
        fixture.transport.beforeResponse = () async {
          arrived.complete();
          if (concurrent) await release.future;
        };
        final check = fixture.notifier.refresh(topic.id);
        await arrived.future;
        if (!concurrent) await check;
        final provider = nhentaiTopicCoversProvider((
          fixture.access.key,
          _query,
          null,
        ));
        final observer = fixture.harness.container.listen(provider, (_, _) {});
        addTearDown(observer.close);
        final result = fixture.harness.container.read(provider.future);
        release.complete();
        expect(await result, [
          'https://t1.nhentai.net/galleries/7001/thumb.webp',
        ]);
        expect(await check, isA<SearchRefreshSucceeded>());
        expect(fixture.transport.requests, hasLength(1));
        fixture.verifyRequests(expectedQuery: 'language:"english" $_query');
      },
    );
  }
  test(
    'automatic Gallery checks keep a single request and a durable NEW count',
    () async {
      final fixture = _Fixture();
      addTearDown(fixture.dispose);
      final repository = fixture.harness.repository;
      final topic = await fixture.seed();
      expect(fixture.config.auth.apiKey, isNull);
      expect(
        fixture.harness.container.read(
          followingTopicQueryTrackingSupportedProvider(fixture.config.auth),
        )(_query),
        isTrue,
      );

      fixture.transport.respondWith([]);
      final baseline = await fixture.notifier.refresh(topic.id);
      expect(baseline, isA<SearchRefreshSucceeded>());
      expect((baseline as SearchRefreshSucceeded).baseline, isTrue);
      expect(baseline.topic.hasNewPosts, isFalse);
      expect(baseline.topic.lastSuccessfulCheckAt, isNotNull);

      fixture.now = baseline.topic.lastSuccessfulCheckAt!.add(
        const Duration(days: 2),
      );
      fixture.transport.respondWith([100, 99]);
      final coordinator = fixture.harness.container.read(
        searchRefreshCoordinatorProvider.notifier,
      );
      coordinator.setForeground(true);
      expect(await coordinator.run(), 1);
      coordinator.setForeground(false);
      final firstMatch = (await repository.getById(topic.id))!;
      expect(firstMatch.highestSeenPostId, 100);
      expect(firstMatch.newPostCountEstimate, 2);
      expect(firstMatch.newPostCountIsLowerBound, isFalse);

      fixture.now = fixture.now.add(const Duration(days: 1));
      fixture.transport.respondWith(
        List.generate(25, (index) => 200 - index),
        pages: 4,
      );
      expect(
        await fixture.notifier.refresh(topic.id),
        isA<SearchRefreshSucceeded>(),
      );
      final reopened = HiveFollowingTopicRepository(
        box: fixture.harness.box,
        organizationBox: fixture.harness.organizationBox,
      );
      final saved = (await reopened.getById(topic.id))!;
      expect(saved.highestSeenPostId, 200);
      expect(saved.hasNewPosts, isTrue);
      expect(saved.newPostCountEstimate, 27);
      expect(saved.newPostCountIsLowerBound, isTrue);

      await fixture.notifier.markRead(topic.id);
      fixture.now = fixture.now.add(const Duration(days: 1));
      fixture.transport.respondWith([201, 200, 199], pages: 4);
      await fixture.notifier.refresh(topic.id);
      final overlap = (await repository.getById(topic.id))!;
      expect(overlap.newPostCountEstimate, 1);
      expect(overlap.newPostCountIsLowerBound, isFalse);
      await fixture.notifier.markRead(topic.id);
      expect((await reopened.getById(topic.id))!.hasNewPosts, isFalse);
      expect(fixture.transport.requests, hasLength(4));
      fixture.verifyRequests();
    },
  );

  test(
    'invalid or cancelled Gallery pages and cooldown preserve the checkpoint',
    () async {
      final fixture = _Fixture();
      addTearDown(fixture.dispose);
      final topic = await fixture.seed();
      fixture.transport.respondWith([100]);
      await fixture.notifier.refresh(topic.id);
      final before = (await fixture.harness.repository.getById(topic.id))!;

      fixture.transport.respondWith([102, 102, 100]);
      expect(
        await fixture.notifier.refresh(topic.id),
        const SearchRefreshFailed(SearchRefreshErrorKind.pagination),
      );
      final invalid = (await fixture.harness.repository.getById(topic.id))!;
      expect(invalid.lastSuccessfulCheckAt, before.lastSuccessfulCheckAt);
      expect(invalid.highestSeenPostId, before.highestSeenPostId);
      expect(invalid.hasNewPosts, isFalse);

      fixture.transport.respondWith([103]);
      final entered = Completer<void>();
      final release = Completer<void>();
      fixture.transport.beforeResponse = () async {
        entered.complete();
        await release.future;
      };
      final cancel = CancelToken();
      final pending = fixture.notifier.refresh(topic.id, cancelToken: cancel);
      await entered.future;
      cancel.cancel();
      release.complete();
      expect(await pending, const SearchRefreshDiscarded());

      fixture.transport.beforeResponse = null;
      fixture.transport.status = 429;
      expect(
        await fixture.notifier.refresh(topic.id),
        isA<SearchRefreshDeferred>(),
      );
      final saved = (await fixture.harness.repository.getById(topic.id))!;
      expect(saved.lastSuccessfulCheckAt, before.lastSuccessfulCheckAt);
      expect(saved.highestSeenPostId, before.highestSeenPostId);
      expect(saved.hasNewPosts, isFalse);
      fixture.verifyRequests();
    },
  );

  test('a mixed folder keeps Gallery tracking out of its Post feed', () async {
    final fixture = _Fixture();
    addTearDown(fixture.dispose);
    final notifier = fixture.notifier;
    await fixture.harness.container.read(followingTopicsProvider.future);
    final folder = await notifier.createSharedFolder(
      'Mixed',
      feedEnabled: true,
    );
    final gallery = await notifier.followLocally(
      profileId: fixture.config.id,
      query: _query,
      name: null,
      folderId: folder.id,
    );
    final post = await notifier.followLocally(
      profileId: testProfile.id,
      query: 'cat',
      name: null,
      folderId: folder.id,
    );
    final feed = await notifier.openFolderFeed(folder.id);
    expect(feed!.sourceIds, [post.id]);
    fixture.transport.respondWith([100]);
    expect(await notifier.refresh(gallery.id), isA<SearchRefreshSucceeded>());
    final saved = (await fixture.harness.repository.getFeeds()).single;
    expect(saved.sourceIds, [post.id]);
    expect(saved.posts, isEmpty);
    fixture.verifyRequests();
  });
}

class _Fixture {
  _Fixture({bool loadImages = false, List<String> includedTags = const []}) {
    access = galleryAccess(includedTags: includedTags);
    final clock = Clock(() => now);
    coordinator = ApiRequestCoordinator(now: clock.now);
    final source = const AnonymousSourcePolicy(nhentaiEnabled: true)
        .resolve(BooruType.nhentai, Uri.parse(config.url))!;
    dio = Dio()..httpClientAdapter = transport;
    dio.httpClientAdapter = NhentaiPublicTransport(
      dio: dio,
      source: source,
      current: () => true,
    );
    coordinateApiDio(dio, coordinator);
    harness = FollowingTopicHarness(
      clock: clock,
      profiles: [config, testProfile],
      loadImages: loadImages,
      networkAllowed: true,
      scheduler: SearchRefreshScheduler(clock: clock, spacing: Duration.zero),
      overrides: [
        booruRepoProvider.overrideWith(
          (ref, auth) => auth.booruType == BooruType.nhentai
              ? NhentaiRepository(ref: ref)
              : DanbooruRepository(ref: ref),
        ),
        followingTopicsProvider.overrideWith(FollowingTopicsNotifier.new),
        nhentaiAvailableProvider.overrideWithValue(true),
        nhentaiDioProvider(config.auth).overrideWithValue(dio),
        contentAccessContextProvider(access.key).overrideWithValue(access),
        nhentaiGalleryListingProvider(access.key).overrideWithValue(
          NhentaiGalleryListing(
            source: gallerySource,
            blacklist: const {},
            cache: tags,
            current: () => true,
          ),
        ),
        booruChipColorsProvider.overrideWithValue(palette),
        tagColorProvider((config.auth, 'artist'))
            .overrideWithValue(Colors.purple),
      ],
    );
  }

  late final ContentAccessContext access;
  BooruConfig get config => access.config!;
  late final gallerySource = NhentaiGallerySource(
    access: access,
    fetchGallery: (_) async =>
        throw StateError('unexpected Gallery detail read'),
    mediaPolicy: () async => galleryPolicy(),
  );
  final tags = NhentaiTagCache(
    store: NhentaiPersistentTagStore(Cache()),
    lookup: (_, _) async => [],
    catalog: (_, _, _, _) async =>
        throw StateError('unexpected tag catalog read'),
  );
  final palette = BooruChipColors.colorScheme(
    ColorScheme.fromSeed(seedColor: Colors.blue),
  );
  var now = DateTime.utc(2026, 11, 25);
  final transport = _GallerySearchTransport();
  late final Dio dio;
  late final ApiRequestCoordinator coordinator;
  late final FollowingTopicHarness harness;

  FollowingTopicsNotifier get notifier =>
      harness.container.read(followingTopicsProvider.notifier);

  Future<FollowingTopic> seed() async {
    final topic = await harness.repository.create(
      profileId: config.id,
      query: _query,
      name: null,
    );
    await harness.container.read(followingTopicsProvider.future);
    return topic;
  }

  void verifyRequests({String expectedQuery = _query}) {
    for (final request in transport.requests) {
      expect(request.method, 'GET');
      expect(request.uri.path, '/api/v2/search');
      expect(request.uri.queryParameters, {
        'page': '1',
        'query': expectedQuery,
      });
      expect(
        request.headers.keys.map((key) => key.toLowerCase()),
        isNot(contains('authorization')),
      );
    }
  }

  void dispose() {
    harness.dispose();
    gallerySource.dispose();
    tags.dispose();
    dio.close(force: true);
    coordinator.dispose();
  }
}

class _GallerySearchTransport implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  var ids = <int>[];
  var pages = 0;
  var status = 200;
  Future<void> Function()? beforeResponse;

  void respondWith(List<int> galleries, {int? pages}) {
    ids = galleries;
    this.pages = pages ?? (ids.isEmpty ? 0 : 1);
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    await beforeResponse?.call();
    return ResponseBody.fromString(
      jsonEncode({
        'result': [
          for (final id in ids)
            {
              'id': id,
              'media_id': '7001',
              'thumbnail': 'galleries/7001/thumb.webp',
            },
        ],
        'num_pages': pages,
        'total': pages > 1 ? 100 : ids.length,
      }),
      status,
      headers: {
        'Content-Type': ['application/json'],
        if (status == 429) 'Retry-After': ['60'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
