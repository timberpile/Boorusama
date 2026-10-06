import 'dart:typed_data';

import 'package:booru_clients/danbooru.dart';
import 'package:boorusama/boorus/danbooru/client_provider.dart';
import 'package:boorusama/boorus/danbooru/posts/favorites/src/data/providers.dart';
import 'package:boorusama/boorus/danbooru/posts/post/src/providers.dart';
import 'package:boorusama/boorus/danbooru/posts/votes/providers.dart';
import 'package:boorusama/boorus/danbooru/users/user/providers.dart';
import 'package:boorusama/boorus/danbooru/users/user/types.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/http/client/coordination.dart';
import 'package:boorusama/core/posts/favorites/providers.dart';
import 'package:boorusama/core/posts/favorites/src/data/providers.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../search/subscriptions/subscription_test_utils.dart';

void main() {
  for (final cancelled in [false, true]) {
    test(
      'actual detached favorite/vote preload ${cancelled ? 'stays discarded after parent cancellation' : 'drops when all physical slots are occupied'}',
      () async {
        final config = BooruConfig.defaultConfig(
          booruType: BooruType.danbooru,
          url: 'https://site.test',
          customDownloadFileNameFormat: null,
        );
        final coordinator = ApiRequestCoordinator();
        addTearDown(coordinator.dispose);
        final key = ApiQuotaKey.fromUri(Uri.parse(config.url));
        final permits = <ApiRequestPermit>[];
        for (var i = 0; i < 4; i++) {
          permits.add(await coordinator.acquire(key));
        }
        final transport = _MetadataTransport();
        final dio = Dio(BaseOptions(baseUrl: config.url))
          ..httpClientAdapter = transport;
        coordinateApiDio(dio, coordinator);
        final token = CancelToken();
        var eligible = true;
        var parentStarts = 0;
        final parent = ApiRequestContext(
          requestClass: ApiRequestClass.userInitiated,
          cancelToken: token,
          canStart: () => eligible,
          onStarted: () => parentStarts++,
        );
        final transform = Provider(
          (ref) => runWithApiRequestContext(
            parent,
            () => transformPosts(
              ref,
              [TestSearchPost(1, DateTime.utc(2026))].toResult(),
              config.search,
            ),
          ),
        );
        final container = ProviderContainer(
          overrides: [
            danbooruClientProvider(
              config.auth,
            ).overrideWithValue(DanbooruClient(baseUrl: config.url, dio: dio)),
            danbooruCurrentUserProvider(
              config.auth,
            ).overrideWith((ref) => Future.value(UserSelf.placeholder())),
            favoriteRepoProvider(config.auth).overrideWith(
              (ref) => ref.watch(danbooruFavoriteRepoProvider(config.auth)),
            ),
          ],
        );
        addTearDown(container.dispose);
        await container.read(transform);
        for (var i = 0; i < 20; i++) {
          await Future<void>.delayed(Duration.zero);
        }
        expect(coordinator.snapshot(key).queued, 0);
        expect(transport.contexts, isEmpty);
        if (cancelled) {
          eligible = false;
          token.cancel();
        }
        for (final permit in permits) {
          permit.abandon();
        }

        for (var i = 0; i < 5; i++) {
          await Future<void>.delayed(Duration.zero);
        }
        expect(parentStarts, 0);
        expect(coordinator.snapshot(key).queued, 0);
        expect(transport.contexts, isEmpty);
        expect(
          container.read(favoritesProvider(config.auth)).containsKey(1),
          false,
        );
        expect(
          container.read(danbooruPostVotesProvider(config.auth)).containsKey(1),
          false,
        );
      },
    );
  }
}

class _MetadataTransport implements HttpClientAdapter {
  final contexts = <ApiRequestContext>[];
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    contexts.add(apiRequestContextFor(options));
    return ResponseBody.fromString(
      '[]',
      200,
      headers: {
        'content-type': ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
