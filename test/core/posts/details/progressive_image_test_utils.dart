import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:cache_manager/cache_manager.dart';
import 'package:dio/dio.dart';
import 'package:extended_image/src/image/raw_image.dart';
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
