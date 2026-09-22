// Project imports:
import '../../../core/posts/post/types.dart';
import 'post_data.dart';
import 'types.dart';

final class GelbooruPostCodec extends EmptyPostDataCodec {
  const GelbooruPostCodec() : super('gelbooru');
}

UnifiedPost gelbooruPostToUnified(GelbooruPost post, PostOrigin origin) =>
    UnifiedPost(
      origin: origin,
      core: PostCoreData.fromPost(post),
      booruData: gelbooruPostData,
    );
