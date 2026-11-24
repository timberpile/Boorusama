// Flutter imports:
import 'package:flutter/widgets.dart';

// Project imports:
import '../../../../configs/config/types.dart';
import '../../../details_parts/src/details_ui_builder.dart';
import 'booru_post_data.dart';
import 'post.dart';

typedef PostDetailsWrapperBuilder = Widget Function({
  required Post post,
  required Widget child,
});

typedef PostDetailsImageBuilder = Widget Function({
  required Post post,
  required BooruConfig config,
  required bool active,
  required Widget poster,
});

abstract interface class BooruPostPresentation {
  bool supports(BooruPostData data);
  PostDetailsUIBuilder detailsBuilder(Post post);
  PostDetailsWrapperBuilder? get detailsWrapperBuilder;
}

final class TypedBooruPostPresentation<D extends BooruPostData>
    implements BooruPostPresentation {
  const TypedBooruPostPresentation({
    required this.typeKey,
    required this.uiBuilder,
    this.detailsWrapperBuilder,
    this.detailsImageBuilder,
  });

  final String typeKey;
  final PostDetailsUIBuilder uiBuilder;

  @override
  final PostDetailsWrapperBuilder? detailsWrapperBuilder;

  final PostDetailsImageBuilder? detailsImageBuilder;

  @override
  bool supports(BooruPostData data) => data is D && data.typeKey == typeKey;

  @override
  PostDetailsUIBuilder detailsBuilder(Post post) => uiBuilder;
}

final class GenericPostPresentation implements BooruPostPresentation {
  const GenericPostPresentation();

  @override
  bool supports(BooruPostData data) => true;

  @override
  PostDetailsUIBuilder detailsBuilder(Post post) =>
      const PostDetailsUIBuilder();

  @override
  PostDetailsWrapperBuilder? get detailsWrapperBuilder => null;
}
