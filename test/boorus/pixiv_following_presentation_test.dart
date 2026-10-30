import 'package:booru_clients/pixiv.dart';
import 'package:boorusama/boorus/pixiv/following/presentation.dart';
import 'package:boorusama/core/posts/rating/types.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('preview extraction is bounded, respects visibility and artist identity', () {
    final artist = _artist([
      _work(1), _work(2, visible: false), _work(3, user: 8), _work(4),
    ]);
    expect(pixivFollowingPreviewUrls(artist, maxRestriction: 0),
      ['https://i.pximg.net/1.jpg']);
    expect(pixivFollowingPreviewUrls(_artist([_work(1, restriction: 1)]),
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

  for (final restriction in <int?>[0, null]) {
    test('known explicit sanity level is not unrestricted: $restriction', () {
      final artist = _artist([
        _work(1, restriction: restriction, sanity: 6),
      ]);
      expect(pixivFollowingPreviews(artist, maxRestriction: 0), isEmpty);
      final allowed = pixivFollowingPreviews(artist, maxRestriction: 1).single;
      expect(allowed.artworkId, 1);
      expect(allowed.rating, Rating.explicit);
      expect(allowed.url, 'https://i.pximg.net/1.jpg');
    });
  }

  test('R18G restriction remains stricter than the explicit display rating', () {
    final artist = _artist([_work(1, restriction: 2)]);
    expect(pixivFollowingPreviews(artist, maxRestriction: 1), isEmpty);
    expect(pixivFollowingPreviews(artist, maxRestriction: 2).single.rating,
      Rating.explicit);
  });

  test('preserves general, questionable and unknown ratings without new policy', () {
    final previews = pixivFollowingPreviews(_artist([
      _work(1, sanity: 2),
      _work(2, sanity: 4),
      _work(3, restriction: null),
    ]), maxRestriction: 0);
    expect(previews.map((preview) => preview.rating),
      [Rating.general, Rating.questionable, Rating.unknown]);
  });
}

PixivFollowingArtist _artist(List<PixivIllustDto> works) =>
    PixivFollowingArtist(user: const PixivIllustUser(id: 7), illusts: works);

PixivIllustDto _work(int id, {
  int user = 7,
  bool visible = true,
  int? restriction = 0,
  int? sanity,
}) => PixivIllustDto.fromJson({
  'id': id, 'user': {'id': user}, 'type': 'illust', 'page_count': 1,
  'visible': visible, 'x_restrict': restriction, 'sanity_level': sanity,
  'image_urls': {'square_medium': 'https://i.pximg.net/$id.jpg'},
});
