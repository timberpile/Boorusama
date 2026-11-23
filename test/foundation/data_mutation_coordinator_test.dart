import 'dart:async';

import 'package:boorusama/foundation/data_mutation_coordinator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('runs unrelated mutations one at a time in arrival order', () async {
    final coordinator = DataMutationCoordinator();
    final firstMayFinish = Completer<void>();
    final events = <String>[];

    final first = coordinator.runExclusive(() async {
      events.add('first started');
      await firstMayFinish.future;
      events.add('first finished');
    });
    final second = coordinator.runExclusive(() async {
      events.add('second started');
    });

    await Future<void>.delayed(Duration.zero);
    expect(events, ['first started']);
    firstMayFinish.complete();
    await Future.wait([first, second]);
    expect(events, ['first started', 'first finished', 'second started']);
  });

  test('allows nested mutations in the same transaction', () async {
    final coordinator = DataMutationCoordinator();
    final events = <String>[];

    await coordinator.runExclusive(() async {
      events.add('outer');
      await coordinator.runExclusive(() async => events.add('inner'));
    });

    expect(events, ['outer', 'inner']);
  });

  test(
    'expired transaction zones cannot bypass a later active mutation',
    () async {
      final coordinator = DataMutationCoordinator();
      late Zone expiredZone;
      await coordinator.runExclusive(() async {
        expiredZone = Zone.current;
      });

      final secondStarted = Completer<void>();
      final releaseSecond = Completer<void>();
      final second = coordinator.runExclusive(() async {
        secondStarted.complete();
        await releaseSecond.future;
      });
      await secondStarted.future;

      var thirdStarted = false;
      final third = expiredZone.run(
        () => coordinator.runExclusive(() async {
          thirdStarted = true;
        }),
      );

      try {
        expect(thirdStarted, isFalse);
      } finally {
        releaseSecond.complete();
      }
      await Future.wait([second, third]);
      expect(thirdStarted, isTrue);
    },
  );

  test(
    'failed transaction zones cannot bypass a later active mutation',
    () async {
      final coordinator = DataMutationCoordinator();
      late Zone expiredZone;
      await expectLater(
        coordinator.runExclusive<void>(() {
          expiredZone = Zone.current;
          return Future<void>.error(StateError('expected failure'));
        }),
        throwsA(isA<StateError>()),
      );

      final secondStarted = Completer<void>();
      final releaseSecond = Completer<void>();
      final second = coordinator.runExclusive(() async {
        secondStarted.complete();
        await releaseSecond.future;
      });
      await secondStarted.future;

      var thirdStarted = false;
      final third = expiredZone.run(
        () => coordinator.runExclusive(() async {
          thirdStarted = true;
        }),
      );

      try {
        expect(thirdStarted, isFalse);
      } finally {
        releaseSecond.complete();
      }
      await Future.wait([second, third]);
      expect(thirdStarted, isTrue);
    },
  );
}
