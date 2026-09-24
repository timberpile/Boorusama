// Project imports:
import '../../../core/posts/listing/types.dart';
import '../../../core/posts/post/types.dart';
import '../../gelbooru/common/grid_thumbnail_url.dart';
import 'types.dart';

GridThumbnailMedia gelbooruV2ThumbnailOnlyGridThumbnailMedia(
  Post post,
  GridThumbnailSettings settings,
) => switch (post) {
  GelbooruV2Post(isVideoPreview: true) => gelbooruGridThumbnailMedia(
    post,
    settings,
    isVideoPreview: true,
  ),
  _ => const DefaultGridThumbnailUrlGenerator.thumbnailOnly().resolve(
    post,
    settings: settings,
  ),
};
