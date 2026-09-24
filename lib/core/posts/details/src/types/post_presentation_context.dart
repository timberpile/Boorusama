// Project imports:
import '../../../../configs/config/types.dart';
import '../../../post/types.dart';

final class PostPresentationContext {
  const PostPresentationContext._({
    required this.post,
    required this.presentation,
    required this.resolvedConfig,
    required bool hasValidatedPayload,
  }) : _hasValidatedPayload = hasValidatedPayload;

  factory PostPresentationContext.resolve({
    required Post post,
    required BooruPostPresentation presentation,
    BooruConfig? resolvedConfig,
  }) {
    final isCompatible =
        presentation is! GenericPostPresentation &&
        presentation.supports(post.booruData);

    return PostPresentationContext._(
      post: post,
      presentation: isCompatible
          ? presentation
          : const GenericPostPresentation(),
      resolvedConfig: resolvedConfig,
      hasValidatedPayload: isCompatible,
    );
  }

  factory PostPresentationContext.generic(Post post) =>
      PostPresentationContext._(
        post: post,
        presentation: const GenericPostPresentation(),
        resolvedConfig: null,
        hasValidatedPayload: false,
      );

  final Post post;
  final BooruPostPresentation presentation;
  final BooruConfig? resolvedConfig;
  final bool _hasValidatedPayload;

  D? data<D extends BooruPostData>() {
    final data = post.booruData;
    return _hasValidatedPayload && data is D ? data : null;
  }
}
