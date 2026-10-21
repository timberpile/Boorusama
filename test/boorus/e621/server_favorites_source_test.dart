import 'package:booru_clients/e621.dart';
import 'package:boorusama/boorus/e621/client_provider.dart';
import 'package:boorusama/core/bookmarks/server_favorites.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'e621 uses ordered account favorites without browsing filters',
    () async {
      final profile = BooruConfig.fromJson({
        ...BooruConfig.empty.toJson(),
        'id': '00000000-0000-4000-8000-000000000044',
        'booruId': BooruType.e621.id,
        'booruIdHint': BooruType.e621.id,
        'url': 'https://e926.net',
        'login': 'fixture',
        'apiKey': 'fixture-key',
        'alwaysIncludeTags': 'excluded_by_browsing_filter',
      });
      final requests = <RequestOptions>[];
      final dio = Dio(BaseOptions(baseUrl: profile.url))
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              requests.add(options);
              handler.resolve(
                Response<dynamic>(
                  requestOptions: options,
                  statusCode: 200,
                  data: {
                    'posts': switch (options.queryParameters['page']) {
                      1 => [
                        for (final id in [7, 90, 2])
                          {
                            'id': id,
                            'file': {
                              'url': 'https://static.e926.net/$id.jpg',
                              'ext': 'jpg',
                            },
                          },
                      ],
                      3 => [
                        {'id': 100},
                      ],
                      _ => [],
                    },
                  },
                ),
              );
            },
          ),
        );
      final container = ProviderContainer(
        overrides: [
          e621ClientProvider.overrideWith(
            (ref, auth) => E621Client(
              baseUrl: auth.url,
              login: auth.login,
              apiKey: auth.apiKey,
              dio: dio,
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      final source = container.read(serverFavoriteSourceProvider(profile));
      final first = await source.fetchPage(1);
      expect(first.posts.map((p) => p.id), [7, 90, 2]);
      expect(first.hasMore, isTrue);
      expect(
        first.posts.every(
          (p) =>
              p.origin.sourceHost == 'e926.net' &&
              p.origin.profileIdHint == profile.id,
        ),
        isTrue,
      );
      final end = await source.fetchPage(2);
      expect(end.posts, isEmpty);
      expect(end.hasMore, isFalse);
      expect(requests.map((r) => r.path), [
        '/favorites.json',
        '/favorites.json',
      ]);
      expect(requests.map((r) => r.queryParameters), [
        {'page': 1, 'limit': 100},
        {'page': 2, 'limit': 100},
      ]);
      final unavailable = await source.fetchPage(3);
      expect(unavailable.posts, isEmpty);
      expect(unavailable.hasMore, isTrue);
    },
  );
}
