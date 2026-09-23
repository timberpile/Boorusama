// Dart imports:
import 'dart:io';

// Package imports:
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

// Project imports:
import 'package:boorusama/boorus/gelbooru_v2/posts/post_codec.dart';
import 'package:boorusama/boorus/gelbooru_v2/posts/post_data.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/bookmark_group_hive_object.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/bookmark_group_repository_hive.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/bookmark_hive_object.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/repository.dart';
import 'package:boorusama/core/bookmarks/src/data/bookmark_convert.dart';
import 'package:boorusama/core/bookmarks/src/services/bookmark_library_service.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_target.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_repository.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/hive/hive_adapters.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/posts/rating/types.dart';
import 'package:boorusama/core/posts/sources/types.dart';

void main() {
  late Directory tempDirectory;
  late Box<BookmarkHiveObject> bookmarkBox;
  late Box<BookmarkGroupHiveObject> groupBox;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp(
      'bookmark_snapshot_migration_test_',
    );
    Hive.init(tempDirectory.path);
    if (!Hive.isAdapterRegistered(4)) {
      Hive.registerAdapter(BookmarkHiveObjectAdapter());
    }
    if (!Hive.isAdapterRegistered(5)) {
      Hive.registerAdapter(BookmarkGroupHiveObjectAdapter());
    }
    bookmarkBox = await Hive.openBox<BookmarkHiveObject>('bookmarks');
    groupBox = await Hive.openBox<BookmarkGroupHiveObject>('groups');
  });

  tearDown(() async {
    await bookmarkBox.close();
    await groupBox.close();
    await tempDirectory.delete(recursive: true);
  });

  test(
    'legacy rows migrate to snapshots without changing identity or groups',
    () async {
      final createdAt = DateTime.utc(2024, 1, 2, 3, 4);
      final updatedAt = DateTime.utc(2024, 2, 3, 4, 5);
      await bookmarkBox.put(
        17,
        BookmarkHiveObject(
          booruId: 21,
          createdAt: createdAt,
          updatedAt: updatedAt,
          thumbnailUrl: 'https://gelbooru.example/thumb.jpg',
          sampleUrl: 'https://gelbooru.example/sample.jpg',
          originalUrl: 'https://gelbooru.example/original.jpg',
          sourceUrl: 'https://gelbooru.example/index.php?page=post&s=view&id=9',
          width: 1200,
          height: 800,
          md5: 'abc',
          tags: const ['one', 'two'],
          realSourceUrl: 'https://artist.example/work',
          format: 'jpg',
          postId: 9,
          metadata: const {'page': '3', 'limit': '20', 'search': 'one'},
        ),
      );
      await BookmarkGroupRepositoryHive(groupBox).createGroup(
        'Kept',
        id: '550e8400-e29b-41d4-a716-446655440000',
      );
      await BookmarkGroupRepositoryHive(groupBox).addBookmarks(
        '550e8400-e29b-41d4-a716-446655440000',
        const {17},
      );

      final bookmarks =
          await BookmarkHiveRepository(
            bookmarkBox,
          ).getAllBookmarksOrThrow(
            imageUrlResolver: (_) => const DefaultImageUrlResolver(),
          );

      final bookmark = bookmarks.single;
      expect(bookmark.id, 17);
      expect(bookmark.createdAt, createdAt);
      expect(bookmark.updatedAt, updatedAt);
      expect(bookmark.snapshot.origin.booruTypeId, 21);
      expect(bookmark.snapshot.origin.booruId, 21);
      expect(bookmark.snapshot.origin.sourceHost, 'gelbooru.example');
      expect(bookmark.snapshot.common['id'], 9);
      expect(bookmark.toPost(), isA<Post>());
      expect(bookmark.toPost().booruData, isA<LegacyPostData>());

      final migrated = bookmarkBox.get(17)!;
      expect(migrated.snapshotSchemaVersion, 1);
      expect(migrated.postSnapshot, bookmark.snapshot.toJson());
      expect(
        (await BookmarkGroupRepositoryHive(
          groupBox,
        ).getGroups()).single.bookmarkIds,
        {17},
      );
    },
  );

  test(
    'malformed snapshots retain cached media through generic data',
    () async {
      await bookmarkBox.put(
        4,
        BookmarkHiveObject(
          booruId: 21,
          createdAt: DateTime.utc(2024),
          updatedAt: DateTime.utc(2024),
          thumbnailUrl: 'https://gelbooru.example/thumb.jpg',
          sampleUrl: 'https://gelbooru.example/sample.jpg',
          originalUrl: 'https://gelbooru.example/original.jpg',
          sourceUrl: 'https://gelbooru.example/post/5',
          width: 10,
          height: 20,
          md5: 'broken',
          tags: const ['cached'],
          realSourceUrl: null,
          format: 'jpg',
          postId: 5,
          metadata: const {},
          snapshotSchemaVersion: 999,
          postSnapshot: const {'invalid': true},
        ),
      );

      final bookmark =
          (await BookmarkHiveRepository(
                bookmarkBox,
              ).getAllBookmarksOrThrow(
                imageUrlResolver: (_) => const DefaultImageUrlResolver(),
              ))
              .single;

      expect(bookmark.toPost().originalImageUrl, contains('original.jpg'));
      expect(bookmark.toPost().tags, {'cached'});
      expect(bookmark.toPost().booruData, isA<LegacyPostData>());
    },
  );

  test('native snapshot data survives repository storage and reload', () async {
    final post = Post(
      origin: PostOrigin.fromSource(
        booruType: BooruType.gelbooruV2,
        booruId: 37,
        source: 'https://gelbooru.example',
        profileIdHint: 12,
      ),
      core: PostCoreData(
        id: 91,
        createdAt: DateTime.utc(2026, 4, 5),
        thumbnailImageUrl: 'https://cdn.example/thumb.jpg',
        sampleImageUrl: 'https://cdn.example/sample.jpg',
        originalImageUrl: 'https://cdn.example/original.png',
        videoUrl: '',
        videoThumbnailUrl: '',
        width: 1200,
        height: 800,
        format: 'png',
        md5: 'native-hash',
        fileSize: 4096,
        duration: 0,
        tags: const {'native', 'notes'},
        rating: Rating.general,
        hasComment: true,
        isTranslated: false,
        hasParentOrChildren: false,
        source: PostSource.from('https://artist.example/work'),
        score: 42,
      ),
      booruData: const GelbooruV2PostData(hasNotes: true),
    );
    final repository = BookmarkHiveRepository(
      bookmarkBox,
      postDataCodec: (type) => switch (type) {
        BooruType.gelbooruV2 => const GelbooruV2PostCodec(),
        _ => null,
      },
    );

    final created = await repository.addBookmark(
      37,
      post,
      imageUrlResolver: (_) => const DefaultImageUrlResolver(),
      postLinkGenerator: (_) => const _PostLinkGenerator(),
    );
    final reloaded = (await repository.getAllBookmarksOrThrow(
      imageUrlResolver: (_) => const DefaultImageUrlResolver(),
    )).single;

    expect(reloaded.id, created.id);
    expect(reloaded.post, post);
    expect(reloaded.post.booruData, const GelbooruV2PostData(hasNotes: true));
    expect(reloaded.snapshot.custom, {'hasNotes': true});
    expect(reloaded.snapshot.origin.profileIdHint, 12);
  });

  test(
    'successful refresh upgrades the snapshot without changing identity or groups',
    () async {
      final repository = BookmarkHiveRepository(
        bookmarkBox,
        postDataCodec: (type) => switch (type) {
          BooruType.gelbooruV2 => const GelbooruV2PostCodec(),
          _ => null,
        },
      );
      final legacy = await repository
          .addBookmarkWithBookmarks([
            Bookmark(
              id: -1,
              booruId: BooruType.gelbooruV2.id,
              createdAt: DateTime.utc(2025),
              updatedAt: DateTime.utc(2025, 1, 2),
              thumbnailUrl: 'thumb',
              sampleUrl: 'sample',
              originalUrl: 'original',
              sourceUrl: 'https://gelbooru.example/post/91',
              width: 100,
              height: 100,
              md5: 'legacy',
              tags: const {'cached'},
              realSourceUrl: null,
              format: 'jpg',
              imageUrlResolver: const DefaultImageUrlResolver(),
              postId: 91,
              metadata: const {},
            ),
          ])
          .then((bookmarks) => bookmarks.single);
      const groupId = '550e8400-e29b-41d4-a716-446655440000';
      final groups = BookmarkGroupRepositoryHive(groupBox);
      await groups.createGroup('Kept', id: groupId);
      await groups.addBookmarks(groupId, {legacy.id});
      final refreshedAt = DateTime.utc(2026, 6, 7);
      final refreshedPost = _nativePost();
      final service = BookmarkLibraryService(
        bookmarkRepository: repository,
        groupRepository: groups,
        imageUrlResolver: (_) => const DefaultImageUrlResolver(),
      );

      final upgraded = await service.upgradeBookmarkSnapshot(
        bookmark: legacy,
        post: refreshedPost,
        dataCodec: const GelbooruV2PostCodec(),
        updatedAt: refreshedAt,
      );
      final state = await service.load(const BookmarkTarget.ungrouped());

      expect(upgraded.id, legacy.id);
      expect(upgraded.createdAt, legacy.createdAt);
      expect(upgraded.updatedAt, refreshedAt);
      expect(upgraded.post, refreshedPost);
      expect(state.bookmarksById[legacy.id], upgraded);
      expect(state.groupsById[groupId]?.bookmarkIds, {legacy.id});
    },
  );
}

Post _nativePost() => Post(
  origin: PostOrigin.fromSource(
    booruType: BooruType.gelbooruV2,
    booruId: 37,
    source: 'https://gelbooru.example',
    profileIdHint: 12,
  ),
  core: PostCoreData(
    id: 91,
    createdAt: DateTime.utc(2026, 4, 5),
    thumbnailImageUrl: 'https://cdn.example/thumb.jpg',
    sampleImageUrl: 'https://cdn.example/sample.jpg',
    originalImageUrl: 'https://cdn.example/original.png',
    videoUrl: '',
    videoThumbnailUrl: '',
    width: 1200,
    height: 800,
    format: 'png',
    md5: 'native-hash',
    fileSize: 4096,
    duration: 0,
    tags: const {'native', 'notes'},
    rating: Rating.general,
    hasComment: true,
    isTranslated: false,
    hasParentOrChildren: false,
    source: PostSource.from('https://artist.example/work'),
    score: 42,
  ),
  booruData: const GelbooruV2PostData(hasNotes: true),
);

final class _PostLinkGenerator implements PostLinkGenerator<Post> {
  const _PostLinkGenerator();

  @override
  String getLink(Post post) => 'https://gelbooru.example/post/${post.id}';
}
