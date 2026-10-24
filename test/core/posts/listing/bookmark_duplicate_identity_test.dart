import 'package:boorusama/boorus/pixiv/posts/types.dart';
import 'package:boorusama/boorus/sankaku/posts/post_data.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_identity.dart';
import 'package:boorusama/core/posts/listing/src/widgets/post_duplicate_checker.dart';
import 'package:boorusama/core/posts/listing/src/widgets/post_grid_controller.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foundation/foundation.dart';

import '../../../support/fakes/test_post.dart';

void main() {
  test(
    'bookmark ingestion keeps cross-site IDs and engine-specific keys',
    () async {
      final rows = [
        _post('https://a.test', BooruType.danbooru),
        _post('https://b.test', BooruType.danbooru),
        for (var page = 0; page < 2; page++)
          _post(
            'https://pixiv.test',
            BooruType.pixiv,
            PixivPostData(
              illustId: 123,
              pageIndex: page,
              pageCount: 2,
              userId: 1,
              userName: 'Artist',
              userAccount: 'artist',
              illustType: PixivIllustType.illust,
              totalBookmarks: 0,
              totalView: 0,
              aiType: 0,
              seriesTitle: null,
              isUgoira: false,
              isRestricted: false,
            ),
          ),
        for (final key in ['abc', 'xyz'])
          _post(
            'https://sankaku.test',
            BooruType.sankaku,
            SankakuPostData(
              sankakuId: SankakuPostIdData(value: key, isNumeric: false),
              isFavorited: false,
              favoriteCount: 0,
              artistDetailsTags: const [],
              characterDetailsTags: const [],
              copyrightDetailsTags: const [],
              generalDetailsTags: const [],
              metaDetailsTags: const [],
            ),
          ),
      ];
      // This is the secondary defect: every numeric ID is 42.
      final numeric = PostDuplicateTracker<Post>();
      var accepted = 0;
      for (final row in rows) {
        if (!numeric.isDuplicate(row)) {
          numeric.trackItem(row);
          accepted++;
        }
      }
      expect(accepted, 1);

      final controller = PostGridController<Post>(
        fetcher: (_) => TaskEither.right(
          PostResult(
            posts: [...rows, _post('https://a.test', BooruType.danbooru)],
            total: 7,
          ),
        ),
        blacklistedTagsFetcher: () async => const {},
        mountedChecker: () => true,
        duplicateTracker: PostDuplicateTracker(
          identityExtractor: BookmarkIdentity.tryFromPost,
        ),
        onError: (_) {},
      );
      addTearDown(controller.dispose);
      await controller.refresh();
      expect(controller.items, rows);
    },
  );

  test(
    'unknown special-engine identities are never collapsed by numeric ID',
    () {
      final tracker = PostDuplicateTracker<Post>(
        identityExtractor: BookmarkIdentity.tryFromPost,
      );
      final a = _post('https://sankaku.test', BooruType.sankaku);
      final b = _post('https://sankaku.test', BooruType.sankaku);
      tracker.trackItem(a);
      expect(tracker.isDuplicate(b), isFalse);
      tracker.rebuildFrom([a, b]);
      expect(tracker.isDuplicate(b), isFalse);
    },
  );
}

Post _post(String site, BooruType type, [BooruPostData? data]) => TestPost(
  id: 42,
  origin: PostOrigin.fromSource(
    booruType: type,
    booruId: type.id,
    source: site,
  ),
  booruData: data ?? EmptyPostData(typeKey: type.name),
);
