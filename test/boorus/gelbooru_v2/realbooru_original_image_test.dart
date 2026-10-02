// Dart imports:
import 'dart:io';

// Package imports:
import 'package:booru_clients/src/gelbooru_v2/parsers/rb_parsers.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Realbooru media parsing', () {
    test('keeps a listing thumbnail instead of inventing a jpg original', () {
      final post = parseRbPostsHtml(
        _response(_fixture('realbooru_search_result.html')),
        const {'baseUrl': 'https://realbooru.test/'},
      ).posts.single;

      expect(
        post.fileUrl,
        'https://realbooru.test/thumbnails/ab/cd/'
        'thumbnail_0123456789abcdef0123456789abcdef.jpg',
      );
      expect(post.sampleUrl, post.fileUrl);
    });

    final urlCases = [
      (
        name: 'root-relative media',
        raw: '/images/ab/cd/0123456789abcdef0123456789abcdef.jpeg',
        expected:
            'https://realbooru.test/images/ab/cd/'
            '0123456789abcdef0123456789abcdef.jpeg',
      ),
      (
        name: 'path-relative media',
        raw: 'images/ab/cd/0123456789abcdef0123456789abcdef.jpeg',
        expected:
            'https://realbooru.test/images/ab/cd/'
            '0123456789abcdef0123456789abcdef.jpeg',
      ),
      (
        name: 'protocol-relative media',
        raw:
            '//cdn.realbooru.test/images/ab/cd/'
            '0123456789abcdef0123456789abcdef.jpeg',
        expected:
            'https://cdn.realbooru.test/images/ab/cd/'
            '0123456789abcdef0123456789abcdef.jpeg',
      ),
      (
        name: 'external absolute media',
        raw:
            'https://media.example/images/ab/cd/'
            '0123456789abcdef0123456789abcdef.jpeg?token=kept',
        expected:
            'https://media.example/images/ab/cd/'
            '0123456789abcdef0123456789abcdef.jpeg?token=kept',
      ),
    ];

    for (final c in urlCases) {
      test('resolves ${c.name}', () {
        final html = _fixture('realbooru_post.html').replaceFirst(
          '/images/ab/cd/0123456789abcdef0123456789abcdef.jpeg',
          c.raw,
        );

        final post = parseRbPostHtml(
          _response(html),
          const {'baseUrl': 'https://realbooru.test/'},
        );

        expect(post?.fileUrl, c.expected);
        expect(post?.sampleUrl, c.expected);
      });
    }

    final invalidCases = [
      (name: 'missing media', image: ''),
      (name: 'an unsupported scheme', image: 'javascript:alert(1)'),
      (name: 'relative media without a base URL', image: 'images/file.jpeg'),
    ];

    for (final c in invalidCases) {
      test('returns no post for ${c.name}', () {
        final html = _fixture('realbooru_post.html').replaceFirst(
          'src="/images/ab/cd/0123456789abcdef0123456789abcdef.jpeg"',
          c.image.isEmpty ? '' : 'src="${c.image}"',
        );

        final post = parseRbPostHtml(
          _response(html),
          c.name == 'relative media without a base URL'
              ? const {}
              : const {'baseUrl': 'https://realbooru.test/'},
        );

        expect(post, isNull);
      });
    }
  });
}

Response<String> _response(String html) => Response<String>(
  requestOptions: RequestOptions(path: '/index.php?page=post&s=view&id=42'),
  data: html,
);

String _fixture(String name) => File(
  'test/boorus/gelbooru_v2/fixtures/$name',
).readAsStringSync();
