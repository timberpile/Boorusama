import 'dart:async';

import 'package:boorusama/core/blacklists/providers.dart';
import 'package:boorusama/core/bookmarks/src/providers/bookmark_provider.dart';
import 'package:boorusama/core/bookmarks/src/services/bookmark_library_service.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_library_state.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_view.dart';
import 'package:boorusama/core/bookmarks/src/types/post_bookmark.dart';
import 'package:boorusama/core/bookmarks/src/widgets/bookmark_scroll_view.dart';
import 'package:boorusama/core/bookmarks/src/widgets/bookmark_access_placeholder.dart';
import 'package:boorusama/core/bookmarks/src/widgets/bookmark_unavailable_indicator.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/posts/details/src/types/post_presentation_fallback_reason.dart';
import 'package:boorusama/core/posts/listing/widgets.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurumi/material.dart';
import 'package:scroll_to_index/scroll_to_index.dart';

import '../search/following_topics/following_topic_test_utils.dart';
import '../../support/fakes/test_post.dart';

void main() {
  testWidgets(
    'a failed policy keeps a visible slot without blocking a healthy source',
    (tester) async {
      BooruConfig profile(String id, String host) => BooruConfig.fromJson({
        ...testProfile.toJson(),
        'id': id,
        'url': 'https://$host',
        'booruId': BooruType.danbooru.id,
        'booruIdHint': BooruType.danbooru.id,
      });
      final bad = profile(
        '11111111-1111-4111-8111-111111111111',
        'stalled.example',
      );
      final good = profile(
        '22222222-2222-4222-8222-222222222222',
        'healthy.example',
      );
      final gate = Completer<Set<String>>();
      PostBookmark saved(int id, BooruConfig p) {
        final post = TestPost(
          id: id,
          booruData: const LegacyPostData(
            typeKey: 'legacy_danbooru',
            custom: {},
          ),
          origin: PostOrigin.fromSource(
            booruType: BooruType.danbooru,
            booruId: BooruType.danbooru.id,
            source: p.url,
            profileIdHint: p.id,
          ),
        );
        return PostBookmark.fromSnapshot(
          id: id,
          createdAt: DateTime.utc(2026),
          updatedAt: DateTime.utc(2026),
          postId: id,
          snapshot: const StoredPostCodec().encode(post),
          post: post,
        );
      }

      final state = BookmarkLibraryState(
        bookmarks: [saved(1, bad), saved(2, good)],
        groups: const [],
      );
      final harness = FollowingTopicHarness(
        profiles: [bad, good],
        overrides: [
          bookmarkProvider.overrideWith(() => _Library(state)),
          blacklistTagsProvider.overrideWith(
            (ref, c) =>
                c.auth.url == bad.url ? gate.future : Future.value(<String>{}),
          ),
        ],
      );
      addTearDown(harness.dispose);
      final scroll = AutoScrollController();
      final search = TextEditingController();
      addTearDown(scroll.dispose);
      addTearDown(search.dispose);
      await harness.pump(
        tester,
        Scaffold(
          body: BookmarkScrollView(
            scrollController: scroll,
            searchController: search,
            view: const BookmarkView.all(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(BookmarkAccessPlaceholder), findsOneWidget);
      expect(
        tester.getSize(find.byType(BookmarkAccessPlaceholder)).shortestSide,
        greaterThan(40),
      );
      expect(find.byType(DefaultImageGridItem), findsOneWidget);
      gate.completeError(StateError('controlled policy failure'));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.cloud_off_outlined), findsOneWidget);
      expect(find.byType(DefaultImageGridItem), findsOneWidget);
      final indicator = tester.widget<BookmarkUnavailableIndicator>(
        find.byType(BookmarkUnavailableIndicator),
      );
      expect(indicator.counts[PostPresentationFallbackReason.refreshFailed], 1);
      expect(tester.takeException(), isNull);
    },
  );
}

class _Library extends BookmarkLibraryNotifier {
  _Library(this.library);
  final BookmarkLibraryState library;
  @override
  FutureOr<BookmarkLibraryState> build() => library;
}
