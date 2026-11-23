import 'dart:convert';

import 'package:booru_clients/src/gelbooru_v2/post_v2_dto.dart';
import 'package:boorusama/boorus/gelbooru_v2/posts/parser.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/posts/details/src/types/media_url_resolver.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/settings/types.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final post =
      realbooruFavoriteListedPost(
        PostV2Dto(
          id: 42,
          previewUrl: 'https://realbooru.com/thumbnails/a.jpg',
          tags: 'fixture',
          rating: 'e',
        ),
      ).copyWith(
        origin: PostOrigin.fromSource(
          booruType: BooruType.gelbooruV2,
          booruId: BooruType.gelbooruV2.id,
          source: 'https://realbooru.com',
        ),
      );
  const codec = StoredPostCodec();
  test('listed snapshot round trips with no installed engine codec', () {
    final snapshot = codec.encode(post);
    expect(snapshot.codecVersion, 1);
    expect(snapshot.custom, {'snapshotKind': 'listed'});
    final restored = StoredPostSnapshot.fromJson(
      jsonDecode(jsonEncode(snapshot.toJson())),
    );
    final decoded = (codec.decode(restored) as StoredPostDecodeSuccess).post;
    expect(decoded, post);
    expect(decoded.requiresDetailLookup, isTrue);
    expect(decoded.hasOriginalMedia, isFalse);
  });
  test(
    'contradictory listed media and wrong engine are rejected before fallback',
    () {
      final snapshot = codec.encode(post);
      for (final field in [
        'sampleImageUrl',
        'originalImageUrl',
        'videoUrl',
        'md5',
      ]) {
        final invalid = StoredPostSnapshot(
          origin: snapshot.origin,
          common: {...snapshot.common, field: 'invented'},
          custom: snapshot.custom,
          codecVersion: snapshot.codecVersion,
        );
        expect(codec.decode(invalid), isA<StoredPostDecodeFailure>());
      }
      expect(
        () => codec.encode(
          post.copyWith(origin: PostOrigin.forBooruType(BooruType.danbooru)),
        ),
        throwsFormatException,
      );
    },
  );
  test('every viewer quality retains exactly the listing thumbnail', () {
    for (final quality in PostQuality.values) {
      expect(
        DefaultMediaUrlResolver(postQuality: quality)
            .resolveMediaUrl(post, BooruConfig.empty.viewer),
        post.thumbnailImageUrl,
      );
    }
  });
}
