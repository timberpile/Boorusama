// Project imports:
import '../../../../boorus/booru/types.dart';
import 'booru_post_data.dart';
import 'booru_post_presentation.dart';
import 'post_origin.dart';

final class BooruPostCapability<D extends BooruPostData> {
  const BooruPostCapability({
    required this.booruType,
    required this.codec,
    required this.presentation,
  });

  final BooruType booruType;
  final BooruPostDataCodec<D>? codec;
  final BooruPostPresentation presentation;

  BooruPostDataCodec<D>? codecFor(PostOrigin origin, BooruPostData data) {
    final candidate = codec;
    return origin.booruType == booruType &&
            candidate != null &&
            candidate.supports(data)
        ? candidate
        : null;
  }

  BooruPostPresentation presentationFor(
    PostOrigin origin,
    BooruPostData data,
  ) => codecFor(origin, data) != null && presentation.supports(data)
      ? presentation
      : const GenericPostPresentation();
}
