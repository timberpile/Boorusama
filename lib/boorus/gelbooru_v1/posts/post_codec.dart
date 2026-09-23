// Project imports:
import '../../../core/posts/post/types.dart';
import 'post_data.dart';
import 'types.dart';

final class GelbooruV1PostCodec extends EmptyPostDataCodec {
  const GelbooruV1PostCodec() : super('gelbooru_v1');
}

Post gelbooruV1PostFromRecord(
  GelbooruV1PostRecord post,
  PostOrigin origin,
) => Post(
  origin: origin,
  core: PostCoreData.fromPost(post),
  booruData: gelbooruV1PostData,
);
