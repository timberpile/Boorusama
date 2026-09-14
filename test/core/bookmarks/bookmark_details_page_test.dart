// Flutter imports:
import 'package:flutter/material.dart';

// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';

// Project imports:
import 'package:boorusama/core/bookmarks/src/data/bookmark_convert.dart';
import 'package:boorusama/core/bookmarks/src/pages/bookmark_details_page.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark.dart';
import 'package:boorusama/core/configs/config/providers.dart';
import 'package:boorusama/core/posts/details/providers.dart';
import 'package:boorusama/core/posts/details/types.dart';
import 'package:boorusama/core/posts/details_pageview/widgets.dart';
import 'package:boorusama/core/premiums/providers.dart';
import 'package:boorusama/core/settings/providers.dart';
import 'package:boorusama/core/settings/src/types/settings.dart';

void main() {
  testWidgets('bookmark details toolbar renders inside bookmark post details', (
    tester,
  ) async {
    final post = Bookmark.empty.toPost();
    final detailsController = PostDetailsController<BookmarkPost>(
      scrollController: null,
      initialPage: 0,
      posts: [post],
      initialThumbnailUrl: null,
      reduceAnimations: true,
      dislclaimer: null,
      doubleTapSeekDuration: 5,
    );
    final pageViewController = PostDetailsPageViewController(
      initialPage: 0,
      totalPage: 1,
      checkIfLargeScreen: () => false,
    );
    addTearDown(detailsController.dispose);
    addTearDown(pageViewController.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          firstMatchingConfigBySourceUrlProvider.overrideWith(
            (ref, params) => null,
          ),
          imageViewerSettingsProvider.overrideWithValue(
            Settings.defaultSettings.viewer,
          ),
          showPremiumFeatsProvider.overrideWithValue(false),
        ],
        child: BooruLocalization(
          child: MaterialApp(
            builder: (context, child) => KurumiTheme(
              data: KurumiThemeData.fromMaterial(Theme.of(context)),
              child: child!,
            ),
            home: PostDetailsPageViewScope(
              controller: pageViewController,
              child: PostDetails<BookmarkPost>(
                data: PostDetailsData(
                  posts: [post],
                  controller: detailsController,
                ),
                child: CustomScrollView(
                  slivers: [
                    InheritedPost<BookmarkPost>(
                      post: post,
                      child: const BookmarkPostActionToolbar(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(BookmarkPostActionToolbar), findsOneWidget);
  });
}
