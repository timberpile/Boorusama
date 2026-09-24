// Project imports:
import '../../../core/posts/post/types.dart';
import 'post_data.dart';
import 'types.dart';

final class NozomiPostCodec extends EmptyPostDataCodec {
  const NozomiPostCodec() : super('nozomi');
}

Post nozomiPostFromRecord(NozomiPostRecord post, PostOrigin origin) => Post(
  origin: origin,
  core: PostCoreData.fromPost(post),
  booruData: nozomiPostData,
);
