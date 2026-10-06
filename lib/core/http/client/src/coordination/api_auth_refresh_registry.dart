import 'dart:async';
import 'package:dio/dio.dart';
import 'api_request_context.dart';

/// Account-level refresh ownership is independent of any single caller. Queued
/// exchanges need a live owner; dispatched credential rotation is allowed to
/// finish so that its replacement token can be persisted.
final class ApiAuthRefreshRegistry {
  final _inFlight = <Object, _RefreshOperation>{};
  final _credentialIdentities = <String, Object>{};

  /// A private app-lifetime fallback when an account ID is unavailable.
  /// The returned identity contains no printable credential or digest.
  Object opaqueCredentialIdentity(String credential) =>
      _credentialIdentities.putIfAbsent(credential, Object.new);

  Future<T> run<T>(Object account, Future<T> Function() refresh) async {
    final caller = ApiRequestContext.current();
    final owner = Object();
    var operation = _inFlight[account];
    if (operation == null ||
        (!operation.dispatched && operation.queuedCancellation.isCancelled)) {
      operation = _RefreshOperation();
      _inFlight[account] = operation;
      operation.owners[owner] = caller;
      final shared = operation;
      shared.result = runWithApiRequestContext(
        ApiRequestContext(
          requestClass: caller.requestClass,
          requestClassResolver: () => shared.priority,
          changes: shared.changes.stream,
          replaySafety: ApiReplaySafety.mutation,
          cancelToken: shared.queuedCancellation,
          canStart: () => shared.owners.values.any(_isLive),
          canAdmit: () => shared.owners.values.any(
            (owner) => _isLive(owner) && (owner.canAdmit?.call() ?? true),
          ),
          onStarted: () {
            shared.dispatched = true;
            for (final context in shared.owners.values.where(_isLive)) {
              context.onStarted?.call();
            }
          },
          allowCooldownRetry: false,
        ),
        () async {
          try {
            return _RefreshResult.success(await refresh());
          } catch (error, stack) {
            return _RefreshResult.failure(error, stack);
          } finally {
            if (identical(_inFlight[account], shared)) {
              _inFlight.remove(account);
            }
            unawaited(shared.changes.close());
          }
        },
      );
    } else {
      operation.owners[owner] = caller;
      operation.notify();
    }
    final shared = operation;
    final policySubscription = caller.changes?.listen((_) => shared.notify());
    void detach() {
      shared.owners.remove(owner);
      shared.notify();
      if (!shared.dispatched && !shared.owners.values.any(_isLive)) {
        shared.queuedCancellation.cancel('No live refresh owners');
      }
    }

    final cancellation = caller.cancelToken;
    if (cancellation != null) {
      unawaited(cancellation.whenCancel.then((_) => detach()));
      if (cancellation.isCancelled) detach();
    }
    try {
      final result = await Future.any([
        shared.result,
        if (cancellation != null)
          cancellation.whenCancel.then(
            (error) => _RefreshResult.failure(error, StackTrace.current),
          ),
      ]);
      if (result.error case final error?) {
        Error.throwWithStackTrace(error, result.stack!);
      }
      return result.value as T;
    } finally {
      await policySubscription?.cancel();
      detach();
    }
  }

  static bool _isLive(ApiRequestContext context) =>
      !(context.cancelToken?.isCancelled ?? false) &&
      (context.canStart?.call() ?? true);
}

final class _RefreshOperation {
  final owners = <Object, ApiRequestContext>{};
  final queuedCancellation = CancelToken();
  late Future<_RefreshResult> result;
  var dispatched = false;
  final changes = StreamController<void>.broadcast(sync: true);
  ApiRequestClass get priority => owners.values
      .where(ApiAuthRefreshRegistry._isLive)
      .map((owner) => owner.requestClass)
      .fold(ApiRequestClass.preload, (a, b) => a.index < b.index ? a : b);
  void notify() {
    if (!changes.isClosed) changes.add(null);
  }
}

final class _RefreshResult {
  const _RefreshResult.success(this.value) : error = null, stack = null;
  const _RefreshResult.failure(this.error, this.stack) : value = null;
  final Object? value;
  final Object? error;
  final StackTrace? stack;
}
