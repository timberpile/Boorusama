import 'dart:typed_data';
import 'package:booru_clients/gelbooru.dart';
import 'package:booru_clients/hybooru.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Gelbooru comments and notes use the injected data transport', () async {
    final a = _HtmlAdapter();
    final dio = Dio(
      BaseOptions(
        baseUrl: 'http://127.0.0.1:1',
        connectTimeout: const Duration(milliseconds: 100),
      ),
    )..httpClientAdapter = a;
    final client = GelbooruClient(dio: dio);
    try {
      await client
          .getCommentsFromPostId(postId: 1)
          .timeout(const Duration(milliseconds: 200));
    } catch (_) {}
    try {
      await client
          .getNotesFromPostId(postId: 1)
          .timeout(const Duration(milliseconds: 200));
    } catch (_) {}
    expect(a.paths, ['/index.php', '/index.php']);
  });
  test('Hybooru tags use the injected data transport', () async {
    final a = _HtmlAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'http://127.0.0.1:1'))
      ..httpClientAdapter = a;
    try {
      await HybooruClient(
        dio: dio,
        baseUrl: 'http://127.0.0.1:1',
      ).getTagsFromPostId(postId: 1).timeout(const Duration(milliseconds: 200));
    } catch (_) {}
    expect(a.paths, ['/posts/1']);
  });
}

final class _HtmlAdapter implements HttpClientAdapter {
  final paths = <String>[];
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    paths.add(options.uri.path);
    return ResponseBody.fromString(
      '<html></html>',
      200,
      headers: {
        'content-type': ['text/html'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
