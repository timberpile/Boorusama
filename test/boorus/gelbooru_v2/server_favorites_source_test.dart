import 'dart:async';
import 'dart:io';

import 'package:booru_clients/generated.dart';
import 'package:boorusama/boorus/gelbooru_v2/client_provider.dart';
import 'package:boorusama/boorus/gelbooru_v2/gelbooru_v2.dart';
import 'package:boorusama/boorus/gelbooru_v2/gelbooru_v2_provider.dart';
import 'package:boorusama/core/bookmarks/server_favorites.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/http/client/coordination.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _favorites = '''
<span class="thumb"><a href="index.php?page=post&amp;s=view&amp;id=42">
<img src="https://realbooru.com/thumbnails/ab/cd/thumbnail_0123456789abcdef0123456789abcdef.jpg"></a></span>
<script>posts[42] = {'tags': 'portrait', 'rating': 'safe', 'score': '1', 'user': 'fixture'};</script>
''';

void main() {
  late ProviderContainer container;
  late BooruConfig profile;
  late List<RequestOptions> requests;
  late List<ApiRequestContext> requestContexts;
  Completer<void>? detailRequested;
  Completer<Response<String>>? detail;

  setUp(() {
    profile = BooruConfig.fromJson({
      ...BooruConfig.empty.toJson(),
      'id': '00000000-0000-4000-8000-000000000044',
      'booruId': BooruType.gelbooruV2.id,
      'booruIdHint': BooruType.gelbooruV2.id,
      'url': 'https://realbooru.com',
      'login': '123',
      'apiKey': null,
      'passHash': 'synthetic-cookie',
      'alwaysIncludeTags': 'excluded_by_browsing_filter',
    });
    requests = [];
    requestContexts = [];
    detailRequested = null;
    detail = null;
    final dio = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) async {
            requests.add(options);
            requestContexts.add(ApiRequestContext.current());
            if (options.uri.queryParameters['page'] == 'favorites') {
              handler.resolve(
                Response<String>(
                  requestOptions: options,
                  statusCode: 200,
                  data: options.uri.queryParameters['pid'] == '0'
                      ? _favorites
                      : '<div id="content"></div>',
                ),
              );
            } else if (detail case final pending?) {
              detailRequested!.complete();
              handler.resolve(await pending.future);
            } else {
              handler.resolve(
                Response<String>(
                  requestOptions: options,
                  statusCode: 200,
                  data: File(
                    'test/boorus/gelbooru_v2/fixtures/realbooru_post.html',
                  ).readAsStringSync(),
                ),
              );
            }
          },
        ),
      );
    container = ProviderContainer(
      overrides: [
        gelbooruV2Provider.overrideWithValue(
          GelbooruV2(
            config: BooruYamlConfigs.gelbooruV2,
            globalUserParams:
                BooruYamlConfigs.gelbooruV2.globalUserParams ?? {},
          ),
        ),
        gelbooruV2DioProvider.overrideWith((ref, auth) => dio),
      ],
    );
  });
  tearDown(() => container.dispose());

  test('Realbooru uses cookie credentials and favorites offsets, and resolves originals', () async {
    expect(
      container.read(serverFavoriteAvailabilityProvider(profile.auth)),
      isNull,
    );
    expect(requests, isEmpty);
    final source = container.read(serverFavoriteSourceProvider(profile));
    final first = await source.fetchPage(1);
    final post = first.posts.single;
    expect(post.id, 42);
    expect(
      post.originalImageUrl,
      'https://realbooru.com/images/ab/cd/0123456789abcdef0123456789abcdef.jpeg',
    );
    expect(post.origin.sourceHost, 'realbooru.com');
    expect(post.origin.profileIdHint, profile.id);
    expect((await source.fetchPage(2)).posts, isEmpty);
    final pages = requests
        .where((r) => r.uri.queryParameters['page'] == 'favorites')
        .toList();
    expect(pages.map((r) => r.uri.queryParameters['pid']), ['0', '50']);
    expect(pages.every((r) => r.uri.queryParameters['id'] == '123'), isTrue);
    expect(
      requests.every(
        (r) =>
            !r.uri.queryParameters.containsKey('tags') &&
            !r.uri.queryParameters.containsKey('api_key'),
      ),
      isTrue,
    );
  });

  test(
    'Realbooru nested detail requests inherit bulk import pacing',
    () async {
      final source = container.read(serverFavoriteSourceProvider(profile));
      final cancellation = ServerFavoriteCancellation();
      final page = await runWithApiRequestContext(
        ApiRequestContext(
          requestClass: ApiRequestClass.bulkTransfer,
          allowCooldownRetry: false,
          canStart: () => !cancellation.isCancelled,
        ),
        () => source.fetchPage(1, cancellation: cancellation),
      );
      expect(page.posts.single.id, 42);
      expect(
        requests.map((r) => r.uri.queryParameters['page']),
        ['favorites', 'post'],
      );
      expect(requestContexts, hasLength(2));
      for (final context in requestContexts) {
        expect(context.requestClass, ApiRequestClass.bulkTransfer);
        expect(context.allowCooldownRetry, isFalse);
        expect(context.canStart?.call(), isTrue);
      }
      cancellation.cancel();
      expect(requestContexts.every((context) => !context.canStart!()), isTrue);
    },
  );

  test(
    'cancelling while resolving a thumbnail stops the source immediately',
    () async {
      detailRequested = Completer();
      detail = Completer();
      final cancellation = ServerFavoriteCancellation();
      final source = container.read(serverFavoriteSourceProvider(profile));
      final fetch = source.fetchPage(1, cancellation: cancellation);
      final expectation = expectLater(
        fetch,
        throwsA(isA<ServerFavoriteCancelled>()),
      );
      await detailRequested!.future;
      cancellation.cancel();
      await expectation;
      detail!.complete(
        Response<String>(
          requestOptions: requests.last,
          statusCode: 200,
          data: File('test/boorus/gelbooru_v2/fixtures/realbooru_post.html')
              .readAsStringSync(),
        ),
      );
    },
  );

  test('a profile without cookie or API credentials is unavailable without requests', () {
    final signedOut = BooruConfig.fromJson({
      ...profile.toJson(),
      'passHash': null,
    });
    expect(
      container.read(serverFavoriteAvailabilityProvider(signedOut.auth)),
      ServerFavoriteProblem.signedOut,
    );
    expect(requests, isEmpty);
  });
}
