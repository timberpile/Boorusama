// Project imports:
import '../../../details_parts/src/details_ui_builder.dart';
import 'booru_post_data.dart';
import 'unified_post.dart';

abstract interface class BooruPostPresentation {
  bool supports(BooruPostData data);
  PostDetailsUIBuilder detailsBuilder(UnifiedPost post);
}

final class GenericPostPresentation implements BooruPostPresentation {
  const GenericPostPresentation();

  @override
  bool supports(BooruPostData data) => true;

  @override
  PostDetailsUIBuilder detailsBuilder(UnifiedPost post) =>
      const PostDetailsUIBuilder();
}
