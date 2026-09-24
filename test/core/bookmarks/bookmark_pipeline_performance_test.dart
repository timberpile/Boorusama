// Dart imports:
import 'dart:io';

// Package imports:
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

// Project imports:
import 'package:boorusama/boorus/gelbooru_v2/posts/post_codec.dart';
import 'package:boorusama/boorus/gelbooru_v2/posts/post_data.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/bookmark_hive_object.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/repository.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_repository.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/hive/hive_adapters.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/posts/rating/types.dart';
import 'package:boorusama/core/posts/sources/types.dart';

const _bookmarkCount = 1000;
const _catastrophicOperationLimit = Duration(seconds: 10);
const _hiveSizeLimit = 20 * 1024 * 1024;

void main() {
  late Directory tempDirectory;
  late Box<BookmarkHiveObject> bookmarkBox;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp(
      'bookmark_pipeline_performance_test_',
    );
    Hive.init(tempDirectory.path);
    if (!Hive.isAdapterRegistered(4)) {
      Hive.registerAdapter(BookmarkHiveObjectAdapter());
    }
    bookmarkBox = await Hive.openBox<BookmarkHiveObject>('bookmarks');
  });

  tearDown(() async {
    if (bookmarkBox.isOpen) await bookmarkBox.close();
    await tempDirectory.delete(recursive: true);
  });

  test(
    'a large snapshot library stays bounded and reports cold-load cost',
    () async {
      final posts = [for (var i = 0; i < _bookmarkCount; i++) _post(i)];
      final repository = _repository(bookmarkBox);

      final writeWatch = Stopwatch()..start();
      final stored = await repository.addBookmarks(
        BooruType.gelbooruV2.id,
        posts,
        imageUrlResolver: (_) => const DefaultImageUrlResolver(),
        postLinkGenerator: (_) => const _PostLinkGenerator(),
      );
      writeWatch.stop();
      expect(stored.length, _bookmarkCount);

      await bookmarkBox.close();
      final hiveBytes = _directoryBytes(tempDirectory);

      final loadWatch = Stopwatch()..start();
      bookmarkBox = await Hive.openBox<BookmarkHiveObject>('bookmarks');
      final loaded = await _repository(bookmarkBox).getAllBookmarksOrThrow(
        imageUrlResolver: (_) => const DefaultImageUrlResolver(),
      );
      loadWatch.stop();

      expect(loaded.length, _bookmarkCount);
      expect(loaded.first.post.id, 0);
      expect(loaded.last.post.id, _bookmarkCount - 1);
      expect(
        loaded.every(
          (bookmark) => bookmark.post.booruData is GelbooruV2PostData,
        ),
        isTrue,
      );
      expect(hiveBytes, lessThan(_hiveSizeLimit));
      expect(
        writeWatch.elapsed,
        lessThan(_catastrophicOperationLimit),
      );
      expect(loadWatch.elapsed, lessThan(_catastrophicOperationLimit));

      stdout.writeln(
        'POST_PIPELINE_BENCH bookmarks=$_bookmarkCount '
        'hive_write_ms=${writeWatch.elapsedMicroseconds / 1000} '
        'hive_cold_load_ms=${loadWatch.elapsedMicroseconds / 1000} '
        'hive_bytes=$hiveBytes',
      );
    },
    timeout: const Timeout(Duration(seconds: 45)),
  );
}

BookmarkHiveRepository _repository(Box<BookmarkHiveObject> box) =>
    BookmarkHiveRepository(
      box,
      postDataCodec: (type) => switch (type) {
        BooruType.gelbooruV2 => const GelbooruV2PostCodec(),
        _ => null,
      },
    );

Post _post(int id) => Post(
  origin: PostOrigin.fromSource(
    booruType: BooruType.gelbooruV2,
    booruId: BooruType.gelbooruV2.id,
    source: 'https://gelbooru.example/index.php?page=post&s=view&id=$id',
    profileIdHint: 21,
  ),
  core: PostCoreData(
    id: id,
    createdAt: DateTime.utc(2026, 9, 24).add(Duration(seconds: id)),
    thumbnailImageUrl: 'https://cdn.example/$id/thumbnail.jpg',
    sampleImageUrl: 'https://cdn.example/$id/sample.jpg',
    originalImageUrl: 'https://cdn.example/$id/original.jpg',
    videoUrl: '',
    videoThumbnailUrl: '',
    mediaVariants: {
      '180x180': 'https://cdn.example/$id/thumbnail.jpg',
      '720x720': 'https://cdn.example/$id/sample.jpg',
    },
    width: 1400,
    height: 1000,
    format: 'jpg',
    md5: '0123456789abcdef$id',
    fileSize: 1_000_000 + id,
    duration: 0,
    tags: {for (var tag = 0; tag < 30; tag++) 'tag_${id % 11}_$tag'},
    artistTags: {'artist_${id % 7}'},
    characterTags: {'character_${id % 13}'},
    copyrightTags: {'copyright_${id % 5}'},
    rating: Rating.general,
    hasComment: id.isEven,
    isTranslated: id % 3 == 0,
    hasParentOrChildren: id % 4 == 0,
    source: PostSource.from('https://artist.example/works/$id'),
    score: id,
    uploaderId: id % 17,
    uploaderName: 'uploader_${id % 17}',
    metadata: const PostMetadata(page: 1, search: 'benchmark', limit: 40),
  ),
  booruData: GelbooruV2PostData(hasNotes: id % 3 == 0),
);

int _directoryBytes(Directory directory) => directory
    .listSync(recursive: true)
    .whereType<File>()
    .fold(0, (total, file) => total + file.lengthSync());

final class _PostLinkGenerator implements PostLinkGenerator<Post> {
  const _PostLinkGenerator();

  @override
  String getLink(Post post) => 'https://gelbooru.example/post/${post.id}';
}
