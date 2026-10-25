import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/posts/rating/types.dart';
import 'package:boorusama/boorus/gelbooru_v2/posts/types.dart';
import 'package:booru_clients/danbooru.dart' as danbooru_api;
import 'package:boorusama/boorus/danbooru/posts/post/src/converter.dart'
    as danbooru;
import 'package:booru_clients/gelbooru.dart' as gelbooru_api;
import 'package:boorusama/boorus/gelbooru/posts/parser.dart' as gelbooru;
import 'package:booru_clients/gelbooru.dart' as gelbooru_v1_api;
import 'package:boorusama/boorus/gelbooru_v1/posts/parser.dart' as gelbooru_v1;
import 'package:booru_clients/gelbooru.dart' as gelbooru_v2_api;
import 'package:boorusama/boorus/gelbooru_v2/posts/parser.dart' as gelbooru_v2;
import 'package:booru_clients/moebooru.dart' as moebooru_api;
import 'package:boorusama/boorus/moebooru/posts/parser.dart' as moebooru;
import 'package:booru_clients/e621.dart' as e621_api;
import 'package:boorusama/boorus/e621/posts/parser.dart' as e621;
import 'package:booru_clients/philomena.dart' as philomena_api;
import 'package:boorusama/boorus/philomena/posts/parser.dart' as philomena;
import 'package:booru_clients/sankaku.dart' as sankaku_api;
import 'package:boorusama/boorus/sankaku/posts/parser.dart' as sankaku;
import 'package:booru_clients/szurubooru.dart' as szurubooru_api;
import 'package:boorusama/boorus/szurubooru/posts/parser.dart' as szurubooru;
import 'package:booru_clients/shimmie2.dart' as shimmie2_api;
import 'package:boorusama/boorus/shimmie2/posts/parser.dart' as shimmie2;
import 'package:booru_clients/pixiv.dart' as pixiv_api;
import 'package:boorusama/boorus/pixiv/posts/parser.dart' as pixiv;
import 'package:booru_clients/anime_pictures.dart' as anime_pictures_api;
import 'package:boorusama/boorus/anime-pictures/posts/parser.dart'
    as anime_pictures;
import 'package:booru_clients/eshuushuu.dart' as eshuushuu_api;
import 'package:boorusama/boorus/eshuushuu/posts/parser.dart' as eshuushuu;
import 'package:booru_clients/hybooru.dart' as hybooru_api;
import 'package:boorusama/boorus/hybooru/posts/parser.dart' as hybooru;
import 'package:booru_clients/hydrus.dart' as hydrus_api;
import 'package:boorusama/boorus/hydrus/posts/parser.dart' as hydrus;
import 'package:booru_clients/nozomi.dart' as nozomi_api;
import 'package:boorusama/boorus/nozomi/posts/parser.dart' as nozomi;
import 'package:booru_clients/zerochan.dart' as zerochan_api;
import 'package:boorusama/boorus/zerochan/posts/parser.dart' as zerochan;

void main() {
  const base = 'https://source.test';
  final parsers = <String, Post Function(Map<String, dynamic>)>{
    'Danbooru': (j) => danbooru.postDtoToPostNoMetadata(
      danbooru_api.PostDto.fromJson({'id': 12, ...j}),
    ),
    'Gelbooru': (j) => gelbooru.gelbooruPostDtoToGelbooruPostNoMetadata(
      gelbooru_api.PostDto.fromJson({'id': 12, ...j}, base),
    ),
    'Gelbooru V1': (j) => gelbooru_v1.postDtoToPost(
      gelbooru_v1_api.PostV1Dto(id: 12, score: j['score']),
      null,
    ),
    'Gelbooru V2': (j) => gelbooru_v2.gelbooruV2PostDtoToGelbooruPostNoMetadata(
      gelbooru_v2_api.PostV2Dto.fromJson({'id': 12, ...j}, base),
      const _Resolver(),
    ),
    'Moebooru': (j) => moebooru.postDtoToPostNoMetadata(
      moebooru_api.PostDto.fromJson({'id': 12, ...j}),
    ),
    'e621': (j) => e621.postDtoToPostNoMetadata(
      e621_api.PostDto.fromJson({
        'id': 12,
        'file': {'url': '$base/original.png'},
        ...j,
      }),
    )!,
    'Philomena': (j) => philomena.postDtoToPost(
      philomena_api.ImageDto.fromJson({'id': 12, ...j}),
      null,
    ),
    'Sankaku': (j) => sankaku.postDtoToPost(
      sankaku_api.PostDto.fromJson({'id': 'real-source-id', ...j}),
      PostIdGenerator(),
      null,
    ),
    'Szurubooru': (j) => szurubooru.postDtoToPost(
      szurubooru_api.PostDto.fromJson({'id': 12, ...j}),
      null,
      null,
    ),
    'Shimmie2': (j) => shimmie2.postDtoToPost(
      shimmie2_api.PostDto(
        id: 12,
        score: j['score'],
        favorites: j['favorites'],
      ),
      null,
    ),
    'Pixiv': (j) => pixiv
        .illustDtoToPosts(
          pixiv_api.PixivIllustDto.fromJson({
            'id': 12,
            'user': {'id': 2},
            'meta_single_page': {'original_image_url': '$base/original.png'},
            ...j,
          }),
        )
        .single,
    'Anime Pictures': (j) => anime_pictures.dtoToAnimePicturesPost(
      anime_pictures_api.PostDto.fromJson({'id': 12, ...j}, base),
    ),
    'e-shuushuu': (j) => eshuushuu.postDtoToPost(
      eshuushuu_api.PostDto.fromJson({'image_id': 12, ...j}),
      null,
    ),
    'HyBooru': (j) => hybooru.postDtoToPost(
      hybooru_api.PostDto.fromJson({'id': 12, ...j}),
      null,
      base,
    ),
    'Hydrus': (j) => hydrus.postDtoToPost(
      hydrus_api.FileDto.fromJson({'file_id': 12, ...j}, base, const []),
      null,
    ),
    'Nozomi': (j) => nozomi.postDtoToPost(
      nozomi_api.NozomiPostDto.fromJson({'postid': 12, ...j}),
      null,
    ),
    'Zerochan': (j) => zerochan.postDtoToPost(
      zerochan_api.PostDto.fromJson({'id': 12, ...j}),
      null,
    ),
  };

  for (final entry in parsers.entries) {
    test(
      '${entry.key} does not promote absent source counts or media defaults',
      () {
        final post = entry.value({});
        expect(post.detailFacts.score, isNull);
        expect(post.detailFacts.favoriteCount, isNull);
        expect(post.detailFacts.commentCount, isNull);
        expect(post.detailFacts.originalByteSize, isNull);
        expect(post.rating, Rating.unknown);
        expect(post.score, 0); // Operational compatibility remains non-null.
      },
    );
    test(
      '${entry.key} source facts survive offline unknown-payload storage and replacements',
      () {
        final post = entry
            .value({})
            .withDetailFacts(
              const PostDetailFacts(
                originalByteSize: 0,
                originalWidth: 800,
                originalHeight: 600,
                originalFormat: 'png',
                score: 0,
                favoriteCount: 0,
                commentCount: 0,
                description: 'Source description',
              ),
            )
            .copyWith(
              booruData: const UnknownPostData(
                typeKey: 'future',
                schemaVersion: 99,
                custom: {
                  'future': {
                    'opaque': [0, 'keep'],
                  },
                },
                reason: UnknownPostDataReason.unavailableCodec,
              ),
            );
        const codec = StoredPostCodec();
        final snapshot = StoredPostSnapshot.fromJson(
          jsonDecode(jsonEncode(codec.encode(post).toJson())),
        );
        final decoded =
            (codec.decode(snapshot) as StoredPostDecodeSuccess).post;
        expect(decoded.detailFacts, post.detailFacts);
        if (entry.key == 'Sankaku' || entry.key == 'Pixiv')
          expect(decoded.sitePostId, isNull);
        expect(
          (decoded.booruData as UnknownPostData).custom,
          (post.booruData as UnknownPostData).custom,
        );
        expect(PostCoreData.fromPost(decoded).detailFacts, post.detailFacts);
        final legacy = StoredPostSnapshot(
          origin: snapshot.origin,
          common: {...snapshot.common, 'schemaVersion': 1}
            ..remove('detailFacts'),
          custom: snapshot.custom,
          codecVersion: snapshot.codecVersion,
        );
        final old = (codec.decode(legacy) as StoredPostDecodeSuccess).post;
        expect(old.detailFacts.score, isNull);
        expect(old.detailFacts.originalByteSize, isNull);
        expect(old.width, post.width);
      },
    );
  }

  test(
    'explicit legacy Safe ratings retain their existing s classification',
    () {
      for (final name in [
        'Gelbooru',
        'Gelbooru V2',
        'Moebooru',
        'e621',
        'Sankaku',
      ]) {
        expect(parsers[name]!({'rating': 'safe'}).rating, Rating.sensitive);
      }
      expect(parsers['Danbooru']!({'rating': 'g'}).rating, Rating.general);
      expect(parsers['Danbooru']!({'rating': 's'}).rating, Rating.sensitive);
    },
  );

  test(
    'invalid Original dimensions and empty format never become detail facts',
    () {
      for (final value in [-1.0, 0.0, 1.5, double.nan, double.infinity]) {
        expect(PostDetailFacts(originalWidth: value).originalWidth, isNull);
      }
      const facts = PostDetailFacts(
        originalByteSize: -1,
        originalFormat: '.',
        favoriteCount: -1,
        commentCount: -1,
        score: -1,
      );
      expect(facts.originalByteSize, isNull);
      expect(facts.originalFormat, isNull);
      expect(facts.favoriteCount, isNull);
      expect(facts.commentCount, isNull);
      expect(facts.score, -1);
    },
  );

  test('source zero remains known for actual count fields', () {
    final dan = parsers['Danbooru']!({
      'score': 0,
      'fav_count': 0,
      'file_size': 0,
    });
    expect(dan.detailFacts.score, 0);
    expect(dan.detailFacts.favoriteCount, 0);
    expect(dan.detailFacts.originalByteSize, 0);
    final phil = parsers['Philomena']!({
      'score': 0,
      'faves': 0,
      'comment_count': 0,
    });
    expect(phil.detailFacts.score, 0);
    expect(phil.detailFacts.favoriteCount, 0);
    expect(phil.detailFacts.commentCount, 0);
    final szuru = parsers['Szurubooru']!({
      'score': 0,
      'favoriteCount': 0,
      'commentCount': 0,
    });
    expect(szuru.detailFacts.score, 0);
    expect(szuru.detailFacts.favoriteCount, 0);
    expect(szuru.detailFacts.commentCount, 0);
    final sank = parsers['Sankaku']!({
      'total_score': 0,
      'fav_count': 0,
      'comment_count': 0,
    });
    expect(sank.detailFacts.favoriteCount, 0);
    expect(sank.detailFacts.commentCount, 0);
    expect(sank.sitePostId, 'real-source-id');
  });

  test('different community metrics cannot become score, favorites, or upload dates', () {
    final eshu = parsers['e-shuushuu']!({
      'favorites': 7,
      'rating': 5,
      'posts': 2,
    });
    expect(eshu.detailFacts.favoriteCount, 7);
    expect(eshu.detailFacts.score, isNull);
    expect(eshu.detailFacts.commentCount, isNull);
    expect(eshu.rating, Rating.unknown);
    final pix = parsers['Pixiv']!({
      'total_bookmarks': 7,
      'caption': 'Authored caption',
    });
    expect(pix.sitePostId, '12');
    expect(pix.detailFacts.favoriteCount, isNull);
    expect(pix.detailFacts.score, isNull);
    expect(pix.detailFacts.description, 'Authored caption');
    final local = parsers['Hydrus']!({
      'time_imported': 12345,
      'ratings': {'fav': 1},
    });
    expect(local.createdAt, isNull);
    expect(local.detailFacts.favoriteCount, isNull);
  });

  test('e621 original facts stay distinct from video samples', () {
    final post = parsers['e621']!({
      'file': {
        'url': '$base/original.webm',
        'ext': 'webm',
        'size': 900,
        'width': 1800,
        'height': 1200,
      },
      'sample': {'url': '$base/sample.jpg', 'width': 300, 'height': 200},
      'score': {'total': 0},
      'fav_count': 0,
      'comment_count': 0,
    });
    expect(post.detailFacts.originalByteSize, 900);
    expect(post.detailFacts.originalWidth, 1800);
    expect(post.detailFacts.originalFormat, 'webm');
    expect(post.detailFacts.commentCount, 0);
  });

  test(
    'inferred or sampled Original paths do not establish Original properties',
    () {
      expect(parsers['Gelbooru V1']!({}).detailFacts.originalFormat, isNull);
      final preview = parsers['Anime Pictures']!({
        'width': 1200,
        'height': 800,
        'size': 900,
        'ext': 'png',
      });
      expect(preview.width, 1200);
      expect(preview.detailFacts.originalWidth, isNull);
      expect(preview.detailFacts.originalByteSize, isNull);
      final fallback = parsers['Zerochan']!({
        'large': '$base/sample.jpg',
        'width': 100,
        'height': 200,
        'size': 900,
      });
      expect(fallback.detailFacts.originalWidth, isNull);
      expect(fallback.detailFacts.originalFormat, isNull);
    },
  );
}

class _Resolver implements GelbooruV2ImageUrlResolver {
  const _Resolver();
  @override
  String resolveImageUrl(String url) => url;
  @override
  String resolvePreviewUrl(String url) => url;
  @override
  String resolveThumbnailUrl(String url) => url;
}
