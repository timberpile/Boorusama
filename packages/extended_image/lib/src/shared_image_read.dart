import 'dart:async';
import 'dart:typed_data';
import 'package:cache_manager/cache_manager.dart';
import 'package:dio/dio.dart';

/// Transport identity and scoped cache identity keep different actors apart.
/// Only pending reads are retained. Each observer owns its cancellation.
final class SharedImageRead {
  static final _clients =
      Expando<Map<(ImageCacheManager, String, String), _Read>>();
  static Future<Uint8List?> run({
    required Dio dio,
    required ImageCacheManager manager,
    required String key,
    required Map<String, String>? headers,
    required CancelToken? owner,
    required Future<Uint8List?> Function(CancelToken) load,
  }) async {
    final fields = headers?.entries.toList() ?? [];
    fields.sort((a, b) => a.key.compareTo(b.key));
    final signature = fields
        .map((e) => '${e.key.length}:${e.key}${e.value.length}:${e.value}')
        .join();
    final reads = _clients[dio] ??= {};
    final identity = (manager, key, signature);
    final existing = reads[identity];
    final read = existing ?? _Read();
    reads[identity] = read;
    final observer = Object();
    read.owners.add(observer);
    void detach() {
      read.owners.remove(observer);
      if (read.owners.isEmpty && !read.done) {
        if (identical(reads[identity], read)) reads.remove(identity);
        read.cancel.cancel('No image observers');
      }
    }

    if (owner != null) {
      unawaited(owner.whenCancel.then((_) => detach()));
      if (owner.isCancelled) detach();
    }
    final result = Future.any<Uint8List?>([
      read.result.future,
      if (owner != null)
        owner.whenCancel.then<Uint8List?>((error) => throw error),
    ]);
    if (existing == null) {
      unawaited(
        Future<Uint8List?>.sync(() => load(read.cancel)).then<void>(
          (bytes) {
            read.done = true;
            if (identical(reads[identity], read)) reads.remove(identity);
            read.result.complete(bytes);
          },
          onError: (Object error, StackTrace stack) {
            read.done = true;
            if (identical(reads[identity], read)) reads.remove(identity);
            read.result.completeError(error, stack);
          },
        ),
      );
    }
    try {
      return await result;
    } finally {
      detach();
    }
  }
}

class _Read {
  final result = Completer<Uint8List?>();
  final cancel = CancelToken();
  final owners = <Object>{};
  var done = false;
}
