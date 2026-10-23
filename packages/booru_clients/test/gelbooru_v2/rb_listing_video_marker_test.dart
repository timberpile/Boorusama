import 'package:booru_clients/src/gelbooru_v2/parsers/rb_parsers.dart';
import 'package:booru_clients/src/gelbooru_v2/post_v2_dto.dart';
import 'package:dio/dio.dart';
import 'package:test/test.dart';

void main() {
  for (final style in [
    'border: 3px solid #0000ff;',
    'BORDER : 3px SOLID #0000FF ;',
    'border: 2px solid blue',
    'border: #00f solid 3px !important;',
    'border: 3px solid rgb(0, 0, 255);',
    'display: block; border: 3px solid #0000ff; margin: 0;',
  ]) {
    test('blue video border works without a video title tag: $style', () {
      final post = _parse(style: style, title: 'sound, webm');
      expect(post.isVideoPreview, isTrue);
      expect(post.previewUrl, contains('/thumbnails/'));
      expect(post.fileUrl, contains('/images/'));
      expect(post.fileUrl, endsWith('.jpg'));
    });
  }

  for (final style in <String?>[
    null,
    '',
    'border: 3px solid #ff0000;',
    'background: #0000ff; color: blue;',
    'outline: 3px solid #0000ff;',
    'border-color: #0000ff;',
    'border: 0px solid #0000ff;',
    'border: none blue;',
    'border: 3px solid #0000ff; border: 3px solid red;',
  ]) {
    test('image styling does not invent a video: $style', () {
      final post = _parse(style: style, title: 'scenery');
      expect(post.isVideoPreview, isFalse);
      expect(post.fileUrl, post.previewUrl);
    });
  }

  test('border-only rows do not require a title attribute', () {
    expect(_parse(style: 'border: 3px solid #0000ff;').isVideoPreview, isTrue);
  });

  test('old exact video title marker remains a fallback', () {
    expect(_parse(title: 'sound, video, webm').isVideoPreview, isTrue);
    expect(
      _parse(title: 'video_game, video with sound').isVideoPreview,
      isFalse,
    );
  });
}

const _thumbnail =
    'https://realbooru.test/thumbnails/91/7f/thumbnail_917f6b67890db46e7eabf7caca32802a.jpg';

PostV2Dto _parse({String? style, String? title}) => parseRbPostsHtml(
  Response<String>(
    requestOptions: RequestOptions(path: '/index.php?page=post&s=list'),
    data:
        '<div class="col thumb"><a id="p1013686">'
        '<img src="$_thumbnail" '
        '${style == null ? '' : 'style="$style" '}'
        '${title == null ? '' : 'title="$title" '}'
        '/></a></div>',
  ),
  const {},
).posts.single;
