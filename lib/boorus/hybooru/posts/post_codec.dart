// Project imports:
import '../../../core/posts/post/types.dart';
import 'post_data.dart';
import 'types.dart';

final class HybooruPostCodec extends EmptyPostDataCodec {
  const HybooruPostCodec() : super('hybooru');
}

Post hybooruPostFromRecord(HybooruPostRecord post, PostOrigin origin) => Post(
  origin: origin,
  core: PostCoreData.fromPost(post),
  booruData: hybooruPostData,
);
