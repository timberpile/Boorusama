// Project imports:
import '../../../core/posts/post/types.dart';
import 'post_data.dart';
import 'types.dart';

final class GelbooruV1PostCodec extends EmptyPostDataCodec {
  const GelbooruV1PostCodec() : super('gelbooru_v1');
}

UnifiedPost gelbooruV1PostToUnified(
  GelbooruV1Post post,
  PostOrigin origin,
) => UnifiedPost(
  origin: origin,
  core: PostCoreData.fromPost(post),
  booruData: gelbooruV1PostData,
);
