// Project imports:
import '../../../core/posts/post/types.dart';
import 'types.dart';

/// Builds the web URL for a Pixiv work.
///
/// Pixiv is single-site, and its canonical artwork URL is fixed regardless
/// of `config.url`, so this does not consult a base URL at all.
///
/// Typed against [Post] rather than [PixivPost]: Dart generics are
/// covariant, so a `PostLinkGenerator<PixivPost>` would satisfy the
/// analyzer here and then throw at runtime on anything else.
class PixivPostLinkGenerator implements PostLinkGenerator<Post> {
  const PixivPostLinkGenerator();

  @override
  String getLink(Post post) {
    if (post is! PixivPost) return 'https://www.pixiv.net/';

    return 'https://www.pixiv.net/artworks/${post.illustId}';
  }
}
