// Dart imports:
import 'dart:io';

// Package imports:
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

// Project imports:
import 'package:boorusama/boorus/sankaku/posts/post_codec.dart';
import 'package:boorusama/boorus/sankaku/posts/post_data.dart';
import 'package:boorusama/core/bookmarks/src/data/bookmark_convert.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/bookmark_hive_object.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/repository.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_repository.dart';
import 'package:boorusama/core/hive/hive_adapters.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/posts/post/types.dart';

void main() {
  late Directory tempDirectory;
  late Box<BookmarkHiveObject> box;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp(
      'bookmark_schema_test_',
    );
    Hive.init(tempDirectory.path);
    if (!Hive.isAdapterRegistered(4)) {
      Hive.registerAdapter(BookmarkHiveObjectAdapter());
    }
    box = await Hive.openBox<BookmarkHiveObject>('bookmarks');
  });

  tearDown(() async {
    await box.close();
    await tempDirectory.delete(recursive: true);
  });

  test('unkeyable bookmarks cannot become current Hive rows', () {
    expect(
      () => favoriteToHiveObject(Bookmark.empty),
      throwsFormatException,
    );
  });

  test('a batch with one missing upstream ID makes no writes', () {
    final valid = Bookmark.empty
        .copyWith(
          sourceUrl: 'https://booru.example',
          postId: () => 42,
        )
        .toPost();
    final invalid = Bookmark.empty.toPost();

    expect(
      () => BookmarkHiveRepository(box).addBookmarks(
        BooruType.gelbooruV2.id,
        [valid, invalid],
        imageUrlResolver: (_) => const DefaultImageUrlResolver(),
        postLinkGenerator: (_) => const _TestLinkGenerator(),
      ),
      throwsFormatException,
    );
    expect(box.isEmpty, isTrue);
  });

  test('old URL-only rows stay unread without changing stored data', () async {
    await box.put(
      17,
      BookmarkHiveObject(
        booruId: BooruType.gelbooruV2.id,
        createdAt: DateTime.utc(2024),
        updatedAt: DateTime.utc(2024),
        thumbnailUrl: 'https://img.example/thumb.jpg',
        sampleUrl: 'https://img.example/sample.jpg',
        originalUrl: 'https://img.example/original.jpg',
        sourceUrl: 'https://booru.example/posts/42',
        width: 100,
        height: 100,
        md5: 'md5',
        tags: const [],
        realSourceUrl: null,
        format: 'jpg',
        postId: 42,
        metadata: const {},
      ),
    );
    final read = await BookmarkHiveRepository(box).getAllBookmarksOrThrow(
      imageUrlResolver: (_) => const DefaultImageUrlResolver(),
    );

    expect(read, isEmpty);
    expect(box.get(17)!.snapshotSchemaVersion, isNull);
    expect(box.get(17)!.postSnapshot, isNull);
  });

  test('native Sankaku string identity survives a Hive reload', () async {
    final post = Bookmark.empty
        .copyWith(
          id: 88,
          sourceUrl: 'https://sankaku.example/board',
          postId: () => 88,
          originalUrl: 'https://img.example/88.jpg',
        )
        .toPost()
        .copyWith(
          origin: PostOrigin.fromSource(
            booruType: BooruType.sankaku,
            booruId: BooruType.sankaku.id,
            source: 'https://sankaku.example/board',
          ),
          booruData: const SankakuPostData(
            sankakuId: SankakuPostIdData(value: 'abc123', isNumeric: false),
            isFavorited: false,
            favoriteCount: 0,
            artistDetailsTags: [],
            characterDetailsTags: [],
            copyrightDetailsTags: [],
            generalDetailsTags: [],
            metaDetailsTags: [],
          ),
        );
    BookmarkHiveRepository repository() => BookmarkHiveRepository(
      box,
      postDataCodec: (type) =>
          type == BooruType.sankaku ? const SankakuPostCodec() : null,
    );

    await repository().addBookmark(
      BooruType.sankaku.id,
      post,
      imageUrlResolver: (_) => const DefaultImageUrlResolver(),
      postLinkGenerator: (_) => const _TestLinkGenerator(),
    );
    await box.close();
    box = await Hive.openBox<BookmarkHiveObject>('bookmarks');

    final loaded = await repository().getAllBookmarksOrThrow(
      imageUrlResolver: (_) => const DefaultImageUrlResolver(),
    );
    expect(loaded, hasLength(1));
    expect(loaded.single.post.booruData, isA<SankakuPostData>());
    expect(loaded.single.uniqueId, BookmarkIdentity.fromPost(post));
    expect(loaded.single.identity.postKey, 'id:abc123');
  });

  test(
    'old snapshot schema stays unread while the current row loads',
    () async {
      final bookmark = Bookmark(
        id: 42,
        booruId: BooruType.gelbooruV2.id,
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
        thumbnailUrl: 'https://img.example/thumb.jpg',
        sampleUrl: 'https://img.example/sample.jpg',
        originalUrl: 'https://img.example/original.jpg',
        sourceUrl: 'https://booru.example/board',
        width: 100,
        height: 100,
        md5: 'md5',
        tags: const {},
        realSourceUrl: null,
        format: 'jpg',
        imageUrlResolver: const DefaultImageUrlResolver(),
        postId: 42,
        metadata: const {},
      );
      final old = favoriteToHiveObject(bookmark)..snapshotSchemaVersion = 1;
      await box.put(1, old);
      await box.put(2, favoriteToHiveObject(bookmark));

      final read = await BookmarkHiveRepository(box).getAllBookmarksOrThrow(
        imageUrlResolver: (_) => const DefaultImageUrlResolver(),
      );

      expect(read, hasLength(1));
      expect(read.single.id, 2);
      expect(read.single.post.origin.sourceHost, 'booru.example/board');
      expect(read.single.uniqueId, isA<BookmarkIdentity>());
    },
  );
}

final class _TestLinkGenerator implements PostLinkGenerator<Post> {
  const _TestLinkGenerator();

  @override
  String getLink(Post post) => 'https://booru.example/posts/${post.id}';
}
