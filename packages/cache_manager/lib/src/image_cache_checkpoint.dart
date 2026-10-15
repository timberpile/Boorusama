import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

/// Only immutable scalar values cross the isolate boundary, not live entries.
typedef ImageCacheCheckpointEntry = ({
  String key,
  String filename,
  int size,
  int use,
});

typedef ImageCacheCheckpointSnapshot = ({
  String stagedPath,
  int revision,
  List<ImageCacheCheckpointEntry> entries,
});

/// Completes only after the staged file has been written, flushed and closed.
/// Publication and journal truncation remain the caller's responsibility.
typedef ImageCacheCheckpointWriter =
    Future<void> Function(
      ImageCacheCheckpointSnapshot snapshot,
    );

/// Infrastructure failures are retryable optional-metadata failures. Ordinary
/// programming errors are deliberately not translated into this exception.
class ImageCacheCheckpointWorkerException implements Exception {
  const ImageCacheCheckpointWorkerException(this.cause);

  final Object cause;

  @override
  String toString() => 'Image cache checkpoint worker unavailable';
}

Future<void> writeImageCacheCheckpointInBackground(
  ImageCacheCheckpointSnapshot snapshot,
) async {
  try {
    await _runCheckpointIsolate(snapshot);
  } on IsolateSpawnException catch (error, stack) {
    Error.throwWithStackTrace(
      ImageCacheCheckpointWorkerException(error),
      stack,
    );
  } on RemoteError catch (error, stack) {
    // An unhandled asynchronous isolate failure has no transferable typed error.
    Error.throwWithStackTrace(
      ImageCacheCheckpointWorkerException(error),
      stack,
    );
  }
}

// Keep this closure's scope separate from callers: it must capture no manager,
// provider, recorder, file handle or test callback along with the snapshot.
Future<void> _runCheckpointIsolate(ImageCacheCheckpointSnapshot snapshot) =>
    Isolate.run(
      () => _writeCheckpoint(snapshot),
      debugName: 'image-cache-checkpoint',
    );

Future<void> _writeCheckpoint(ImageCacheCheckpointSnapshot snapshot) async {
  final bytes = JsonUtf8Encoder().convert({
    'version': 1,
    'revision': snapshot.revision,
    'entries': [
      for (final entry in snapshot.entries)
        {
          'key': entry.key,
          'file': entry.filename,
          'size': entry.size,
          'use': entry.use,
        },
    ],
  });
  await File(snapshot.stagedPath).writeAsBytes(bytes, flush: true);
}
