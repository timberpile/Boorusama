import 'dart:async';

import 'package:dio/dio.dart';

import '../../../../http/client/coordination.dart';

bool isFavoriteRequestInterruption(Object error) =>
    error is DioException &&
    (error.type == DioExceptionType.cancel ||
        error.error is ApiCooldownException ||
        error.error is ApiRequestDeferredException);

/// The favorite mutation completed; only its separate cleanup was interrupted.
final class FavoriteCompletedWithInterruption implements Exception {
  const FavoriteCompletedWithInterruption(this.interruption, this.stackTrace);

  final DioException interruption;
  final StackTrace stackTrace;

  @override
  String toString() => 'Favorite completed with interrupted cleanup';
}

final _completedInterruptionKey = Object();

/// A UI boundary receives cleanup feedback while confirmed-success callbacks
/// continue. Outside that boundary the original completion signal propagates.
bool reportCompletedFavoriteInterruption(
  FavoriteCompletedWithInterruption error,
) {
  final report =
      Zone.current[_completedInterruptionKey]
          as void Function(FavoriteCompletedWithInterruption)?;
  if (report == null) return false;
  report(error);
  return true;
}

Future<T> collectFavoriteInterruptions<T>(
  Future<T> Function() action,
  void Function(FavoriteCompletedWithInterruption) report,
) => runZoned(action, zoneValues: {_completedInterruptionKey: report});
