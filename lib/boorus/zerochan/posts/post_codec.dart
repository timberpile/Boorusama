// Project imports:
import '../../../core/posts/post/types.dart';
import 'post_data.dart';
import 'types.dart';

final class ZerochanPostCodec extends EmptyPostDataCodec {
  const ZerochanPostCodec() : super('zerochan');
}

UnifiedPost zerochanPostToUnified(ZerochanPost post, PostOrigin origin) =>
    UnifiedPost(
      origin: origin,
      core: PostCoreData.fromPost(post),
      booruData: zerochanPostData,
    );
