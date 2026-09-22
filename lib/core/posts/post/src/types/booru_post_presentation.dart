// Flutter imports:
import 'package:flutter/widgets.dart';

// Project imports:
import '../../../details_parts/src/details_ui_builder.dart';
import 'booru_post_data.dart';
import 'unified_post.dart';

typedef PostDetailsWrapperBuilder =
    Widget Function({required UnifiedPost post, required Widget child});

abstract interface class BooruPostPresentation {
  bool supports(BooruPostData data);
  PostDetailsUIBuilder detailsBuilder(UnifiedPost post);
  PostDetailsWrapperBuilder? get detailsWrapperBuilder;
}

final class TypedBooruPostPresentation<D extends BooruPostData>
    implements BooruPostPresentation {
  const TypedBooruPostPresentation({
    required this.typeKey,
    required this.uiBuilder,
    this.detailsWrapperBuilder,
  });

  final String typeKey;
  final PostDetailsUIBuilder uiBuilder;

  @override
  final PostDetailsWrapperBuilder? detailsWrapperBuilder;

  @override
  bool supports(BooruPostData data) => data is D && data.typeKey == typeKey;

  @override
  PostDetailsUIBuilder detailsBuilder(UnifiedPost post) => uiBuilder;
}

final class GenericPostPresentation implements BooruPostPresentation {
  const GenericPostPresentation();

  @override
  bool supports(BooruPostData data) => true;

  @override
  PostDetailsUIBuilder detailsBuilder(UnifiedPost post) =>
      const PostDetailsUIBuilder();

  @override
  PostDetailsWrapperBuilder? get detailsWrapperBuilder => null;
}
