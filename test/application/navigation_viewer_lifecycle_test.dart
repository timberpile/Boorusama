import 'package:boorusama/core/navigation/app_navigation_shell.dart';
import 'package:boorusama/core/navigation/destination_id.dart';
import 'package:boorusama/core/navigation/navigation_controller.dart';
import 'package:boorusama/core/posts/details/widgets.dart';
import 'package:boorusama/core/posts/listing/widgets.dart';
import 'package:boorusama/core/router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurumi/material.dart';
import 'package:boorusama/core/bookmarks/src/pages/bookmark_group_browser_page.dart';
import 'package:boorusama/core/bookmarks/src/pages/bookmark_page.dart';
import 'package:boorusama/core/bookmarks/src/pages/bookmark_details_page.dart';
import 'package:boorusama/core/bookmarks/src/providers/bookmark_details_mutation_notifier.dart';
import 'package:boorusama/core/posts/details_parts/widgets.dart';
import 'package:boorusama/core/posts/details/src/routes/details_route_context.dart';
import 'package:boorusama/core/search/following_topics/widgets.dart';
import 'package:boorusama/core/navigation/navigation_chrome_controller.dart';

import '../support/boorusama_test_runtime.dart';
import 'support/app_flow_driver.dart';

import 'support/fake_booru_backend.dart';
import 'support/headless_app_harness.dart';

void main() {
  testWidgets('viewer Back reveals the original navigation bar immediately', (
    tester,
  ) async {
    final harness = await HeadlessAppHarness.mount(
      tester,
      viewportSize: kMobileViewport,
    );
    await harness.pumpUntilFound(tester, find.byType(PostGrid));
    final container = ProviderScope.containerOf(
      tester.element(find.byType(AppNavigationShell)),
    );
    final bar = find.ancestor(
      of: find.byKey(const Key('nav-shortcut-browse')),
      matching: find.byType(AnimatedSlide),
    );
    final originalBar = tester.state(bar);
    final originalPosition = tester.getRect(
      find.byKey(const Key('nav-shortcut-browse')),
    );
    await tester.tap(find.byType(SliverPostGridImageGridItem).first);
    await harness.pumpUntilFound(tester, find.byType(PostDetailsPageScaffold));
    await harness.settle(tester);
    expect(find.byKey(const Key('nav-shortcut-browse')), findsNothing);

    await tester.binding.handlePopRoute();
    await harness.pumpUntil(
      tester,
      () => container.read(navigationChromeProvider).viewerClosing,
    );
    await tester.pump();
    expect(find.byType(PostDetailsPageScaffold), findsOneWidget);
    expect(container.read(navigationChromeProvider).viewerOpen, isTrue);
    expect(tester.state(bar), same(originalBar));
    final translation = find.descendant(
      of: bar,
      matching: find.byType(FractionalTranslation),
    );
    expect(
      tester.widget<FractionalTranslation>(translation).translation,
      Offset.zero,
    );
    expect(
      tester.getRect(find.byKey(const Key('nav-shortcut-browse'))),
      originalPosition,
    );
    await harness.settle(tester);
    expect(find.byType(PostDetailsPageScaffold), findsNothing);
    expect(container.read(navigationChromeProvider).viewerClosing, isFalse);
    expect(
      tester.widget<FractionalTranslation>(translation).translation,
      Offset.zero,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('a completed Browse viewer cannot return from a cached branch', (
    tester,
  ) async {
    final backend = FakeBooruBackend();
    final harness = await HeadlessAppHarness.mount(
      tester,
      booruBackend: backend,
      viewportSize: kMobileViewport,
    );
    await harness.pumpUntilFound(tester, find.byType(PostGrid));
    final container = ProviderScope.containerOf(
      tester.element(find.byType(AppNavigationShell)),
    );
    final controller = container.read(navigationControllerProvider.notifier);
    final router = container.read(routerProvider);
    final grid = tester.state(find.byType(PostGrid).first);
    for (var visit = 0; visit < 3; visit++) {
      await tester.tap(find.byType(SliverPostGridImageGridItem).first);
      await harness.pumpUntilFound(
        tester,
        find.byType(PostDetailsPageScaffold),
      );
      await harness.settle(tester);
      expect(find.byKey(const Key('nav-shortcut-browse')), findsNothing);
      expect(container.read(navigationChromeProvider).viewerOpen, isTrue);
      var completed = false;
      final transition = controller
          .selectDestination(
            const DestinationId.app(AppDestination.bookmarks),
          )
          .then((value) {
            completed = true;
            return value;
          });
      await harness.pumpUntil(tester, () => completed);
      expect(await transition, isTrue);
      await harness.settle(tester);
      await controller.selectBrowseProfile(backend.config.id);
      await harness.settle(tester);
      expect(
        router.state.uri.path,
        DestinationId.browse(backend.config.id).location,
      );
      expect(find.byType(PostDetailsPageScaffold), findsNothing);
      expect(tester.state(find.byType(PostGrid).first), same(grid));
      expect(tester.takeException(), isNull);
    }
    await tester.tap(find.byType(SliverPostGridImageGridItem).first);
    await harness.pumpUntilFound(tester, find.byType(PostDetailsPageScaffold));
    await harness.settle(tester);
    final viewer = controller.binding!.currentRoute!;
    var completions = 0;
    viewer.popped.then((_) => completions++);
    router.go('/bookmarks');
    await harness.pumpUntil(
      tester,
      () =>
          controller.binding!.currentDestination ==
          const DestinationId.app(AppDestination.bookmarks),
    );
    await harness.settle(tester);
    router.go('/');
    await harness.pumpUntil(
      tester,
      () =>
          controller.binding!.currentDestination ==
          DestinationId.browse(backend.config.id),
    );
    await harness.settle(tester);
    expect(completions, 1);
    expect(find.byType(PostDetailsPageScaffold), findsNothing);
    expect(tester.state(find.byType(PostGrid).first), same(grid));
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'Browse and bookmark viewers close normally before Following and retain their grids',
    (tester) async {
      final backend = FakeBooruBackend();
      final repository = MemoryBookmarkRepository();
      final harness = await HeadlessAppHarness.mount(
        tester,
        booruBackend: backend,
        runtime: backend.createRuntime(bookmarkRepository: repository),
        viewportSize: kMobileViewport,
      );
      await harness.pumpUntilFound(tester, find.byType(PostGrid));
      final container = ProviderScope.containerOf(
        tester.element(find.byType(AppNavigationShell)),
      );
      final controller = container.read(navigationControllerProvider.notifier);
      final router = container.read(routerProvider);
      Future<void> select(DestinationId id) async {
        var finished = false;
        final selected = controller.selectDestination(id).then((value) {
          finished = true;
          return value;
        });
        await harness.pumpUntil(tester, () => finished);
        expect(await selected, isTrue);
        await harness.settle(tester);
      }

      await tester.tap(find.byType(SliverPostGridImageGridItem).first);
      await harness.pumpUntilFound(
        tester,
        find.byType(PostDetailsPageScaffold),
      );
      await harness.settle(tester);
      final bookmark = find.descendant(
        of: find.byType(BookmarkPostButton),
        matching: find.byType(IconButton),
      );
      await tester.tap(bookmark);
      await harness.pumpUntil(tester, () => repository.bookmarks.length == 1);
      final saved = repository.bookmarks.single;
      final browseViewer = controller.binding!.currentRoute!;
      var browseCompleted = 0;
      browseViewer.popped.then((_) => browseCompleted++);
      await select(const DestinationId.app(AppDestination.bookmarks));
      expect(browseCompleted, 1);
      expect(find.byType(BookmarkGroupBrowserPage), findsOneWidget);
      await tester.tap(find.text('All'));
      await harness.pumpUntilFound(tester, find.byType(BookmarkPage));
      await harness.settle(tester);
      await AppFlowDriver(tester: tester, harness: harness).openBookmarkDetails(
        postId: saved.postId!,
        booruId: saved.booruId,
        sourceUrl: saved.post.origin.sourceHost,
      );
      await harness.settle(tester);
      expect(container.read(bookmarkDetailsMutationProvider).isVisible, isTrue);
      // A root dialog belongs to this viewer, as does a branch-local popup.
      final viewerContext = tester.element(find.byType(BookmarkDetailsPage));
      var rootCompleted = 0;
      showDialog<void>(
        context: viewerContext,
        builder: (_) => const AlertDialog(title: Text('Viewer dialog')),
      ).then((_) => rootCompleted++);
      await harness.settle(tester);
      expect(container.read(navigationChromeProvider).viewerOpen, isTrue);
      await select(const DestinationId.app(AppDestination.following));
      expect(rootCompleted, 1);
      expect(find.text('Viewer dialog'), findsNothing);
      expect(
        container.read(bookmarkDetailsMutationProvider).isVisible,
        isFalse,
      );
      expect(find.byType(PostDetailsPageScaffold), findsNothing);
      final pageRef =
          tester.element(find.byType(FollowingTopicsPage)) as WidgetRef;
      var followingCompleted = 0;
      pageRef
          .pushRoute<void>(
            '/details',
            extra: DetailsRouteContext(
              initialIndex: 0,
              posts: backend.posts,
              scrollController: null,
              isDesktop: false,
              hero: false,
              initialThumbnailUrl: null,
              config: backend.config,
              useMixedViewer: true,
            ),
          )
          .then((_) => followingCompleted++);
      await harness.pumpUntilFound(
        tester,
        find.byType(PostDetailsPageScaffold),
      );
      await harness.settle(tester);
      final context = tester.element(find.byType(PostDetailsPageScaffold));
      var localCompleted = 0;
      showDialog<void>(
        context: context,
        useRootNavigator: false,
        builder: (_) => const AlertDialog(title: Text('Local viewer dialog')),
      ).then((_) => localCompleted++);
      await harness.settle(tester);
      await select(DestinationId.browse(backend.config.id));
      expect(followingCompleted, 1);
      expect(localCompleted, 1);
      expect(
        router.state.uri.path,
        DestinationId.browse(backend.config.id).location,
      );
      expect(find.byType(PostDetailsPageScaffold), findsNothing);
      await select(const DestinationId.app(AppDestination.bookmarks));
      expect(find.byType(BookmarkPage), findsOneWidget);
      expect(find.byType(PostDetailsPageScaffold), findsNothing);
      expect(repository.bookmarks, hasLength(1));
      expect(tester.takeException(), isNull);
    },
  );
}
