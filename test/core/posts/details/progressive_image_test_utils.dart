import 'dart:async';
import 'dart:io';
import 'package:cache_manager/cache_manager.dart';
import 'package:dio/dio.dart';
import 'package:extended_image/src/image/raw_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurumi/kurumi.dart';

final lowerPng = File('test/fixtures/post_quality/lower.png').readAsBytesSync();
final targetPng = File(
  'test/fixtures/post_quality/target.png',
).readAsBytesSync();
final originalPng = File(
  'test/fixtures/post_quality/original.png',
).readAsBytesSync();
final comicPng = File('test/fixtures/post_quality/comic.png').readAsBytesSync();
final portraitPng = File(
  'test/fixtures/post_quality/portrait.png',
).readAsBytesSync();

Widget testApp(Widget child) => MaterialApp(
  builder: (context, child) => KurumiTheme(
    data: KurumiThemeData.fromMaterial(Theme.of(context)),
    child: child!,
  ),
  home: Scaffold(
    body: Center(child: SizedBox(width: 300, height: 300, child: child)),
  ),
);
Future<void> decodePump(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 80)),
  );
  await tester.pump(const Duration(milliseconds: 600));
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 80)),
  );
  await tester.pump();
}

Future<List<int>> paintedPixel(WidgetTester tester) async {
  final image = tester
      .widgetList<ExtendedRawImage>(find.byType(ExtendedRawImage))
      .map((widget) => widget.image)
      .nonNulls
      .first;
  final bytes = await tester.runAsync(
    () => image.toByteData(),
  );
  return bytes!.buffer.asUint8List().take(4).toList();
}

class ControlledImageAdapter implements HttpClientAdapter {
  final pending = <String, Completer<ResponseBody>>{};
  final requests = <RequestOptions>[];
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    requests.add(options);
    return (pending[options.uri.toString()] ??= Completer<ResponseBody>())
        .future;
  }

  void complete(String url, Uint8List bytes, {int status = 200}) =>
      pending[url]!.complete(
        ResponseBody.fromBytes(
          bytes,
          status,
          headers: {
            Headers.contentTypeHeader: ['image/png'],
          },
        ),
      );
  @override
  void close({bool force = false}) {}
}

class TestImageCache implements ImageCacheManager {
  TestImageCache(this.bytes);
  final Map<String, Uint8List> bytes;
  @override
  String generateCacheKey(String url, {String? customKey}) => url;
  @override
  FutureOr<Uint8List?> getCachedFileBytes(String key, {Duration? maxAge}) =>
      bytes[key];
  @override
  Future<void> saveFile(String key, Uint8List data) async {
    bytes[key] = data;
  }

  @override
  FutureOr<String?> getCachedFilePath(String key, {Duration? maxAge}) => null;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// These helpers run inside tester.runAsync: wait for real I/O and decoding,
// rather than assuming a fixed number of wall-clock delays is sufficient.
Future<void> pumpUntil(
  WidgetTester tester,
  FutureOr<bool> Function() ready, {
  required String reason,
}) async {
  final elapsed = Stopwatch()..start();
  while (!await ready()) {
    if (elapsed.elapsed > const Duration(seconds: 10)) {
      fail('Timed out waiting for $reason');
    }
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await tester.pump(const Duration(milliseconds: 20));
  }
}

Future<void> waitForPixel(WidgetTester tester, List<int> expected) => pumpUntil(
  tester,
  () async {
    final images = tester
        .widgetList<ExtendedRawImage>(find.byType(ExtendedRawImage))
        .map((widget) => widget.image)
        .nonNulls;
    if (images.isEmpty) return false;
    final data = await images.first.toByteData();
    return data != null &&
        listEquals(data.buffer.asUint8List().take(4).toList(), expected);
  },
  reason: 'painted pixel $expected',
);

/// Unmounting cancels transport, but its asynchronous abort and cache usage
/// bookkeeping can still be running. Drain them before deleting fixture files.
class DrainingImageCacheManager extends DefaultImageCacheManager {
  DrainingImageCacheManager({super.maxBytes, super.cacheRootPathProvider});

  final _pending = <Future<void>>{};

  Future<T> _track<T>(Future<T> operation) async {
    final done = Completer<void>();
    _pending.add(done.future);
    try {
      return await operation;
    } finally {
      _pending.remove(done.future);
      done.complete();
    }
  }

  @override
  Future<void> touch(String key) => _track(super.touch(key));

  @override
  Future<Uint8List?> getCachedFileBytes(String key, {Duration? maxAge}) =>
      _track(super.getCachedFileBytes(key, maxAge: maxAge));

  @override
  Future<ImageCacheWriteSession> beginFileWrite(String key) async {
    final done = Completer<void>();
    _pending.add(done.future);
    void finish() {
      if (done.isCompleted) return;
      _pending.remove(done.future);
      done.complete();
    }

    try {
      return _DrainingWriteSession(
        await super.beginFileWrite(key),
        finish,
        _track<void>,
      );
    } on Object {
      finish();
      rethrow;
    }
  }

  Future<void> drain() async {
    do {
      await Future.wait(_pending.toList()).timeout(const Duration(seconds: 10));
      // Let the provider continuation enqueue its final abort/bookkeeping.
      await Future<void>.delayed(Duration.zero);
    } while (_pending.isNotEmpty);
  }
}

class _DrainingWriteSession implements ImageCacheWriteSession {
  _DrainingWriteSession(this.inner, this.finish, this.track);
  final ImageCacheWriteSession inner;
  final void Function() finish;
  final Future<void> Function(Future<void>) track;

  @override
  String get stagedPath => inner.stagedPath;
  @override
  Future<void> saveBytes(Uint8List bytes) =>
      track(inner.saveBytes(bytes).whenComplete(finish));
  @override
  Future<ImageCacheFileLease> commit() => inner.commit();
  @override
  Future<void> abort() => track(inner.abort().whenComplete(finish));
}
