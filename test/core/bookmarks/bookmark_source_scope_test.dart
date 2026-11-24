import 'package:boorusama/boorus/pixiv/posts/link_generator.dart';
import 'package:boorusama/boorus/pixiv/posts/post_codec.dart';
import 'package:boorusama/boorus/pixiv/works/bookmark_targets.dart';
import 'package:boorusama/boorus/pixiv/works/work_mapper.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_grid_entry.dart';
import 'package:boorusama/core/bookmarks/src/types/legacy_group_bookmark.dart';
import 'package:boorusama/core/content/types.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_mirror_state.dart';

import '../../boorus/pixiv/works/work_test_fixtures.dart';
import '../../support/fakes/test_post.dart';
import 'pool_bookmark_test_utils.dart';

import 'package:boorusama/core/bookmarks/src/providers/bookmark_group_selectors.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:boorusama/core/bookmarks/src/providers/bookmark_provider.dart';
import 'package:boorusama/core/bookmarks/src/providers/local_providers.dart';
import 'package:boorusama/core/bookmarks/src/providers/suggestion_provider.dart';
import 'package:boorusama/core/configs/manage/providers.dart';
import 'package:boorusama/core/bookmarks/src/data/stored_bookmark_codec.dart';
import 'package:boorusama/core/bookmarks/types.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/posts/post/types.dart';

void main() {
  test(
    'saved Pixiv Ugoira and Works share one source in All and Groups',
    () async {
      final access = workAccess(site: 'https://pixiv.net');
      final animation = pixivWorkPagePosts(
        work(type: 'ugoira', pageCount: 1),
        access,
      ).single;
      final at = DateTime.utc(2026);
      final artworkLink = const PixivPostLinkGenerator().getLink(animation);
      final draft = PixivPageBookmarkTarget(access: access, post: animation)
          .draft(currentAccess: access, at: at)
          .copyWith(id: 1, sourceUrl: artworkLink);
      final codec = StoredBookmarkCodec(
        postDataCodec: (_) => const PixivPostCodec(),
      );
      final ugoira = codec.decode(codec.encode(draft)) as PostBookmark;
      final illustration = PixivWorkBookmarkTarget(
        access: access,
        summary: pixivWorkSummary(work(id: 121), access),
      ).draft(currentAccess: access, at: at).copyWith(id: 2);
      final library = BookmarkLibraryState(
        bookmarks: [ugoira],
        records: [ugoira, illustration],
        groups: [
          BookmarkGroup(
            id: poolGroupA,
            name: 'Pixiv',
            bookmarkIds: const {1, 2},
          ),
        ],
      );
      final container = ProviderContainer(
        overrides: [bookmarkProvider.overrideWith(() => _Library(library))],
      );
      addTearDown(container.dispose);

      expect(ugoira.sourceUrl, 'https://www.pixiv.net/artworks/120');
      expect(ugoira.identity.site, 'pixiv.net');
      expect(illustration.reference.siteNamespace, 'pixiv.net');
      for (final view in [
        const BookmarkView.all(),
        BookmarkView.group(poolGroupA),
      ]) {
        expect(
          await container.read(
            availableBookmarkViewSourcesProvider(view).future,
          ),
          ['pixiv.net'],
        );
        container.read(selectedBooruUrlProvider.notifier).state =
            'www.pixiv.net';
        final selected = container.read(effectiveBookmarkSourceProvider(view));
        expect(selected, 'pixiv.net');
        final entries = selectBookmarkGridEntries(
          state: library,
          view: view,
          selectedTags: const [],
          sortType: BookmarkSortType.newest,
          selectedBooruUrl: selected,
        );
        expect(entries.whereType<BookmarkPostEntry>().single.bookmark, ugoira);
        expect(
          entries.whereType<BookmarkNativeGroupEntry>().single.bookmark,
          illustration,
        );
      }
    },
  );

  test('imported source choices and filtering use portable origins without profiles', () async {
    const codec = StoredBookmarkCodec();
    const hosts = [
      'danbooru.donmai.us',
      'rule34.xxx',
      'gelbooru.com',
      'realbooru.com',
    ];
    final records = [
      for (final (id, host) in hosts.indexed)
        codec.decode(
          codec.encodeForTransfer(
            PostBookmark(
              id: id,
              booruId: BooruType.gelbooruV2.id,
              createdAt: DateTime.utc(2024),
              updatedAt: DateTime.utc(2024),
              thumbnailUrl: '',
              sampleUrl: '',
              originalUrl: '',
              sourceUrl: 'https://$host',
              width: 100,
              height: 100,
              md5: '',
              tags: {'source_$id'},
              realSourceUrl: null,
              format: 'jpg',
              imageUrlResolver: const DefaultImageUrlResolver(),
              postId: id + 1,
              metadata: const {},
            ),
          ),
        ) as PostBookmark,
    ];
    expect(records.map((r) => r.sourceUrl), everyElement(isEmpty));
    final state = BookmarkLibraryState(
      bookmarks: records,
      records: records,
      groups: [
        BookmarkGroup(
          id: defaultBookmarkGroupId,
          name: 'Default',
          bookmarkIds: records.map((r) => r.id).toSet(),
        ),
      ],
    );
    final container = ProviderContainer(
      overrides: [
        bookmarkProvider.overrideWith(() => _Library(state)),
        booruConfigProvider.overrideWith(
          () => BooruConfigNotifier(initialConfigs: const []),
        ),
      ],
    );
    addTearDown(container.dispose);
    final suggestions = container.listen(
      bookmarkTagIndexProvider(const BookmarkView.all()),
      (_, _) {},
    );
    addTearDown(suggestions.close);
    expect(
      await container.read(availableBooruUrlsProvider.future),
      unorderedEquals(hosts),
    );
    for (final (id, host) in hosts.indexed) {
      expect(
        filterBookmarks(
          bookmarks: records,
          selectedTags: const [],
          sortType: BookmarkSortType.newest,
          selectedBooruUrl: host,
        ).map((r) => r.id),
        [id],
      );
      container.read(selectedBooruUrlProvider.notifier).state = host;
      final index = await container.read(
        bookmarkTagIndexProvider(const BookmarkView.all()).future,
      );
      expect(index.byName.keys, ['source_$id']);
      expect(index.byName.values.single.sources.keys.single.url, host);
    }
  });

  test('direct and subtree choices include received mixed records without profiles', () async {
    const child = '550e8400-e29b-41d4-a716-446655440003';
    const other = '550e8400-e29b-41d4-a716-446655440004';
    PostBookmark portable(int id, String host) {
      final post = TestPost(
        id: id,
        origin: poolOrigin(host: host),
        booruData: const LegacyPostData(typeKey: 'legacy_danbooru', custom: {}),
      );
      return PostBookmark.fromSnapshot(
        id: id,
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
        postId: id,
        post: post,
        snapshot: const StoredPostCodec().encode(post),
      );
    }

    final records = [
      portable(1, 'a.test'),
      portable(2, 'b.test'),
      portable(3, 'c.test'),
      portable(4, 'd.test'),
    ];
    final native = ContentGroupBookmark(
      id: 5,
      createdAt: DateTime.utc(2026),
      observedAt: DateTime.utc(2026),
      snapshot: StoredGroupSnapshot(
        summary: ContentGroupSummary(
          reference: const ContentReferenceCodec().parse(
            engine: BooruType.pixiv,
            site: Uri.parse('https://www.pixiv.net'),
            kind: ContentKind.group,
            sourceKey: 'work:120',
          ),
        ),
      ),
    );
    BookmarkMirrorOwner owner(String source) => BookmarkMirrorOwner(
      publisher: poolProfile,
      source: source,
      revision: 1,
      payloadDigest: 'a' * 64,
      groupDigest: 'b' * 64,
    );
    final initial = BookmarkLibraryState(
      bookmarks: records,
      groups: [
        BookmarkGroup(id: poolGroupA, name: 'Local A', bookmarkIds: const {1}),
        BookmarkGroup(
          id: poolGroupB,
          name: 'Received B',
          bookmarkIds: const {1, 2, 5, 6},
        ),
        BookmarkGroup(
          id: child,
          name: 'Child C',
          parentGroupId: poolGroupB,
          bookmarkIds: const {2, 3},
        ),
        BookmarkGroup(id: other, name: 'Other D', bookmarkIds: const {4}),
      ],
      records: [
        ...records,
        native,
        LegacyGroupBookmark.fromMetadata(
          id: 6,
          metadata: testPool(host: 'pool.test', groups: {poolGroupB}),
        ),
      ],
      mirrors: BookmarkMirrorState(
        epoch: 1,
        owners: {
          poolGroupB: owner(poolGroupB),
          child: owner(child),
          other: owner(other),
        },
      ),
    );
    final library = _Library(initial);
    final container = ProviderContainer(
      overrides: [
        bookmarkProvider.overrideWith(() => library),
        booruConfigProvider.overrideWith(
          () => BooruConfigNotifier(initialConfigs: const []),
        ),
      ],
    );
    addTearDown(container.dispose);
    final view = BookmarkView.group(poolGroupB);
    final subscriptions = [
      container.listen(availableBookmarkViewSourcesProvider(view), (_, _) {}),
      container.listen(effectiveBookmarkSourceProvider(view), (_, _) {}),
    ];
    addTearDown(() {
      for (final subscription in subscriptions) {
        subscription.close();
      }
    });
    expect(
      await container.read(availableBookmarkViewSourcesProvider(view).future),
      unorderedEquals(['a.test', 'b.test', 'pool.test', 'pixiv.net']),
    );
    expect(
      await container.read(
        availableBookmarkViewSourcesProvider(BookmarkView.subtree(poolGroupB))
            .future,
      ),
      unorderedEquals([
        'a.test',
        'b.test',
        'c.test',
        'pool.test',
        'pixiv.net',
      ]),
    );
    expect(await container.read(availableBooruUrlsProvider.future), ['a.test']);
    container.read(selectedBooruUrlProvider.notifier).state = 'b.test';
    expect(container.read(effectiveBookmarkSourceProvider(view)), 'b.test');
    expect(
      selectBookmarks(
        state: initial,
        view: view,
        selectedTags: ['no_match'],
        sortType: BookmarkSortType.newest,
        selectedBooruUrl: 'b.test',
      ),
      isEmpty,
    );
    expect(container.read(effectiveBookmarkSourceProvider(view)), 'b.test');
    library.replace(
      initial.applyCommittedChanges(
        groups: [
          for (final group in initial.groups)
            group.id == poolGroupB ? group.copyWith(bookmarkIds: {1}) : group,
        ],
        folders: initial.folders,
      ),
    );
    await container.read(availableBookmarkViewSourcesProvider(view).future);
    expect(container.read(effectiveBookmarkSourceProvider(view)), isNull);
    expect(
      container.read(bookmarkProvider).requireValue.mirrors,
      initial.mirrors,
    );

    // Native records still supply source choices without a reader.
    library.replace(
      BookmarkLibraryState(
        bookmarks: const [],
        records: [native],
        groups: [
          BookmarkGroup(
            id: poolGroupB,
            name: 'Received native',
            bookmarkIds: const {5},
          ),
        ],
        mirrors: initial.mirrors,
      ),
    );
    expect(
      await container.read(availableBookmarkViewSourcesProvider(view).future),
      ['pixiv.net'],
    );
    expect(await container.read(availableBooruUrlsProvider.future), isEmpty);
  });

  test(
    'host choices and restored URL choices share the listing source scope',
    () {
      for (final choice in [
        'example.test',
        'EXAMPLE.test',
        'https://example.test',
        'https://example.test/install/',
      ]) {
        expect(
          bookmarkSourceMatchesHost('https://example.test/posts/1', choice),
          isTrue,
        );
        expect(
          bookmarkSourceMatchesHost('https://another.test', choice),
          isFalse,
        );
      }
      expect(bookmarkSourceMatchesHost('', 'example.test'), isFalse);
      expect(bookmarkSourceMatchesHost('https://example.test', ''), isFalse);
    },
  );

  test('source matching aliases only the two Pixiv website hosts', () {
    expect(
      bookmarkSourceMatchesHost(
        'https://www.pixiv.net/artworks/120',
        'pixiv.net',
      ),
      isTrue,
    );
    expect(
      bookmarkSourceMatchesHost('https://pixiv.net', 'https://www.pixiv.net/'),
      isTrue,
    );
    expect(
      bookmarkSourceMatchesHost('app-api.pixiv.net', 'pixiv.net'),
      isFalse,
    );
    expect(
      bookmarkSourceMatchesHost('www.pixiv.net.example', 'pixiv.net'),
      isFalse,
    );
    expect(
      bookmarkSourceMatchesHost('www.example.test', 'example.test'),
      isFalse,
    );
  });
}

class _Library extends BookmarkLibraryNotifier {
  _Library(this.value);
  final BookmarkLibraryState value;
  @override
  BookmarkLibraryState build() => value;
  void replace(BookmarkLibraryState next) => state = AsyncData(next);
}
