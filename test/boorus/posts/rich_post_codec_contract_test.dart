// Package imports:
import 'package:flutter_test/flutter_test.dart';

// Project imports:
import 'package:boorusama/boorus/anime-pictures/posts/post_codec.dart';
import 'package:boorusama/boorus/anime-pictures/posts/post_data.dart';
import 'package:boorusama/boorus/anime-pictures/posts/types.dart';
import 'package:boorusama/boorus/eshuushuu/posts/post_codec.dart';
import 'package:boorusama/boorus/eshuushuu/posts/post_data.dart';
import 'package:boorusama/boorus/eshuushuu/posts/types.dart';
import 'package:boorusama/boorus/hydrus/posts/post_codec.dart';
import 'package:boorusama/boorus/hydrus/posts/post_data.dart';
import 'package:boorusama/boorus/hydrus/posts/types.dart';
import 'package:boorusama/boorus/nozomi/posts/post_codec.dart';
import 'package:boorusama/boorus/nozomi/posts/post_data.dart';
import 'package:boorusama/boorus/nozomi/posts/types.dart';
import 'package:boorusama/boorus/philomena/posts/post_codec.dart';
import 'package:boorusama/boorus/philomena/posts/post_data.dart';
import 'package:boorusama/boorus/philomena/posts/types.dart';
import 'package:boorusama/boorus/pixiv/posts/post_codec.dart';
import 'package:boorusama/boorus/pixiv/posts/post_data.dart';
import 'package:boorusama/boorus/pixiv/posts/types.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/posts/rating/types.dart';
import 'package:boorusama/core/posts/sources/types.dart';

void main() {
  final origin = PostOrigin.fromSource(
    booruType: BooruType.danbooru,
    booruId: 1,
    source: 'https://example.com',
  );

  test('AnimePictures preserves tag count and numeric status', () {
    final legacy = _animePicturesPost();

    final decoded = _roundTrip(
      animePicturesPostFromRecord(legacy, origin),
      const AnimePicturesPostCodec(),
    );

    _expectCommonPost(decoded, legacy);
    expect(
      decoded.booruData,
      const AnimePicturesPostData(
        tagsCount: 14,
        statusValue: 2,
        statusType: 7,
      ),
    );
  });

  test('AnimePictures preserves absent numeric status', () {
    const data = AnimePicturesPostData(
      tagsCount: 0,
      statusValue: null,
      statusType: null,
    );

    expect(
      _roundTripData(data, const AnimePicturesPostCodec()),
      data,
    );
  });

  test('Eshuushuu preserves categorized tags and favorite metadata', () {
    final legacy = _eshuushuuPost();

    final decoded = _roundTrip(
      eshuushuuPostFromRecord(legacy, origin),
      const EshuushuuPostCodec(),
    );

    _expectCommonPost(decoded, legacy);
    expect(
      decoded.booruData,
      const EshuushuuPostData(
        characters: {'character'},
        artists: {'artist'},
        sourceTags: {'series'},
        generalTags: {'general'},
        largeImageUrl: 'large',
        isFavorited: true,
        favorites: 12,
        bayesianRating: 4.75,
      ),
    );
  });

  test('Eshuushuu preserves absent optional metadata', () {
    const data = EshuushuuPostData(
      characters: null,
      artists: null,
      sourceTags: null,
      generalTags: null,
      largeImageUrl: null,
      isFavorited: null,
      favorites: null,
      bayesianRating: null,
    );

    expect(_roundTripData(data, const EshuushuuPostCodec()), data);
  });

  test('Hydrus preserves own-favorite state', () {
    final legacy = _hydrusPost();

    final decoded = _roundTrip(
      hydrusPostFromRecord(legacy, origin),
      const HydrusPostCodec(),
    );

    _expectCommonPost(decoded, legacy);
    expect(decoded.booruData, const HydrusPostData(ownFavorite: true));
  });

  test('Hydrus preserves absent own-favorite state', () {
    const data = HydrusPostData(ownFavorite: null);

    expect(_roundTripData(data, const HydrusPostCodec()), data);
  });

  test('Nozomi preserves categorized tags and media aspect ratios', () {
    final legacy = _nozomiPost();

    final decoded = _roundTrip(
      nozomiPostFromRecord(legacy, origin),
      const NozomiPostCodec(),
    );

    _expectCommonPost(decoded, legacy);
    expect(decoded.booruData, nozomiPostData);
    expect(decoded.artistTags, {'artist'});
    expect(decoded.characterTags, {'character'});
    expect(decoded.copyrightTags, {'copyright'});
    expect(decoded.thumbnailAspectRatio, 1);
    expect(decoded.sampleAspectRatio, 1.5);
    expect(decoded.originalAspectRatio, 2);
    expect(decoded.videoThumbnailAspectRatio, 2.5);
    expect(decoded.videoAspectRatio, 3);
  });

  test(
    'Pixiv preserves illustration, user, series, AI and restriction data',
    () {
      final legacy = _pixivPost();

      final decoded = _roundTrip(
        pixivPostFromRecord(legacy, origin),
        const PixivPostCodec(),
      );

      _expectCommonPost(decoded, legacy);
      expect(
        decoded.booruData,
        const PixivPostData(
          illustId: 123,
          pageIndex: 1,
          pageCount: 3,
          userId: 9,
          userName: 'User',
          userAccount: 'user_account',
          illustType: PixivIllustType.manga,
          totalBookmarks: 45,
          totalView: 678,
          aiType: 2,
          seriesTitle: 'Series',
          isUgoira: false,
          isRestricted: true,
        ),
      );
    },
  );

  test('Pixiv preserves an absent series title', () {
    const data = PixivPostData(
      illustId: 123,
      pageIndex: 0,
      pageCount: 1,
      userId: 9,
      userName: 'User',
      userAccount: 'user_account',
      illustType: PixivIllustType.illust,
      totalBookmarks: 0,
      totalView: 0,
      aiType: 0,
      seriesTitle: null,
      isUgoira: false,
      isRestricted: false,
    );

    expect(_roundTripData(data, const PixivPostCodec()), data);
  });

  test(
    'Philomena preserves description, counts, votes and representations',
    () {
      final legacy = _philomenaPost();

      final decoded = _roundTrip(
        philomenaPostFromRecord(legacy, origin),
        const PhilomenaPostCodec(),
      );

      _expectCommonPost(decoded, legacy);
      expect(
        decoded.booruData,
        const PhilomenaPostData(
          description: 'Description',
          commentCount: 4,
          favCount: 5,
          upvotes: 8,
          representation: PhilomenaRepresentation(
            full: 'full',
            large: 'large',
            medium: 'medium',
            small: 'small',
            tall: 'tall',
            thumb: 'thumb',
            thumbSmall: 'thumb-small',
            thumbTiny: 'thumb-tiny',
          ),
        ),
      );
      expect(decoded.downvotes, 2);
    },
  );
}

Post _roundTrip<D extends BooruPostData>(
  Post post,
  BooruPostDataCodec<D> dataCodec,
) {
  expect(post.runtimeType, Post);
  const codec = StoredPostCodec();
  final result = codec.decode(
    codec.encode(post, dataCodec: dataCodec),
    dataCodec: dataCodec,
  );
  expect(result, isA<StoredPostDecodeSuccess>());
  final decoded = (result as StoredPostDecodeSuccess).post;
  expect(decoded.runtimeType, Post);
  return decoded;
}

D _roundTripData<D extends BooruPostData>(
  D data,
  BooruPostDataCodec<D> dataCodec,
) {
  final post = Post(
    origin: PostOrigin.fromSource(
      booruType: BooruType.danbooru,
      booruId: 1,
      source: 'https://example.com',
    ),
    core: PostCoreData.fromPost(_hydrusPost()),
    booruData: data,
  );
  return _roundTrip(post, dataCodec).booruData as D;
}

void _expectCommonPost(Post actual, PostRecord expected) {
  expect(actual.id, expected.id);
  expect(actual.createdAt, expected.createdAt);
  expect(actual.thumbnailImageUrl, expected.thumbnailImageUrl);
  expect(actual.sampleImageUrl, expected.sampleImageUrl);
  expect(actual.originalImageUrl, expected.originalImageUrl);
  expect(actual.tags, expected.tags);
  expect(actual.rating, expected.rating);
  expect(actual.score, expected.score);
  expect(actual.downvotes, expected.downvotes);
  expect(actual.artistTags, expected.artistTags);
  expect(actual.characterTags, expected.characterTags);
  expect(actual.copyrightTags, expected.copyrightTags);
}

AnimePicturesPostRecord _animePicturesPost() => AnimePicturesPostRecord(
  id: 1,
  thumbnailImageUrl: 'thumb',
  sampleImageUrl: 'sample',
  originalImageUrl: 'original',
  tags: const {'tag'},
  rating: Rating.sensitive,
  hasComment: false,
  isTranslated: false,
  hasParentOrChildren: false,
  source: PostSource.none(),
  score: 3,
  duration: 0,
  fileSize: 4,
  format: 'jpg',
  hasSound: null,
  height: 600,
  md5: 'hash',
  videoThumbnailUrl: '',
  videoUrl: '',
  width: 800,
  uploaderId: 5,
  createdAt: DateTime.utc(2026),
  uploaderName: null,
  metadata: null,
  status: AnimePicturesPostStatus.from(value: 2, type: 7),
  tagsCount: 14,
);

EshuushuuPostRecord _eshuushuuPost() => EshuushuuPostRecord(
  id: 2,
  thumbnailImageUrl: 'thumb',
  sampleImageUrl: 'sample',
  originalImageUrl: 'original',
  tags: const {'character', 'artist', 'series', 'general'},
  rating: Rating.general,
  hasComment: true,
  isTranslated: false,
  hasParentOrChildren: false,
  source: PostSource.none(),
  score: 12,
  duration: 0,
  fileSize: 4,
  format: 'png',
  hasSound: null,
  height: 600,
  md5: 'hash',
  videoThumbnailUrl: '',
  videoUrl: '',
  width: 800,
  uploaderId: 5,
  createdAt: null,
  uploaderName: 'Uploader',
  metadata: null,
  characters: const {'character'},
  artist: const {'artist'},
  sourceTags: const {'series'},
  generalTags: const {'general'},
  largeImageUrl: 'large',
  isFavorited: true,
  favorites: 12,
  bayesianRating: 4.75,
);

HydrusPostRecord _hydrusPost() => HydrusPostRecord(
  id: 3,
  thumbnailImageUrl: 'thumb',
  sampleImageUrl: 'sample',
  originalImageUrl: 'original',
  tags: const {'tag'},
  rating: Rating.general,
  hasComment: false,
  isTranslated: false,
  hasParentOrChildren: false,
  source: PostSource.none(),
  score: 0,
  duration: 0,
  fileSize: 4,
  format: 'jpg',
  hasSound: false,
  height: 600,
  md5: 'hash',
  videoThumbnailUrl: '',
  videoUrl: '',
  width: 800,
  uploaderId: null,
  createdAt: null,
  uploaderName: null,
  metadata: null,
  ownFavorite: true,
);

NozomiPostRecord _nozomiPost() => NozomiPostRecord(
  id: 4,
  thumbnailImageUrl: 'thumb',
  sampleImageUrl: 'sample',
  originalImageUrl: 'original',
  tags: const {'artist', 'character', 'copyright'},
  rating: Rating.unknown,
  hasComment: false,
  isTranslated: false,
  hasParentOrChildren: false,
  source: PostSource.none(),
  score: 0,
  duration: 0,
  fileSize: 0,
  format: '.webm',
  hasSound: null,
  height: 600,
  md5: 'hash',
  videoThumbnailUrl: 'video-thumb',
  videoUrl: 'video',
  width: 800,
  uploaderId: null,
  createdAt: null,
  uploaderName: null,
  metadata: null,
  thumbnailMediaAspectRatio: 1,
  sampleMediaAspectRatio: 1.5,
  originalMediaAspectRatio: 2,
  videoThumbnailMediaAspectRatio: 2.5,
  videoMediaAspectRatio: 3,
  artistTagSet: const {'artist'},
  characterTagSet: const {'character'},
  copyrightTagSet: const {'copyright'},
);

PixivPostRecord _pixivPost() => PixivPostRecord(
  id: 12301,
  thumbnailImageUrl: 'thumb',
  sampleImageUrl: 'sample',
  originalImageUrl: 'original',
  tags: const {'tag'},
  rating: Rating.general,
  hasComment: false,
  isTranslated: false,
  hasParentOrChildren: true,
  source: PostSource.none(),
  score: 0,
  duration: 0,
  fileSize: 0,
  format: 'jpg',
  hasSound: false,
  height: 600,
  md5: '',
  videoThumbnailUrl: 'thumb',
  videoUrl: '',
  width: 800,
  uploaderId: 9,
  metadata: null,
  illustId: 123,
  pageIndex: 1,
  pageCount: 3,
  userId: 9,
  userName: 'User',
  userAccount: 'user_account',
  illustType: PixivIllustType.manga,
  totalBookmarks: 45,
  totalView: 678,
  aiType: 2,
  seriesTitle: 'Series',
  isUgoira: false,
  isRestricted: true,
);

PhilomenaPostRecord _philomenaPost() => PhilomenaPostRecord(
  id: 5,
  thumbnailImageUrl: 'thumb',
  sampleImageUrl: 'sample',
  originalImageUrl: 'original',
  tags: const {'artist:somebody'},
  rating: Rating.general,
  isTranslated: false,
  hasParentOrChildren: false,
  source: PostSource.none(),
  score: 6,
  duration: 0,
  fileSize: 10,
  format: 'jpg',
  hasSound: false,
  height: 600,
  md5: 'hash',
  videoThumbnailUrl: '',
  videoUrl: '',
  width: 800,
  description: 'Description',
  commentCount: 4,
  favCount: 5,
  upvotes: 8,
  downvotes: 2,
  representation: const PhilomenaRepresentation(
    full: 'full',
    large: 'large',
    medium: 'medium',
    small: 'small',
    tall: 'tall',
    thumb: 'thumb',
    thumbSmall: 'thumb-small',
    thumbTiny: 'thumb-tiny',
  ),
  uploaderId: 7,
  uploaderName: 'Uploader',
  metadata: null,
  status: null,
);
