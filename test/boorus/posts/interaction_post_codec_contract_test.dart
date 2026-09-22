// Package imports:
import 'package:flutter_test/flutter_test.dart';

// Project imports:
import 'package:boorusama/boorus/danbooru/posts/post/src/danbooru_post_codec.dart';
import 'package:boorusama/boorus/danbooru/posts/post/src/danbooru_post_data.dart';
import 'package:boorusama/boorus/danbooru/posts/post/types.dart' as danbooru;
import 'package:boorusama/boorus/e621/posts/post_codec.dart';
import 'package:boorusama/boorus/e621/posts/post_data.dart';
import 'package:boorusama/boorus/e621/posts/types.dart';
import 'package:boorusama/boorus/sankaku/posts/post_codec.dart';
import 'package:boorusama/boorus/sankaku/posts/post_data.dart';
import 'package:boorusama/boorus/shimmie2/posts/post_codec.dart';
import 'package:boorusama/boorus/shimmie2/posts/post_data.dart';
import 'package:boorusama/boorus/szurubooru/pools/types.dart';
import 'package:boorusama/boorus/szurubooru/posts/post_codec.dart';
import 'package:boorusama/boorus/szurubooru/posts/post_data.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/posts/rating/types.dart';
import 'package:boorusama/core/posts/sources/types.dart';
import 'package:boorusama/core/tags/categories/types.dart';
import 'package:boorusama/core/tags/tag/types.dart';

void main() {
  test('Danbooru preserves interaction, tag and moderation data', () {
    final data = DanbooruPostData(
      lastCommentAt: DateTime.utc(2026, 2, 3),
      upScore: 13,
      downScore: -2,
      favCount: 8,
      approverId: 99,
      generalTags: const {'general'},
      metaTags: const {'sound'},
      hasChildren: true,
      hasLarge: true,
      pixelHash: 'pixel-hash',
    );

    expect(_roundTripData(data, const DanbooruPostCodec()), data);
  });

  test('Danbooru preserves absent moderation metadata', () {
    const data = DanbooruPostData(
      lastCommentAt: null,
      upScore: 0,
      downScore: 0,
      favCount: 0,
      approverId: null,
      generalTags: {},
      metaTags: {},
      hasChildren: false,
      hasLarge: false,
      pixelHash: '',
    );

    expect(_roundTripData(data, const DanbooruPostCodec()), data);
  });

  test(
    'Danbooru conversion keeps variants and moderation status in common data',
    () {
      final legacy = danbooru.DanbooruPost(
        id: 2,
        thumbnailImageUrl: 'thumb',
        sampleImageUrl: 'sample',
        originalImageUrl: 'original',
        tags: const {'general', 'sound'},
        copyrightTags: const {'copyright'},
        characterTags: const {'character'},
        artistTags: const {'artist'},
        generalTags: const {'general'},
        metaTags: const {'sound'},
        width: 1000,
        height: 800,
        format: 'jpg',
        md5: 'hash',
        lastCommentAt: null,
        source: PostSource.none(),
        createdAt: null,
        score: 4,
        upScore: 5,
        downScore: -1,
        favCount: 6,
        uploaderId: 7,
        approverId: null,
        rating: Rating.general,
        fileSize: 8,
        hasChildren: false,
        parentId: null,
        hasLarge: true,
        duration: 0,
        variants: danbooru.PostVariants.fromMap(const {
          '180x180': 'small',
          '720x720': 'large',
        }),
        pixelHash: 'pixel',
        metadata: null,
        status: const danbooru.BannedStatus(),
      );

      final converted = danbooruPostToUnified(
        legacy,
        PostOrigin.fromSource(
          booruType: BooruType.danbooru,
          booruId: BooruType.danbooru.id,
          source: 'https://danbooru.donmai.us',
        ),
      );

      expect(converted.core.mediaVariants, {
        '180x180': 'small',
        '720x720': 'large',
      });
      expect(converted.core.status, 'banned');
    },
  );

  test('e621 preserves tag groups, sources, favorite and video data', () {
    const data = E621PostData(
      generalTags: {'general'},
      metaTags: {'sound'},
      speciesTags: {'species'},
      invalidTags: {'invalid'},
      loreTags: {'lore'},
      upScore: 20,
      downScore: -3,
      favCount: 7,
      isFavorited: true,
      sources: [
        E621PostSourceData(kind: 'web', value: 'https://source.example/1'),
        E621PostSourceData(kind: 'nonWeb', value: 'book page 4'),
      ],
      description: 'Description',
      videoVariants: [
        E621VideoVariantData(
          type: E621VideoVariantType.v720p,
          url: 'video-720.mp4',
          size: 123,
          width: 1280,
          height: 720,
          codec: 'h264',
          fps: 30,
        ),
      ],
    );

    expect(_roundTripData(data, const E621PostCodec()), data);
  });

  test('Sankaku preserves native ID, favorite and detailed tag groups', () {
    final data = SankakuPostData(
      sankakuId: const SankakuPostIdData(value: 'abc123', isNumeric: false),
      isFavorited: true,
      favoriteCount: 12,
      artistDetailsTags: [_tag('artist', TagCategory.artist(), 10)],
      characterDetailsTags: [_tag('character', TagCategory.character(), 20)],
      copyrightDetailsTags: [_tag('copyright', TagCategory.copyright(), 30)],
      generalDetailsTags: [_tag('general', TagCategory.general(), 40)],
      metaDetailsTags: [_tag('meta', TagCategory.meta(), 50)],
    );

    expect(_roundTripData(data, const SankakuPostCodec()), data);
  });

  test('Sankaku preserves an absent native ID', () {
    const data = SankakuPostData(
      sankakuId: null,
      isFavorited: false,
      favoriteCount: 0,
      artistDetailsTags: [],
      characterDetailsTags: [],
      copyrightDetailsTags: [],
      generalDetailsTags: [],
      metaDetailsTags: [],
    );

    expect(_roundTripData(data, const SankakuPostCodec()), data);
  });

  test('Shimmie2 preserves moderation, owner, vote and comment data', () {
    final data = Shimmie2PostData(
      locked: true,
      ext: 'jpg',
      mime: 'image/jpeg',
      niceName: 'nice.jpg',
      tooltip: 'Tooltip',
      favorites: 9,
      numericScore: 14,
      notes: 2,
      hasChildren: true,
      title: 'Title',
      approved: false,
      approvedById: 3,
      isPrivate: true,
      trash: false,
      ownerJoinDate: DateTime.utc(2020, 1, 2),
      votes: const [
        Shimmie2VoteData(score: -1, userName: 'Voter', userId: 5),
      ],
      myVote: 1,
      comments: [
        Shimmie2CommentData(
          id: 8,
          comment: 'Comment',
          posted: DateTime.utc(2026, 1, 1),
          ownerName: 'Owner',
          ownerId: 6,
        ),
      ],
    );

    expect(_roundTripData(data, const Shimmie2PostCodec()), data);
  });

  test('Shimmie2 preserves absent optional data', () {
    const data = Shimmie2PostData(
      locked: null,
      ext: null,
      mime: null,
      niceName: null,
      tooltip: null,
      favorites: null,
      numericScore: null,
      notes: null,
      hasChildren: null,
      title: null,
      approved: null,
      approvedById: null,
      isPrivate: null,
      trash: null,
      ownerJoinDate: null,
      votes: null,
      myVote: null,
      comments: null,
    );

    expect(_roundTripData(data, const Shimmie2PostCodec()), data);
  });

  test('Szurubooru preserves favorites, counts, tags, status and pools', () {
    final data = SzurubooruPostData(
      ownFavorite: true,
      favoriteCount: 11,
      commentCount: 4,
      tagDetails: [
        _tag('custom', const TagCategory(id: 17, name: 'custom'), 2),
      ],
      status: 'active',
      pools: [
        SzurubooruPool(
          id: 7,
          names: const ['Pool'],
          category: 'series',
          description: 'Description',
          postCount: 2,
          postIds: const [1, 2],
          thumbnailUrls: const ['one', 'two'],
          createdAt: DateTime.utc(2024),
          updatedAt: DateTime.utc(2025),
        ),
      ],
    );

    expect(_roundTripData(data, const SzurubooruPostCodec()), data);
  });
}

Tag _tag(String name, TagCategory category, int postCount) => Tag(
  name: name,
  category: category,
  postCount: postCount,
);

D _roundTripData<D extends BooruPostData>(
  D data,
  BooruPostDataCodec<D> dataCodec,
) {
  const codec = StoredPostCodec();
  final post = UnifiedPost(
    origin: PostOrigin.fromSource(
      booruType: BooruType.danbooru,
      booruId: BooruType.danbooru.id,
      source: 'https://example.com',
    ),
    core: _commonPost(),
    booruData: data,
  );
  final result = codec.decode(
    codec.encode(post, dataCodec: dataCodec),
    dataCodec: dataCodec,
  );
  expect(result, isA<StoredPostDecodeSuccess>());
  return (result as StoredPostDecodeSuccess).post.booruData as D;
}

PostCoreData _commonPost() => PostCoreData(
  id: 1,
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
  fileSize: 0,
  format: 'jpg',
  height: 1,
  md5: '',
  videoThumbnailUrl: '',
  videoUrl: '',
  width: 1,
);
