import 'package:boorusama/core/posts/cross_profile_lookup/types.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final text in [
    'https://www.pixiv.net/artworks/12345',
    'Artwork title\nhttps://www.pixiv.net/en/artworks/12345?utm_source=share#private',
    '作品 (https://www.pixiv.net/artworks/12345).',
    'https://pixiv.net/member_illust.php?mode=medium&illust_id=12345',
    'https://i.pximg.net/img-original/img/2026/01/01/00/00/00/12345_p2.png',
    'https://www.pixiv.net/artworks/12345 https://www.pixiv.net/en/artworks/12345',
  ]) {
    test('extracts one artwork reference from $text', () {
      final reference = PixivArtworkReference.parseSharedText(text)!;
      expect(reference.id, '12345');
      expect(reference.url, 'https://www.pixiv.net/artworks/12345');
    });
  }

  for (final (index, text) in <String?>[
    null,
    '',
    '12345',
    'https://www.pixiv.net/users/12345',
    'https://www.pixiv.net/artworks/0',
    'https://www.pixiv.net/artworks/012345',
    'https://www.pixiv.net/artworks/12345oops',
    'https://www.pixiv.net/artworks/123456789012345678901',
    'https://pixiv.net.evil.test/artworks/12345',
    'https://pixiv.net@evil.test/artworks/12345',
    'https://secret@www.pixiv.net/artworks/12345',
    'https://www.pixiv.net:444/artworks/12345',
    'javascript:https://evil.test/?next=https://www.pixiv.net/artworks/12345',
    'https://www.pixiv.net/member_illust.php?illust_id=12345&illust_id=23456',
    'https://www.pixiv.net/member_illust.php?illust_id=%FF',
    'https://www.pixiv.net/artworks/12345 https://www.pixiv.net/artworks/23456',
    '${'a' * 16384} https://www.pixiv.net/artworks/12345',
  ].indexed) {
    test(
      'rejects unsafe, ambiguous or non-artwork input case ${index + 1}',
      () {
        expect(PixivArtworkReference.parseSharedText(text), isNull);
      },
    );
  }
}
