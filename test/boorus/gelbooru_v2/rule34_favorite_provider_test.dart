import 'package:booru_clients/generated.dart';
import 'package:booru_clients/gelbooru.dart';
import 'package:boorusama/boorus/gelbooru_v2/client_provider.dart';
import 'package:boorusama/boorus/gelbooru_v2/favorites/providers.dart';
import 'package:boorusama/boorus/gelbooru_v2/gelbooru_v2.dart';
import 'package:boorusama/boorus/gelbooru_v2/gelbooru_v2_provider.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/http/client/coordination.dart';
import 'package:boorusama/core/posts/favorites/providers.dart';
import 'package:boorusama/core/posts/favorites/src/data/providers.dart';
import 'package:boorusama/core/posts/favorites/types.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const postId = 7;
  late List<RequestOptions> requests;
  late Object? body;
  late DioException Function(RequestOptions)? interrupt;
  late ProviderContainer container;

  setUp(() {
    requests = [];
    body = null;
    interrupt = null;
    final dio = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (request, handler) {
            requests.add(request);
            if (interrupt case final fail?) {
              handler.reject(fail(request));
            } else {
              handler.resolve(
                Response(
                  requestOptions: request,
                  data: body,
                  statusCode: 200,
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
        gelbooruV2DioProvider.overrideWith((ref, config) {
          dio.options.baseUrl = config.url;
          return dio;
        }),
        favoriteRepoProvider.overrideWith(
          (ref, auth) => ref.watch(gelbooruV2FavoriteRepoProvider(auth)),
        ),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(() => dio.close(force: true));
  });

  test(
    'API reads work while API-only Favorites require website login',
    () async {
      final auth = _auth();
      expect(ApiAndCookieBasedLoginDetails(config: auth).hasLogin(), true);
      expect(container.read(canFavoriteProvider(auth)), false);
      expect(container.read(favoriteNeedsWebsiteLoginProvider(auth)), true);
      final notifier = container.read(favoritesProvider(auth).notifier);
      final preMutation = container.read(favoritesProvider(auth));

      final add = notifier.add(postId);
      expect(container.read(favoritesProvider(auth)), preMutation);
      await expectLater(
        add,
        throwsA(FavoriteActionFailure.websiteLoginRequired),
      );
      await expectLater(
        notifier.remove(postId),
        throwsA(FavoriteActionFailure.websiteLoginRequired),
      );
      expect(requests, isEmpty);

      body = [
        {'id': postId, 'hash': 'fake-post-hash'},
      ];
      final posts = await container
          .read(gelbooruV2ClientProvider(auth))
          .getPosts();
      expect(posts.posts.single.id, postId);
      expect(requests.single.uri.host, 'api.rule34.xxx');
      expect(
        requests.single.uri.queryParameters,
        containsPair('user_id', '42'),
      );
      expect(
        requests.single.uri.queryParameters,
        containsPair('api_key', 'fake-api-key'),
      );
      expect(requests.single.headers.containsKey('Cookie'), false);
    },
  );

  test(
    'website session alone enables mutations and 1 confirms already favorited',
    () async {
      final auth = _auth(passHash: 'fake-session', apiKey: null);
      expect(container.read(canFavoriteProvider(auth)), true);
      expect(container.read(favoriteNeedsWebsiteLoginProvider(auth)), false);
      body = '1\n';
      final notifier = container.read(favoritesProvider(auth).notifier);
      expect(await notifier.add(postId), AddFavoriteStatus.alreadyExists);
      expect(container.read(favoritesProvider(auth))[postId], true);
      expect(requests.single.uri.host, 'rule34.xxx');
    },
  );

  test(
    'a rejected session or ambiguous response rolls back and stays retryable',
    () async {
      final auth = _auth(passHash: 'fake-session');
      final notifier = container.read(favoritesProvider(auth).notifier);
      final original = container.read(favoritesProvider(auth));

      body = '2';
      await expectLater(
        notifier.add(postId),
        throwsA(FavoriteActionFailure.websiteSessionRejected),
      );
      expect(container.read(favoritesProvider(auth)), original);

      body = '<html>Unknown response</html>';
      expect(await notifier.add(postId), AddFavoriteStatus.failure);
      expect(container.read(favoritesProvider(auth)), original);

      body = '3';
      expect(await notifier.add(postId), AddFavoriteStatus.success);
      expect(container.read(favoritesProvider(auth))[postId], true);
      expect(requests, hasLength(3));
    },
  );

  for (final kind in ['connection', 'cancel', 'cooldown', 'permission']) {
    test('Rule34 $kind failure rolls back without a retry', () async {
      final auth = _auth(passHash: 'fake-session');
      final notifier = container.read(favoritesProvider(auth).notifier);
      late DioException reported;
      interrupt = (options) => reported = switch (kind) {
        'cancel' => DioException(
          requestOptions: options,
          type: DioExceptionType.cancel,
        ),
        'cooldown' => DioException(
          requestOptions: options,
          error: ApiCooldownException(
            ApiQuotaKey.fromUri(options.uri),
            DateTime.utc(2030),
          ),
        ),
        'permission' => DioException(
          requestOptions: options,
          error: const ApiRequestDeferredException(ApiWaitReason.passiveBudget),
        ),
        _ => DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
        ),
      };
      if (kind == 'connection') {
        expect(await notifier.add(postId), AddFavoriteStatus.failure);
      } else {
        await expectLater(
          notifier.add(postId),
          throwsA(predicate((e) => identical(e, reported))),
        );
      }
      expect(container.read(favoritesProvider(auth))[postId], isNull);
      expect(requests, hasLength(1));
    });
  }

  test('rejected removal restores the last confirmed favorite', () async {
    final auth = _auth(passHash: 'fake-session');
    final notifier = container.read(favoritesProvider(auth).notifier);
    body = '3';
    expect(await notifier.add(postId), AddFavoriteStatus.success);
    body = '<form action="/index.php?page=account&s=login"><input type="password"></form>';
    await expectLater(
      notifier.remove(postId),
      throwsA(FavoriteActionFailure.websiteSessionRejected),
    );
    expect(container.read(favoritesProvider(auth))[postId], true);
    expect(requests.last.uri.queryParameters['s'], 'view');
  });

  test('a legacy Rule34 pass hash requires a new browser sign-in', () {
    final auth = _auth(passHash: 'fake-legacy-hash', legacy: true);
    expect(ApiAndCookieBasedLoginDetails(config: auth).hasLogin(), true);
    expect(container.read(canFavoriteProvider(auth)), false);
    expect(container.read(favoriteNeedsWebsiteLoginProvider(auth)), true);
    expect(requests, isEmpty);
  });

  test('an interceptor-rejected 401 prompts relogin', () async {
    final auth = _auth(passHash: 'fake-session');
    final notifier = container.read(favoritesProvider(auth).notifier);
    interrupt = (options) => DioException(
      requestOptions: options,
      response: Response(requestOptions: options, statusCode: 401),
      type: DioExceptionType.badResponse,
    );

    await expectLater(
      notifier.add(postId),
      throwsA(FavoriteActionFailure.websiteSessionRejected),
    );
    expect(container.read(favoritesProvider(auth))[postId], isNull);
    expect(requests, hasLength(1));
  });

  for (final site in ['realbooru.com', 'gelbooru.com', 'custom.test']) {
    test('legacy auth and add mapping are preserved for $site', () async {
      final auth = _auth(site: site, passHash: 'fake-session');
      expect(container.read(canFavoriteProvider(auth)), true);
      expect(container.read(favoriteNeedsWebsiteLoginProvider(auth)), false);
      final notifier = container.read(favoritesProvider(auth).notifier);
      body = '2';
      expect(await notifier.add(postId), AddFavoriteStatus.failure);
      body = '3';
      expect(await notifier.add(postId), AddFavoriteStatus.success);
      expect(await notifier.remove(postId), true);
      expect(requests.last.uri.host, site);
      expect(requests.last.uri.queryParameters['s'], 'delete');
    });
  }
}

BooruConfigAuth _auth({
  String site = 'rule34.xxx',
  String? passHash,
  String? apiKey = 'fake-api-key',
  bool legacy = false,
}) => BooruConfig.fromJson({
  ...BooruConfig.defaultConfig(
    booruType: BooruType.gelbooruV2,
    url: 'https://$site/',
    customDownloadFileNameFormat: null,
  ).toJson(),
  'id': '00000000-0000-4000-8000-000000000042',
  'login': '42',
  'apiKey': apiKey,
  'passHash': site == 'rule34.xxx' && passHash != null && !legacy
      ? Rule34WebsiteSession.fromCookies(
          signedUserId: '42.fake-signature',
          token: passHash,
        )!.toStoredValue()
      : passHash,
}).auth;
