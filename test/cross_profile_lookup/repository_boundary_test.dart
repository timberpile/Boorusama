import 'dart:convert';

import 'package:booru_clients/generated.dart';
import 'package:boorusama/boorus/gelbooru_v2/client_provider.dart';
import 'package:boorusama/boorus/gelbooru_v2/gelbooru_v2.dart';
import 'package:boorusama/boorus/gelbooru_v2/gelbooru_v2_provider.dart';

import 'package:boorusama/boorus/danbooru/client_provider.dart';
import 'package:boorusama/boorus/danbooru/danbooru.dart';
import 'package:boorusama/boorus/gelbooru/client_provider.dart';
import 'package:boorusama/boorus/gelbooru/gelbooru.dart';
import 'package:boorusama/core/blacklists/providers.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/boorus/engine/providers.dart';
import 'package:boorusama/core/boorus/engine/types.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/configs/manage/providers.dart';
import 'package:boorusama/core/posts/cross_profile_lookup/providers.dart';
import 'package:boorusama/core/posts/cross_profile_lookup/types.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../core/posts/links/boorusama_post_link_test.dart' show config;
import 'providers_test.dart' show sourceProfile, post, hash, Profiles;

void main() {
  for (final (type, host) in [
    (BooruType.danbooru, 'target.test'),
    (BooruType.gelbooru, 'gelbooru.com'),
    (BooruType.gelbooruV2, 'rule34.xxx'),
    (BooruType.gelbooruV2, 'safebooru.org'),
  ]) {
    test(
      '$host production repository uses target credentials and restrictions',
      () async {
        final target = BooruConfig.fromJson({
          ...config(
            'https://$host/',
            type: type,
          ).copyWith(login: '123', apiKey: 'target-api-key').toJson(),
          'ratingFilter': 2,
          'deletedItemBehavior': 1,
        });
        final other = BooruConfig.fromJson({
          ...target.toJson(),
          'id': '00000000-0000-4000-8000-000000000099',
          'login': '456',
          'apiKey': 'other-api-key',
        });
        final requests = <RequestOptions>[];
        Dio dio(BooruConfigAuth auth) {
          expect([target.auth, other.auth], contains(auth));
          final value = Dio(BaseOptions(baseUrl: auth.url));
          value.interceptors.add(
            InterceptorsWrapper(
              onRequest: (request, handler) {
                requests.add(request);
                final data = {
                  'id': 42,
                  'md5': hash,
                  'hash': hash,
                  'rating': 'g',
                  'tags': '',
                  'tag_string': '',
                  'file_url': 'https://media.test/a.jpg',
                  'source': 'https://www.pixiv.net/artworks/12345',
                };
                handler.resolve(
                  Response(
                    requestOptions: request,
                    statusCode: 200,
                    data: type != BooruType.gelbooru
                        ? [data]
                        : {
                            '@attributes': {'count': 1},
                            'post': [data],
                          },
                  ),
                );
              },
            ),
          );
          return value;
        }

        final container = ProviderContainer(
          overrides: [
            booruConfigProvider.overrideWith(
              () => Profiles([sourceProfile, target, other]),
            ),
            booruEngineRegistryProvider.overrideWith((ref) {
              final registry = BooruEngineRegistry();
              for (final components in [
                createDanbooru(),
                createGelbooru(),
                createGelbooruV2(),
              ]) {
                final booru = components.parser.parse();
                registry.register(
                  booru.type,
                  BooruEngine(
                    booru: booru,
                    builder: components.createBuilder(),
                    repository: components.createRepository(ref),
                  ),
                );
              }
              return registry;
            }),
            gelbooruV2Provider.overrideWithValue(
              GelbooruV2(
                config: BooruYamlConfigs.gelbooruV2,
                globalUserParams:
                    BooruYamlConfigs.gelbooruV2.globalUserParams ?? {},
              ),
            ),
            gelbooruV2DioProvider.overrideWith((ref, auth) => dio(auth)),
            danbooruDioProvider.overrideWith((ref, auth) => dio(auth)),
            gelbooruDioProvider.overrideWith((ref, auth) => dio(auth)),
            blacklistTagsProvider.overrideWith((ref, filter) => <String>{}),
          ],
        );
        addTearDown(container.dispose);
        final sub = container.listen(
          exactPostLookupProvider(target),
          (_, _) {},
        );
        addTearDown(sub.close);
        final service = await container.read(
          exactPostLookupProvider(target).future,
        );
        final result = await service.find(post(sourceProfile));
        expect(result, isA<PostLookupPage>());
        expect(
          (result as PostLookupPage).posts.single.origin.profileIdHint,
          target.id,
        );
        expect(requests, hasLength(1));
        final request = requests.single;
        expect(
          request.uri.host,
          host == 'rule34.xxx' ? 'api.rule34.xxx' : host,
        );
        expect(request.uri.queryParameters['tags'], contains('md5:$hash'));
        expect(
          request.uri.queryParameters['tags'],
          contains(switch (type) {
            BooruType.danbooru => 'rating:g',
            BooruType.gelbooruV2 => 'rating:safe',
            _ => 'rating:general',
          }),
        );
        expect(request.uri.queryParameters['tags'], isNot(contains('source:')));
        final otherService = await container.read(
          exactPostLookupProvider(other).future,
        );
        final otherResult = await otherService.findHash(hash);
        expect(otherResult, isA<PostLookupPage>());
        expect(
          (otherResult as PostLookupPage).posts.single.origin.profileIdHint,
          other.id,
        );
        final otherRequest = requests.last;
        if (type == BooruType.danbooru) {
          expect(
            otherRequest.headers['Authorization'],
            'Basic ${base64Encode(utf8.encode('456:other-api-key'))}',
          );
        } else {
          expect(otherRequest.uri.queryParameters['user_id'], '456');
          expect(otherRequest.uri.queryParameters['api_key'], 'other-api-key');
        }

        if (type != BooruType.danbooru) {
          expect(request.uri.queryParameters['user_id'], '123');
          expect(request.uri.queryParameters['api_key'], 'target-api-key');
        }
        if (host == 'gelbooru.com' || host == 'rule34.xxx') {
          final sourceService = await container.read(
            sourcePostLookupProvider(target).future,
          );
          for (var variant = 0; variant < 3; variant++) {
            final found = await sourceService.findArtwork(
              '12345',
              variant: variant,
              cancellation: PostLookupCancellation(),
            );
            expect(found, isA<PostLookupPage>());
            expect(
              (found as PostLookupPage).posts.single.origin.profileIdHint,
              target.id,
            );
            final actual = requests.last;
            expect(
              actual.uri.host,
              host == 'rule34.xxx' ? 'api.rule34.xxx' : host,
            );
            expect(actual.uri.queryParameters['user_id'], '123');
            expect(actual.uri.queryParameters['api_key'], 'target-api-key');
            expect(actual.uri.queryParameters['tags'], contains('source:*'));
            expect(actual.uri.queryParameters['tags'], contains('12345'));
            expect(
              actual.uri.queryParameters['tags'],
              contains(host == 'rule34.xxx' ? 'rating:safe' : 'rating:general'),
            );
          }
        }
        if (type == BooruType.danbooru) {
          expect(
            request.headers['Authorization'],
            'Basic ${base64Encode(utf8.encode('123:target-api-key'))}',
          );
          expect(
            request.uri.queryParameters['tags'],
            contains('-status:deleted'),
          );
          final artwork = PixivArtworkReference.parseSharedText(
            'https://www.pixiv.net/artworks/12345',
          )!;
          final sessionSubscription = container.listen(
            sharedPixivLookupSessionProvider(artwork),
            (_, _) {},
          );
          addTearDown(sessionSubscription.close);
          final sourceResult = await container
              .read(
                sharedPixivLookupSessionProvider(artwork),
              )
              .find(target, cancellation: PostLookupCancellation());
          expect(
            sourceResult,
            isA<PostLookupPage>().having(
              (page) => page.matchKind,
              'provenance',
              PostLookupMatchKind.pixivSource,
            ),
          );
          expect(
            (sourceResult as PostLookupPage).posts.single.origin.profileIdHint,
            target.id,
          );
          expect(requests, hasLength(3));
          final sourceRequest = requests.last;
          expect(sourceRequest.uri.host, 'target.test');
          expect(
            sourceRequest.uri.queryParameters['tags'],
            contains('pixiv_id:12345'),
          );
          expect(
            sourceRequest.uri.queryParameters['tags'],
            contains('rating:g'),
          );
          expect(
            sourceRequest.uri.queryParameters['tags'],
            contains('-status:deleted'),
          );
          expect(
            sourceRequest.headers['Authorization'],
            request.headers['Authorization'],
          );
        }
      },
    );
  }
}
