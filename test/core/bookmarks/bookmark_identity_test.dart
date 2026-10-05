// Package imports:
import 'package:flutter_test/flutter_test.dart';

// Project imports:
import 'package:boorusama/boorus/pixiv/posts/types.dart';
import 'package:boorusama/boorus/sankaku/posts/post_data.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/bookmarks/types.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/posts/rating/types.dart';
import 'package:boorusama/core/posts/sources/types.dart';
import '../../profile_uuid_utils.dart';

void main() {
  test('matches one site post across profiles and media URL changes', () {
    final first = BookmarkIdentity.fromPost(
      _post(
        source: 'https://Gelbooru.Example/posts/',
        profileId: profileUuid(7),
        originalUrl: 'https://cdn-one.example/42.jpg',
      ),
    );
    final second = BookmarkIdentity.fromPost(
      _post(
        source: 'http://gelbooru.example/posts',
        profileId: profileUuid(99),
        originalUrl: 'https://cdn-two.example/changed-42.jpg',
      ),
    );

    expect(first, second);
    expect(first.site, 'gelbooru.example/posts');
    expect(first.postKey, 'id:42');
  });

  test('keeps matching post IDs on separate installations distinct', () {
    final first = BookmarkIdentity.fromPost(
      _post(source: 'https://booru.example/first'),
    );
    final second = BookmarkIdentity.fromPost(
      _post(source: 'https://booru.example/second'),
    );

    expect(first, isNot(second));
  });

  test('ignores changed engine metadata for one upstream post', () {
    final first = BookmarkIdentity.fromPost(
      _post(source: 'https://booru.example', type: BooruType.gelbooruV2),
    );
    final second = BookmarkIdentity.fromPost(
      _post(source: 'https://booru.example', type: BooruType.danbooru),
    );

    expect(first, second);
  });

  test('does not merge two posts sharing one media URL', () {
    final first = BookmarkIdentity.fromPost(
      _post(source: 'https://booru.example'),
    );
    final second = BookmarkIdentity.fromPost(
      _post(source: 'https://booru.example', id: 43),
    );

    expect(first, isNot(second));
  });

  test('uses the upstream Sankaku string ID instead of generated post ID', () {
    const data = SankakuPostData(
      sankakuId: SankakuPostIdData(value: 'abc123', isNumeric: false),
      isFavorited: false,
      favoriteCount: 0,
      artistDetailsTags: [],
      characterDetailsTags: [],
      copyrightDetailsTags: [],
      generalDetailsTags: [],
      metaDetailsTags: [],
    );
    final first = BookmarkIdentity.fromPost(
      _post(
        source: 'https://sankaku.example',
        type: BooruType.sankaku,
        id: 1,
        data: data,
      ),
    );
    final second = BookmarkIdentity.fromPost(
      _post(
        source: 'https://sankaku.example',
        type: BooruType.sankaku,
        id: 99,
        data: data,
      ),
    );

    expect(first, second);
    expect(first.postKey, 'id:abc123');
  });

  test('uses the upstream Sankaku numeric ID instead of generated post ID', () {
    const data = SankakuPostData(
      sankakuId: SankakuPostIdData(value: '542', isNumeric: true),
      isFavorited: false,
      favoriteCount: 0,
      artistDetailsTags: [],
      characterDetailsTags: [],
      copyrightDetailsTags: [],
      generalDetailsTags: [],
      metaDetailsTags: [],
    );
    final identity = BookmarkIdentity.fromPost(
      _post(
        source: 'https://sankaku.example',
        type: BooruType.sankaku,
        id: 99,
        data: data,
      ),
    );

    expect(identity.postKey, 'id:542');
  });

  test('rejects a nonpositive Sankaku numeric ID', () {
    const data = SankakuPostData(
      sankakuId: SankakuPostIdData(value: '0', isNumeric: true),
      isFavorited: false,
      favoriteCount: 0,
      artistDetailsTags: [],
      characterDetailsTags: [],
      copyrightDetailsTags: [],
      generalDetailsTags: [],
      metaDetailsTags: [],
    );
    expect(
      BookmarkIdentity.tryFromPost(
        _post(
          source: 'https://sankaku.example',
          type: BooruType.sankaku,
          id: 99,
          data: data,
        ),
      ),
      isNull,
    );
  });

  test('keeps Pixiv pages distinct with explicit work and page keys', () {
    final first = BookmarkIdentity.fromPost(
      _post(
        source: 'https://pixiv.example',
        type: BooruType.pixiv,
        id: 123000,
        data: _pixivData(pageIndex: 0),
      ),
    );
    final second = BookmarkIdentity.fromPost(
      _post(
        source: 'https://pixiv.example',
        type: BooruType.pixiv,
        id: 123001,
        data: _pixivData(pageIndex: 1),
      ),
    );

    expect(first.postKey, 'work-page:123:0');
    expect(second.postKey, 'work-page:123:1');
    expect(first, isNot(second));
  });

  test(
    'does not trust generated IDs when special engine data is unavailable',
    () {
      final sankaku = _post(
        source: 'https://sankaku.example',
        type: BooruType.sankaku,
        data: const UnknownPostData(
          typeKey: 'sankaku',
          schemaVersion: 1,
          custom: {},
          reason: UnknownPostDataReason.unavailableCodec,
        ),
      );

      expect(
        BookmarkUniqueId.fromPost(sankaku),
        isA<UnbookmarkablePostIdentity>(),
      );
    },
  );

  test('marks a post without upstream ID unavailable for bookmarking', () {
    final missing = _post(source: 'https://booru.example', id: 0);

    expect(
      BookmarkUniqueId.fromPost(missing),
      isA<UnbookmarkablePostIdentity>(),
    );
    expect(() => BookmarkIdentity.fromPost(missing), throwsFormatException);
  });
}

PixivPostData _pixivData({required int pageIndex}) => PixivPostData(
  illustId: 123,
  pageIndex: pageIndex,
  pageCount: 2,
  userId: 1,
  userName: 'Artist',
  userAccount: 'artist',
  illustType: PixivIllustType.illust,
  totalBookmarks: 0,
  totalView: 0,
  aiType: 0,
  seriesTitle: null,
  isUgoira: false,
  isRestricted: false,
);

Post _post({
  required String source,
  String? profileId,
  int id = 42,
  BooruType type = BooruType.gelbooruV2,
  BooruPostData? data,
  String originalUrl = 'https://img.example/shared.jpg',
}) => Post(
  origin: PostOrigin.fromSource(
    booruType: type,
    booruId: type.id,
    source: source,
    profileIdHint: profileId ?? profileUuid(1),
  ),
  core: PostCoreData(
    id: id,
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
  booruData: data ?? EmptyPostData(typeKey: type.name),
);
