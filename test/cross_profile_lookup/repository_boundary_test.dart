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
import 'package:boorusama/core/posts/cross_profile_lookup/providers.dart';
import 'package:boorusama/core/posts/cross_profile_lookup/types.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../core/posts/links/boorusama_post_link_test.dart' show config;
import 'providers_test.dart' show sourceProfile, post, hash;

void main() {
  for (final type in [
    BooruType.danbooru,
    BooruType.gelbooru,
    BooruType.gelbooruV2,
  ]) {
    test(
      '$type production repository uses target credentials and restrictions',
      () async {
        final target = BooruConfig.fromJson({
          ...config(
            type == BooruType.gelbooruV2
                ? 'https://rule34.xxx/'
                : 'https://target.test',
            type: type,
          ).copyWith(login: '123', apiKey: 'target-api-key').toJson(),
          'ratingFilter': 2,
          'deletedItemBehavior': 1,
        });
        final requests = <RequestOptions>[];
        Dio dio(BooruConfigAuth auth) {
          expect(auth, target.auth);
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
          type == BooruType.gelbooruV2 ? 'api.rule34.xxx' : 'target.test',
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
        if (type != BooruType.danbooru) {
          expect(request.uri.queryParameters['user_id'], '123');
          expect(request.uri.queryParameters['api_key'], 'target-api-key');
        } else {
          expect(
            request.headers['Authorization'],
            'Basic ${base64Encode(utf8.encode('123:target-api-key'))}',
          );
          expect(
            request.uri.queryParameters['tags'],
            contains('-status:deleted'),
          );
        }
      },
    );
  }
}
