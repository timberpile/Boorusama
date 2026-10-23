import 'dart:async';

import 'package:boorusama/core/search/following_topics/src/services/topic_preview_loader.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'returns at most four unique HTTP thumbnails without timestamp metadata',
    () async {
      final loader = TopicPreviewLoader();
      var calls = 0;
      final urls = await loader.load(
        canStart: () => true,
        fetch: () async {
          calls++;
          return [
            '',
            'file:///secret',
            '/relative',
            'https://site.test/1.jpg',
            'https://site.test/1.jpg',
            'https://site.test/2.jpg',
            'https://site.test/3.jpg',
            'https://site.test/4.jpg',
            'https://site.test/5.jpg',
          ];
        },
      );
      expect(calls, 1);
      expect(urls, [for (var i = 1; i <= 4; i++) 'https://site.test/$i.jpg']);
      expect(() => urls.add('https://site.test/6.jpg'), throwsUnsupportedError);
    },
  );

  test('bounds concurrency and does not fetch disposed queued work', () async {
    final loader = TopicPreviewLoader(concurrency: 1);
    final started = Completer<void>();
    final finish = Completer<Iterable<String>>();
    final first = loader.load(
      canStart: () => true,
      fetch: () {
        started.complete();
        return finish.future;
      },
    );
    await started.future;
    var queuedAllowed = true;
    var queuedCalls = 0;
    final queued = loader.load(
      canStart: () => queuedAllowed,
      fetch: () async {
        queuedCalls++;
        return const ['https://site.test/queued.jpg'];
      },
    );
    queuedAllowed = false;
    finish.complete(['https://site.test/first.jpg']);
    expect(await first, ['https://site.test/first.jpg']);
    expect(await queued, isEmpty);
    expect(queuedCalls, 0);
  });

  test('discards a result when its owner is no longer valid', () async {
    final loader = TopicPreviewLoader();
    final finish = Completer<Iterable<String>>();
    var valid = true;
    final result = loader.load(
      canStart: () => valid,
      fetch: () => finish.future,
    );
    valid = false;
    finish.complete(['https://site.test/stale.jpg']);
    expect(await result, isEmpty);
  });

  test('exposes failures separately and releases the request slot', () async {
    final loader = TopicPreviewLoader(concurrency: 1);
    await expectLater(
      loader.load(
        canStart: () => true,
        fetch: () async => throw StateError('preview failed'),
      ),
      throwsStateError,
    );
    expect(
      await loader.load(
        canStart: () => true,
        fetch: () async => ['https://site.test/ok.jpg'],
      ),
      ['https://site.test/ok.jpg'],
    );
  });
}
