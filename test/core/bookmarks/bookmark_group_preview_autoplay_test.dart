import 'package:boorusama/core/bookmarks/src/pages/bookmark_group_browser_page.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final gif = Bookmark.empty.copyWith(
    format: () => 'gif',
    thumbnailUrl: 'https://example.test/thumb.JPG?version=1',
    sampleUrl: 'https://example.test/sample.gif',
    originalUrl: 'https://example.test/original.gif',
  );

  test('disabled autoplay chooses the static poster without changing enabled behavior', () {
    expect(bookmarkGroupPreviewUrl(gif), gif.sampleUrl);
    expect(bookmarkGroupPreviewUrl(gif, autoplayGif: false), gif.thumbnailUrl);
  });

  test('a static sample can replace an animated thumbnail', () {
    final post = gif.copyWith(
      thumbnailUrl: 'https://example.test/thumb.gif',
      sampleUrl: 'https://example.test/sample.jpg',
    );
    expect(bookmarkGroupPreviewUrl(post, autoplayGif: false), post.sampleUrl);
  });

  for (final thumbnail in [
    '',
    'https://example.test/thumb.gif',
    'https://example.test/image',
    'https://example.test/thumb.webp',
  ]) {
    test('no proven static preview produces no image request: $thumbnail', () {
      final post = gif.copyWith(thumbnailUrl: thumbnail);
      expect(bookmarkGroupPreviewUrl(post, autoplayGif: false), isEmpty);
    });
  }

  test(
    'a GIF original with a misleading suffix is not used as a static preview',
    () {
      final post = gif.copyWith(
        thumbnailUrl: 'https://example.test/original.jpg',
        sampleUrl: 'https://example.test/original.jpg',
        originalUrl: 'https://example.test/original.jpg',
        format: () => 'gif',
      );
      expect(bookmarkGroupPreviewUrl(post, autoplayGif: false), isEmpty);
    },
  );

  test('ordinary image quality and video poster selection stay unchanged', () {
    final image = gif.copyWith(
      format: () => 'jpg',
      sampleUrl: 'https://example.test/sample.jpg',
      originalUrl: 'https://example.test/original.jpg',
    );
    final video = gif.copyWith(
      format: () => 'mp4',
      originalUrl: 'https://example.test/original.mp4',
    );
    expect(bookmarkGroupPreviewUrl(image, autoplayGif: false), image.sampleUrl);
    expect(
      bookmarkGroupPreviewUrl(video, autoplayGif: false),
      video.thumbnailUrl,
    );
  });
}
