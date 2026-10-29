import 'dart:convert';

import 'package:booru_clients/pixiv.dart';
import 'package:dio/dio.dart';
import 'package:test/test.dart';

void main() {
  String next({String host = 'app-api.pixiv.net', String user = '7',
    String restrict = 'public', String cursor = '900'}) =>
      'https://$host/v1/user/bookmarks/illust?user_id=$user&restrict=$restrict&max_bookmark_id=$cursor';

  test('reads a cursor without fetching the supplied URL', () async {
    final requests = <RequestOptions>[];
    final dio = Dio(BaseOptions(baseUrl: kPixivApiBaseUrl));
    dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      requests.add(options);
      handler.resolve(Response(
        requestOptions: options,
        data: {'illusts': [{'id': 100}], 'next_url':
          requests.length == 1 ? next() : null},
      ));
    }));
    final client = PixivClient(accessToken: 'fixture-not-a-real-token', dio: dio);
    final first = await client.getUserBookmarks(userId: 7);
    await client.getUserBookmarks(userId: 7, maxBookmarkId: first.nextBookmarkId);
    expect(first.illusts.single.id, 100);
    expect(first.hasMore, isTrue);
    expect(requests, hasLength(2));
    expect(requests.map((r) => r.path).toSet(), {'/v1/user/bookmarks/illust'});
    expect(requests.first.queryParameters.containsKey('max_bookmark_id'), isFalse);
    expect(requests.last.queryParameters['max_bookmark_id'], '900');
    expect(requests.last.queryParameters.containsKey('offset'), isFalse);
    expect(requests.last.followRedirects, isFalse);
    expect(requests.last.headers['Authorization'], 'Bearer fixture-not-a-real-token');
    expect(dio.options.headers.containsKey('Authorization'), isFalse);
  });

  for (final visibility in PixivBookmarkVisibility.values) {
    test('keeps ${visibility.name} scope in requests', () async {
      final dio = Dio(BaseOptions(baseUrl: kPixivApiBaseUrl));
      dio.interceptors.add(InterceptorsWrapper(onRequest: (r, handler) {
        expect(r.queryParameters['restrict'], visibility.name);
        expect(r.queryParameters['user_id'], 7);
        handler.resolve(Response(requestOptions: r, data: {'illusts': []}));
      }));
      final page = await PixivClient(accessToken: 'fixture', dio: dio)
          .getUserBookmarks(userId: 7, visibility: visibility);
      expect(page.hasMore, isFalse);
    });
  }

  for (final url in [
    next(host: 'example.invalid'),
    next(user: '8'),
    next(restrict: 'private'),
    next(cursor: '900') + '&max_bookmark_id=800',
    next(cursor: 'not-an-id'),
    next().replaceFirst('https:', 'http:'),
    next().replaceFirst('/v1/user/bookmarks/illust', '/v1/user/following'),
    next() + '#fragment',
    '',
  ]) {
    test('rejects malformed or foreign continuation ${jsonEncode(url)}', () {
      expect(() => PixivBookmarkPage.fromJson(
        {'illusts': [], 'next_url': url}, userId: 7,
        visibility: PixivBookmarkVisibility.public,
      ), throwsFormatException);
    });
  }

  test('rejects non-list payload rather than reporting an empty account', () {
    expect(() => PixivBookmarkPage.fromJson({}, userId: 7,
        visibility: PixivBookmarkVisibility.public), throwsFormatException);
  });

  test('filtered empty source page can still advertise continuation', () {
    final page = PixivBookmarkPage.fromJson(
      {'illusts': [], 'next_url': next()}, userId: 7,
      visibility: PixivBookmarkVisibility.public,
    );
    expect(page.illusts, isEmpty);
    expect(page.nextBookmarkId, '900');
  });

  test('rejects a cursor that fails to advance', () {
    expect(() => PixivBookmarkPage.fromJson(
      {'illusts': [], 'next_url': next()}, userId: 7,
      visibility: PixivBookmarkVisibility.public, previousBookmarkId: '900',
    ), throwsFormatException);
  });
}
