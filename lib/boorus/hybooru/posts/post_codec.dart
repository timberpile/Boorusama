// Project imports:
import '../../../core/posts/post/types.dart';
import 'post_data.dart';
import 'types.dart';

final class HybooruPostCodec extends EmptyPostDataCodec {
  const HybooruPostCodec() : super('hybooru');
}

UnifiedPost hybooruPostToUnified(HybooruPost post, PostOrigin origin) =>
    UnifiedPost(
      origin: origin,
      core: PostCoreData.fromPost(post),
      booruData: hybooruPostData,
    );
