import 'package:boorusama/core/posts/media_preload/src/viewer_preload_metadata.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fakes/test_post.dart';

void main() {
  test('an Original grid fallback cannot enter a speculative request', () {
    final post = TestPost(
      id: 1,
      thumbnailImageUrl: 'thumb',
      sampleImageUrl: 'sample',
      originalImageUrl: 'original',
    );
    expect(
      viewerPreloadMedia(
        post,
        displayUrl: 'sample',
        thumbnailUrl: 'original',
      )!.allUrls,
      {'thumb', 'sample'},
    );
  });
  test('an Original viewer choice preloads the original and a preview', () {
    final post = TestPost(
      id: 1,
      thumbnailImageUrl: 'thumb',
      sampleImageUrl: 'sample',
      originalImageUrl: 'original',
    );
    final media = viewerPreloadMedia(
      post,
      displayUrl: 'original',
      thumbnailUrl: post.sampleImageUrl,
    );
    expect(media!.allUrls, {'sample', 'original'});
  });

  test('a full rendition shared by High and Original is preloaded once', () {
    final post = TestPost(
      id: 1,
      thumbnailImageUrl: 'thumb',
      sampleImageUrl: 'original',
      originalImageUrl: 'original',
    );
    expect(
      viewerPreloadMedia(
        post,
        displayUrl: 'original',
        thumbnailUrl: post.sampleImageUrl,
      )!.allUrls,
      {'thumb', 'original'},
    );
  });

  test('a resolved original aliased as its own thumbnail is queued once', () {
    final post = TestPost(
      id: 1,
      thumbnailImageUrl: 'original',
      sampleImageUrl: 'original',
      originalImageUrl: 'original',
    );
    expect(
      viewerPreloadMedia(post, displayUrl: 'original')!.allUrls,
      {'original'},
    );
  });

  test('unresolved listings admit only their thumbnail', () {
    final post = TestPost(
      id: 1,
      thumbnailImageUrl: 'thumb',
      sampleImageUrl: 'unverified',
    );
    expect(
      viewerPreloadMedia(
        post,
        displayUrl: null,
        thumbnailUrl: 'unverified-grid-url',
      )!.allUrls,
      {'thumb'},
    );
  });
}
