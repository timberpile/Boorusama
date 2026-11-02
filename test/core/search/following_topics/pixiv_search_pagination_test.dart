// Package imports:
import 'package:booru_clients/pixiv.dart';
import 'package:flutter_test/flutter_test.dart';

// Project imports:
import 'package:boorusama/boorus/pixiv/posts/parser.dart';

void main() {
  const illust = PixivIllustDto(
    id: 42,
    user: PixivIllustUser(id: 7),
    pageCount: 1,
    metaSinglePage: PixivMetaSinglePage(
      originalImageUrl: 'https://i.pximg.net/img-original/example.jpg',
    ),
    createDate: '2026-09-14T12:00:00+09:00',
  );

  for (final hasMore in [true, false]) {
    test('preserves Pixiv continuation when it is $hasMore', () {
      final result = pixivIllustListResultToPostResult(
        PixivIllustListResult(illusts: [illust], hasMore: hasMore),
      );

      expect(result.posts.map((post) => post.id), [42000]);
      expect(result.hasMore, hasMore);
      expect(result.copyWith(), result);
    });

    test('preserves continuation $hasMore when every page is unavailable', () {
      final result = pixivIllustListResultToPostResult(
        PixivIllustListResult(
          illusts: const [
            PixivIllustDto(
              id: 42,
              user: PixivIllustUser(id: 7),
              pageCount: 3,
              metaPages: [PixivMetaPage(), PixivMetaPage(), PixivMetaPage()],
            ),
          ],
          hasMore: hasMore,
        ),
      );

      expect(result.posts, isEmpty);
      expect(result.hasMore, hasMore);
    });
  }
}
