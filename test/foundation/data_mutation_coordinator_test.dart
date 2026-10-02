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
}
