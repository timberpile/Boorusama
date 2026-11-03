import 'package:booru_clients/danbooru.dart';
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
      BookmarkLibraryState(bookmarks: [], groups: [], pools: saved);
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
  final reference = RelatedBookmark(
    family: family,
    localId: testPool().localId,
    createdAt: DateTime.utc(2025),
    observedAt: DateTime.utc(2025),
    groupIds: {poolGroupA},
    tags: {'last_known'},
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
  }) async {
    final current = source ?? config;
    final dio = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (request, handler) {
            calls?.add(request);
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
        blacklistTagsProvider.overrideWith((ref, filter) async => blacklist),
        originAwarePostRepoProvider.overrideWith(
          (ref, config) => OriginAwarePostRepository(
            delegate: ref.watch(danbooruPostRepoProvider(config.search)),
            origin: postOriginFromConfig(config),
          ),
        ),
        danbooruClientProvider.overrideWith(
          (ref, auth) => DanbooruClient(baseUrl: auth.url, dio: dio),
        ),
      ],
    );
    addTearDown(() {
      container.dispose();
      dio.close();
    });
    final provider = relatedBookmarkDraftProvider((current, family));
    container.listen(provider, (_, _) {});
    return (await Future.wait([
      for (var i = 0; i < readers; i++) container.read(provider.future),
    ])).first;
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
        row(12, parent: 10, tags: 'visible', ext: 'gif'),
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
