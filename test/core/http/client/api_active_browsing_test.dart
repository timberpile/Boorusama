import 'dart:convert';
import 'dart:typed_data';

import 'package:boorusama/boorus/danbooru/client_provider.dart';
import 'package:boorusama/boorus/danbooru/posts/favorites/src/data/providers.dart';
import 'package:boorusama/boorus/danbooru/posts/post/src/providers.dart';
import 'package:boorusama/boorus/danbooru/posts/votes/providers.dart';
import 'package:boorusama/boorus/danbooru/users/user/providers.dart';
import 'package:boorusama/boorus/danbooru/users/user/types.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/cache/persistent/providers.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/ddos/handler/providers.dart';
import 'package:boorusama/core/ddos/handler/types.dart';
import 'package:boorusama/core/http/client/coordination.dart';
import 'package:boorusama/core/http/client/providers.dart';
import 'package:boorusama/core/http/client/types.dart';
import 'package:boorusama/core/tags/configs/providers.dart';
import 'package:boorusama/core/tags/configs/src/tag_info.dart';
import 'package:boorusama/core/posts/favorites/providers.dart';
import 'package:boorusama/core/posts/favorites/src/data/providers.dart';
import 'package:boorusama/foundation/info/app_info.dart';
import 'package:boorusama/foundation/info/package_info.dart';
import 'package:boorusama/foundation/loggers.dart';
import 'package:fake_async/fake_async.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../search/subscriptions/subscription_test_utils.dart';

void main() {
  test('unknown active browsing has no assumed minute or second ceiling', () {
    fakeAsync((time) {
      final coordinator = ApiRequestCoordinator(elapsed: () => time.elapsed);
      final key = ApiQuotaKey.fromUri(Uri.parse('https://unknown.test'));
      var starts = 0;
      for (var i = 0; i < 40; i++) {
        coordinator.acquire(key).then((permit) {
          starts++;
          permit.release();
        });
      }
      time.flushMicrotasks();
      expect(starts, 40);
      expect(time.elapsed, Duration.zero);
      coordinator.dispose();
    });
  });

  for (final cold in [false, true]) {
    test(
      'rapid real Danbooru pagination with ${cold ? 'cold profile' : 'warm user'} avoids a synthetic minute pause',
      () async {
        var elapsed = Duration.zero;
        final coordinator = ApiRequestCoordinator(elapsed: () => elapsed);
        final config = BooruConfig.defaultConfig(
          booruType: BooruType.danbooru,
          url: 'https://danbooru.donmai.us',
          customDownloadFileNameFormat: null,
        ).copyWith(login: 'fixture', apiKey: 'fixture');
        addTearDown(coordinator.dispose);
        final transport = _BrowsingTransport();
        final container = ProviderContainer(
          overrides: [
            apiRequestCoordinatorProvider.overrideWithValue(coordinator),
            tagInfoProvider.overrideWithValue(
              const TagInfo(
                metatags: {},
                defaultBlacklistedTags: {},
                r18Tags: {},
              ),
            ),
            appInfoProvider.overrideWithValue(AppInfo.empty),
            packageInfoProvider.overrideWith(
              (ref) => ref.read(dummyPackageInfoProvider),
            ),
            defaultUserAgentProvider.overrideWithValue('fixture'),
            defaultNetworkProtocolInfoProvider.overrideWith(
              (ref, auth) =>
                  NetworkProtocolInfo.generic(cronetAvailable: false),
            ),
            httpDdosProtectionBypassProvider.overrideWithValue(_Protection()),
            loggerProvider.overrideWithValue(_Logger()),
            persistentCacheBoxProvider.overrideWith(
              (ref) => Future.value(MemoryBox<String>()),
            ),
            if (!cold)
              danbooruCurrentUserProvider(
                config.auth,
              ).overrideWith((ref) => Future.value(UserSelf.placeholder())),
            favoriteRepoProvider(config.auth).overrideWith(
              (ref) => ref.watch(danbooruFavoriteRepoProvider(config.auth)),
            ),
          ],
        );
        addTearDown(container.dispose);
        final dio = container.read(danbooruDioProvider(config.auth));
        dio.transformer = SyncTransformer();
        expect(dio.httpClientAdapter, isA<CoordinatedHttpClientAdapter>());
        dio.httpClientAdapter = CoordinatedHttpClientAdapter(
          transport,
          coordinator,
        );
        final client = container.read(danbooruClientProvider(config.auth));
        expect(await client.countPosts(tags: ['fixture']), 1800);
        await client.getTagsByName(tags: {'fixture'});
        final repo = container.read(danbooruPostRepoProvider(config.search));
        var completed = 0;
        for (var page = 1; page <= 30; page++) {
          await repo
              .getPosts('', page, limit: 60)
              .run()
              .timeout(
                const Duration(seconds: 1),
                onTimeout: () => fail(
                  'page $page blocked; completed=$completed physicalPosts=${transport.paths.where((p) => p == '/posts.json').length}',
                ),
              )
              .then((result) {
                result.fold(
                  (error) => fail('page returned ${error.runtimeType}'),
                  (posts) {
                    expect(posts.posts, hasLength(60));
                    completed++;
                  },
                );
              });
          for (var i = 0; i < 12; i++) {
            await Future<void>.delayed(Duration.zero);
          }
          expect(
            completed,
            page,
            reason: 'page $page must finish; observed paths ${transport.paths}',
          );

          if (page < 30) elapsed += const Duration(seconds: 2);
        }
        expect(
          coordinator
              .snapshot(ApiQuotaKey.fromUri(Uri.parse(config.url)))
              .queued,
          0,
          reason: 'speculative metadata must not accumulate',
        );
        expect(transport.paths.where((p) => p == '/posts.json'), hasLength(30));
        final metadata = transport.contexts.where(
          (c) => c.requestClass == ApiRequestClass.preload,
        );
        expect(metadata, hasLength(12));
        expect(
          container.read(favoritesProvider(config.auth)).containsKey(1800),
          false,
          reason: 'dropped favorite status stays unknown',
        );
        expect(
          container
              .read(danbooruPostVotesProvider(config.auth))
              .containsKey(1800),
          false,
          reason: 'dropped vote status stays unknown',
        );
        expect(
          transport.paths.where((p) => p == '/counts/posts.json'),
          hasLength(1),
        );
        expect(transport.paths.where((p) => p == '/tags.json'), hasLength(1));
        if (cold) {
          expect(
            transport.paths.where((p) => p == '/profile.json'),
            hasLength(1),
          );
          expect(
            transport.paths.where((p) => p == '/users/7.json'),
            hasLength(1),
          );
        }
        container.dispose();
        coordinator.dispose();
      },
    );
  }
}

class _BrowsingTransport implements HttpClientAdapter {
  final paths = <String>[];
  final contexts = <ApiRequestContext>[];
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancel,
  ) async {
    paths.add(options.uri.path);
    contexts.add(apiRequestContextFor(options));
    Object data = <Object>[];
    if (options.uri.path == '/posts.json') {
      final page = int.parse('${options.queryParameters['page']}');
      data = List.generate(
        60,
        (i) => {
          'id': (page - 1) * 60 + i + 1,
          'tag_string': 'fixture',
          'rating': 'g',
          'file_ext': 'jpg',
        },
      );
    } else if (options.uri.path == '/counts/posts.json') {
      data = {
        'counts': {'posts': 1800},
      };
    } else if (options.uri.path == '/profile.json' ||
        options.uri.path == '/users/7.json') {
      data = {
        'id': 7,
        'name': 'fixture',
        'level': 20,
        'created_at': '2026-01-01T00:00:00Z',
      };
    }
    return ResponseBody.fromString(
      jsonEncode(data),
      200,
      headers: {
        'content-type': ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _Protection implements HttpProtectionHandler {
  @override
  Future<Map<String, String>> prepareRequestHeaders(
    Uri uri,
    Map<String, String> headers,
  ) async => headers;
  @override
  Future<bool> handleResponse(Object response) async => false;
  @override
  Future<bool> handleError(Object error) async => false;
  @override
  void resetRetryAttempts(Uri uri) {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Logger implements Logger {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
