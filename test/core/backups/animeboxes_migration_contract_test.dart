import 'dart:io';

import 'package:boorusama/core/backups/sources/bookmark_backup_codec.dart';
import 'package:boorusama/core/backups/sources/pinned_search_backup_codec.dart';
import 'package:boorusama/core/backups/utils/data_converter.dart';
import 'package:boorusama/core/backups/utils/json_handler.dart';
import 'package:boorusama/core/blacklists/types.dart';
import 'package:boorusama/core/bookmarks/types.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/posts/rating/types.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('bookmark artifact decodes through the production version 2 codec', () {
    final payload = decodeData(data: _fixture('boorusama_bookmarks.json'));
    final data = BookmarkBackupCodec(
      bookmarkParser: (json) => Bookmark.fromJson(
        json,
        imageUrlResolver: const DefaultImageUrlResolver(),
      ),
    ).parse(payload);

    expect(payload.version, 2);
    expect(payload.exportDate, DateTime.parse('2026-08-16T08:48:50+0200'));
    expect(payload.exportVersion, isNull);
    final group = data.groups.single;
    expect(group.id, isNull);
    expect(group.name, 'AnimeBoxes');
    expect(group.bookmarkIds, [1]);
    final bookmark = data.bookmarks.single;
    expect(bookmark.localId, 1);
    expect(bookmark.postId, 42);
    expect(bookmark.booruId, 20);
    expect(bookmark.post.origin.sourceHost, 'danbooru.donmai.us');
    expect(bookmark.thumbnailUrl, 'https://cdn.example/preview-42.jpg');
    expect(bookmark.sampleUrl, 'https://cdn.example/sample-42.jpg');
    expect(bookmark.originalUrl, 'https://cdn.example/original-42.webm');
    expect(bookmark.post.videoUrl, bookmark.originalUrl);
    expect(bookmark.post.videoThumbnailUrl, bookmark.thumbnailUrl);
    expect(bookmark.tags, {'tag_one', 'tag_two'});
    expect(bookmark.post.artistTags, {'artist_one'});
    expect(bookmark.post.characterTags, {'character_one'});
    expect(bookmark.post.copyrightTags, {'copyright_one'});
    expect(bookmark.post.rating, Rating.questionable);
    expect(bookmark.post.fileSize, 0);
    expect(bookmark.post.duration, -1);
    expect(bookmark.post.createdAt, isNull);
    expect(bookmark.post.parentId, 123);
    expect(bookmark.post.hasParentOrChildren, isTrue);
    expect(bookmark.post.hasComment, isTrue);
    expect(bookmark.post.isTranslated, isTrue);
    expect(bookmark.post.booruData, isA<UnknownPostData>());
  });

  test('blacklist artifact decodes through the production list handler', () {
    final payload = decodeData(
      data: _fixture('boorusama_blacklisted_tags.json'),
    );
    final tags = ListHandler<BlacklistedTag>(
      parser: BlacklistedTag.fromJson,
      encoder: (tag) => tag.toJson(),
    ).parse(payload);

    expect(payload.version, 1);
    final tag = tags.single;
    expect(tag.id, 1);
    expect(tag.name, 'blocked, tag');
    expect(tag.isActive, isTrue);
    expect(tag.createdDate, DateTime.parse('2026-08-16T08:48:50+0200'));
    expect(tag.updatedDate, tag.createdDate);
  });

  test('pinned-search artifact preserves order and complete membership', () {
    final payload = decodeData(
      data: _fixture('boorusama_pinned_searches.json'),
    );
    final data = PinnedSearchBackupCodec().parse(payload);

    expect(payload.version, 1);
    expect(payload.extraFields['source'], 'pinned_searches');
    expect(data.folders, hasLength(1));
    expect(data.records, hasLength(1));
    expect(data.homeSearchIds, isEmpty);
    final folder = data.folders.single;
    final search = data.records.single;
    expect(folder.position, 0);
    expect(folder.name, 'Folder, café');
    expect(folder.searchIds, [search.id]);
    expect(search.position, 0);
    expect(search.name, 'Quoted "title"');
    expect(search.query, 'rating:general');
    expect(search.profile.id, 2);
    expect(search.profile.booruType, 'danbooru');
    expect(search.profile.url, 'https://danbooru.donmai.us');
    expect(search.profile.name, 'Donmai Fixture');
  });
}

String _fixture(String name) => File(
  'packages/boorusama_cli/test/migrations/animeboxes/fixtures/$name',
).readAsStringSync();
