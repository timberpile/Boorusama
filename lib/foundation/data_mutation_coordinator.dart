import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

final dataMutationCoordinatorProvider = Provider<DataMutationCoordinator>(
  (ref) => DataMutationCoordinator(),
);

final class DataMutationCoordinator {
  static final _zoneKey = Object();

  Future<void> _tail = Future.value();

  Future<T> runExclusive<T>(Future<T> Function() operation) {
    final owner = Zone.current[_zoneKey];
    if (owner is _MutationScope &&
        owner.active &&
        identical(owner.coordinator, this)) {
      return operation();
    }

    final completer = Completer<T>();
    _tail = _tail.catchError((_) {}).then((_) async {
      final scope = _MutationScope(this);
      try {
        final result = await runZoned(
          operation,
          zoneValues: {_zoneKey: scope},
        );
        completer.complete(result);
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      } finally {
        // Deferred callbacks inherit their registering zone, but they no
        // longer own this transaction after its awaited operation finishes.
        scope.active = false;
      }
    });
    return completer.future;
  }
}

final class _MutationScope {
  _MutationScope(this.coordinator);
  final DataMutationCoordinator coordinator;
  var active = true;
}
