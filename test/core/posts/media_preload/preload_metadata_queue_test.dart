import 'dart:async';

import 'package:boorusama/core/posts/media_preload/src/preload_metadata_queue.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('only one request runs and a newer window replaces queued work', () async {
    final calls = <int>[];
    final first = Completer<String?>();
    final latest = Completer<String?>();
    final latestStarted = Completer<void>();
    var notifications = 0;
    final queue = PreloadMetadataQueue<int, String>(onResolved: () => notifications++);
    addTearDown(queue.dispose);
    final drained = queue.replace([
      (key: 1, load: () { calls.add(1); return first.future; }),
      (key: 2, load: () async { calls.add(2); return 'old'; }),
    ]);
    expect(calls, [1]);
    unawaited(queue.replace([
      (key: 3, load: () {
        calls.add(3);
        latestStarted.complete();
        return latest.future;
      }),
    ]));
    expect(calls, [1]);
    first.complete('obsolete');
    await latestStarted.future;
    expect(calls, [1, 3]);
    expect(queue.peek(1), isNull);
    latest.complete('current');
    await drained;
    expect(queue.peek(3), 'current');
    expect(notifications, 1);
  });

  test('successes and failures are reused only inside the current window', () async {
    var calls = 0;
    final queue = PreloadMetadataQueue<int, String>(onResolved: () {});
    addTearDown(queue.dispose);
    Future<String?> fail() async { calls++; throw StateError('unavailable'); }
    Future<String?> load() async { calls++; return 'ready'; }
    await queue.replace([(key: 1, load: fail), (key: 2, load: load)]);
    await queue.replace([(key: 1, load: fail), (key: 2, load: load)]);
    expect(calls, 2);
    expect(queue.peek(2), 'ready');
    await queue.replace([]);
    expect(queue.peek(2), isNull);
    await queue.replace([(key: 1, load: fail)]);
    expect(calls, 3);
  });

  test('cancelling never publishes an in-flight shared result', () async {
    final pending = Completer<String?>();
    var notified = false;
    final queue = PreloadMetadataQueue<int, String>(onResolved: () => notified = true);
    final drained = queue.replace([(key: 1, load: () => pending.future)]);
    queue.dispose();
    pending.complete('finished');
    await drained;
    expect(notified, isFalse);
    expect(queue.peek(1), isNull);
  });
}
