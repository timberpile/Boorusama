import 'package:boorusama/core/bookmarks/src/providers/bookmark_profile_availability.dart';
import 'package:boorusama/core/bookmarks/src/data/stored_bookmark_codec.dart';
import 'package:boorusama/core/bookmarks/types.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('unavailable counts follow timeline, source and tag scope without duplicate memberships', () {
    final records = [
      _post(1, 'danbooru.donmai.us', {'cat'}),
      _post(2, 'rule34.xxx', {'cat', 'blue_hair'}),
      _post(3, 'rule34.xxx', {'dog'}),
      _post(4, 'realbooru.com', {'cat'}),
    ];
    const root = '10000000-0000-4000-8000-000000000001';
    const child = '10000000-0000-4000-8000-000000000002';
    final library = BookmarkLibraryState(
      bookmarks: records,
      records: records,
      groups: [
        BookmarkGroup(
          id: defaultBookmarkGroupId,
          name: 'Default',
          bookmarkIds: {4},
        ),
        BookmarkGroup(id: root, name: 'Root', bookmarkIds: {1, 2}),
        BookmarkGroup(
          id: child,
          name: 'Child',
          parentGroupId: root,
          bookmarkIds: {2, 3},
        ),
      ],
    );
    final profile = BooruConfig.fromJson({
      ...BooruConfig.defaultConfig(
        booruType: BooruType.danbooru,
        url: 'https://danbooru.donmai.us',
        customDownloadFileNameFormat: null,
      ).toJson(),
      'id': '20000000-0000-4000-8000-000000000001',
    });
    Map<String, int> counts(
      BookmarkView view, {
      List<String> tags = const [],
      String? source,
      List<BooruConfig>? profiles,
    }) => BookmarkProfileAvailability(library, profiles ?? [profile])
        .unavailablePostsBySite(
          library: library,
          view: view,
          selectedTags: tags,
          selectedBooruUrl: source,
        );
    expect(records.map((post) => post.sourceUrl), everyElement(isEmpty));
    expect(counts(const BookmarkView.all()), {
      'rule34.xxx': 2,
      'realbooru.com': 1,
    });
    expect(counts(BookmarkView.group(root)), {'rule34.xxx': 1});
    expect(counts(BookmarkView.subtree(root)), {'rule34.xxx': 2});
    expect(counts(const BookmarkView.defaultGroup()), {'realbooru.com': 1});
    expect(counts(const BookmarkView.all(), tags: ['cat', '-blue_hair']), {
      'realbooru.com': 1,
    });
    expect(counts(const BookmarkView.all(), source: 'https://rule34.xxx/'), {
      'rule34.xxx': 2,
    });
    expect(counts(const BookmarkView.all(), profiles: []), {
      'danbooru.donmai.us': 1,
      'rule34.xxx': 2,
      'realbooru.com': 1,
    });
  });
}

PostBookmark _post(int id, String host, Set<String> tags) {
  const codec = StoredBookmarkCodec();
  return codec.decode(
    codec.encodeForTransfer(
      PostBookmark(
        id: id,
        booruId: BooruType.danbooru.id,
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
        thumbnailUrl: '',
        sampleUrl: '',
        originalUrl: '',
        sourceUrl: 'https://$host',
        width: 100,
        height: 100,
        md5: '',
        tags: tags,
        realSourceUrl: null,
        format: 'jpg',
        imageUrlResolver: const DefaultImageUrlResolver(),
        postId: id,
        metadata: const {},
      ),
    ),
  ) as PostBookmark;
}
