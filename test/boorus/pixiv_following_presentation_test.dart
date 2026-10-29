import 'package:booru_clients/pixiv.dart';
import 'package:boorusama/boorus/pixiv/following/presentation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('preview extraction is bounded, respects visibility and artist identity', () {
    PixivIllustDto work(int id, {int user = 7, bool visible = true,
      int restriction = 0}) => PixivIllustDto.fromJson({
        'id': id, 'user': {'id': user}, 'type': 'illust',
        'page_count': 1, 'visible': visible, 'x_restrict': restriction,
        'image_urls': {'square_medium': 'https://i.pximg.net/$id.jpg'},
        'meta_single_page': {'original_image_url': 'https://i.pximg.net/$id.jpg'},
      });
    final artist = PixivFollowingArtist(user: const PixivIllustUser(id: 7),
      illusts: [work(1), work(2, visible: false), work(3, user: 8), work(4)]);
    expect(pixivFollowingPreviewUrls(artist, maxRestriction: 0),
      ['https://i.pximg.net/1.jpg']);
    expect(pixivFollowingPreviewUrls(PixivFollowingArtist(
      user: const PixivIllustUser(id: 7), illusts: [work(1, restriction: 1)]),
      maxRestriction: 0), isEmpty);
  });

  test('preview image URLs reject foreign initial media hosts', () {
    expect(pixivFollowingImageUrl('https://i.pximg.net/avatar.jpg'), isNotNull);
    for (final url in ['http://i.pximg.net/a.jpg',
      'https://i.pximg.net.example.invalid/a.jpg',
      'https://user@i.pximg.net/a.jpg', 'file:///avatar.jpg', null]) {
      expect(pixivFollowingImageUrl(url), isNull);
    }
  });
}
