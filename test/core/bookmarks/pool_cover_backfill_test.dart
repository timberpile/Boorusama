import 'dart:async';

import 'package:clock/clock.dart';

import 'package:boorusama/core/blacklists/providers.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/bookmarks/providers.dart';
import 'package:boorusama/core/bookmarks/types.dart';
import 'package:boorusama/core/bookmarks/src/providers/pool_bookmark_provider.dart';
import 'package:boorusama/core/bookmarks/src/services/pool_cover_backfill_queue.dart';
import 'package:boorusama/core/bookmarks/src/types/pool_bookmark_cover.dart';
import 'package:boorusama/core/bookmarks/src/types/pool_bookmark_capability.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/configs/manage/providers.dart';
import 'package:boorusama/core/posts/post/providers.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/posts/rating/types.dart';
import 'package:boorusama/core/search/queries/types.dart';
import 'package:boorusama/core/settings/types.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fakes/test_post.dart';
import 'pool_bookmark_test_utils.dart';

class _Profiles extends BooruConfigNotifier {
  _Profiles(List<BooruConfig> profiles) : super(initialConfigs: profiles);
  void removeAll() => state = [];
}

class _Saved extends BookmarkLibraryNotifier {
  _Saved(this.pool);
  final CollectionBookmark pool;
  CollectionBookmark? filled;
  @override
  Future<BookmarkLibraryState> build() async => BookmarkLibraryState(
    bookmarks: const [],
    pools: [pool],
    groups: const [],
  );
  @override
  Future<void> fillMissingPoolCover(
    CollectionBookmark summary, {
    required bool Function() canCommit,
  }) async {
    if (canCommit()) filled = pool.withMissingCoverFrom(summary);
  }
}

void main() {
  final config = BooruConfig.fromJson({
    ...BooruConfig.defaultConfig(
      booruType: BooruType.danbooru,
      url: 'https://danbooru.donmai.us',
      customDownloadFileNameFormat: null,
    ).toJson(),
    'id': poolProfile,
  });
  Post post({Set<String> tags = const {}, Rating rating = Rating.general}) {
    const codec = StoredPostCodec();
    final snapshot = codec.encode(
      TestPost(
        id: 1,
        origin: poolOrigin(),
        booruData: const LegacyPostData(typeKey: 'legacy_danbooru', custom: {}),
        tags: tags,
        thumbnailImageUrl: 'https://danbooru.donmai.us/cover.jpg',
      ),
    );
    return (codec.decode(
      StoredPostSnapshot(
        origin: snapshot.origin,
        common: {...snapshot.common, 'rating': rating.name},
        custom: snapshot.custom,
        codecVersion: snapshot.codecVersion,
      ),
    ) as StoredPostDecodeSuccess).post;
  }

  test('failed cover jobs retry after cooldown instead of remaining cached forever', () async {
    var now = DateTime.utc(2026);
    await withClock(Clock(() => now), () async {
      final queue = PoolCoverBackfillQueue();
      var calls = 0;
      Future<void> failing() async {
        calls++;
        throw StateError('offline');
      }

      await expectLater(queue.run('pool', failing), throwsStateError);
      await expectLater(queue.run('pool', failing), throwsStateError);
      expect(calls, 1);
      now = now.add(const Duration(minutes: 2));
      await queue.run('pool', () async {
        calls++;
      });
      expect(calls, 2);
    });
  });

  test(
    'background jobs deduplicate and serialize without blocking the caller',
    () async {
      final queue = PoolCoverBackfillQueue();
      final gate = Completer<void>();
      final entered = Completer<void>();
      final calls = <int>[];
      final first = queue.run<void>('a', () async {
        calls.add(1);
        entered.complete();
        await gate.future;
      });
      expect(
        queue.run<void>('a', () async {
          fail('duplicate');
        }),
        same(first),
      );
      final second = queue.run('b', () async {
        calls.add(2);
      });
      await entered.future;
      expect(calls, [1]);
      gate.complete();
      await Future.wait([first, second]);
      expect(calls, [1, 2]);
    },
  );

  test('completed cover retention is bounded and in-flight keys remain deduplicated', () async {
    final queue = PoolCoverBackfillQueue(maxCompletedJobs: 2);
    var calls = 0;
    await queue.run('first', () async {
      calls++;
    });
    await queue.run('second', () async {});
    await queue.run('third', () async {});
    await queue.run('first', () async {
      calls++;
    });
    expect(calls, 2);
  });

  test('cached cover requires verified source, policy, static media and permitted rating', () {
    expect(eligiblePoolCover(config, {}, [post()]), isNotNull);
    expect(
      eligiblePoolCover(
        config,
        {'blocked'},
        [
          post(tags: {'blocked'}),
        ],
      ),
      isNull,
    );
    expect(eligiblePoolCover(config, {}, [TestPost(id: 2)]), isNull);
    final restricted = BooruConfig.fromJson({
      ...config.toJson(),
      'ratingFilter': BooruConfigRatingFilter.hideNSFW.index,
    });
    expect(
      eligiblePoolCover(restricted, {}, [post(rating: Rating.explicit)]),
      isNull,
    );
  });

  test(
    'new draft takes an eligible loaded member without fetching metadata',
    () async {
      var calls = 0;
      final container = ProviderContainer(
        overrides: [
          bookmarkProvider.overrideWith(() => _Saved(testPool())),
          blacklistTagsProvider.overrideWith((_, _) async => {}),
          originAwarePostRepoProvider.overrideWith((_, _) {
            calls++;
            throw StateError('must not fetch');
          }),
        ],
      );
      addTearDown(container.dispose);
      final keep = container.listen(
        blacklistTagsProvider(config.filter),
        (_, _) {},
      );
      addTearDown(keep.close);
      await container.read(blacklistTagsProvider(config.filter).future);
      final draft = await container.read(
        poolBookmarkDraftProvider((
          config,
          RemoteBookmarkPool(
            id: 20,
            title: 'New',
            category: BookmarkedPoolCategory.series,
            total: 1,
            cachedMembers: [post()],
          ),
        )).future,
      );
      expect(draft.coverUrl, post().thumbnailImageUrl);
      expect(draft.groupIds, isEmpty);
      expect(calls, 0);
    },
  );

  test('cover-only merge preserves identity, membership dates and unrelated metadata', () {
    final original = testPool();
    final summary = original.copyWith(
      cover: PoolBookmarkCover.fromPost(post()),
      coverUrl: post().thumbnailImageUrl,
      coverPolicy: 'safe',
    );
    final merged = original.withMissingCoverFrom(summary);
    expect(merged.coverUrl, post().thumbnailImageUrl);
    expect(merged.localId, original.localId);
    expect(merged.groupIds, original.groupIds);
    expect(merged.addedAt, original.addedAt);
    expect(merged.createdAt, original.createdAt);
    expect(merged.tags, original.tags);
    expect(
      merged.withMissingCoverFrom(summary.copyWith(coverUrl: 'replacement')),
      same(merged),
    );
    expect(
      original.withMissingCoverFrom(summary.copyWith(localId: 'different')),
      same(original),
    );
  });

  for (final scenario in [
    'eligible',
    'empty',
    'blocked',
    'transient',
    'offline',
    'revoked',
  ]) {
    test('missing imported cover $scenario is bounded and cached', () async {
      final pool = testPool();
      final saved = _Saved(pool);
      var calls = 0;
      final requests = <String>[];
      final entered = Completer<void>();
      final reply = Completer<PostResult<Post>>();
      final profiles = _Profiles([config]);
      final container = ProviderContainer(
        overrides: [
          bookmarkProvider.overrideWith(() => saved),
          booruConfigProvider.overrideWith(
            () => profiles,
          ),
          blacklistTagsProvider.overrideWith(
            (_, _) async => scenario == 'blocked' ? {'blocked'} : {},
          ),
          originAwarePostRepoProvider.overrideWith(
            (_, _) => PostRepositoryBuilder<Post>(
              fetch: (tags, page, {limit, options}) async {
                calls++;
                requests.add(tags.join(' '));
                if (scenario == 'revoked') {
                  entered.complete();
                  return reply.future;
                }
                expect(limit, lessThanOrEqualTo(40));
                if (scenario == 'offline' ||
                    (scenario == 'transient' && calls == 1))
                  throw StateError('offline');
                if (scenario == 'empty') return PostResult<Post>.empty();
                return PostResult<Post>(
                  posts: [
                    post(tags: {'blocked'}),
                  ],
                  total: 1,
                );
              },
              fetchSingle: (_, {options}) async => null,
              getSettings: () async => Settings.defaultSettings.listing,
              tagComposer: EmptyTagQueryComposer(),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      await container.read(bookmarkProvider.future);
      final provider = missingPoolCoverProvider((config, pool));
      final subscription = container.listen(provider, (_, _) {});
      addTearDown(subscription.close);
      final pending = container.read(provider.future);
      if (scenario == 'revoked') {
        await entered.future;
        profiles.removeAll();
        await container.pump();
        reply.complete(PostResult(posts: [post()], total: 1));
      }
      if (scenario == 'offline') {
        await expectLater(pending, throwsA(anything));
      } else {
        await pending;
      }
      expect(
        calls,
        scenario == 'transient' || scenario == 'offline' ? 2 : 1,
        reason: requests.toString(),
      );
      expect(
        saved.filled?.cover,
        scenario == 'eligible' || scenario == 'transient' ? isNotNull : isNull,
      );
      final after = calls;
      try {
        await container.read(provider.future);
      } catch (_) {}
      expect(calls, after);
    });
  }
}
