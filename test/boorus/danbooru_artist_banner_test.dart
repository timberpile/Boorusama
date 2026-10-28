import 'dart:async';

import 'package:boorusama/boorus/danbooru/artists/artist/src/widgets/artist_identity.dart';
import 'package:boorusama/core/posts/listing/providers.dart';
import 'package:boorusama/core/posts/listing/widgets.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foundation/foundation.dart';

import '../support/fakes/test_post.dart';

void main() {
  test(
    'still lookup continues past blocked, animated and unusable candidates',
    () async {
      final pages = <int>[];
      final video = _post(10, format: 'mp4');
      final selected = Completer<void>();
      final controller = _controller(
        [video],
        hiddenTags: {'blocked'},
        hiddenUrls: {'https://example.com/8.jpg'},
      );
      final banner = ArtistBannerSnapshot(
        fetchStillImages: (page) async {
          pages.add(page);
          return switch (page) {
            1 => [
              _post(9, tags: {'blocked'}),
              _post(8),
            ],
            2 => [TestPost(id: 7), _post(6, format: 'gif'), _post(5)],
            _ => [],
          };
        },
      )..attach(controller);
      addTearDown(controller.dispose);
      addTearDown(banner.dispose);
      banner.addListener(() {
        if (banner.post?.id == 5 && !selected.isCompleted) selected.complete();
      });
      await controller.refresh();
      await selected.future.timeout(const Duration(seconds: 10));
      expect(pages, [1, 2]);
      expect(banner.post?.id, 5);
      expect(controller.allItems.single.id, 10);
      expect(controller.page, 1);
      banner.newest = false;
      await controller.refresh();
      expect(banner.post?.id, 5);
      expect(pages, [1, 2]);
    },
  );

  test('disposing a banner ignores an outstanding still lookup', () async {
    final started = Completer<void>();
    final response = Completer<List<Post>>();
    final controller = _controller([_post(10, format: 'mp4')]);
    final banner = ArtistBannerSnapshot(
      fetchStillImages: (_) {
        started.complete();
        return response.future;
      },
    )..attach(controller);
    addTearDown(controller.dispose);
    await controller.refresh();
    await started.future;
    banner.dispose();
    response.complete([_post(1)]);
    await response.future;
    expect(banner.post, isNull);
  });

  for (final fails in [false, true]) {
    test(
      'an exhausted or failed still lookup stays on the fallback ($fails)',
      () async {
        final started = Completer<void>();
        final response = Completer<List<Post>>();
        var requests = 0;
        final controller = _controller([_post(10, format: 'mp4')]);
        final banner = ArtistBannerSnapshot(
          fetchStillImages: (_) {
            requests++;
            started.complete();
            return response.future;
          },
        )..attach(controller);
        addTearDown(controller.dispose);
        addTearDown(banner.dispose);
        await controller.refresh();
        await started.future;
        if (fails) {
          response.completeError(Exception('unavailable'));
        } else {
          response.complete([]);
        }
        await response.future.then<void>((_) {}, onError: (_) {});
        controller.notifyListeners();
        expect(requests, 1);
        expect(banner.post, isNull);
      },
    );
  }

  test(
    'a newer refresh cannot be overwritten by a stale still lookup',
    () async {
      final started = Completer<void>();
      final response = Completer<List<Post>>();
      var calls = 0;
      final selected = Completer<void>();
      final controller = _controller([_post(10, format: 'mp4')]);
      final banner = ArtistBannerSnapshot(
        fetchStillImages: (_) {
          if (calls++ == 0) {
            started.complete();
            return response.future;
          }
          return Future.value([_post(2)]);
        },
      )..attach(controller);
      addTearDown(controller.dispose);
      addTearDown(banner.dispose);
      banner.addListener(() {
        if (banner.post?.id == 2 && !selected.isCompleted) selected.complete();
      });
      await controller.refresh();
      await started.future;
      await controller.refresh();
      await selected.future.timeout(const Duration(seconds: 10));
      response.complete([_post(1)]);
      await response.future;
      expect(banner.post?.id, 2);
    },
  );
}

Post _post(int id, {String format = 'jpg', Set<String> tags = const {}}) =>
    TestPost(
      id: id,
      format: format,
      tags: tags,
      thumbnailImageUrl: 'https://example.com/$id-thumb.jpg',
      originalImageUrl: 'https://example.com/$id.jpg',
    );

PostGridController<Post> _controller(
  List<Post> posts, {
  Set<String> hiddenTags = const {},
  Set<String> hiddenUrls = const {},
}) => PostGridController<Post>(
  fetcher: (_) =>
      TaskEither.right(PostResult(posts: posts, total: posts.length)),
  blacklistedTagsFetcher: () async => hiddenTags,
  blacklistedUrlsFetcher: () async => hiddenUrls,
  duplicateTracker: PostDuplicateTracker<Post>(),
  mountedChecker: () => true,
  onError: (_) {},
);
