// Package imports:
import 'package:flutter_test/flutter_test.dart';

// Project imports:
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/posts/rating/types.dart';
import 'package:boorusama/core/posts/sources/types.dart';

void main() {
  test('snapshot decoding keeps the sole concrete runtime post type', () {
    const dataCodec = EmptyPostDataCodec('test');
    const codec = StoredPostCodec();
    final post = Post(
      origin: PostOrigin.forBooruType(BooruType.unknown),
      core: _core(id: 1),
      booruData: const EmptyPostData(typeKey: 'test'),
    );

    final result = codec.decode(
      codec.encode(post, dataCodec: dataCodec),
      dataCodec: dataCodec,
    );

    expect(post.runtimeType, Post);
    expect(result, isA<StoredPostDecodeSuccess>());
    final decoded = (result as StoredPostDecodeSuccess).post;
    expect(decoded.runtimeType, Post);
    expect(decoded, post);
  });

  test('changing the origin keeps common and booru-specific data intact', () {
    final post = Post(
      origin: PostOrigin.forBooruType(BooruType.unknown),
      core: _core(id: 2),
      booruData: const EmptyPostData(typeKey: 'test'),
    );
    final origin = PostOrigin.fromSource(
      booruType: BooruType.gelbooru,
      booruId: 7,
      source: 'https://gelbooru.example',
      profileIdHint: 3,
    );

    final rebound = post.copyWith(origin: origin);

    expect(rebound.runtimeType, Post);
    expect(rebound.origin, origin);
    expect(rebound.core, same(post.core));
    expect(rebound.booruData, same(post.booruData));
  });
}

PostCoreData _core({required int id}) => PostCoreData(
  id: id,
  thumbnailImageUrl: 'thumbnail',
  sampleImageUrl: 'sample',
  originalImageUrl: 'original',
  videoUrl: '',
  videoThumbnailUrl: '',
  width: 1,
  height: 1,
  format: 'jpg',
  md5: '',
  fileSize: 0,
  duration: 0,
  tags: const {'tag'},
  rating: Rating.general,
  hasComment: false,
  isTranslated: false,
  hasParentOrChildren: false,
  source: PostSource.none(),
  score: 0,
);
