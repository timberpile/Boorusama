import 'package:boorusama/core/content/content_access_provider.dart';
import 'package:boorusama/core/content/groups/related_group_counts.dart';
import 'package:boorusama/core/content/types.dart';
import 'package:booru_clients/danbooru.dart';
import 'package:boorusama/core/posts/related/related_posts_order_value.dart';
import 'package:boorusama/core/posts/post/types.dart';

import '../../support/fakes/test_post.dart';

import 'package:boorusama/boorus/danbooru/client_provider.dart';
import 'package:boorusama/boorus/danbooru/posts/post/providers.dart';
import 'package:boorusama/core/blacklists/providers.dart';
import 'package:boorusama/core/bookmarks/src/providers/bookmark_provider.dart';
import 'package:boorusama/core/bookmarks/src/providers/pool_bookmark_provider.dart';
import 'package:boorusama/core/bookmarks/src/providers/related_bookmark_provider.dart';
import 'package:boorusama/core/bookmarks/types.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/posts/post/providers.dart';
import 'package:boorusama/core/posts/related/related_family.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'pool_bookmark_test_utils.dart';

class _Library extends BookmarkLibraryNotifier {
  _Library(this.saved);
  final List<CollectionBookmark> saved;
  @override
  Future<BookmarkLibraryState> build() async =>
      BookmarkLibraryState(bookmarks: const [], groups: const [], pools: saved);
}

void main() {
  final config = BooruConfig.fromJson({
    ...BooruConfig.defaultConfig(
      booruType: poolOrigin().booruType,
      url: 'https://danbooru.donmai.us',
      customDownloadFileNameFormat: null,
    ).toJson(),
    'id': poolProfile,
  });
  final family = RelatedFamilyReference(
    origin: postOriginFromConfig(config),
    anchorId: 10,
  );
  final reference = RelatedCollectionBookmark(
    family: family,
    localId: testPool().localId,
    createdAt: DateTime.utc(2025),
    observedAt: DateTime.utc(2025),
    groupIds: const {poolGroupA},
    tags: const {'last_known'},
  );

  Future<CollectionBookmark> draft({
    required List<Map<String, Object?>> rows,
    int? count,
    Set<String> blacklist = const {},
    List<CollectionBookmark> saved = const [],
    bool fail = false,
    List<RequestOptions>? calls,
    BooruConfig? source,
    int readers = 1,
    List<Override> overrides = const [],
    void Function(ProviderContainer container)? before,
    void Function(ProviderContainer container)? after,
    void Function()? onRequest,
  }) async {
    final current = source ?? config;
    final dio = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (request, handler) {
            calls?.add(request);
            onRequest?.call();
            if (fail) {
              handler.reject(DioException(requestOptions: request));
              return;
            }
            handler.resolve(
              Response<dynamic>(
                requestOptions: request,
                statusCode: 200,
                data: request.path == '/posts.json'
                    ? rows
                    : {
                        'counts': {'posts': count},
                      },
              ),
            );
          },
        ),
      );
    final container = ProviderContainer(
      overrides: [
        bookmarkProvider.overrideWith(() => _Library(saved)),
        blacklistTagsProvider.overrideWith(
          (ref, filter) => Future.sync(() => blacklist),
        ),
        originAwarePostRepoProvider.overrideWith(
          (ref, config) => OriginAwarePostRepository(
            delegate: ref.watch(danbooruPostRepoProvider(config.search)),
            origin: postOriginFromConfig(config),
          ),
        ),
        danbooruClientProvider.overrideWith(
          (ref, auth) => DanbooruClient(baseUrl: auth.url, dio: dio),
        ),
        ...overrides,
      ],
    );
    addTearDown(() {
      container.dispose();
      dio.close();
    });
    before?.call(container);
    final provider = relatedBookmarkRefreshProvider((current, family));
    container.listen(provider, (_, _) {});
    final result = (await Future.wait([
      for (var i = 0; i < readers; i++) container.read(provider.future),
    ])).first;
    after?.call(container);
    return result;
  }

  Map<String, Object?> row(
    int id, {
    int? parent,
    String tags = 'visible',
    String rating = 'g',
    String ext = 'jpg',
  }) => {
    'id': id,
    'parent_id': parent,
    'tag_string': tags,
    'rating': rating,
    'file_ext': ext,
    'image_width': 100,
    'image_height': 100,
    'preview_file_url': 'https://media.test/$id.$ext',
  };

  for (final revoke in [false, true]) {
    test(
      'explicit Related bookmark refresh updates the shared total only for its current actor (revoke=$revoke)',
      () async {
        final access = ContentAccessContext.profile(
          config: config,
          authEpoch: 1,
          policyEpoch: 1,
        );
        final metadata = GroupMetadataKey(
          reference: const ContentReferenceCodec().parse(
            engine: config.auth.booruType,
            site: Uri.parse(config.url),
            kind: ContentKind.group,
            sourceKey: 'related:10',
          ),
          access: access.key,
        );
        late ProviderContainer owner;
        final calls = <RequestOptions>[];
        await draft(
          rows: [row(10)],
          count: 9,
          calls: calls,
          overrides: [
            contentProfileAccessProvider.overrideWith(() => _Access(access)),
          ],
          before: (container) {
            owner = container;
            container.read(contentProfileAccessProvider(config.id));
            final counts = container.read(relatedGroupCountsProvider.notifier);
            counts.publish(counts.begin(metadata), 17);
          },
          onRequest: () {
            if (revoke) {
              (owner.read(
                contentProfileAccessProvider(config.id).notifier,
              ) as _Access).revoke();
            }
          },
          after: (container) {
            expect(
              relatedGroupTotal(
                container.read(relatedGroupCountsProvider),
                metadata,
              ),
              revoke ? null : 9,
            );
          },
        );
        expect(calls.map((request) => request.path), [
          '/posts.json',
          '/counts/posts.json',
        ]);
      },
    );
  }

  for (final order in RelatedPostsOrder.values) {
    test(
      'new Related uses a source-verified cached static cover without requests ($order)',
      () async {
        var requests = 0;
        final cached = TestPost(
          id: 10,
          origin: PostOrigin.fromSource(
            booruType: config.auth.booruType,
            booruId: config.booruId,
            source: config.url,
            profileIdHint: poolGroupB,
          ),
          thumbnailImageUrl: 'https://cdn.donmai.us/10.jpg',
        );
        final container = ProviderContainer(
          overrides: [
            bookmarkProvider.overrideWith(() => _Library([])),
            blacklistTagsProvider.overrideWith(
              (ref, filter) => Future.sync(() => {}),
            ),
            originAwarePostRepoProvider.overrideWith((ref, config) {
              requests++;
              throw StateError('Save must not fetch');
            }),
          ],
        );
        addTearDown(container.dispose);
        await container.read(blacklistTagsProvider(config.filter).future);
        final draft = await container.read(
          relatedBookmarkCachedDraftProvider(
            RelatedBookmarkDraftInput(
              config: config,
              family: family,
              order: order,
              cachedMembers: [
                TestPost(
                  id: 999,
                  origin: cached.origin,
                  thumbnailImageUrl: 'https://cdn.donmai.us/unrelated.jpg',
                ),
                cached,
              ],
            ),
          ).future,
        );
        expect(draft.cover?.thumbnail, cached.thumbnailImageUrl);
        expect(draft.cover?.postId, 10);
        expect(draft.cover?.visibility?.tags, cached.tags);
        expect(draft.coverage, PoolTagCoverage.unknown);
        expect(requests, 0);
      },
    );
  }

  test('bounded summary uses the producer count without extra probes or recursive children', () async {
    final calls = <RequestOptions>[];
    final value = await draft(
      rows: [
        row(10),
        row(11, parent: 10),
        row(12, parent: 11, tags: 'grandchild'),
      ],
      count: 3,
      calls: calls,
    );
    expect(calls.map((r) => r.path), ['/posts.json', '/counts/posts.json']);
    expect(calls.first.queryParameters['limit'], 40);
    expect(calls.first.queryParameters['tags'], contains('parent:10'));
    expect(calls.last.queryParameters['estimate_count'], false);
    expect(value.tags, {'visible'});
    expect(value.coverage, PoolTagCoverage.partial);
    expect(value.total, 3);
    expect(value.newestUpload, isNull);
    expect(value.oldestUpload, isNull);
  });

  test(
    'concurrent summary consumers share the same bounded producer operations',
    () async {
      final calls = <RequestOptions>[];
      await draft(rows: [row(10)], count: 1, calls: calls, readers: 3);
      expect(calls.map((r) => r.path), ['/posts.json', '/counts/posts.json']);
    },
  );

  for (final missingParent in [false, true]) {
    test(
      'singleton remains valid with missing parent=$missingParent',
      () async {
        final value = await draft(
          rows: [
            row(missingParent ? 11 : 10, parent: missingParent ? 10 : null),
          ],
          count: 1,
        );
        expect(value.family, family);
        expect(value.total, 1);
        expect(value.coverage, PoolTagCoverage.complete);
        expect(value.cover, isNotNull);
        expect(value.oldestUpload, isNull);
      },
    );
  }

  test('blacklist and rating restrictions exclude tags and covers without proving absence', () async {
    final safe = BooruConfig.fromJson({
      ...config.toJson(),
      'ratingFilter': BooruConfigRatingFilter.hideNSFW.index,
    });
    final value = await draft(
      source: safe,
      rows: [
        row(10, tags: 'blocked'),
        row(11, parent: 10, tags: 'secret', rating: 'e'),
        row(12, parent: 10, ext: 'gif'),
      ],
      count: 3,
      blacklist: {'blocked'},
    );
    expect(value.tags, {'visible'});
    expect(value.cover, isNull);
    expect(value.coverage, PoolTagCoverage.partial);
    expect(value.total, 3);
    expect(value.coverPolicy, poolCoverPolicy(safe, {'blocked'}));
  });

  test('failed refresh preserves the last known summary and new offline references remain unknown', () async {
    await expectLater(
      draft(rows: [], saved: [reference], fail: true),
      throwsStateError,
    );
    final unknown = await draft(rows: [], fail: true);
    expect(unknown.total, isNull);
    expect(unknown.coverage, PoolTagCoverage.unknown);
    expect(unknown.tags, isEmpty);
    expect(reference.tags, {'last_known'});
    final inaccessible = await draft(rows: [], count: 0, saved: [reference]);
    expect(inaccessible.family, family);
    expect(inaccessible.localId, reference.localId);
    expect(inaccessible.groupIds, reference.groupIds);
  });

  test(
    'server ignoring the requested limit cannot expand the summary budget',
    () async {
      final value = await draft(
        rows: [
          row(10),
          for (var id = 11; id < 100; id++)
            row(id, parent: 10, tags: 'tag_$id'),
        ],
        count: 90,
      );
      expect(value.tags, hasLength(40));
      expect(value.tags, isNot(contains('tag_50')));
      expect(value.coverage, PoolTagCoverage.partial);
    },
  );
}

class _Access extends ContentProfileAccess {
  _Access(this.access);
  final ContentAccessContext access;
  @override
  ContentAccessContext? build(String arg) => access;
  void revoke() => state = null;
}
