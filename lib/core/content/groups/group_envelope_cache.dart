import 'dart:async';

import 'package:dio/dio.dart';

import '../../errors/types.dart';
import '../../http/client/coordination.dart';
import '../content_access.dart';
import '../content_reference.dart';

/// Optional source-owned sharing for an API that already returns Details and
/// members together. The cache belongs to one access scope and contains no
/// member-order policy or independent HTTP client/retry implementation.
final class GroupEnvelopeCache<T> {
  GroupEnvelopeCache({required this.access, this.maxEntries = 16}) {
    if (maxEntries < 1) throw ArgumentError.value(maxEntries, 'maxEntries');
  }
  final ContentAccessKey access;
  final int maxEntries;
  final _entries = <ContentReference, _Envelope<T>>{};
  var _disposed = false;

  /// Admit a real envelope already fetched by the same source route. This does
  /// not replace pending work or grant access to an imported metadata snapshot.
  bool seed(ContentReference reference, T value) {
    if (_disposed) return false;
    if (reference.kind != ContentKind.group ||
        reference.engine != access.engine ||
        reference.siteNamespace != access.siteNamespace) {
      throw const FormatException('Foreign Group envelope');
    }
    final existing = _entries[reference];
    if (existing != null) return false;
    while (_entries.length >= maxEntries) {
      final completed = _entries.entries
          .where((entry) => entry.value.done)
          .firstOrNull;
      if (completed == null) return false;
      _entries.remove(completed.key);
    }
    final entry = _Envelope<T>()..done = true;
    entry.result.complete(value);
    unawaited(entry.changes.close());
    _entries[reference] = entry;
    return true;
  }

  Future<T> load(ContentReference reference, Future<T> Function() loader) {
    if (_disposed) return Future.error(RequestCancelledError());
    if (reference.kind != ContentKind.group ||
        reference.engine != access.engine ||
        reference.siteNamespace != access.siteNamespace) {
      return Future.error(const FormatException('Foreign Group envelope'));
    }
    var entry = _entries.remove(reference);
    final created = entry == null;
    if (entry == null) {
      while (_entries.length >= maxEntries) {
        final completed = _entries.entries
            .where((value) => value.value.done)
            .firstOrNull;
        if (completed == null) {
          return Future.error(
            const ApiRequestDeferredException(ApiWaitReason.concurrency),
          );
        }
        _entries.remove(completed.key);
      }
      entry = _Envelope<T>();
    }
    _entries[reference] = entry;
    // Attach ownership before invoking a loader which may synchronously ask
    // the existing HTTP coordinator whether it is allowed to start.
    final observer = _observe(reference, entry, ApiRequestContext.current());
    if (created) _start(reference, entry, loader);
    return observer;
  }

  Future<T> _observe(
    ContentReference reference,
    _Envelope<T> entry,
    ApiRequestContext caller,
  ) async {
    final owner = Object();
    entry.owners[owner] = caller;
    entry.notify();
    final policy = caller.changes?.listen((_) => entry.notify());
    void detach() {
      if (entry.owners.remove(owner) == null) return;
      entry.notify();
      if (!entry.done && !entry.owners.values.any(_isLive)) {
        _abort(reference, entry);
      }
    }

    final cancellation = caller.cancelToken;
    if (cancellation != null) {
      unawaited(cancellation.whenCancel.then((_) => detach()));
      if (cancellation.isCancelled) detach();
    }
    try {
      final value = await Future.any<T>([
        entry.result.future,
        entry.cancel.whenCancel.then<T>((_) => throw RequestCancelledError()),
        if (cancellation != null)
          cancellation.whenCancel.then<T>((_) => throw RequestCancelledError()),
      ]);
      if (_disposed ||
          entry.invalidated ||
          (cancellation?.isCancelled ?? false) ||
          !(caller.canStart?.call() ?? true)) {
        throw RequestCancelledError();
      }
      return value;
    } finally {
      await policy?.cancel();
      detach();
    }
  }

  void _start(
    ContentReference reference,
    _Envelope<T> entry,
    Future<T> Function() loader,
  ) {
    final context = ApiRequestContext(
      requestClassResolver: () => entry.owners.values
          .where(_isLive)
          .map((value) => value.requestClass)
          .fold(ApiRequestClass.preload, (a, b) => a.index < b.index ? a : b),
      replaySafety: ApiReplaySafety.safeRead,
      onStarted: () {
        final callbacks = entry.owners.values
            .where(_isLive)
            .map((owner) => owner.onStarted)
            .whereType<void Function()>()
            .toSet();
        for (final callback in callbacks) {
          callback();
        }
      },
      cancelToken: entry.cancel,
      changes: entry.changes.stream,
      canStart: () =>
          !_disposed && !entry.invalidated && entry.owners.values.any(_isLive),
      canAdmit: () =>
          !_disposed &&
          !entry.invalidated &&
          entry.owners.values.any(
            (owner) => _isLive(owner) && (owner.canAdmit?.call() ?? true),
          ),
      allowCooldownRetryResolver: () => entry.owners.values
          .where(_isLive)
          .any((owner) => owner.allowCooldownRetry),
    );
    final request = entry.invalidated
        ? Future<T>.error(RequestCancelledError())
        : runWithApiRequestContext(context, () => Future<T>.sync(loader));
    unawaited(
      request.then<void>(
        (value) {
          if (entry.invalidated || _disposed) {
            entry.result.completeError(
              RequestCancelledError(),
              StackTrace.current,
            );
          } else {
            entry.result.complete(value);
          }
          entry.done = true;
          unawaited(entry.changes.close());
        },
        onError: (Object error, StackTrace stack) {
          entry.done = true;
          if (identical(_entries[reference], entry)) _entries.remove(reference);
          entry.result.completeError(
            entry.invalidated || _disposed ? RequestCancelledError() : error,
            stack,
          );
          unawaited(entry.changes.close());
        },
      ),
    );
  }

  void _abort(ContentReference reference, _Envelope<T> entry) {
    entry.invalidated = true;
    if (identical(_entries[reference], entry)) _entries.remove(reference);
    if (!entry.cancel.isCancelled) {
      entry.cancel.cancel('Group envelope has no live scope');
    }
  }

  void invalidate(ContentReference reference) {
    final entry = _entries[reference];
    if (entry != null) _abort(reference, entry);
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    for (final reference in _entries.keys.toList()) {
      _abort(reference, _entries[reference]!);
    }
  }

  static bool _isLive(ApiRequestContext context) =>
      !(context.cancelToken?.isCancelled ?? false) &&
      (context.canStart?.call() ?? true);
}

final class _Envelope<T> {
  final result = Completer<T>();
  final cancel = CancelToken();
  final changes = StreamController<void>.broadcast(sync: true);
  final owners = <Object, ApiRequestContext>{};
  var done = false;
  var invalidated = false;
  void notify() {
    if (!changes.isClosed) changes.add(null);
  }
}
