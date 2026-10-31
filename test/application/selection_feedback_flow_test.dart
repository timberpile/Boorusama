import 'package:boorusama/core/configs/config/providers.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/configs/manage/providers.dart';
import 'package:boorusama/core/posts/favorites/src/data/providers.dart';
import 'package:boorusama/core/posts/favorites/src/data/repository.dart';
import 'package:boorusama/core/posts/favorites/types.dart';
import 'package:oktoast/oktoast.dart';
import 'package:boorusama/core/bookmarks/src/providers/bookmark_provider.dart';
import 'package:boorusama/core/bookmarks/src/widgets/bookmark_batch_dialog.dart';
import 'package:boorusama/core/bookmarks/src/widgets/bookmark_group_picker.dart';
import 'package:boorusama/core/navigation/navigation_chrome_controller.dart';
import 'package:boorusama/core/widgets/widgets.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart' show Icons;
import 'package:selection_mode/selection_mode.dart';
import 'package:flutter/gestures.dart';
import 'package:boorusama/core/settings/providers.dart';
import 'package:boorusama/core/settings/types.dart';

import 'support/app_flow_finders.dart';
import 'support/app_flow_driver.dart';
import 'support/headless_app_harness.dart';
import 'support/fake_booru_backend.dart';

void main() {
  testWidgets(
    'optional long press menu enters the same selection mode and toggles back live',
    (tester) async {
      final backend = FakeBooruBackend();
      final harness = await HeadlessAppHarness.mount(
        tester,
        booruBackend: backend,
        runtime: backend.createRuntime(
          settings: Settings.defaultSettings.copyWith(
            postLongPressContextMenu: true,
          ),
        ),
      );
      await harness.pumpUntilFound(tester, postTile(102));
      final selection = SelectionMode.of(tester.element(postTile(101)));
      final container = ProviderScope.containerOf(
        tester.element(postTile(101)),
      );
      await tester.longPress(postTile(101));
      await harness.settle(tester);
      expect(selection.isActive, isFalse);
      expect(find.byType(KurumiContextMenuTile), findsWidgets);
      final route = ModalRoute.of(tester.element(postTile(101)))!;
      expect(route.willHandlePopInternally, isTrue);
      await tester.binding.handlePopRoute();
      await harness.settle(tester);
      expect(route.willHandlePopInternally, isFalse);
      expect(find.byType(KurumiContextMenuTile), findsNothing);
      expect(postTile(101).hitTestable(), findsOneWidget);
      await tester.longPress(postTile(101));
      await harness.settle(tester);
      final select = find.text(appStrings(tester).generic.action.select);
      await tester.ensureVisible(select);
      await harness.settle(tester);
      expect(select.hitTestable(), findsOneWidget);
      await tester.tap(select);
      await harness.settle(tester);
      expect(selection.selection, {0});
      final gesture = await tester.startGesture(
        tester.getCenter(postTile(102)),
      );
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 10));
      await gesture.moveTo(tester.getCenter(postTile(101)));
      await tester.pump();
      await gesture.up();
      expect(selection.selection, {0, 1});
      expect(find.byType(KurumiContextMenuTile), findsNothing);
      selection.disable();
      expect(
        await container
            .read(settingsNotifierProvider.notifier)
            .updateWith((s) => s.copyWith(postLongPressContextMenu: false)),
        isTrue,
      );
      await harness.settle(tester);
      await tester.longPress(postTile(101));
      await harness.settle(tester);
      expect(selection.selection, {0});
      expect(find.byType(KurumiContextMenuTile), findsNothing);
    },
  );

  testWidgets('closed post menus do not start favorite status requests', (
    tester,
  ) async {
    var lookups = 0;
    final repo = FavoriteRepositoryBuilder(
      canFavorite: () => true,
      isFavorited: (_) => false,
      filter: (ids) async {
        lookups++;
        return [];
      },
      add: (_) async => AddFavoriteStatus.success,
      remove: (_) async => true,
    );
    final harness = await HeadlessAppHarness.mount(
      tester,
      additionalOverrides: [
        favoriteRepoProvider.overrideWith((ref, auth) => repo),
        booruLoginDetailsProvider.overrideWith(
          (ref, auth) => DefaultBooruLoginDetails(
            login: 'fixture',
            apiKey: 'fixture',
            url: auth.url,
          ),
        ),
      ],
    );
    await harness.pumpUntilFound(tester, postTile(102));
    await harness.settle(tester);
    expect(lookups, 0);
    final driver = AppFlowDriver(tester: tester, harness: harness);
    await driver.openPostMenu(101, via: PostMenuOpener.rightClick);
    await harness.pumpUntil(tester, () => lookups > 0);
    expect(find.text(appStrings(tester).post.action.favorite), findsOneWidget);
  });

  testWidgets(
    'bulk favorites stay direct, retry completed targets safely and retain selection',
    (tester) async {
      final added = <int>[];
      final removed = <int>[];
      var rejectSecond = true;
      final repo = FavoriteRepositoryBuilder(
        canFavorite: () => true,
        isFavorited: (_) => false,
        add: (id) async {
          added.add(id);
          if (id == 102 && rejectSecond) {
            rejectSecond = false;
            return AddFavoriteStatus.failure;
          }
          return AddFavoriteStatus.success;
        },
        remove: (id) async {
          removed.add(id);
          return true;
        },
      );
      final harness = await HeadlessAppHarness.mount(
        tester,
        viewportSize: kMobileViewport,
        additionalOverrides: [
          favoriteRepoProvider.overrideWith((ref, auth) => repo),
          booruLoginDetailsProvider.overrideWith(
            (ref, auth) => DefaultBooruLoginDetails(
              login: 'fixture',
              apiKey: 'fixture',
              url: auth.url,
            ),
          ),
        ],
      );
      await harness.pumpUntilFound(tester, postTile(102));
      final container = ProviderScope.containerOf(
        tester.element(postTile(101)),
      );
      final active = container.read(currentBooruConfigProvider);
      await tester.longPress(postTile(101));
      await harness.settle(tester);
      await tester.tap(postTile(102));
      await harness.settle(tester);
      final favorite = find.widgetWithText(
        MultiSelectButton,
        appStrings(tester).post.action.favorite,
      );
      expect(favorite.hitTestable(), findsOneWidget);
      expect(
        (tester.widget<MultiSelectButton>(favorite).icon as Icon).icon,
        Icons.favorite_border,
      );
      await tester.tap(favorite);
      await harness.pumpUntil(tester, () => added.length == 2);
      await harness.settle(tester);
      expect(SelectionMode.of(tester.element(postTile(101))).selection, {0, 1});
      await tester.tap(favorite);
      await harness.pumpUntil(tester, () => added.length == 3);
      await harness.settle(tester);
      expect(added, [101, 102, 102]);
      final unfavorite = find.widgetWithText(
        MultiSelectButton,
        appStrings(tester).post.action.unfavorite,
      );
      expect(unfavorite.hitTestable(), findsOneWidget);
      expect(
        (tester.widget<MultiSelectButton>(unfavorite).icon as Icon).icon,
        Icons.favorite,
      );
      await tester.tap(unfavorite);
      await harness.pumpUntil(tester, () => removed.length == 2);
      await harness.settle(tester);
      expect(removed, [101, 102]);
      expect(container.read(currentBooruConfigProvider), active);
      dismissAllToast();
      await tester.pump(const Duration(seconds: 4));
    },
  );

  testWidgets(
    'bookmark groups reserve navigation space and use collection actions',
    (tester) async {
      final harness = await HeadlessAppHarness.mount(
        tester,
        viewportSize: kMobileViewport,
      );
      await harness.pumpUntilFound(tester, postTile(101));
      final container = ProviderScope.containerOf(
        tester.element(postTile(101)),
      );
      final library = container.read(bookmarkProvider.notifier);
      await library.future;
      for (var i = 0; i < 8; i++) {
        await library.createGroup('Group $i');
      }
      await library.createGroup('Z final group');
      await tester.tap(find.byKey(const ValueKey('nav-shortcut-bookmarks')));
      await harness.settle(tester);
      final list = find.byType(Scrollable).hitTestable().last;
      await tester.scrollUntilVisible(
        find.text('Z final group'),
        400,
        scrollable: list,
      );
      await harness.settle(tester);
      final card = find
          .ancestor(
            of: find.text('Z final group'),
            matching: find.byType(DecoratedBox),
          )
          .first;
      final navigation = find.byKey(const ValueKey('nav-shortcut-bookmarks'));
      expect(
        tester.getRect(card).bottom,
        lessThanOrEqualTo(tester.getRect(navigation).top),
      );
      await tester.longPress(find.text('Z final group'));
      await harness.settle(tester);
      expect(find.byType(MultiSelectionActionBar), findsOneWidget);
      expect(
        find.widgetWithText(
          MultiSelectButton,
          appStrings(tester).bookmark.groups.rename,
        ),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(
          MultiSelectButton,
          appStrings(tester).bookmark.groups.duplicate,
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Z final group'));
      await harness.settle(tester);
      expect(find.byType(MultiSelectionActionBar), findsNothing);
    },
  );

  testWidgets('manual final deselection closes but All/None keeps empty mode', (
    tester,
  ) async {
    final harness = await HeadlessAppHarness.mount(
      tester,
      viewportSize: kMobileViewport,
    );
    await harness.pumpUntilFound(tester, postTile(101));
    final selection = SelectionMode.of(tester.element(postTile(101)));
    await tester.longPress(postTile(101));
    await harness.settle(tester);
    await tester.tap(postTile(101));
    await harness.settle(tester);
    expect(selection.isActive, isFalse);
    await tester.longPress(postTile(101));
    await harness.settle(tester);
    await tester.tap(find.byTooltip(appStrings(tester).select.select_all));
    await harness.settle(tester);
    await tester.tap(find.byTooltip(appStrings(tester).select.deselect_all));
    await harness.settle(tester);
    expect(selection.isActive, isTrue);
    expect(selection.selection, isEmpty);
    expect(find.byType(MultiSelectionActionBar), findsNothing);
  });

  testWidgets(
    'single selection uses one overflow and exposes Download directly',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        final harness = await HeadlessAppHarness.mount(
          tester,
          viewportSize: kMobileViewport,
        );
        await harness.pumpUntilFound(tester, postTile(101));
        await tester.longPress(postTile(101));
        await harness.settle(tester);
        final bar = find.byType(MultiSelectionActionBar);
        expect(
          find.bySemanticsLabel(appStrings(tester).post.action.bookmark),
          findsOneWidget,
        );
        expect(
          find
              .descendant(
                of: bar,
                matching: find.text(appStrings(tester).download.download),
              )
              .hitTestable(),
          findsOneWidget,
        );
        expect(
          find.byWidgetPredicate(
            (w) =>
                w is MultiSelectPopupButton &&
                w.name == appStrings(tester).generic.action.more,
          ),
          findsNothing,
        );
      } finally {
        semantics.dispose();
      }
    },
  );

  testWidgets(
    'selection hides navigation instantly and retains it through bookmark dialogs',
    (tester) async {
      final harness = await HeadlessAppHarness.mount(
        tester,
        viewportSize: kMobileViewport,
      );
      await harness.pumpUntilFound(tester, postTile(101));
      final container = ProviderScope.containerOf(
        tester.element(postTile(101)),
      );
      await tester.longPress(postTile(101));
      await harness.settle(tester);
      final slide = tester.widget<AnimatedSlide>(
        find
            .ancestor(
              of: find.byKey(const ValueKey('nav-shortcut-browse')),
              matching: find.byType(AnimatedSlide),
            )
            .first,
      );
      expect(slide.duration, Duration.zero);
      await tester.tap(
        find.widgetWithText(
          MultiSelectButton,
          appStrings(tester).post.action.bookmark,
        ),
      );
      await harness.settle(tester);
      expect(find.byType(BookmarkGroupPicker), findsOneWidget);
      expect(container.read(navigationChromeProvider).selectionActive, isTrue);
      await tester.binding.handlePopRoute();
      await harness.settle(tester);
      expect(find.byType(BookmarkGroupPicker), findsNothing);
      await tester.tap(postTile(102));
      await harness.settle(tester);
      await tester.tap(find.byKey(const Key('selection-batch-bookmarks')));
      await harness.settle(tester);
      await tester.tap(
        find.widgetWithText(
          KurumiPopupMenuItem,
          appStrings(tester).bookmark.bulk.add,
        ),
      );
      await harness.settle(tester);
      expect(find.byType(BookmarkBatchDialog), findsOneWidget);
      expect(container.read(navigationChromeProvider).selectionActive, isTrue);
    },
  );
}
