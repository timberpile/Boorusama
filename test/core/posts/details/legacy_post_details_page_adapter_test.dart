// Package imports:
import 'package:flutter_test/flutter_test.dart';

// Project imports:
import 'package:boorusama/boorus/gelbooru/posts/post_codec.dart';
import 'package:boorusama/boorus/gelbooru/posts/types.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/posts/details/routes.dart';
import 'package:boorusama/core/posts/details/widgets.dart';
import 'package:boorusama/core/posts/post/types.dart';

void main() {
  test('preserves route state while converting legacy posts', () {
    final legacy = GelbooruPost.empty();
    final origin = PostOrigin.fromSource(
      booruType: BooruType.gelbooru,
      booruId: BooruType.gelbooru.id,
      source: 'https://gelbooru.com',
      profileIdHint: 42,
    );
    const disclaimer = 'viewer disclaimer';
    const thumbnail = 'https://example.com/thumb.jpg';
    final payload = DetailsRouteContext<Post>(
      initialIndex: 0,
      posts: [legacy],
      scrollController: null,
      isDesktop: false,
      hero: true,
      initialThumbnailUrl: thumbnail,
      configSearch: null,
      dislclaimer: disclaimer,
    );

    final converted = LegacyPostDetailsPageAdapter.convertPayload(
      payload: payload,
      origin: origin,
      converter: (post, postOrigin) =>
          gelbooruPostToUnified(post as GelbooruPost, postOrigin),
    );

    expect(converted.posts, hasLength(1));
    expect(converted.posts.single.origin, origin);
    expect(converted.posts.single.id, legacy.id);
    expect(converted.initialIndex, payload.initialIndex);
    expect(converted.scrollController, same(payload.scrollController));
    expect(converted.isDesktop, payload.isDesktop);
    expect(converted.hero, payload.hero);
    expect(converted.initialThumbnailUrl, thumbnail);
    expect(converted.dislclaimer, disclaimer);
    expect(converted.configSearch, payload.configSearch);
    expect(converted.useMixedViewer, isTrue);
  });
}
