import 'package:booru_clients/src/gelbooru_v2/parsers/rb_parsers.dart';
import 'package:dio/dio.dart';
import 'package:test/test.dart';

void main() {
  for (final day in ['Feb, 12 2020', 'May, 21 2020', 'Aug, 21 2020']) {
    test('an own Posted label preserves its calendar upload day: $day', () {
      final post = parseRbPostHtml(
        Response<String>(
          requestOptions: RequestOptions(),
          data:
              '<input name="id" value="1"><img id="image" src="https://realbooru.test/sample.jpg">'
              '<a href="?page=account&amp;s=profile&amp;id=999">unrelated_user</a>'
              '<div id="tagLink">Posted at $day by <a href="?page=account&amp;s=profile&amp;id=42">source_uploader</a></div>',
        ),
        {'baseUrl': 'https://realbooru.test'},
      );
      expect(post, isNotNull);
      expect(post!.owner, 'source_uploader');
      final date = DateTime.parse(post.createdAt!);
      expect(date.isUtc, isTrue);
      expect(date.year, 2020);
      expect(
        date.month,
        day.startsWith('Feb')
            ? 2
            : day.startsWith('May')
            ? 5
            : 8,
      );
      expect(date.day, day.startsWith('Feb') ? 12 : 21);
    });
  }
  test(
    'unrelated dates and invalid days do not establish upload dates or uploaders',
    () {
      final post = parseRbPostHtml(
        Response<String>(
          requestOptions: RequestOptions(),
          data:
              '<input name="id" value="1"><img id="image" src="https://realbooru.test/sample.jpg">'
              '<p>Posted at Aug, 21 2020 by unrelated</p>'
              '<a href="?page=account&amp;s=profile&amp;id=999">unrelated_user</a>'
              '<div id="tagLink">Posted at Feb, 30 2020 by unknown</div>',
        ),
        {'baseUrl': 'https://realbooru.test'},
      );
      expect(post!.createdAt, isNull);
      expect(post.owner, isNull);
    },
  );
}
