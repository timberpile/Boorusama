import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:boorusama/core/bookmarks/src/server_favorites/projection_queue.dart';

void main() {
  test('a slow add cannot overtake an acknowledged removal', () async {
    final queue = ServerFavoriteProjectionQueue<String>();
    final started = Completer<void>();
    final snapshot = Completer<void>();
    final values = <bool>[];
    final add = queue.run('site/post/group', () async {
      started.complete();
      await snapshot.future;
      values.add(true);
    });
    await started.future;
    final remove = queue.run('site/post/group', () async => values.add(false));
    expect(values, isEmpty);
    snapshot.complete();
    await Future.wait([add, remove]);
    expect(values, [true, false]);
  });

  test(
    'a failed earlier projection does not block later acknowledgements',
    () async {
      final queue = ServerFavoriteProjectionQueue<String>();
      final gate = Completer<void>();
      final first = queue.run('post', () async {
        await gate.future;
        throw StateError('stale account');
      });
      final failure = expectLater(first, throwsStateError);
      var applied = false;
      final second = queue.run('post', () async => applied = true);
      gate.complete();
      await failure;
      await second;
      expect(applied, isTrue);
    },
  );

  test(
    'an invalid later action does not suppress a valid earlier action',
    () async {
      final queue = ServerFavoriteProjectionQueue<String>();
      final gate = Completer<void>();
      var applied = false;
      final first = queue.run('post', () async {
        await gate.future;
        applied = true;
      });
      final second = queue.run(
        'post',
        () async => throw StateError('old account'),
      );
      final failure = expectLater(second, throwsStateError);
      gate.complete();
      await first;
      await failure;
      expect(applied, isTrue);
    },
  );

  test('unrelated posts and target groups do not block each other', () async {
    final queue = ServerFavoriteProjectionQueue<String>();
    final gate = Completer<void>();
    final first = queue.run('site/post/group-a', () => gate.future);
    var independent = false;
    await queue.run('site/post/group-b', () async => independent = true);
    expect(independent, isTrue);
    gate.complete();
    await first;
  });
}
