import 'package:booru_clients/pixiv.dart';
import 'package:boorusama/boorus/pixiv/posts/types.dart';
import 'package:boorusama/boorus/pixiv/works/work_mapper.dart';
import 'package:boorusama/core/content/types.dart';
import 'package:flutter_test/flutter_test.dart';

import 'work_test_fixtures.dart';

void main() {
  test(
    'native listings retain one entry per Work and genuine animation Posts',
    () {
      final access = workAccess();
      final result = PixivIllustListResult(
        illusts: [
          work(),
          work(id: 121),
          work(id: 122, type: 'ugoira', pageCount: 1),
        ],
        hasMore: true,
      );
      final entries = pixivWorkListingEntries(result, access: access);
      expect(entries.map((entry) => entry.reference.sourceKey), [
        'work:120',
        'work:121',
        'work-page:122:0',
      ]);
      expect(entries.take(2).whereType<GroupContentEntry>(), hasLength(2));
      final animation = entries.last as PostContentEntry;
      expect(animation.post.isUgoira, isTrue);
      expect(animation.post.origin.profileIdHint, access.key.profileId);
      expect((entries.first as GroupContentEntry).summary.memberCount, 3);
      expect(result.hasMore, isTrue);
    },
  );

  test('list Summary needs no original media and preserves unknown count', () {
    final access = workAccess();
    final dto = work(pageCount: null, pages: const []);
    final summary = pixivWorkSummary(dto, access);
    expect(summary.reference.sourceKey, 'work:120');
    expect(summary.memberCount, isNull);
    expect(summary.cover!.thumbnail.toString(), contains('/thumb/120_p0.jpg'));
    expect(summary.cover!.representedPost, isNull);
  });

  test(
    'unavailable page does not change later Page key, filename index or media',
    () {
      final access = workAccess();
      final dto = work(pages: [page(120, 0), null, page(120, 2)]);
      final posts = pixivWorkPagePosts(dto, access);
      expect(posts.map((post) => post.pageIndex), [0, 2]);
      expect(posts.map((post) => post.id), [120000, 120002]);
      expect(posts.last.originalImageUrl, endsWith('/120_p2.jpg'));
      expect(posts.last.sampleImageUrl, contains('/large/120_p2.jpg'));
      expect(posts.last.pixivData!.stableBookmarkPostKey, 'work-page:120:2');
      expect(posts.last.detailFacts.description, isNull);
      expect(
        pixivWorkDetails(dto, access).description!.text,
        '<p>Work caption</p>',
      );
    },
  );

  test('hidden, muted and Ugoira envelopes cannot become Work Groups', () {
    final access = workAccess();
    for (final dto in [
      work(visible: false),
      work(muted: true),
      work(type: 'ugoira', pageCount: 1),
    ]) {
      expect(() => pixivWorkSummary(dto, access), throwsFormatException);
    }
    final entries = pixivWorkListingEntries(
      PixivIllustListResult(
        illusts: [
          work(visible: false),
          work(muted: true),
          work(id: 121),
        ],
      ),
      access: access,
    );
    expect(entries.map((entry) => entry.reference.sourceKey), ['work:121']);
  });
}
