// Project imports:
import '../../../core/posts/post/types.dart';
import 'post_data.dart';
import 'types.dart';

final class NozomiPostCodec extends EmptyPostDataCodec {
  const NozomiPostCodec() : super('nozomi');
}

UnifiedPost nozomiPostToUnified(NozomiPost post, PostOrigin origin) =>
    UnifiedPost(
      origin: origin,
      core: PostCoreData.fromPost(post),
      booruData: nozomiPostData,
    );
