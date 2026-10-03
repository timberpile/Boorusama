// Package imports:
import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';

// Project imports:
import 'package:boorusama/core/backups/sources/bookmark_backup_data.dart';
import 'package:boorusama/core/backups/sources/bookmark_import_plan.dart';
import 'package:boorusama/core/backups/sources/bookmark_import_planner.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/bookmarks/types.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/posts/rating/types.dart';
import 'package:boorusama/core/posts/sources/types.dart';

void main() {
  const groupId = '550e8400-e29b-41d4-a716-446655440000';
  final first = Bookmark.empty.copyWith(
    id: 10,
    sourceUrl: 'https://example.com',
    postId: () => 10,
    originalUrl: 'https://example.com/first.jpg',
  );
  final second = Bookmark.empty.copyWith(
    id: 20,
    sourceUrl: 'https://example.com',
    postId: () => 20,
    originalUrl: 'https://example.com/second.jpg',
  );

  test('rejects an unkeyable incoming bookmark before group planning', () {
    final invalid = Bookmark.empty.copyWith(
      id: 0,
      sourceUrl: 'https://example.com',
    );

    expect(
      () => const BookmarkImportPlanner().plan(
        data: BookmarkBackupData(
          bookmarks: [invalid],
          groups: const [
            BookmarkGroupBackup(id: groupId, name: 'Invalid', bookmarkIds: [0]),
          ],
        ),
        currentBookmarks: const [],
        currentGroups: const [],
      ),
      throwsFormatException,
    );
  });

  test('legacy groups with matching names always receive new IDs', () {
    final plan = const BookmarkImportPlanner().plan(
      data: BookmarkBackupData(
        bookmarks: [first],
        groups: const [
          BookmarkGroupBackup(id: null, name: 'Same', bookmarkIds: [10]),
          BookmarkGroupBackup(id: null, name: 'Same', bookmarkIds: [10]),
        ],
      ),
      currentBookmarks: [first],
      currentGroups: [
        BookmarkGroup(id: groupId, name: 'Same', bookmarkIds: const {}),
      ],
    );

    expect(plan.groups.map((group) => group.id).toSet(), hasLength(2));
    expect(
      plan.groups.every((group) => Uuid.isValidUUID(fromString: group.id)),
      isTrue,
    );
    expect(plan.conflicts, isEmpty);
  });

  test('detects conflicts by GUID and maps file-local bookmark IDs', () {
    final plan = const BookmarkImportPlanner().plan(
      data: BookmarkBackupData(
        bookmarks: [first, second],
        groups: const [
          BookmarkGroupBackup(
            id: groupId,
            name: 'Imported name',
            bookmarkIds: [10, 999],
          ),
        ],
      ),
      currentBookmarks: [first],
      currentGroups: [
        BookmarkGroup(id: groupId, name: 'Local name', bookmarkIds: const {}),
      ],
    );

    expect(plan.missingBookmarks, [second]);
    expect(plan.conflicts.single.name, 'Imported name');
    expect(plan.conflicts.single.bookmarkIds, {first.uniqueId});
    expect(
      plan.resolve({groupId: BookmarkGroupConflictChoice.replace}).isResolved,
      isTrue,
    );
  });

  test('keeps same-ID posts from two installations separate on import', () {
    final current = _nativeBookmark(
      id: 1,
      originalUrl: 'https://img.example/shared.jpg',
      site: 'https://booru.example/first',
    );
    final incoming = _nativeBookmark(
      id: 2,
      originalUrl: 'https://img.example/shared.jpg',
      site: 'https://booru.example/second',
    );

    final plan = const BookmarkImportPlanner().plan(
      data: BookmarkBackupData(bookmarks: [incoming], groups: const []),
      currentBookmarks: [current],
      currentGroups: const [],
    );

    expect(plan.missingBookmarks, [incoming]);
  });

  test('reuses a site post after its media URL changes', () {
    final current = _nativeBookmark(
      id: 1,
      originalUrl: 'https://old-cdn.example/42.jpg',
    );
    final imported = _nativeBookmark(
      id: 2,
      originalUrl: 'https://new-cdn.example/42.jpg',
    );

    final plan = const BookmarkImportPlanner().plan(
      data: BookmarkBackupData(bookmarks: [imported], groups: const []),
      currentBookmarks: [current],
      currentGroups: const [],
    );

    expect(plan.missingBookmarks, isEmpty);
  });
}

Bookmark _nativeBookmark({
  required int id,
  required String originalUrl,
  String site = 'https://gelbooru.example',
}) {
  final post = Post(
    origin: PostOrigin.fromSource(
      booruType: BooruType.gelbooruV2,
      booruId: BooruType.gelbooruV2.id,
      source: site,
    ),
    core: PostCoreData(
      id: 42,
      thumbnailImageUrl: 'thumb',
      sampleImageUrl: 'sample',
      originalImageUrl: originalUrl,
      videoUrl: '',
      videoThumbnailUrl: '',
      width: 100,
      height: 100,
      format: 'jpg',
      md5: 'md5',
      fileSize: 1,
      duration: 0,
      tags: const {},
      rating: Rating.general,
      hasComment: false,
      isTranslated: false,
      hasParentOrChildren: false,
      source: PostSource.none(),
      score: 0,
    ),
    booruData: const LegacyPostData(typeKey: 'test', custom: {}),
  );
  return Bookmark.fromSnapshot(
    id: id,
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
    snapshot: const StoredPostCodec().encode(post),
    post: post,
    postId: post.id,
  );
}
