// Project imports:
import '../../../core/posts/post/types.dart';
import 'types.dart';

/// Builds the web URL for a Pixiv work.
///
/// Pixiv is single-site, and its canonical artwork URL is fixed regardless
/// of `config.url`, so this does not consult a base URL at all.
///
class PixivPostLinkGenerator implements PostLinkGenerator<Post> {
  const PixivPostLinkGenerator();

  @override
  String getLink(Post post) => post.pixivData == null
      ? 'https://www.pixiv.net/'
      : 'https://www.pixiv.net/artworks/${post.illustId}';
}
