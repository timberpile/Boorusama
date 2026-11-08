import 'package:boorusama/boorus/registry.dart';
import 'package:boorusama/boorus/danbooru/client_provider.dart';
import 'package:boorusama/core/blacklists/providers.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/boorus/engine/providers.dart';
import 'package:boorusama/core/content/types.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/posts/pools/src/types/group_post_pager.dart';
import 'package:boorusama/core/posts/pools/group_post_scope.dart';
import 'package:boorusama/core/posts/listing/widgets.dart';
import 'package:boorusama/core/posts/listing/providers.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/settings/types.dart';
import 'package:kurumi/material.dart';
import 'package:boorusama/core/http/client/providers.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../posts/links/boorusama_post_link_test.dart' show config;
import '../search/following_topics/following_topic_test_utils.dart';

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
  for (final order in ['oldest', 'newest']) {
    for (final allHidden in [false, true]) {
      for (final countAvailable in [false, true]) {
        test(
          'Related $order continues after ${allHidden ? 'all' : 'one'} filtered raw posts with ${countAvailable ? 'exact' : 'missing'} count',
          () async {
            final base = config('https://site.test');
            final profile = BooruConfig.fromJson({
              ...base.toJson(),
              'bannedPostVisibility': 1,
            });
            final postPages = <int>[];
            final lastId = order == 'oldest' ? 103 : 101;
            Map<String, dynamic> post(
              int id, {
              bool banned = false,
              bool flash = false,
            }) => {
              'id': id,
              'parent_id': 42,
              'is_banned': banned,
              'md5': '0123456789abcdef0123456789abcdef',
              'rating': 'g',
              'tag_string': '',
              'tag_string_meta': flash ? 'flash' : '',
              'file_ext': 'jpg',
              'file_url': 'https://site.test/$id.jpg',
            };
            final dio = Dio(BaseOptions(baseUrl: profile.url))
              ..interceptors.add(
                InterceptorsWrapper(
                  onRequest: (request, handler) {
                    final Object data;
                    if (request.path.contains('/counts/')) {
                      data = {
                        'counts': {'posts': countAvailable ? 3 : null},
                      };
                    } else {
                      final page = int.parse(
                        request.queryParameters['page'].toString(),
                      );
                      postPages.add(page);
                      final tags = request.queryParameters['tags'].toString();
                      expect(tags, contains('parent:42'));
                      expect(
                        tags,
                        contains(
                          order == 'oldest' ? 'order:id_asc' : 'order:id_desc',
                        ),
                      );
                      data = page == 1
                          ? [
                              post(order == 'oldest' ? 101 : 103, banned: true),
                              post(102, flash: allHidden),
                            ]
                          : [post(lastId)];
                    }
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
            final source = container
                .read(booruEngineRegistryProvider)
                .getGroupCapability(BooruType.danbooru)!
                .createSource(
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
              sourceKey: 'related:42',
            );
            final first =
                (await source
                        .loadMembers(
                          GroupMemberQuery(
                            reference: reference,
                            orderKey: order,
                            requestedLimit: 2,
                          ),
                        )
                        .run())
                    .fold((e) => throw e, (v) => v);
            expect(
              first.resolved.length,
              allHidden ? 0 : 1,
              reason: 'native filter must remove banned and Flash posts',
            );
            expect(
              first.page.next,
              isNotNull,
              reason: 'a full raw page must retain its continuation',
            );
            final second =
                (await source
                        .loadMembers(
                          GroupMemberQuery(
                            reference: reference,
                            orderKey: order,
                            requestedLimit: 2,
                            cursor: first.page.next,
                          ),
                        )
                        .run())
                    .fold((e) => throw e, (v) => v);
            expect(
              (second.resolved.single as PostContentEntry).post.id,
              lastId,
            );
            final pager = GroupPostPager(
              source: source,
              reference: reference,
              perPage: 2,
              orderKey: order,
              isCurrent: () => true,
            );
            addTearDown(pager.dispose);
            final projectedFirst = await pager.fetch(1);
            expect(projectedFirst.hasMore, isTrue);
            expect((await pager.fetch(2)).posts.single.id, lastId);
            expect(postPages, [1, 2, 1, 2]);
          },
        );
      }
    }
  }
  for (final order in ['oldest', 'newest']) {
    for (final allHidden in [false, true]) {
      testWidgets(
        'Related $order grid reaches later post after ${allHidden ? 'empty' : 'short'} filtered first page',
        (tester) async {
          final base = config('https://site.test');
          final profile = BooruConfig.fromJson({
            ...base.toJson(),
            'bannedPostVisibility': 1,
          });
          final pages = <int>[];
          final laterId = order == 'oldest' ? 103 : 101;
          Map<String, dynamic> post(
            int id, {
            bool banned = false,
            bool flash = false,
          }) => {
            'id': id,
            'parent_id': 42,
            'is_banned': banned,
            'file_ext': 'jpg',
            'image_width': 100,
            'image_height': 100,
            'md5': '0123456789abcdef0123456789abcdef',
            'rating': 'g',
            'tag_string': '',
            'tag_string_meta': flash ? 'flash' : '',
            'file_url': 'https://site.test/$id.jpg',
          };
          final dio = Dio(BaseOptions(baseUrl: profile.url))
            ..interceptors.add(
              InterceptorsWrapper(
                onRequest: (request, handler) {
                  final Object data;
                  if (request.path.contains('/counts/')) {
                    data = {
                      'counts': {'posts': null},
                    };
                  } else {
                    final page = int.parse(
                      request.queryParameters['page'].toString(),
                    );
                    pages.add(page);
                    data = page == 1
                        ? [
                            post(order == 'oldest' ? 101 : 103, banned: true),
                            post(102, flash: allHidden),
                          ]
                        : [post(laterId)];
                  }
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
          final harness = FollowingTopicHarness(
            profiles: [profile],
            listingSettings: Settings.defaultSettings.listing.copyWith(
              postsPerPage: 2,
            ),
            overrides: [
              booruEngineRegistryProvider.overrideWith(
                (ref) => ref.watch(
                  booruInitEngineProvider((db: db, registry: components)),
                ),
              ),
              danbooruDioProvider.overrideWith((ref, auth) => dio),
            ],
          );
          addTearDown(harness.dispose);
          addTearDown(() => dio.close(force: true));
          harness.container
              .read(selectedTestProfileProvider.notifier)
              .select(profile);
          final reference = const ContentReferenceCodec().parse(
            engine: BooruType.danbooru,
            site: Uri.parse(profile.url),
            kind: ContentKind.group,
            sourceKey: 'related:42',
          );
          await harness.pump(
            tester,
            Scaffold(
              body: GroupPostScope(
                reference: reference,
                perPage: 2,
                orderKey: order,
                builder: (context, controller) =>
                    PostGrid<Post>(controller: controller),
              ),
            ),
          );
          PostGridController<Post> controller() => tester
              .widget<PostGrid<Post>>(find.byType(PostGrid<Post>))
              .controller;
          for (
            var i = 0;
            i < 100 &&
                (find.byType(PostGrid<Post>).evaluate().isEmpty ||
                    pages.isEmpty ||
                    controller().loading);
            i++
          ) {
            await tester.pump(const Duration(milliseconds: 100));
          }
          expect(pages, [1]);
          expect(controller().errors.value, isNull);
          expect(controller().items.length, allHidden ? 0 : 1);
          expect(controller().hasMore, isTrue);
          // Exercise the visible manual continuation control, including when
          // the first raw page contains no visible Posts at all.
          await tester.pump();
          final loadMore = find.byType(FilledButton);
          expect(loadMore, findsOneWidget);
          await tester.tap(loadMore);
          for (
            var i = 0;
            i < 100 && (pages.length < 2 || controller().loading);
            i++
          ) {
            await tester.pump(const Duration(milliseconds: 100));
          }
          expect(controller().loading, isFalse);
          expect(controller().errors.value, isNull);
          expect(controller().items.map((p) => p.id), contains(laterId));
          expect(pages, [1, 2]);
          expect(tester.takeException(), isNull);
        },
      );
    }
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
