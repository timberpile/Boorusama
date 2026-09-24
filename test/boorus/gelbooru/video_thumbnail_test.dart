// Flutter imports:
import 'package:flutter_test/flutter_test.dart';

// Project imports:
import 'package:boorusama/boorus/gelbooru/common/video_thumbnail.dart';

void main() {
  group('Gelbooru video poster resolution', () {
    final staticSampleCases = [
      (
        sample: 'https://img.example/images/12/hash.jpg?source=.mp4',
        expected: 'https://img.example/images/12/hash.jpg?source=.mp4',
      ),
      (
        sample: 'https://img.example/images/12/hash.WEBP',
        expected: 'https://img.example/images/12/hash.WEBP',
      ),
    ];

    for (final c in staticSampleCases) {
      test('prefers the static sample ${c.sample}', () {
        expect(
          resolveGelbooruVideoPosterUrl(
            sampleUrl: c.sample,
            videoUrl: 'https://video.example/images/12/hash.mp4',
            thumbnailUrl:
                'https://example.test/thumbnails/12/thumbnail_hash.jpg',
          ),
          c.expected,
        );
      });
    }

    final derivedCases = [
      (
        video: 'https://img.example/images/12/hash.mp4',
        expected: 'https://img.example/images/12/hash.jpg',
      ),
      (
        video: 'https://img.example/images/12/hash.webm?token=abc#frame',
        expected: 'https://img.example/images/12/hash.jpg?token=abc#frame',
      ),
    ];

    for (final c in derivedCases) {
      test('derives a static JPG from ${c.video}', () {
        expect(
          resolveGelbooruVideoPosterUrl(
            sampleUrl: 'https://video.example/images/12/hash.mp4',
            videoUrl: c.video,
            thumbnailUrl:
                'https://example.test/thumbnails/12/thumbnail_hash.jpg',
          ),
          c.expected,
        );
      });
    }

    final fallbackCases = [
      (sample: '', video: 'https://img.example/images/12/hash.zip'),
      (sample: 'not a URL', video: 'not a URL'),
    ];

    for (final c in fallbackCases) {
      test('keeps the thumbnail for unsupported inputs $c', () {
        expect(
          resolveGelbooruVideoPosterUrl(
            sampleUrl: c.sample,
            videoUrl: c.video,
            thumbnailUrl:
                'https://example.test/thumbnails/12/thumbnail_hash.jpg',
          ),
          'https://example.test/thumbnails/12/thumbnail_hash.jpg',
        );
      });
    }
  });
}
