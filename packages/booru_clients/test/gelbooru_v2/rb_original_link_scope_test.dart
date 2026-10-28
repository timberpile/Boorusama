import 'package:booru_clients/src/gelbooru_v2/parsers/rb_parsers.dart';
import 'package:dio/dio.dart';
import 'package:test/test.dart';

void main() {
  const sample = '/samples/ab/cd/sample_0123456789abcdef0123456789abcdef.jpg';
  const original = '/images/ab/cd/0123456789abcdef0123456789abcdef.png';

  test('unrelated Original labels cannot replace or invalidate post media', () {
    for (final control in ['', '<a id="highres" href="$original">Original</a>']) {
      final post = parseRbPostHtml(
        Response<String>(
          requestOptions: RequestOptions(path: '/index.php'),
          data: '''
            <input name="id" value="42">
            <img id="image" src="$sample">
            $control
            <div id="comments"><a href="https://other.test/file.png">Original</a></div>
          ''',
        ),
        const {'baseUrl': 'https://realbooru.test/'},
      );
      expect(post, isNotNull);
      expect(post!.fileUrl, control.isEmpty ? '' : 'https://realbooru.test$original');
      expect(post.sampleUrl, 'https://realbooru.test$sample');
    }
  });

  for (final container in ['post-info', 'stats', 'tagLink']) {
    test('a labeled original control in $container remains supported', () {
      final post = parseRbPostHtml(
        Response<String>(
          requestOptions: RequestOptions(path: '/index.php'),
          data: '''
            <input name="id" value="42">
            <img id="image" src="$sample">
            <div id="$container"><a href="$original">Download original</a></div>
          ''',
        ),
        const {'baseUrl': 'https://realbooru.test/'},
      );
      expect(post?.fileUrl, 'https://realbooru.test$original');
    });
  }
}
