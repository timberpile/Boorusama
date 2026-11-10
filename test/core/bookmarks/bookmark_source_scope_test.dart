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
}

class _Library extends BookmarkLibraryNotifier {
  _Library(this.value);
  final BookmarkLibraryState value;
  @override
  BookmarkLibraryState build() => value;
}
