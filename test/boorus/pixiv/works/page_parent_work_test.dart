import 'package:boorusama/boorus/pixiv/works/work_information.dart';
import 'package:boorusama/boorus/pixiv/works/work_mapper.dart';
import 'package:boorusama/core/content/content_access_provider.dart';
import 'package:boorusama/core/content/content_media_access.dart';
import 'package:boorusama/core/posts/details/routes.dart';
import 'package:boorusama/core/posts/details/src/types/viewer_entry.dart';
import 'package:boorusama/core/router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';

import 'work_test_fixtures.dart';

void main() {
  for (final available in [false, true]) {
    testWidgets('parent navigation, source available=$available', (
      tester,
    ) async {
      final access = workAccess();
      final post = pixivWorkPagePosts(work(id: 456), access)[2];
      DetailsRouteContext<dynamic>? opened;
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => PixivPageParentWork(post: post),
          ),
          GoRoute(
            path: '/details',
            builder: (_, state) {
              opened = state.extra! as DetailsRouteContext<dynamic>;
              return const Text('Parent');
            },
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            routerProvider.overrideWithValue(router),
            currentContentAccessKeyProvider.overrideWithValue(access.key),
            contentAccessContextProvider.overrideWith(
              (ref, key) => available ? access : null,
            ),
          ],
          child: BooruLocalization(
            child: MaterialApp.router(routerConfig: router),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final link = find.byKey(const ValueKey('pixiv-page-parent-work'));
      expect(link, available ? findsOneWidget : findsNothing);
      if (available) {
        // No Bookmark providers/storage are installed: navigating must not save.
        await tester.tap(link);
        await tester.pumpAndSettle();
        final entry = opened!.entries!.single as GroupViewerEntry;
        expect(entry.summary.reference.sourceKey, 'work:456');
        expect(entry.source!.config, access.config);
        expect(entry.source!.bookmarkId, isNull);
      }
    });
  }

  testWidgets('animation Posts have no unsupported parent Work link', (
    tester,
  ) async {
    final access = workAccess();
    final post = pixivWorkPagePosts(work(type: 'ugoira'), access).first;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentContentAccessKeyProvider.overrideWithValue(access.key),
          contentAccessContextProvider.overrideWith((ref, key) => access),
        ],
        child: BooruLocalization(
          child: MaterialApp(home: PixivPageParentWork(post: post)),
        ),
      ),
    );
    expect(find.byKey(const ValueKey('pixiv-page-parent-work')), findsNothing);
  });
}
