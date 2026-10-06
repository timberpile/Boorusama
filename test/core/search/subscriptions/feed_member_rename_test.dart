import 'package:boorusama/core/search/subscriptions/providers.dart';
import 'package:boorusama/core/search/subscriptions/types.dart';
import 'package:flutter_test/flutter_test.dart';
import 'pinned_search_test_utils.dart';

void main() {
  late PinnedSearchHarness h;
  setUp(() => h = PinnedSearchHarness());
  tearDown(() => h.dispose());
  Future<(SearchFollowingFeed, SearchFollowingFeed, SearchSubscription)>
  seed() async {
    final first = await h.repository.saveFeed(
      profileId: testProfile.id,
      name: 'First',
      queries: ['cat', 'dog'],
    );
    final second = await h.repository.saveFeed(
      profileId: testProfile.id,
      name: 'Second',
      queries: ['cat'],
    );
    final source = pinnedFixture(
      id: first.sourceIds.first,
      query: 'cat',
      name: null,
      previewCount: 1,
    );
    final dog = (await h.repository.getById(first.sourceIds.last))!;
    await h.seed([source, dog]);
    await h.container.read(searchSubscriptionsProvider.future);
    return (first, second, source);
  }

  test(
    'renaming a shared member changes both feeds without changing runtime or membership',
    () async {
      final (first, second, source) = await seed();
      final notifier = h.container.read(searchSubscriptionsProvider.notifier);
      await notifier.renameFeedMember(
        feedId: first.id,
        source: source,
        name: 'Artist',
      );
      final renamed = (await h.repository.getById(source.id))!;
      expect(renamed.name, 'Artist');
      expect([...renamed.props]..removeAt(4), [...source.props]..removeAt(4));
      expect((await h.repository.getFeeds()).map((f) => f.sourceIds), [
        first.sourceIds,
        second.sourceIds,
      ]);
      expect(h.requests, isEmpty);
      await notifier.renameFeedMember(
        feedId: second.id,
        source: renamed,
        name: '  ',
      );
      expect(await h.repository.getById(source.id), source);
    },
  );
  test('a removed member cannot be renamed through a stale dialog', () async {
    final (first, second, source) = await seed();
    final notifier = h.container.read(searchSubscriptionsProvider.notifier);
    await notifier.setFeedFollowing(
      feedId: first.id,
      profileId: testProfile.id,
      query: 'cat',
      following: false,
    );
    await expectLater(
      notifier.renameFeedMember(
        feedId: first.id,
        source: source,
        name: 'Stale',
      ),
      throwsStateError,
    );
    expect(await h.repository.getById(source.id), source);
    expect((await h.repository.getFeeds()).last.sourceIds, second.sourceIds);
  });
  test(
    'a replaced definition reusing a member UUID rejects an old name dialog',
    () async {
      final (first, _, source) = await seed();
      final replacement = SearchSubscription.create(
        id: source.id,
        profileId: source.profileId,
        query: source.query,
        name: null,
        position: 0,
        createdAt: source.createdAt.add(const Duration(seconds: 1)),
      );
      final dog = (await h.repository.getById(first.sourceIds.last))!;
      await h.seed([replacement, dog]);
      final notifier = h.container.read(searchSubscriptionsProvider.notifier);
      await expectLater(
        notifier.renameFeedMember(
          feedId: first.id,
          source: source,
          name: 'Stale',
        ),
        throwsStateError,
      );
      expect(await h.repository.getById(source.id), replacement);
    },
  );
}
