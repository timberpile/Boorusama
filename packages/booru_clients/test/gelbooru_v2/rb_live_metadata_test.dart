import 'dart:convert';
import 'dart:io';

import 'package:booru_clients/src/gelbooru_v2/parsers/rb_image_metadata.dart';
import 'package:booru_clients/src/gelbooru_v2/parsers/rb_parsers.dart';
import 'package:dio/dio.dart';
import 'package:html/parser.dart' as html;
import 'package:test/test.dart';

void main() {
  test('absolute media still resolves without a usable source base', () {
    for (final base in ['', 'not a URL', '//realbooru.com/']) {
      const raw = 'https://realbooru.com//images/ab/cd/original.jpg';
      final response = Response<String>(
        requestOptions: RequestOptions(
          path: '/index.php?page=post&s=view&id=42',
        ),
        data:
            '<input name="id" value="42"><div class="imageContainer">'
            '<img id="image" src="$raw"><a href="$raw">Original</a></div>',
      );
      final post = parseRbPostHtml(response, {'baseUrl': base});
      expect(post!.fileUrl, raw);
    }
  });
  for (final external in [false, true]) {
    test(
      'redundant media path slash is canonicalized only on its source (external=$external)',
      () {
        final host = external ? 'cdn.example' : 'realbooru.com';
        final raw = 'https://$host//images/ab/cd/original.jpg?version=1';
        final response = Response<String>(
          requestOptions: RequestOptions(
            path: '/index.php?page=post&s=view&id=42',
          ),
          data:
              '<input name="id" value="42"><div class="imageContainer">'
              '<img id="image" src="$raw"><a href="$raw">Original</a></div>',
        );
        final post = parseRbPostHtml(response, {
          'baseUrl': 'https://realbooru.com/',
        });
        final expected = external
            ? raw
            : 'https://realbooru.com/images/ab/cd/original.jpg?version=1';
        expect(post!.sampleUrl, expected);
        expect(post.fileUrl, expected);
      },
    );
  }
  const directory = 'test/gelbooru_v2/fixtures/realbooru_live';
  final provenance =
      jsonDecode(File('$directory/provenance.json').readAsStringSync()) as Map;
  for (final record in (provenance['records'] as List).cast<Map>()) {
    test(
      'sanitized live Realbooru post ${record['postId']} retains source media facts',
      () {
        final response = Response<String>(
          requestOptions: RequestOptions(path: record['source'] as String),
          data: File('$directory/${record['fixture']}').readAsStringSync(),
        );
        final post = parseRbPostHtml(response, {
          'baseUrl': 'https://realbooru.com/',
        });
        if (record['unavailable'] == true) {
          expect(post, isNull);
          return;
        }
        expect(post, isNotNull);
        expect(post!.id.toString(), record['postId']);
        expect(
          post.fileUrl,
          record['video'] == true
              ? record['resolvedVideoUrl']
              : record['resolvedOriginalControlUrl'],
        );
        expect(
          post.sampleUrl,
          record['video'] == true
              ? record['resolvedVideoUrl']
              : record['resolvedDisplayedUrl'],
        );
        // These captured pages expose neither original dimensions nor exact bytes.
        expect(post.width, isNull);
        expect(post.height, isNull);
        expect(post.fileSize, isNull);
      },
    );
  }

  test('live media container scopes Original to the displayed image', () {
    final document = html.parse('''
      <div class="imageContainer">
        <img id="image" src="/samples/sample.jpg">
        <div><div><a href="/images/original.png">Original</a></div></div>
      </div>
      <div class="imageContainer"><a href="/unrelated.png">Original</a></div>
    ''');
    final metadata = parseRbImageMetadata(
      document,
      displayedUrl: 'https://realbooru.test/samples/sample.jpg',
      resolveUrl: (url) => url == null
          ? null
          : Uri.parse('https://realbooru.test/').resolve(url).toString(),
    );
    expect(metadata.originalUrl, 'https://realbooru.test/images/original.png');
  });
}
