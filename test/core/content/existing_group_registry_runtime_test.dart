import 'package:boorusama/boorus/registry.dart';
import 'package:boorusama/boorus/danbooru/client_provider.dart';
import 'package:boorusama/core/blacklists/providers.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/boorus/engine/providers.dart';
import 'package:boorusama/core/content/types.dart';
import 'package:boorusama/core/http/client/providers.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../posts/links/boorusama_post_link_test.dart' show config;

void main() {
  for (final key in ['pool:42', 'related:42']) {
    test(
      'production Danbooru registry loads $key members through its Post repository',
      () async {
        final profile = config('https://site.test');
        final requests = <String>[];
        final dio = Dio(BaseOptions(baseUrl: profile.url))
          ..interceptors.add(
            InterceptorsWrapper(
              onRequest: (request, handler) {
                requests.add(request.path);
                final data = request.path.contains('/pools/')
                    ? <String, dynamic>{
                        'id': 42,
                        'name': 'Pool',
                        'post_count': 1,
                        'post_ids': [42],
                      }
                    : request.path.contains('/counts/')
                    ? <String, dynamic>{
                        'counts': {'posts': 1},
                      }
                    : [
                        <String, dynamic>{
                          'id': 42,
                          'parent_id': null,
                          'md5': '0123456789abcdef0123456789abcdef',
                          'rating': 'g',
                          'tag_string': '',
                          'file_url': 'https://site.test/42.jpg',
                        },
                      ];
                handler.resolve(
                  Response<dynamic>(
                    requestOptions: request,
                    statusCode: 200,
                    data: data,
                  ),
                );
              },
            ),
          );
        final components = createBooruRegistry();
        final db = BooruDb(
          boorus: {
            BooruType.danbooru: components.parseFromConfig(
              BooruType.danbooru.yamlName,
            ),
          },
        );
        final container = ProviderContainer(
          overrides: [
            booruEngineRegistryProvider.overrideWith(
              (ref) => ref.watch(
                booruInitEngineProvider((db: db, registry: components)),
              ),
            ),
            danbooruDioProvider.overrideWith((ref, auth) => dio),
            blacklistTagsProvider.overrideWith((ref, filter) => <String>{}),
          ],
        );
        addTearDown(container.dispose);
        addTearDown(() => dio.close(force: true));
        final capability = container
            .read(booruEngineRegistryProvider)
            .getGroupCapability(BooruType.danbooru)!;
        final source = capability.createSource(
          ContentAccessContext.profile(
            config: profile,
            authEpoch: 1,
            policyEpoch: 1,
          ),
        );
        addTearDown(source.dispose);
        final reference = const ContentReferenceCodec().parse(
          engine: BooruType.danbooru,
          site: Uri.parse(profile.url),
          kind: ContentKind.group,
          sourceKey: key,
        );
        final metadata = await source.loadDetails(reference).run();
        metadata.fold((error) => fail('metadata failed: $error'), (_) {});
        final result = await source
            .loadMembers(GroupMemberQuery(reference: reference))
            .run();
        final batch = result.fold((error) => throw error, (value) => value);
        expect(batch.resolved, isNotEmpty);
        final origin = (batch.resolved.first as PostContentEntry).post.origin;
        expect(origin.profileIdHint, profile.id);
        expect(origin.sourceHost, 'site.test');
        expect(origin.booruType, BooruType.danbooru);
        expect(requests.where((path) => path.contains('/posts')), isNotEmpty);
      },
    );
  }
  test('production Szurubooru registry loads Pool members through its Post repository', () async {
    final profile = config('https://szuru.test', type: BooruType.szurubooru);
    final requests = <String>[];
    final dio = Dio(BaseOptions(baseUrl: profile.url))
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (request, handler) {
            requests.add(request.path);
            final Object data = switch (request.path) {
              '/api/pool/42' => {
                'id': 42,
                'names': ['Pool'],
                'postCount': 1,
                'posts': [
                  {'id': 42},
                ],
              },
              '/api/posts' => {
                'total': 1,
                'results': [
                  {
                    'id': 42,
                    'safety': 'safe',
                    'tags': [],
                    'contentUrl': '/42.jpg',
                  },
                ],
              },
              '/api/tag-categories' => {'results': []},
              _ => {'results': []},
            };
            handler.resolve(
              Response<dynamic>(
                requestOptions: request,
                statusCode: 200,
                data: data,
              ),
            );
          },
        ),
      );
    final components = createBooruRegistry();
    final db = BooruDb(
      boorus: {
        BooruType.szurubooru: components.parseFromConfig(
          BooruType.szurubooru.yamlName,
        ),
      },
    );
    final container = ProviderContainer(
      overrides: [
        booruEngineRegistryProvider.overrideWith(
          (ref) => ref.watch(
            booruInitEngineProvider((db: db, registry: components)),
          ),
        ),
        defaultDioProvider.overrideWith((ref, auth) => dio),
        blacklistTagsProvider.overrideWith((ref, filter) => <String>{}),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(() => dio.close(force: true));
    final source = container
        .read(booruEngineRegistryProvider)
        .getGroupCapability(BooruType.szurubooru)!
        .createSource(
          ContentAccessContext.profile(
            config: profile,
            authEpoch: 1,
            policyEpoch: 1,
          ),
        );
    addTearDown(source.dispose);
    final reference = const ContentReferenceCodec().parse(
      engine: BooruType.szurubooru,
      site: Uri.parse(profile.url),
      kind: ContentKind.group,
      sourceKey: 'pool:42',
    );
    final metadata = await source.loadDetails(reference).run();
    metadata.fold((error) => fail('metadata failed: $error'), (_) {});
    final result = await source
        .loadMembers(GroupMemberQuery(reference: reference))
        .run();
    final batch = result.fold((error) => throw error, (value) => value);
    expect(batch.resolved, isNotEmpty);
    final origin = (batch.resolved.first as PostContentEntry).post.origin;
    expect(origin.profileIdHint, profile.id);
    expect(origin.sourceHost, 'szuru.test');
    expect(origin.booruType, BooruType.szurubooru);
    expect(requests, contains('/api/posts'));
  });
}
