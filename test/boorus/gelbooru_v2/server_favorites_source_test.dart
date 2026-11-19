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

final _favorites = File(
  'packages/booru_clients/test/gelbooru_v2/fixtures/realbooru_favorites/populated.html',
).readAsStringSync();
final _terminal = File(
  'packages/booru_clients/test/gelbooru_v2/fixtures/realbooru_favorites/terminal.html',
).readAsStringSync();

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
      'login': '1',
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
                      : _terminal,
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

  test('Realbooru uses cookie credentials and favorites offsets, and persists explicit previews', () async {
    expect(
      container.read(serverFavoriteAvailabilityProvider(profile.auth)),
      isNull,
    );
    expect(requests, isEmpty);
    final source = container.read(serverFavoriteSourceProvider(profile));
    final first = await source.fetchPage(1);
    final post = first.posts.single;
    expect(post.id, 646949);
    expect(
      post.originalImageUrl,
      '',
    );
    expect(post.origin.sourceHost, 'realbooru.com');
    expect(post.origin.profileIdHint, profile.id);
    expect((await source.fetchPage(2)).posts, isEmpty);
    final pages = requests
        .where((r) => r.uri.queryParameters['page'] == 'favorites')
        .toList();
    expect(pages.map((r) => r.uri.queryParameters['pid']), ['0', '50']);
    expect(pages.every((r) => r.uri.queryParameters['id'] == '1'), isTrue);
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
    'Realbooru cold import makes only paced listing requests',
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
      expect(page.posts.single.id, 646949);
      expect(page.posts.single.requiresDetailLookup, isTrue);
      expect(
        requests.map((r) => r.uri.queryParameters['page']),
        ['favorites'],
      );
      expect(requestContexts, hasLength(1));
      for (final context in requestContexts) {
        expect(context.requestClass, ApiRequestClass.bulkTransfer);
        expect(context.allowCooldownRetry, isFalse);
        expect(context.canStart?.call(), isTrue);
      }
      cancellation.cancel();
      expect(requestContexts.every((context) => !context.canStart!()), isTrue);
    },
  );

  test('cancelled listing import dispatches no detail requests', () async {
    final cancellation = ServerFavoriteCancellation()..cancel();
    final source = container.read(serverFavoriteSourceProvider(profile));
    await expectLater(
      source.fetchPage(1, cancellation: cancellation),
      throwsA(isA<ServerFavoriteCancelled>()),
    );
    expect(requests, isEmpty);
  });

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
