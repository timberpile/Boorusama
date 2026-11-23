import 'dart:io';
import 'package:booru_clients/src/gelbooru_v2/parsers/common.dart';
import 'package:dio/dio.dart';
import 'package:test/test.dart';

void main() {
  final populated = File(
    'test/gelbooru_v2/fixtures/realbooru_favorites/populated.html',
  ).readAsStringSync();
  final terminal = File(
    'test/gelbooru_v2/fixtures/realbooru_favorites/terminal.html',
  ).readAsStringSync();
  dynamic read(String html, {String account = '1', int status = 200}) =>
      parseDefaultFavoritePostsHtml(
        Response<String>(
          data: html,
          statusCode: status,
          requestOptions: RequestOptions(
            path: 'https://realbooru.com/index.php',
            queryParameters: {
              'page': 'favorites',
              's': 'view',
              'id': account,
              'pid': '0',
            },
          ),
        ),
        {'strictRealbooruFavorites': true, 'user-id': '1'},
      );
  test('deployed populated and terminal listing retain genuine facts only', () {
    final rows = read(populated).posts;
    expect(rows.single.id, 646949);
    expect(rows.single.previewUrl, contains('/thumbnails/'));
    expect(rows.single.fileUrl, isNull);
    expect(rows.single.sampleUrl, isNull);
    expect(read(terminal).posts, isEmpty);
  });
  test('challenge, wrong account, malformed row and non-200 are failures', () {
    for (final page in [
      '<html>challenge</html>',
      populated.replaceAll('id=646949', 'id=invalid'),
      populated.replaceAll(RegExp(r'''id=["']paginator["']'''), 'id="other"'),
    ]) {
      expect(() => read(page), throwsFormatException);
    }
    expect(() => read(populated, account: '2'), throwsFormatException);
    expect(() => read(populated, status: 403), throwsFormatException);
  });
  test(
    'missing optional script fields keeps the locator without media aliases',
    () {
      final rows = read(
        populated.replaceAll(
          RegExp(r'posts\[646949\]\s*=.*?;', dotAll: true),
          '',
        ),
      ).posts;
      expect(rows.single.id, 646949);
      expect(rows.single.fileUrl, isNull);
    },
  );
}
