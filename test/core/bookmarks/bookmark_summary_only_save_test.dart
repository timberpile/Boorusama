import 'package:boorusama/core/blacklists/providers.dart';
import 'package:boorusama/core/bookmarks/src/providers/bookmark_provider.dart';
import 'package:boorusama/core/bookmarks/src/providers/pool_bookmark_provider.dart';
import 'package:boorusama/core/bookmarks/src/providers/related_bookmark_provider.dart';
import 'package:boorusama/core/bookmarks/src/types/pool_bookmark_capability.dart';
import 'package:boorusama/core/bookmarks/types.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/posts/post/providers.dart';
import 'package:boorusama/core/posts/related/related_family.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'pool_bookmark_test_utils.dart';

class _Library extends BookmarkLibraryNotifier {
  _Library(this.saved, {this.onBuild});

  final List<CollectionBookmark> saved;
  final void Function()? onBuild;

  @override
  Future<BookmarkLibraryState> build() async {
    onBuild?.call();
    return BookmarkLibraryState(
      bookmarks: const [],
      groups: const [],
      pools: saved,
    );
  }
}

void main() {
  final config = BooruConfig.fromJson({
    ...BooruConfig.defaultConfig(
      booruType: poolOrigin().booruType,
      url: 'https://danbooru.donmai.us/install',
      customDownloadFileNameFormat: null,
    ).toJson(),
    'id': poolProfile,
  });
  final site = Uri.parse(config.url);

  ProviderContainer containerFor(
    List<CollectionBookmark> saved, {
    required void Function() onRepositoryRead,
    required void Function() onBlacklistRead,
    void Function()? onLibraryRead,
  }) => ProviderContainer(
    overrides: [
      bookmarkProvider.overrideWith(
        () => _Library(saved, onBuild: onLibraryRead),
      ),
      originAwarePostRepoProvider.overrideWith((ref, config) {
        onRepositoryRead();
        throw StateError('Summary-only drafts must not fetch Posts');
      }),
      blacklistTagsProvider.overrideWith((ref, filter) async {
        onBlacklistRead();
        throw StateError('Summary-only drafts must not load blacklists');
      }),
    ],
  );

  test('new Pool draft uses supplied Summary facts only', () async {
    var repositoryReads = 0;
    var blacklistReads = 0;
    final container = containerFor(
      const [],
      onRepositoryRead: () => repositoryReads++,
      onBlacklistRead: () => blacklistReads++,
    );
    addTearDown(container.dispose);

    final draft = await container.read(
      poolBookmarkDraftProvider((
        config,
        const RemoteBookmarkPool(
          id: 42,
          title: 'Source pool title',
          category: BookmarkedPoolCategory.series,
          total: 12,
        ),
      )).future,
    );

    expect(draft, isA<PoolBookmark>());
    expect(draft.sourceSite, site);
    expect(draft.origin.sourceHost, 'danbooru.donmai.us/install');
    expect(draft.referenceId, 42);
    expect(draft.title, 'Source pool title');
    expect(draft.total, 12);
    expect(draft.coverage, PoolTagCoverage.unknown);
    expect(draft.tags, isEmpty);
    expect(draft.groupIds, isEmpty);
    expect(draft.addedAt, isEmpty);
    expect(draft.cover, isNull);
    expect(draft.coverUrl, isNull);
    expect(draft.coverPolicy, isNull);
    expect(draft.oldestUpload, isNull);
    expect(draft.newestUpload, isNull);
    expect(draft.createdAt, draft.observedAt);
    expect(repositoryReads, 0);
    expect(blacklistReads, 0);
  });

  test(
    'existing Pool draft returns saved view without replacing metadata',
    () async {
      var repositoryReads = 0;
      var blacklistReads = 0;
      final saved = PoolBookmark(
        localId: '550e8400-e29b-41d4-a716-446655440022',
        origin: postOriginFromConfig(config),
        poolId: 42,
        category: BookmarkedPoolCategory.collection,
        title: 'Saved title',
        createdAt: DateTime.utc(2023),
        observedAt: DateTime.utc(2024),
        groupIds: const {poolGroupA},
        tags: const {'saved_tag'},
        coverage: PoolTagCoverage.partial,
        total: 4,
      );
      final container = containerFor(
        [saved],
        onRepositoryRead: () => repositoryReads++,
        onBlacklistRead: () => blacklistReads++,
      );
      addTearDown(container.dispose);

      final draft = await container.read(
        poolBookmarkDraftProvider((
          config,
          const RemoteBookmarkPool(
            id: 42,
            title: 'New remote title',
            category: BookmarkedPoolCategory.series,
            total: 99,
          ),
        )).future,
      );

      expect(identical(draft, saved), isTrue);
      expect(draft.title, 'Saved title');
      expect(draft.tags, {'saved_tag'});
      expect(draft.groupIds, {poolGroupA});
      expect(repositoryReads, 0);
      expect(blacklistReads, 0);
    },
  );

  test(
    'new Related draft keeps family identity and has no invented summary facts',
    () async {
      var repositoryReads = 0;
      var blacklistReads = 0;
      final family = RelatedFamilyReference(
        origin: postOriginFromConfig(config),
        anchorId: 73,
      );
      final container = containerFor(
        const [],
        onRepositoryRead: () => repositoryReads++,
        onBlacklistRead: () => blacklistReads++,
      );
      addTearDown(container.dispose);

      final draft = await container.read(
        relatedBookmarkDraftProvider((config, family)).future,
      );

      expect(draft, isA<RelatedCollectionBookmark>());
      expect(draft.sourceSite, site);
      expect(draft.family, family);
      expect(draft.referenceId, 73);
      expect(draft.title, isEmpty);
      expect(draft.total, isNull);
      expect(draft.coverage, PoolTagCoverage.unknown);
      expect(draft.tags, isEmpty);
      expect(draft.groupIds, isEmpty);
      expect(draft.addedAt, isEmpty);
      expect(draft.cover, isNull);
      expect(draft.coverPolicy, isNull);
      expect(draft.oldestUpload, isNull);
      expect(draft.newestUpload, isNull);
      expect(draft.createdAt, draft.observedAt);
      expect(repositoryReads, 0);
      expect(blacklistReads, 0);
    },
  );

  test('existing Related draft returns saved family view unchanged', () async {
    var repositoryReads = 0;
    var blacklistReads = 0;
    final family = RelatedFamilyReference(
      origin: postOriginFromConfig(config),
      anchorId: 73,
    );
    final saved = RelatedCollectionBookmark(
      family: family,
      localId: '550e8400-e29b-41d4-a716-446655440023',
      createdAt: DateTime.utc(2022),
      observedAt: DateTime.utc(2024),
      groupIds: const {poolGroupA},
      tags: const {'related_saved'},
      coverage: PoolTagCoverage.partial,
      total: 8,
    );
    final container = containerFor(
      [saved],
      onRepositoryRead: () => repositoryReads++,
      onBlacklistRead: () => blacklistReads++,
    );
    addTearDown(container.dispose);

    final draft = await container.read(
      relatedBookmarkDraftProvider((config, family)).future,
    );

    expect(identical(draft, saved), isTrue);
    expect(draft.title, isEmpty);
    expect(draft.tags, {'related_saved'});
    expect(draft.groupIds, {poolGroupA});
    expect(repositoryReads, 0);
    expect(blacklistReads, 0);
  });

  test(
    'Related draft rejects a different source namespace before library lookup',
    () async {
      var libraryReads = 0;
      var repositoryReads = 0;
      var blacklistReads = 0;
      final otherConfig = BooruConfig.fromJson({
        ...config.toJson(),
        'url': 'https://other.example/install',
      });
      final family = RelatedFamilyReference(
        origin: postOriginFromConfig(config),
        anchorId: 73,
      );
      final container = containerFor(
        const [],
        onRepositoryRead: () => repositoryReads++,
        onBlacklistRead: () => blacklistReads++,
        onLibraryRead: () => libraryReads++,
      );
      addTearDown(container.dispose);
      await expectLater(
        container.read(
          relatedBookmarkDraftProvider((otherConfig, family)).future,
        ),
        throwsStateError,
      );
      expect(libraryReads, 0);
      expect(repositoryReads, 0);
      expect(blacklistReads, 0);
    },
  );
}
