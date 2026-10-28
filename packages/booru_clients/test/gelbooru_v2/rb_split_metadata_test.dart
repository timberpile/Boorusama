import 'package:booru_clients/src/gelbooru_v2/parsers/rb_image_metadata.dart';
import 'package:html/parser.dart' as html;
import 'package:test/test.dart';

void main() {
  RbImageMetadata parseMetadata(String body) => parseRbImageMetadata(
    html.parse('<img id="image" src="/images/original.png">$body'),
    displayedUrl: 'https://realbooru.test/images/original.png',
    resolveUrl: (value) => value == null
        ? null
        : Uri.parse('https://realbooru.test/').resolve(value).toString(),
  );

  for (final containers in [
    ('post-info', 'stats'),
    ('stats', 'tagLink'),
    ('tagLink', 'post-info'),
  ]) {
    test('reads dimensions and bytes from separate $containers containers', () {
      final metadata = parseMetadata('''
        <div id="${containers.$1}">Resolution: 2400 x 1800</div>
        <div id="${containers.$2}">File size: 123456 bytes</div>
      ''');
      expect(metadata.width, 2400);
      expect(metadata.height, 1800);
      expect(metadata.fileSize, 123456);
    });
  }

  test('an empty earlier container does not hide later metadata', () {
    final metadata = parseMetadata('''
      <div id="post-info"></div>
      <div id="stats">Uploader: example</div>
      <div id="tagLink">Size: 2400 x 1800 File size: 123456 B</div>
    ''');
    expect(metadata.width, 2400);
    expect(metadata.height, 1800);
    expect(metadata.fileSize, 123456);
  });

  test('does not assemble dimensions across separate containers', () {
    final metadata = parseMetadata('''
      <div id="post-info">Resolution: 2400 x</div>
      <div id="stats">1800 File size: 123456 bytes</div>
    ''');
    expect(metadata.width, isNull);
    expect(metadata.height, isNull);
    expect(metadata.fileSize, 123456);
  });

  test('does not read metadata outside supported containers', () {
    final metadata = parseMetadata('''
      <div id="post-info">Uploader: example</div>
      <div id="stats">File size: 1.2 MB</div>
      <div id="comments">Resolution: 2400 x 1800 File size: 123456 bytes</div>
    ''');
    expect(metadata.width, isNull);
    expect(metadata.height, isNull);
    expect(metadata.fileSize, isNull);
  });
}
