import 'package:booru_clients/src/gelbooru_v2/parsers/rb_parsers.dart';
import 'package:dio/dio.dart';
import 'package:test/test.dart';

void main() {
  const original = '/images/ab/cd/0123456789abcdef0123456789abcdef.png';
  const sample = '/samples/ab/cd/sample_0123456789abcdef0123456789abcdef.jpg';
  dynamic parseDetail(String body) => parseRbPostHtml(
    Response<String>(
      requestOptions: RequestOptions(path: '/index.php'),
      data: '<input name="id" value="42">$body',
    ),
    const {'baseUrl': 'https://realbooru.test/'},
  );

  test('keeps sample and original separate and reads original facts', () {
    final post = parseDetail('''
      <img id="image" src="$sample" width="800" height="600">
      <div id="tagLink">Size: 2400 x 1800 File size: 123456 bytes</div>
      <a id="highres" href="$original">Original image</a>
    ''');
    expect(post.fileUrl, 'https://realbooru.test$original');
    expect(post.sampleUrl, 'https://realbooru.test$sample');
    expect(post.previewUrl, contains('/thumbnails/ab/cd/thumbnail_'));
    expect(post.width, 2400);
    expect(post.height, 1800);
    expect(post.fileSize, 123456);
  });

  test('rendered dimensions and rounded byte sizes remain unknown', () {
    final post = parseDetail('''
      <img id="image" src="$original" width="800" height="600">
      <div id="tagLink">File size: 1.2 MB</div>
    ''');
    expect(post.width, isNull);
    expect(post.height, isNull);
    expect(post.fileSize, isNull);
    expect(post.fileUrl, post.sampleUrl);
  });

  for (final link in ['', '<a id="highres" href="javascript:alert(1)">Original</a>']) {
    test('never claims a known sample is an unavailable original: $link', () {
      final post = parseDetail('<img id="image" src="$sample">$link');
      expect(post.sampleUrl, 'https://realbooru.test$sample');
      expect(post.fileUrl, isEmpty);
    });
  }

  test('conflicting originals do not silently pick one', () {
    final post = parseDetail('''
      <img id="image" src="$sample">
      <a id="highres" href="$original">Original</a>
      <a id="original-file" href="/other.png">Original image</a>
    ''');
    expect(post.fileUrl, isEmpty);
  });

  test('protocol-relative originals and explicit dimensions are resolved', () {
    final post = parseDetail('''
      <img id="image" src="$sample" data-original="//cdn.test/original.png"
        data-original-width="2400" data-original-height="1800"
        data-original-file-size="0">
    ''');
    expect(post.fileUrl, 'https://cdn.test/original.png');
    expect(post.width, 2400);
    expect(post.height, 1800);
    expect(post.fileSize, 0);
  });

  test('video playback URL is not replaced by image or original links', () {
    final post = parseDetail('''
      <video id="gelcomVideoPlayer"><source src="/movie.mp4"></video>
      <img id="image" src="$sample">
      <a id="highres" href="$original">Original</a>
    ''');
    expect(post.fileUrl, 'https://realbooru.test/movie.mp4');
    expect(post.sampleUrl, post.fileUrl);
    expect(post.width, isNull);
  });
}
