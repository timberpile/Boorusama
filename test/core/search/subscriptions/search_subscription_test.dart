// Package imports:
import 'package:flutter_test/flutter_test.dart';

// Project imports:
import 'package:boorusama/core/search/subscriptions/types.dart';

void main() {
  final now = DateTime.utc(2026, 9, 14, 12);

  SearchSubscription subscription({
    required String id,
    DateTime? lastSuccessfulCheckAt,
  }) {
    return SearchSubscription(
      id: id,
      profileId: 7,
      query: 'cat_girl order:id',
      position: 0,
      createdAt: now,
      previews: const [],
      recentPostIdentities: const [],
      unreadCount: 0,
      lastSuccessfulCheckAt: lastSuccessfulCheckAt,
    );
  }

  test(
    'stores blank custom names as null and falls back to the exact query',
    () {
      final unnamed = SearchSubscription.create(
        id: 'unnamed',
        profileId: 7,
        query: '  cat_girl   order:id  ',
        name: '   ',
        position: 0,
        createdAt: now,
      );

      expect(unnamed.name, isNull);
      expect(unnamed.query, 'cat_girl   order:id');
      expect(unnamed.displayName, 'cat_girl   order:id');
    },
  );

  for (final testCase in [
    (name: '', description: 'empty'),
    (name: '   ', description: 'whitespace-only'),
  ]) {
    test(
      'normalizes a ${testCase.description} direct custom name to null',
      () {
        final item = SearchSubscription(
          id: 'direct-${testCase.description}',
          profileId: 7,
          query: 'cat_girl order:id',
          name: testCase.name,
          position: 0,
          createdAt: now,
          previews: const [],
          recentPostIdentities: const [],
          unreadCount: 0,
        );

        expect(item.name, isNull);
        expect(item.displayName, 'cat_girl order:id');
      },
    );
  }

  test('normalizes query identities without changing term order or casing', () {
    expect(normalizeSearchIdentity('  A   B  '), 'A B');
    expect(normalizeSearchIdentity('  B  A  '), 'B A');
  });

  test('keeps subscription and refresh collections immutable snapshots', () {
    final preview = SearchPostPreview(
      postId: 1,
      postCreatedAt: now,
      thumbnailUrl: 'https://example.com/thumbnail.jpg',
      sampleUrl: null,
      discoveredAt: now,
    );
    final identity = RecentSearchPostIdentity(
      postId: 1,
      postCreatedAt: now,
    );
    final previews = [preview];
    final identities = [identity];
    final discoveredPosts = [preview];
    final item = SearchSubscription(
      id: 'immutable',
      profileId: 7,
      query: 'cat_girl order:id',
      position: 0,
      createdAt: now,
      previews: previews,
      recentPostIdentities: identities,
      unreadCount: 0,
    );
    final commit = SearchRefreshCommit(
      subscriptionId: item.id,
      expectedCheckpoint: null,
      startedAt: now,
      identityRetentionBoundary: now.subtract(const Duration(days: 1)),
      baseline: true,
      discoveredPosts: discoveredPosts,
    );

    previews.clear();
    identities.clear();
    discoveredPosts.clear();

    expect(item.previews, [preview]);
    expect(item.recentPostIdentities, [identity]);
    expect(commit.discoveredPosts, [preview]);
    expect(
      () => item.previews.add(preview),
      throwsA(isA<UnsupportedError>()),
    );
    expect(
      () => item.recentPostIdentities.add(identity),
      throwsA(isA<UnsupportedError>()),
    );
    expect(
      () => commit.discoveredPosts.add(preview),
      throwsA(isA<UnsupportedError>()),
    );
  });

  test(
    'prioritizes unchecked searches before the oldest successful refresh',
    () {
      const neverId = 'never';
      const oldestId = 'oldest';
      const recentId = 'recent';
      final neverChecked = subscription(id: neverId);
      final oldest = subscription(
        id: oldestId,
        lastSuccessfulCheckAt: DateTime.utc(2026, 9),
      );
      final recent = subscription(
        id: recentId,
        lastSuccessfulCheckAt: DateTime.utc(2026, 9, 10),
      );

      final ordered = [recent, neverChecked, oldest]
        ..sort(compareSearchRefreshPriority);

      expect(ordered.map((item) => item.id), [neverId, oldestId, recentId]);
    },
  );
}
