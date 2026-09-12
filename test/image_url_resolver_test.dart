// Package imports:
import 'package:flutter_test/flutter_test.dart';

// Project imports:
import 'package:boorusama/boorus/gelbooru/posts/types.dart';

void main() {
  const resolver = GelbooruImageUrlResolver();

  group('resolveImageUrl', () {
    final cases = [
      (
        input: 'https://img3.gelbooru.com/images/abc/123.jpg',
        expected: 'https://img4.gelbooru.com/images/abc/123.jpg',
        description: 'normalizes img3 to the current image host',
      ),
      (
        input: 'https://img2.gelbooru.com/images/abc/123.jpg',
        expected: 'https://img4.gelbooru.com/images/abc/123.jpg',
        description: 'normalizes a previously used host to the current one',
      ),
      (
        input: 'https://img10.gelbooru.com/images/abc/123.jpg',
        expected: 'https://img4.gelbooru.com/images/abc/123.jpg',
        description:
            'normalizes multi-digit subdomain to the current image host',
      ),
      (
        input: 'https://img4.gelbooru.com/images/abc/123.jpg',
        expected: 'https://img4.gelbooru.com/images/abc/123.jpg',
        description: 'keeps the current image host unchanged',
      ),
      (
        input: 'https://example.com/images/abc/123.jpg',
        expected: 'https://example.com/images/abc/123.jpg',
        description: 'keeps non-gelbooru URLs unchanged',
      ),
      (
        input: 'invalid-url',
        expected: 'invalid-url',
        description: 'returns original for invalid URLs',
      ),
    ];

    for (final c in cases) {
      test(c.description, () {
        expect(resolver.resolveImageUrl(c.input), c.expected);
      });
    }
  });
}
