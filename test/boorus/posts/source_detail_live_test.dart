import 'dart:convert';
import 'dart:io';

import 'package:booru_clients/anime_pictures.dart' as anime_api;
import 'package:booru_clients/danbooru.dart' as dan_api;
import 'package:booru_clients/e621.dart' as e621_api;
import 'package:booru_clients/eshuushuu.dart' as eshu_api;
import 'package:booru_clients/gelbooru.dart' as gel_api;
import 'package:booru_clients/hybooru.dart' as hy_api;
import 'package:booru_clients/moebooru.dart' as moe_api;
import 'package:booru_clients/nozomi.dart' as nozomi_api;
import 'package:booru_clients/philomena.dart' as phil_api;
import 'package:booru_clients/sankaku.dart' as sank_api;
import 'package:booru_clients/src/sankaku_idol/types/post_dto.dart' as idol_api;
import 'package:booru_clients/src/sankaku_idol/types/type_converters.dart';
import 'package:booru_clients/shimmie2.dart' as shimmie_api;
import 'package:boorusama/boorus/anime-pictures/posts/parser.dart' as anime;
import 'package:boorusama/boorus/danbooru/posts/post/src/converter.dart' as dan;
import 'package:boorusama/boorus/e621/posts/parser.dart' as e621;
import 'package:boorusama/boorus/eshuushuu/posts/parser.dart' as eshu;
import 'package:boorusama/boorus/gelbooru/posts/parser.dart' as gel;
import 'package:boorusama/boorus/gelbooru_v2/posts/parser.dart' as gel2;
import 'package:boorusama/boorus/gelbooru_v2/posts/types.dart';
import 'package:boorusama/boorus/hybooru/posts/parser.dart' as hy;
import 'package:boorusama/boorus/moebooru/posts/parser.dart' as moe;
import 'package:boorusama/boorus/nozomi/posts/parser.dart' as nozomi;
import 'package:boorusama/boorus/philomena/posts/parser.dart' as phil;
import 'package:boorusama/boorus/sankaku/posts/parser.dart' as sank;
import 'package:boorusama/boorus/shimmie2/posts/parser.dart' as shimmie;
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/posts/rating/types.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';
import 'package:booru_clients/src/gelbooru_v2/parsers/rb_parsers.dart' as rb;
import 'package:dio/dio.dart';

void main() {
  final files =
      Directory('test/boorus/posts/fixtures/source_detail_live')
          .listSync()
          .whereType<File>()
          .where(
            (f) =>
                f.path.endsWith('.json') &&
                !f.path.endsWith('/provenance.json'),
          )
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));
  for (final file in files) {
    final fixture = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    test('sanitized live metadata: ${file.uri.pathSegments.last}', () {
      expect(fixture['status'], 200);
      final data =
          (fixture['post'] ?? fixture['detail']) as Map<String, dynamic>;
      XmlElement xml(Map<String, dynamic> attributes) =>
          XmlElement(XmlName('post'), [
            for (final e in attributes.entries)
              XmlAttribute(XmlName(e.key), e.value.toString()),
          ]);
      const base = 'https://fixtures.invalid/';
      final Post post = switch (fixture['family']) {
        'danbooru' => dan.postDtoToPostNoMetadata(
          dan_api.PostDto.fromJson(data),
        ),
        'gelbooru' => gel.gelbooruPostDtoToGelbooruPostNoMetadata(
          gel_api.PostDto.fromJson(data, base),
        ),
        'gelbooru_v2' => gel2.gelbooruV2PostDtoToGelbooruPostNoMetadata(
          fixture['shape'] == 'xml'
              ? gel_api.PostV2Dto.fromXml(xml(data), base)
              : gel_api.PostV2Dto.fromJson(data, base),
          const _Resolver(),
        ),
        'moebooru' => moe.postDtoToPostNoMetadata(
          moe_api.PostDto.fromJson(data),
        ),
        'e621' => e621.postDtoToPostNoMetadata(
          e621_api.PostDto.fromJson(data),
        )!,
        'philomena' => phil.postDtoToPost(
          phil_api.ImageDto.fromJson(data),
          null,
        ),
        'sankaku_idol' => sank.postDtoToPost(
          idol_api.PostIdolDto.fromJson(data).toSankakuPost(),
          PostIdGenerator(),
          null,
        ),
        'sankaku' => sank.postDtoToPost(
          sank_api.PostDto.fromJson(data),
          PostIdGenerator(),
          null,
        ),
        'shimmie2' => shimmie.postDtoToPost(
          shimmie_api.PostDto.fromXml(xml(data), baseUrl: base),
          null,
        ),
        'anime_pictures' when fixture.containsKey('detail') => (() {
          final details = anime_api.PostDetailsDto.fromJson(data, base);
          return anime.dtoToAnimePicturesPost(
            details.post!,
            details: details,
            originalUrl: 'https://fixtures.invalid/original.jpg',
          );
        })(),
        'anime_pictures' => anime.dtoToAnimePicturesPost(
          anime_api.PostDto.fromJson(data, base),
        ),
        'hybooru' => hy.postDtoToPost(
          hy_api.PostDto.fromJson(data),
          null,
          base,
        ),
        'eshuushuu' => eshu.postDtoToPost(
          eshu_api.PostDto.fromJson(data),
          null,
        ),
        'nozomi' => nozomi.postDtoToPost(
          nozomi_api.NozomiPostDto.fromJson(data),
          null,
        ),
        _ => throw StateError('Unexpected live fixture family'),
      };
      expect(post.sitePostId, isNotNull);
      final facts = post.detailFacts;
      if (fixture['family'] == 'anime_pictures' &&
          fixture.containsKey('detail')) {
        expect(facts.originalByteSize, 1471977);
        expect(facts.originalWidth, 3840);
        expect(facts.originalHeight, 2160);
        expect(facts.originalFormat, 'jpg');
        expect(post.uploaderName, 'source_account');
        expect(post.originalImageUrl, isNot(post.sampleImageUrl));
      }
      if (fixture['family'] == 'eshuushuu') {
        expect(facts.score, isNull);
        expect(facts.favoriteCount, data['favorites']);
        expect(facts.commentCount, isNull);
        expect(post.rating, Rating.unknown);
      }
      if (fixture['family'] == 'philomena') {
        expect(post.rating, Rating.unknown);
        expect(facts.commentCount, data['comment_count']);
        expect(facts.favoriteCount, data['faves']);
      }
      if (fixture['family'] == 'e621') {
        expect(facts.originalByteSize, data['file']['size']);
        expect(facts.originalFormat, data['file']['ext']);
        expect(facts.commentCount, data['comment_count']);
        expect(facts.favoriteCount, data['fav_count']);
      }
      if (fixture['family'] == 'sankaku_idol') {
        expect(
          post.createdAt?.toUtc(),
          DateTime.parse(data['created_at'] as String).toUtc(),
        );
        expect(facts.originalByteSize, data['file_size']);
        expect(facts.commentCount, data['comment_count']);
        expect(facts.favoriteCount, data['fav_count']);
        expect(post.uploaderName, 'source_account');
      }
      if (fixture['family'] == 'sankaku') {
        expect(facts.commentCount, data['comment_count']);
        expect(facts.score, data['total_score']);
        expect(post.sitePostId, data['id'].toString());
      }
      if (fixture['family'] == 'shimmie2') {
        expect(facts.score, int.tryParse(data['score'].toString()));
        expect(facts.favoriteCount, isNull);
        expect(facts.commentCount, isNull);
      }
      if (fixture['family'] == 'nozomi') {
        final media = (data['imageurls'] as List).first as Map;
        expect(facts.originalWidth, media['width']);
        expect(facts.originalHeight, media['height']);
        expect(facts.originalByteSize, isNull);
        if (fixture['mediaKind'] == 'video') {
          expect(facts.originalFormat, 'webm');
          expect(post.isVideo, isTrue);
        } else {
          // Static JPEG is served as converted WebP.
          expect(facts.originalFormat, isNull);
        }
      }
      if (fixture['family'] == 'danbooru') {
        expect(facts.originalByteSize, data['file_size']);
        expect(facts.score, data['score']);
        expect(facts.favoriteCount, data['fav_count']);
      }
    });
  }
  test('Realbooru own live Posted day and uploader reach the app independently of modification timestamps', () {
    final dto = rb.parseRbPostHtml(
      Response<String>(
        requestOptions: RequestOptions(),
        data: File(
          'test/boorus/posts/fixtures/source_detail_live/realbooru-upload-day.html',
        ).readAsStringSync(),
      ),
      {'baseUrl': 'https://realbooru.com/'},
    )!;
    final post = gel2.gelbooruV2PostDtoToGelbooruPostNoMetadata(
      dto,
      const _Resolver(),
    );
    expect(post.createdAt, DateTime.utc(2020, 8, 21));
    expect(post.uploaderName, 'source_uploader');
    expect(post.detailFacts.score, 2);
  });
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
