import 'dart:io';
import 'dart:typed_data';

import 'package:boorusama/boorus/gelbooru_v2/client_provider.dart';
import 'package:boorusama/boorus/gelbooru_v2/gelbooru_v2.dart';
import 'package:boorusama/boorus/gelbooru_v2/gelbooru_v2_provider.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/boorus/engine/providers.dart';
import 'package:boorusama/core/boorus/engine/types.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/http/client/coordination.dart';
import 'package:boorusama/core/posts/post/providers.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/search/following_topics/providers.dart';
import 'package:boorusama/core/search/following_topics/src/providers/untracked_topic_preview_provider.dart';
import 'package:boorusama/core/search/following_topics/src/widgets/following_topic_card.dart';
import 'package:boorusama/core/search/following_topics/types.dart';
import 'package:boorusama/core/images/booru_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:yaml/yaml.dart';

import 'following_topic_test_utils.dart';

void main() {
  final config = BooruConfig.fromJson({
    ...BooruConfig.defaultConfig(
      booruType: BooruType.gelbooruV2,
      url: 'https://realbooru.com/',
      customDownloadFileNameFormat: null,
    ).toJson(),
    'id': '00000000-0000-4000-8000-000000000065',
  });
  final components = createGelbooruV2();
  final booru = components.parser.parse() as GelbooruV2;

  test('generated Realbooru override matches tracked YAML', () {
    final yaml = loadYaml(
      File('packages/booru_clients/boorus.yaml').readAsStringSync(),
    ) as List;
    final engine =
        yaml.cast<Map>().firstWhere(
              (entry) => entry.containsKey('gelbooru_v2'),
            )['gelbooru_v2']
            as Map;
    final sites = engine['sites'] as List;
    final site = sites.cast<Map>().firstWhere(
      (site) => site['url'] == config.url,
    );
    final generated = BooruYamlConfigs.gelbooruV2.sites.firstWhere(
      (site) => site.url == config.url,
    );
    expect(generated.metadata['overrides'], site['overrides']);
    final caps = booru.getCapabilitiesForSite(config.url)!.posts!;
    expect(caps.thumbnailOnly, isTrue);
    expect(caps.fixedLimit, 42);
    expect(caps.paginationType, 'offset');
  });

  for (final typed in [false, true]) {
    testWidgets(
      'Realbooru configured HTML search and Topic preview remain bounded ($typed)',
      (tester) async {
        final coordinator = ApiRequestCoordinator();
        addTearDown(coordinator.dispose);
        final transport = _HtmlTransport();
        final dio = Dio(BaseOptions(baseUrl: config.url))
          ..httpClientAdapter = transport;
        coordinateApiDio(dio, coordinator);
        addTearDown(() => dio.close(force: true));
        final harness = FollowingTopicHarness(
          profiles: [config],
          supported: false,
          loadImages: true,
          overrides: [
            gelbooruV2Provider.overrideWithValue(booru),
            gelbooruV2DioProvider.overrideWith((ref, _) => dio),
          ],
        );
        addTearDown(harness.dispose);
        final registry = harness.container.read(booruEngineRegistryProvider);
        final engineProvider = Provider(
          (ref) => BooruEngine(
            booru: booru,
            builder: components.createBuilder(),
            repository: components.createRepository(ref),
          ),
        );
        final engine = harness.container.read(engineProvider);
        registry.register(BooruType.gelbooruV2, engine);
        expect(
          engine.repository.searchRefreshQueryAdapter(config.auth).isSupported,
          isFalse,
        );
        final topic = topicFixture(
          profileId: config.id,
          query: 'cat rating:safe',
          error: SearchRefreshErrorKind.unsupported,
          queryStructure: typed
              ? SearchQueryStructure.typedTags(const ['cat', 'rating:safe'])
              : null,
        );
        await harness.seed([topic]);
        final before = await harness.repository.getAll();
        final mutations = harness.box.mutationCount;
        await tester.runAsync(() async {
          final normal =
              (await harness.container
                      .read(originAwarePostRepoProvider(config))
                      .getPosts(
                        topic.query,
                        1,
                        limit: 42,
                        options: PostFetchOptions.raw,
                      )
                      .run())
                  .getOrElse((error) => throw error);
          expect(normal.posts, hasLength(6));
          expect(normal.posts.every((post) => post.createdAt == null), isTrue);
          final key = (
            config: config,
            query: topic.query,
            structure: topic.queryStructure,
            revision: topic.runtimeRevision,
            attemptedAt: topic.lastAttemptAt,
          );
          final provider = untrackedTopicPreviewProvider(key);
          final listener = harness.container.listen(provider, (_, _) {});
          addTearDown(listener.close);
          final urls = await harness.container.read(provider.future);
          expect(
            urls,
            normal.posts.take(4).map((post) => post.thumbnailImageUrl).toList(),
          );
          expect(urls, hasLength(4));
          expect(transport.requests, hasLength(2));
          for (final request in transport.requests) {
            expect(request.uri.host, 'realbooru.com');
            expect(request.uri.path, '/index.php');
            expect(request.uri.queryParameters, containsPair('page', 'post'));
            expect(request.uri.queryParameters, containsPair('s', 'list'));
            expect(
              request.uri.queryParameters,
              containsPair('tags', topic.query),
            );
            expect(request.uri.queryParameters, containsPair('pid', '0'));
          }
          final previewContext = apiRequestContextFor(transport.requests.last);
          expect(previewContext.requestClass, ApiRequestClass.preload);
          expect(previewContext.allowCooldownRetry, isFalse);
          expect(harness.box.mutationCount, mutations);
          expect(harness.requests, isEmpty);
          expect(
            harness.container.read(
              followingTopicTrackingSupportedProvider(config.auth),
            ),
            isFalse,
          );
        });
        // Read the serialized test store in the same fake-clock zone that
        // created it; only Dio transport work needs runAsync.
        expect(await harness.repository.getAll(), before);
        // The overview renders only four of a fixed-size HTML page, with the
        // tracking warning kept independent from preview success.
        await harness.pump(
          tester,
          Scaffold(
            body: FollowingTopicCard(
              topic: topic,
              config: config.auth,
              refreshing: false,
              onOpen: () {},
              onAction: (_) {},
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(BooruImage), findsNWidgets(4));
        expect(
          find.text('New-post tracking is unsupported for this search.'),
          findsOneWidget,
        );
        expect(await harness.repository.getAll(), before);
        expect(harness.box.mutationCount, mutations);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}

class _HtmlTransport implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      '<html><body>${[
        for (var id = 1; id <= 6; id++) '<span class="thumb"><a id="p$id" href="index.php?page=post&amp;s=view&amp;id=$id">'
              '<img src="/thumbnails/ab/thumbnail_${id.toString().padLeft(32, '0')}.jpg" '
              'title="cat rating:safe score:1"></a></span>',
      ].join()}</body></html>',
      200,
      headers: {
        'content-type': ['text/html'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
