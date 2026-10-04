// Package imports:
import 'package:flutter_test/flutter_test.dart';

// Project imports:
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/bookmarks/types.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/posts/rating/types.dart';
import 'package:boorusama/core/posts/sources/types.dart';

void main() {
  test('matches the same site post across profiles and media URL changes', () {
    final first = BookmarkIdentity.fromPost(
      _post(
        source: 'https://Gelbooru.Example/posts/42',
        profileId: '00000000-0000-4000-8000-000000000007',
        originalUrl: 'https://cdn-one.example/42.jpg',
      ),
    );
    final second = BookmarkIdentity.fromPost(
      _post(
        source: 'gelbooru.example',
        profileId: '00000000-0000-4000-8000-000000000063',
        originalUrl: 'https://cdn-two.example/changed-42.jpg',
      ),
    );

    expect(first, second);
    expect(first.booruType, BooruType.gelbooruV2.name);
    expect(first.site, 'gelbooru.example');
    expect(first.postId, 42);
  });

  test('keeps equal engine post IDs distinct on different sites', () {
    final gelbooru = BookmarkIdentity.fromPost(
      _post(
        source: 'https://gelbooru.com',
        profileId: '00000000-0000-4000-8000-000000000001',
      ),
    );
    final rule34 = BookmarkIdentity.fromPost(
      _post(
        source: 'https://rule34.xxx',
        profileId: '00000000-0000-4000-8000-000000000002',
      ),
    );

    expect(gelbooru, isNot(rule34));
  });
}

Post _post({
  required String source,
  required String profileId,
  String originalUrl = 'https://img.example/42.jpg',
}) => Post(
  origin: PostOrigin.fromSource(
    booruType: BooruType.gelbooruV2,
    booruId: BooruType.gelbooruV2.id,
    source: source,
    profileIdHint: profileId,
  ),
  core: PostCoreData(
    id: 42,
    thumbnailImageUrl: 'https://img.example/thumb.jpg',
    sampleImageUrl: 'https://img.example/sample.jpg',
    originalImageUrl: originalUrl,
    videoUrl: '',
    videoThumbnailUrl: '',
    width: 100,
    height: 100,
    format: 'jpg',
    md5: 'md5',
    fileSize: 100,
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
