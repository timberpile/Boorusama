import 'package:booru_clients/src/gelbooru_v2/parsers/rb_parsers.dart';
import 'package:dio/dio.dart';
import 'package:test/test.dart';

void main() {
  for (final title in ['scenery, gif', 'scenery GIF score:5', 'gif']) {
    test(
      'a GIF title preserves its static preview and identifies the original: $title',
      () {
        final post = parseRbPostsHtml(
          Response<String>(
            requestOptions: RequestOptions(path: '/index.php'),
            data:
                '<span class="thumb"><a id="p1013633"><img '
                'src="https://realbooru.test/thumbnails/1d/d7/thumbnail_1dd78422eb9d083e25b4025889dfc848.jpg?v=1" '
                'title="$title"></a></span>',
          ),
          const {},
        ).posts.single;
        expect(
          post.fileUrl,
          'https://realbooru.test/images/1d/d7/1dd78422eb9d083e25b4025889dfc848.gif?v=1',
        );
        expect(post.previewUrl, contains('/thumbnails/'));
        expect(post.sampleUrl, post.previewUrl);
        expect(post.isVideoPreview, isFalse);
      },
    );
  }

  for (final title in [
    'gift',
    'gif_like',
    'scenery, gif animation',
    'animated',
    '',
  ]) {
    test('only the exact GIF marker identifies a GIF: $title', () {
      final post = parseRbPostsHtml(
        Response<String>(
          requestOptions: RequestOptions(path: '/index.php'),
          data:
              '<span class="thumb"><a id="p123"><img '
              'src="https://realbooru.test/thumbnails/ab/cd/thumbnail_image.jpg" '
              'title="$title"></a></span>',
        ),
        const {},
      ).posts.single;
      expect(post.fileUrl, post.previewUrl);
      expect(post.isVideoPreview, isFalse);
    });
  }

  for (final title in ['gif', 'gif, video']) {
    test('the blue video marker takes priority over a GIF tag: $title', () {
      final post = parseRbPostsHtml(
        Response<String>(
          requestOptions: RequestOptions(path: '/index.php'),
          data:
              '<span class="thumb"><a id="p123"><img '
              'src="https://realbooru.test/thumbnails/ab/cd/thumbnail_image.jpg" '
              'style="border: 3px solid #0000ff;" title="$title"></a></span>',
        ),
        const {},
      ).posts.single;
      expect(post.isVideoPreview, isTrue);
      expect(post.fileUrl, endsWith('.jpg'));
    });
  }
}
