// Package imports:
import 'package:flutter_test/flutter_test.dart';

// Project imports:
import 'package:boorusama/boorus/anime-pictures/anime_pictures_builder.dart';
import 'package:boorusama/boorus/anime-pictures/posts/post_data.dart';
import 'package:boorusama/boorus/danbooru/danbooru_builder.dart';
import 'package:boorusama/boorus/danbooru/posts/post/types.dart';
import 'package:boorusama/boorus/e621/e621_builder.dart';
import 'package:boorusama/boorus/e621/posts/post_data.dart';
import 'package:boorusama/boorus/eshuushuu/eshuushuu_builder.dart';
import 'package:boorusama/boorus/eshuushuu/posts/post_data.dart';
import 'package:boorusama/boorus/gelbooru/gelbooru_builder.dart';
import 'package:boorusama/boorus/gelbooru/posts/post_data.dart';
import 'package:boorusama/boorus/gelbooru_v1/gelbooru_v1_builder.dart';
import 'package:boorusama/boorus/gelbooru_v1/posts/post_data.dart';
import 'package:boorusama/boorus/gelbooru_v2/gelbooru_v2_builder.dart';
import 'package:boorusama/boorus/gelbooru_v2/posts/post_data.dart';
import 'package:boorusama/boorus/hybooru/hybooru_builder.dart';
import 'package:boorusama/boorus/hybooru/posts/post_data.dart';
import 'package:boorusama/boorus/hydrus/hydrus_builder.dart';
import 'package:boorusama/boorus/hydrus/posts/post_data.dart';
import 'package:boorusama/boorus/moebooru/moebooru_builder.dart';
import 'package:boorusama/boorus/moebooru/posts/post_data.dart';
import 'package:boorusama/boorus/nozomi/nozomi_builder.dart';
import 'package:boorusama/boorus/nozomi/posts/post_data.dart';
import 'package:boorusama/boorus/philomena/philomena_builder.dart';
import 'package:boorusama/boorus/philomena/posts/post_data.dart';
import 'package:boorusama/boorus/philomena/posts/types.dart';
import 'package:boorusama/boorus/pixiv/pixiv_builder.dart';
import 'package:boorusama/boorus/pixiv/posts/post_data.dart';
import 'package:boorusama/boorus/pixiv/posts/types.dart';
import 'package:boorusama/boorus/sankaku/posts/post_data.dart';
import 'package:boorusama/boorus/sankaku/sankaku_builder.dart';
import 'package:boorusama/boorus/shimmie2/posts/post_data.dart';
import 'package:boorusama/boorus/shimmie2/shimmie2_builder.dart';
import 'package:boorusama/boorus/szurubooru/posts/post_data.dart';
import 'package:boorusama/boorus/szurubooru/szurubooru_builder.dart';
import 'package:boorusama/boorus/zerochan/posts/post_data.dart';
import 'package:boorusama/boorus/zerochan/zerochan_builder.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/boorus/engine/types.dart';
import 'package:boorusama/core/posts/details_parts/types.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/posts/rating/types.dart';
import 'package:boorusama/core/posts/sources/types.dart';

void main() {
  final cases =
      <
        ({
          String name,
          BooruType type,
          BooruBuilder builder,
          BooruPostData data,
        })
      >[
        (
          name: 'AnimePictures',
          type: BooruType.animePictures,
          builder: AnimePicturesBuilder(),
          data: const AnimePicturesPostData(
            tagsCount: 1,
            statusValue: null,
            statusType: null,
          ),
        ),
        (
          name: 'Danbooru',
          type: BooruType.danbooru,
          builder: DanbooruBuilder(),
          data: const DanbooruPostData(
            lastCommentAt: null,
            upScore: 1,
            downScore: 0,
            favCount: 2,
            approverId: null,
            generalTags: {},
            metaTags: {},
            hasChildren: false,
            hasLarge: true,
            pixelHash: '',
          ),
        ),
        (
          name: 'e621',
          type: BooruType.e621,
          builder: E621Builder(),
          data: const E621PostData(
            generalTags: {},
            metaTags: {},
            speciesTags: {},
            invalidTags: {},
            loreTags: {},
            upScore: 1,
            downScore: 0,
            favCount: 2,
            isFavorited: false,
            sources: [],
            description: '',
            videoVariants: [],
          ),
        ),
        (
          name: 'Eshuushuu',
          type: BooruType.eshuushuu,
          builder: EshuushuuBuilder(),
          data: const EshuushuuPostData(
            characters: {},
            artists: {},
            sourceTags: {},
            generalTags: {},
            largeImageUrl: null,
            isFavorited: false,
            favorites: 0,
            bayesianRating: 0,
          ),
        ),
        (
          name: 'Gelbooru',
          type: BooruType.gelbooru,
          builder: GelbooruBuilder(),
          data: gelbooruPostData,
        ),
        (
          name: 'Gelbooru V1',
          type: BooruType.gelbooruV1,
          builder: GelbooruV1Builder(),
          data: gelbooruV1PostData,
        ),
        (
          name: 'Gelbooru V2',
          type: BooruType.gelbooruV2,
          builder: GelbooruV2Builder(),
          data: const GelbooruV2PostData(hasNotes: false),
        ),
        (
          name: 'Hybooru',
          type: BooruType.hybooru,
          builder: HybooruBuilder(),
          data: hybooruPostData,
        ),
        (
          name: 'Hydrus',
          type: BooruType.hydrus,
          builder: HydrusBuilder(),
          data: const HydrusPostData(ownFavorite: false),
        ),
        (
          name: 'Moebooru',
          type: BooruType.moebooru,
          builder: MoebooruBuilder(),
          data: const MoebooruPostData(largeImageUrl: 'large'),
        ),
        (
          name: 'Nozomi',
          type: BooruType.nozomi,
          builder: NozomiBuilder(),
          data: nozomiPostData,
        ),
        (
          name: 'Philomena',
          type: BooruType.philomena,
          builder: PhilomenaBuilder(),
          data: const PhilomenaPostData(
            description: '',
            commentCount: 0,
            favCount: 0,
            upvotes: 0,
            representation: PhilomenaRepresentation(
              full: '',
              large: '',
              medium: '',
              small: '',
              tall: '',
              thumb: '',
              thumbSmall: '',
              thumbTiny: '',
            ),
          ),
        ),
        (
          name: 'Pixiv',
          type: BooruType.pixiv,
          builder: PixivBuilder(),
          data: const PixivPostData(
            illustId: 1,
            pageIndex: 0,
            pageCount: 1,
            userId: 2,
            userName: 'user',
            userAccount: 'account',
            illustType: PixivIllustType.illust,
            totalBookmarks: 0,
            totalView: 0,
            aiType: 0,
            seriesTitle: null,
            isUgoira: false,
            isRestricted: false,
          ),
        ),
        (
          name: 'Sankaku',
          type: BooruType.sankaku,
          builder: SankakuBuilder(),
          data: const SankakuPostData(
            sankakuId: null,
            isFavorited: false,
            favoriteCount: 0,
            artistDetailsTags: [],
            characterDetailsTags: [],
            copyrightDetailsTags: [],
            generalDetailsTags: [],
            metaDetailsTags: [],
          ),
        ),
        (
          name: 'Shimmie2',
          type: BooruType.shimmie2,
          builder: Shimmie2Builder(),
          data: const Shimmie2PostData(
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
          ),
        ),
        (
          name: 'Szurubooru',
          type: BooruType.szurubooru,
          builder: SzurubooruBuilder(),
          data: const SzurubooruPostData(
            ownFavorite: false,
            favoriteCount: 0,
            commentCount: 0,
            tagDetails: [],
            status: null,
            pools: [],
          ),
        ),
        (
          name: 'Zerochan',
          type: BooruType.zerochan,
          builder: ZerochanBuilder(),
          data: zerochanPostData,
        ),
      ];

  for (final testCase in cases) {
    test('${testCase.name} registers its native post presentation', () {
      final presentation = testCase.builder.postPresentation;
      final post = _post(type: testCase.type, data: testCase.data);

      expect(presentation, isNot(isA<GenericPostPresentation>()));
      expect(presentation.supports(testCase.data), isTrue);
      expect(
        presentation.supports(
          const UnknownPostData(
            typeKey: 'different_engine',
            schemaVersion: 1,
            custom: {},
            reason: UnknownPostDataReason.incompatiblePayload,
          ),
        ),
        isFalse,
      );
      expect(
        presentation.detailsBuilder(post),
        same(testCase.builder.postDetailsUIBuilder),
      );
      expect(
        presentation.detailsBuilder(post).buildableFullParts,
        isNotEmpty,
      );
      expect(
        presentation.detailsBuilder(post).buildableFullParts,
        contains(DetailsPart.toolbar),
      );
      expect(
        presentation.detailsWrapperBuilder,
        switch (testCase.type) {
          BooruType.danbooru || BooruType.moebooru => isNotNull,
          _ => isNull,
        },
      );
    });
  }
}

UnifiedPost _post({required BooruType type, required BooruPostData data}) =>
    UnifiedPost(
      origin: PostOrigin.fromSource(
        booruType: type,
        booruId: type.id,
        source: 'https://${type.id}.example',
      ),
      core: PostCoreData(
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
      ),
      booruData: data,
    );
