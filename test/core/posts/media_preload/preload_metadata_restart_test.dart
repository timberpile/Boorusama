import 'dart:async';

import 'package:boorusama/core/posts/media_preload/src/preload_metadata_queue.dart';
import 'package:boorusama/core/posts/media_preload/src/viewer_preload_metadata.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fakes/test_post.dart';

void main() {
  test('a cancelled result cannot satisfy a new admission of the same key', () async {
    final oldResult = Completer<String?>();
    final freshResult = Completer<String?>();
    final freshStarted = Completer<void>();
    final published = <String?>[];
    late PreloadMetadataQueue<int, String> queue;
    queue = PreloadMetadataQueue<int, String>(
      onResolved: () => published.add(queue.peek(1)),
    );
    addTearDown(queue.dispose);

    final drained = queue.replace([(key: 1, load: () => oldResult.future)]);
    queue.cancel();
    unawaited(queue.replace([
      (
        key: 1,
        load: () {
          freshStarted.complete();
          return freshResult.future;
        },
      ),
    ]));
    oldResult.complete('cancelled');
    // Await the drain when the broken implementation skips the fresh loader,
    // so the regression fails an assertion rather than waiting for a timeout.
    await Future.any<void>([freshStarted.future, drained]);
    expect(freshStarted.isCompleted, isTrue);
    expect(queue.peek(1), isNull);
    expect(published, isEmpty);
    freshResult.complete('fresh');
    await drained;
    expect(queue.peek(1), 'fresh');
    expect(published, ['fresh']);
  });

  test('unresolved metadata never preloads a thumbnail alias of the original', () {
    final post = TestPost(
      id: 1,
      thumbnailImageUrl: 'original',
      sampleImageUrl: 'guessed-sample',
      originalImageUrl: 'original',
    );
    expect(thumbnailOnlyViewerPreloadMedia(post, displayUrl: null), isNull);
  });

  test('unresolved metadata keeps only a distinct thumbnail', () {
    final post = TestPost(
      id: 1,
      thumbnailImageUrl: 'thumb',
      sampleImageUrl: 'guessed-sample',
      originalImageUrl: 'original',
    );
    expect(
      thumbnailOnlyViewerPreloadMedia(post, displayUrl: null)!.allUrls,
      {'thumb'},
    );
  });
}
