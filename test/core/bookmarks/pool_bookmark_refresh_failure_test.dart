import 'package:flutter_test/flutter_test.dart';
import 'package:boorusama/core/bookmarks/src/types/pool_bookmark_cover.dart';

import '../../support/fakes/test_post.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/posts/post/providers.dart';
import 'package:boorusama/core/settings/types.dart';
import 'package:boorusama/core/search/queries/types.dart';
import 'package:boorusama/core/blacklists/providers.dart';
import 'package:boorusama/core/bookmarks/types.dart';
import 'package:boorusama/core/bookmarks/providers.dart';
import 'package:boorusama/core/bookmarks/src/providers/pool_bookmark_provider.dart';
import 'package:boorusama/core/bookmarks/src/types/pool_bookmark_capability.dart';

class _Saved extends BookmarkLibraryNotifier {
  _Saved(this.library);
  final BookmarkLibraryState library;
  @override
  Future<BookmarkLibraryState> build() async => library;
}

void main() {
  for (final authoritativeChange in [false, true]) {
    test(
      'explicit Pool refresh uses source order evidence, not sampled member windows (changed=$authoritativeChange)',
      () async {
        final config = BooruConfig.defaultConfig(
          booruType: BooruType.danbooru,
          url: 'https://danbooru.donmai.us',
          customDownloadFileNameFormat: null,
        );
        Post member(int id) => TestPost(
          id: id,
          origin: postOriginFromConfig(config),
          thumbnailImageUrl: 'https://danbooru.donmai.us/$id.jpg',
        );
        final selected = PoolBookmarkCover.fromPost(member(2))
            .withMemberOrder('a' * 64);
        final old = PoolBookmark(
          localId: '550e8400-e29b-41d4-a716-446655440022',
          origin: postOriginFromConfig(config),
          poolId: 10,
          category: BookmarkedPoolCategory.series,
          title: 'Series',
          createdAt: DateTime.utc(2026),
          observedAt: DateTime.utc(2026),
          groupIds: {defaultBookmarkGroupId},
          tags: {},
          coverage: PoolTagCoverage.partial,
          cover: selected,
          coverUrl: selected.thumbnail,
        );
        final container = ProviderContainer(
          overrides: [
            bookmarkProvider.overrideWith(
              () => _Saved(
                BookmarkLibraryState(bookmarks: [], groups: [], pools: [old]),
              ),
            ),
            blacklistTagsProvider.overrideWith((ref, filter) async => {}),
            originAwarePostRepoProvider.overrideWith(
              (ref, config) => PostRepositoryBuilder<Post>(
                fetch: (tags, page, {limit, options}) async => PostResult(
                  posts: [member(1), member(2), member(3)],
                  total: 3,
                ),
                fetchSingle: (_, {options}) async => null,
                getSettings: () async => Settings.defaultSettings.listing,
                tagComposer: EmptyTagQueryComposer(),
              ),
            ),
          ],
        );
        addTearDown(container.dispose);
        final refreshed = await container.read(
          poolBookmarkRefreshProvider((
            config,
            RemoteBookmarkPool(
              id: 10,
              title: 'Series',
              category: BookmarkedPoolCategory.series,
              total: 3,
              memberOrderDigest: (authoritativeChange ? 'b' : 'a') * 64,
            ),
          )).future,
        );
        expect(refreshed.cover?.postId, authoritativeChange ? 1 : 2);
        if (!authoritativeChange) expect(refreshed.cover, selected);
      },
    );
  }
  for (final scenario in [
    'offline',
    'date failure',
    'empty',
    'initial offline',
  ]) {
    test('Pool refresh preserves safe metadata on $scenario', () async {
      final config = BooruConfig.defaultConfig(
        booruType: BooruType.danbooru,
        url: 'https://danbooru.donmai.us',
        customDownloadFileNameFormat: null,
      );
      final old = PoolBookmark(
        localId: '550e8400-e29b-41d4-a716-446655440022',
        origin: postOriginFromConfig(config),
        poolId: 10,
        category: BookmarkedPoolCategory.series,
        title: 'Series',
        createdAt: DateTime.utc(2026),
        observedAt: DateTime.utc(2026),
        groupIds: const {defaultBookmarkGroupId},
        tags: const {'last_known_tag'},
        coverage: PoolTagCoverage.complete,
        total: 2,
        coverUrl: 'https://danbooru.donmai.us/safe.jpg',
        coverPolicy: poolCoverPolicy(config, {}),
        oldestUpload: DateTime.utc(2020),
        newestUpload: DateTime.utc(2025),
      );
      final library = BookmarkLibraryState(
        bookmarks: const [],
        pools: scenario == 'initial offline' ? [] : [old],
        groups: [
          BookmarkGroup(
            id: defaultBookmarkGroupId,
            name: 'Default',
            bookmarkIds: const {},
          ),
        ],
      );
      var calls = 0;
      final container = ProviderContainer(
        overrides: [
          bookmarkProvider.overrideWith(() => _Saved(library)),
          blacklistTagsProvider.overrideWith(
            (_, _) => Future.value(<String>{}),
          ),
          originAwarePostRepoProvider.overrideWith(
            (_, _) => PostRepositoryBuilder<Post>(
              fetch: (tags, page, {limit, options}) async {
                calls++;
                if (scenario == 'empty') return PostResult<Post>.empty();
                if (scenario == 'date failure' && calls == 1) {
                  return PostResult<Post>.empty();
                }
                throw StateError('offline');
              },
              fetchSingle: (id, {options}) async => null,
              getSettings: () async => Settings.defaultSettings.listing,
              tagComposer: EmptyTagQueryComposer(),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      final result = container.read(
        poolBookmarkRefreshProvider((
          config,
          RemoteBookmarkPool(
            id: 10,
            title: 'Series',
            category: BookmarkedPoolCategory.series,
            total: scenario == 'empty' ? 0 : 2,
            supportsUploadOrder: true,
          ),
        )).future,
      );
      if (scenario == 'offline' || scenario == 'date failure') {
        await expectLater(result, throwsStateError);
        final persisted = (await container.read(bookmarkProvider.future))
            .pools
            .single;
        expect(persisted, old);
        expect(persisted.tags, {'last_known_tag'});
        expect(persisted.coverUrl, old.coverUrl);
        expect(persisted.oldestUpload, old.oldestUpload);
      } else {
        final draft = await result;
        expect(draft.tags, isEmpty);
        expect(draft.coverUrl, isNull);
        expect(
          draft.coverage,
          scenario == 'empty'
              ? PoolTagCoverage.complete
              : PoolTagCoverage.unknown,
        );
      }
      expect(calls, scenario == 'empty' ? 1 : 3);
    });
  }
}
