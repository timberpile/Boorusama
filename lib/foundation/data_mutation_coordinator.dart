import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

final dataMutationCoordinatorProvider = Provider<DataMutationCoordinator>(
  (ref) => DataMutationCoordinator(),
);

final class DataMutationCoordinator {
  static final _zoneKey = Object();

  Future<void> _tail = Future.value();

  Future<T> runExclusive<T>(Future<T> Function() operation) {
    if (identical(Zone.current[_zoneKey], this)) return operation();

    final completer = Completer<T>();
    _tail = _tail.catchError((_) {}).then((_) async {
      try {
        final result = await runZoned(
          operation,
          zoneValues: {_zoneKey: this},
        );
        completer.complete(result);
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }
}
