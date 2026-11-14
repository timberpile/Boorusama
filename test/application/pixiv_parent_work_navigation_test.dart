import 'package:boorusama/boorus/pixiv/pixiv.dart';
import 'package:boorusama/boorus/pixiv/posts/types.dart';
import 'package:boorusama/boorus/pixiv/works/bookmark_targets.dart';
import 'package:boorusama/boorus/pixiv/works/work_mapper.dart';
import 'package:boorusama/boorus/pixiv/works/work_source.dart';
import 'package:boorusama/core/bookmarks/providers.dart';
import 'package:boorusama/core/bookmarks/src/pages/bookmark_page.dart';
import 'package:boorusama/core/bookmarks/src/widgets/bookmark_local_group_card.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_library_state.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/content/content_access_provider.dart';
import 'package:boorusama/core/content/groups/group_source_provider.dart';
import 'package:boorusama/core/navigation/navigation_chrome_controller.dart';
import 'package:boorusama/core/navigation/app_navigation_shell.dart';
import 'package:boorusama/core/navigation/navigation_controller.dart';
import 'package:boorusama/core/posts/details_pageview/widgets.dart';
import 'package:boorusama/core/settings/types.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurumi/material.dart';

import '../boorus/pixiv/works/work_test_fixtures.dart';
import 'support/app_flow_driver.dart';
import 'support/app_flow_finders.dart';
import 'support/fake_booru_backend.dart';
import 'support/fake_image_dio.dart';
import 'support/headless_app_harness.dart';

class _SavedPage extends BookmarkLibraryNotifier {
  _SavedPage(this.library);
  final BookmarkLibraryState library;

  @override
  Future<BookmarkLibraryState> build() async => library;
}

void main() {
  for (final reduced in [false, true]) {
    testWidgets(
      'Page Bookmark to parent Work and Back keeps navigation hidden, reduced=$reduced',
      (tester) async {
        final backend = FakeBooruBackend(
          additionalBoorus: {BooruType.pixiv: createPixiv().parser.parse()},
        )..registry.register(BooruType.pixiv, createPixiv());
        final access = workAccess();
        final dto = work(id: 456);
        final post = pixivWorkPagePosts(dto, access)[2];
        final saved = PixivPageBookmarkTarget(access: access, post: post)
            .draft(currentAccess: access, at: DateTime.utc(2026, 11, 14))
            .copyWith(id: 901);
        final library = BookmarkLibraryState(
          bookmarks: [saved],
          groups: const [],
        );
        final harness = await HeadlessAppHarness.mount(
          tester,
          booruBackend: backend,
          viewportSize: const Size(320, 844),
          runtime: backend.createRuntime(
            configs: [backend.config, access.config!],
            settings: Settings.defaultSettings.copyWith(
              reduceAnimations: reduced,
            ),
          ),
          additionalOverrides: [
            deterministicImageDioOverride(),
            deterministicFaviconDioOverride(),
            bookmarkProvider.overrideWith(() => _SavedPage(library)),
            contentGroupSourceProvider.overrideWith((ref, key) {
              final source = PixivWorkSource(
                access: ref.watch(contentAccessContextProvider(key))!,
                fetchWork: (_) async => dto,
              );
              ref.onDispose(source.dispose);
              return source;
            }),
          ],
        );
        await harness.pumpUntilFound(tester, postTile(101));
        final driver = AppFlowDriver(tester: tester, harness: harness);
        await tester.tap(find.byKey(const Key('nav-shortcut-bookmarks')));
        await harness.pumpUntilFound(
          tester,
          find.byType(BookmarkLocalGroupCard),
        );
        await harness.settle(tester);
        await tester.tap(find.widgetWithText(BookmarkLocalGroupCard, 'All'));
        await harness.pumpUntilFound(
          tester,
          bookmarkTile(postId: post.id, booruId: saved.booruId),
        );
        await harness.settle(tester);
        await driver.openBookmarkDetails(
          postId: post.id,
          booruId: saved.booruId,
          sourceUrl: post.origin.sourceHost,
        );
        final shell = tester.element(find.byType(AppNavigationShell));
        final container = ProviderScope.containerOf(shell, listen: false);
        final chrome = container.read(navigationChromeProvider.notifier);
        final binding = container
            .read(navigationControllerProvider.notifier)
            .binding!;
        final pageRoute = binding.currentRoute!;
        final pager = tester
            .widget<PostDetailsPageView>(find.byType(PostDetailsPageView))
            .controller!;
        await harness.pumpUntilComplete(tester, pager.expandToSnapPoint());
        await tester.ensureVisible(find.text('Work #456'));
        await harness.settle(tester);
        final pageObstruction = container
            .read(navigationChromeProvider)
            .viewerBottomObstruction;
        void expectHidden() {
          expect(container.read(navigationChromeProvider).viewerOpen, isTrue);
          expect(chrome.viewerRouteProgress.value, 1);
          final bar = find.ancestor(
            of: find.byKey(const Key('nav-shortcut-browse')),
            matching: find.byType(AnimatedSlide),
          );
          expect(tester.widget<AnimatedSlide>(bar).offset.dy, 1);
          expect(
            find.byKey(const Key('nav-shortcut-browse')).hitTestable(),
            findsNothing,
          );
        }

        expectHidden();
        for (var visit = 0; visit < 2; visit++) {
          await tester.tap(find.text('Work #456'));
          await harness.pumpUntil(
            tester,
            () => binding.currentRoute != pageRoute,
          );
          await harness.settle(tester);
          expectHidden();
          final workRoute = binding.currentRoute!;
          binding.currentNavigator!.pop();
          await tester.pump();
          // Sample the real reverse transition on the controlled widget clock.
          final animation = workRoute is TransitionRoute
              ? workRoute.animation
              : null;
          for (
            var frame = 0;
            frame < 40 && (animation?.value ?? 0) > 0;
            frame++
          ) {
            expectHidden();
            await tester.pump(const Duration(milliseconds: 16));
          }
          expect(animation?.value ?? 0, 0);
          await harness.settle(tester);
          expect(binding.currentRoute, same(pageRoute));
          expectHidden();
          expect(
            container.read(navigationChromeProvider).viewerBottomObstruction,
            pageObstruction,
          );
          expect(currentDetailPost(tester).pageIndex, 2);
          expect(container.read(bookmarkProvider).requireValue.records, [
            saved,
          ]);
        }
        binding.currentNavigator!.pop();
        await harness.settle(tester);
        expect(container.read(navigationChromeProvider).viewerOpen, isFalse);
        expect(find.byType(BookmarkPage), findsOneWidget);
        expect(
          find.byKey(const Key('nav-shortcut-browse')).hitTestable(),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}
