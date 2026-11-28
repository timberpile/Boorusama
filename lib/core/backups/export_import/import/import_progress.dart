import 'dart:async';
import 'dart:isolate';

enum ImportProgressPhase {
  opening,
  extracting,
  verifying,
  reading,
  decoding,
  preparing,
  checkpoint,
  verifyingCheckpoint,
  saving,
  removing,
  memberships,
  writingGroup,
  committing,
  loadingLibrary,
  preparingLibrary,
  indexingLibrary,
  publishingLibrary,
  restoring,
}

typedef ImportProgressValue = ({
  ImportProgressPhase phase,
  int completed,
  int? total,
});

/// A progress session is scoped to one import or review request.
final class ImportProgress {
  ImportProgress(
    this._publish, {
    Duration Function()? elapsed,
    bool Function()? cancelled,
  }) : _elapsed = elapsed ?? (Stopwatch()..start()).elapsedTime,
       _cancelled = cancelled;

  static final _key = Object();
  static const _interval = Duration(milliseconds: 100);
  static ImportProgress? get current => Zone.current[_key] as ImportProgress?;

  final void Function(ImportProgressValue) _publish;
  final Duration Function() _elapsed;
  final bool Function()? _cancelled;
  ImportProgressValue? _last;
  Duration _publishedAt = Duration.zero;

  Future<T> run<T>(Future<T> Function() operation) =>
      runZoned(operation, zoneValues: {_key: this});

  bool get cancelled => _cancelled?.call() ?? false;

  void show(ImportProgressPhase phase, {int completed = 0, int? total}) {
    if (cancelled) return;
    final sample = (
      phase: phase,
      completed: total == null ? 0 : completed.clamp(0, total),
      total: total,
    );
    if (sample == _last) return;

    final now = _elapsed();
    if (_last?.phase == phase &&
        _last?.total == total &&
        sample.completed != total &&
        now - _publishedAt < _interval) {
      return;
    }
    _last = sample;
    _publishedAt = now;
    _publish(sample);
  }

  void _receive(ImportProgressValue value) =>
      show(value.phase, completed: value.completed, total: value.total);
}

extension on Stopwatch {
  Duration elapsedTime() => elapsed;
}

/// Workers own their file/SQLite handles. Only small progress messages cross
/// the boundary during the operation, followed by the result or original error.
Future<T> runImportWorker<T>(Future<T> Function() operation) async {
  final progress = ImportProgress.current;
  if (progress == null) return Isolate.run(operation);

  final port = ReceivePort();
  final drained = Completer<void>();
  Timer? cancellation;
  final subscription = port.listen((message) {
    if (message == null) {
      drained.complete();
    } else if (message is SendPort && progress._cancelled != null) {
      void check() {
        if (progress.cancelled) {
          message.send(true);
          cancellation?.cancel();
        }
      }

      cancellation = Timer.periodic(
        const Duration(milliseconds: 100),
        (_) => check(),
      );
      check();
    } else if (message is ImportProgressValue) {
      progress._receive(message);
    }
  });
  final task = _ImportWorkerTask(operation, port.sendPort);
  try {
    final result = await Isolate.run(task.run);
    await drained.future;
    return result;
  } finally {
    cancellation?.cancel();
    await subscription.cancel();
    port.close();
  }
}

final class _ImportWorkerTask<T> {
  const _ImportWorkerTask(this.operation, this.messages);

  final Future<T> Function() operation;
  final SendPort messages;

  Future<T> run() async {
    final cancel = ReceivePort();
    var cancelled = false;
    final subscription = cancel.listen((_) => cancelled = true);
    messages.send(cancel.sendPort);
    try {
      return await ImportProgress(
        messages.send,
        cancelled: () => cancelled,
      ).run(operation);
    } finally {
      await subscription.cancel();
      cancel.close();
      messages.send(null);
    }
  }
}
