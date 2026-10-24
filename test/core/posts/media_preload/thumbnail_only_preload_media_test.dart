import 'package:boorusama/core/posts/media_preload/src/viewer_preload_metadata.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fakes/test_post.dart';

void main() {
  test('an Original viewer choice preloads only a distinct intermediate', () {
    final post = TestPost(id: 1, thumbnailImageUrl: 'thumb', sampleImageUrl: 'sample', originalImageUrl: 'original');
    final media = thumbnailOnlyViewerPreloadMedia(post, displayUrl: 'original');
    expect(media!.allUrls, {'thumb', 'sample'});
  });

  test('original-only media keeps the thumbnail rather than relabeling the original', () {
    final post = TestPost(id: 1, thumbnailImageUrl: 'thumb', sampleImageUrl: 'original', originalImageUrl: 'original');
    expect(thumbnailOnlyViewerPreloadMedia(post, displayUrl: 'original')!.allUrls, {'thumb'});
  });

  test('an original aliased as its own thumbnail is never prefetched', () {
    final post = TestPost(id: 1, thumbnailImageUrl: 'original', sampleImageUrl: 'original', originalImageUrl: 'original');
    expect(thumbnailOnlyViewerPreloadMedia(post, displayUrl: 'original'), isNull);
  });

  test('unknown originals do not cause speculative full-image downloads', () {
    final post = TestPost(id: 1, thumbnailImageUrl: 'thumb', sampleImageUrl: 'unverified');
    expect(thumbnailOnlyViewerPreloadMedia(post, displayUrl: 'unverified')!.allUrls, {'thumb'});
  });
}
