import 'package:boorusama/core/bookmarks/src/widgets/bookmark_folder_picker_contents.dart';
import 'package:boorusama/core/posts/related/related_posts_order.dart';
import 'package:boorusama/core/settings/src/types/settings_repository.dart';
import 'package:boorusama/core/posts/related/related_family.dart';
import 'package:boorusama/boorus/danbooru/posts/related/related_gallery.dart';
import 'package:boorusama/core/posts/listing/src/widgets/timeline_toolbar.dart';
import 'package:kurumi/kurumi.dart';
import 'package:boorusama/core/posts/details/src/widgets/viewer_entry_navigation_header.dart';
import 'package:boorusama/core/posts/listing/src/widgets/post_list_configuration_header.dart';
import 'package:boorusama/boorus/danbooru/pools/details/src/widgets/pool_order_selector.dart';
import 'package:boorusama/core/settings/types.dart';
import 'package:boorusama/core/posts/pools/widgets.dart';
import 'package:boorusama/core/bookmarks/src/pages/bookmark_details_page.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:boorusama/core/posts/details/src/widgets/viewer_entry_content.dart';
import 'package:boorusama/core/posts/details/widgets.dart';
import 'package:boorusama/core/posts/details_pageview/widgets.dart';
import 'package:boorusama/boorus/danbooru/danbooru_repository.dart';

import 'dart:io';

import 'package:boorusama/core/images/booru_image.dart';
import 'package:boorusama/core/errors/types.dart';
import 'package:boorusama/core/images/types.dart';
import 'package:boorusama/core/settings/providers.dart';
import 'package:boorusama/core/boorus/defaults/widgets.dart';
import 'package:boorusama/boorus/danbooru/posts/search/widgets.dart';
import 'package:boorusama/core/boorus/engine/providers.dart';
import 'package:boorusama/core/boorus/engine/types.dart';
import 'package:boorusama/boorus/danbooru/posts/search/src/widgets/search_series_grid.dart';
import 'package:boorusama/core/search/following_topics/src/widgets/feed_post_thumbnail.dart';

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:booru_clients/danbooru.dart' as api;
import 'package:boorusama/boorus/danbooru/client_provider.dart';
import 'package:boorusama/boorus/danbooru/pools/bookmarks.dart';
import 'package:boorusama/boorus/danbooru/pools/details/src/pool_detail_page.dart';
import 'package:boorusama/boorus/danbooru/pools/pool/types.dart';
import 'package:boorusama/core/blacklists/providers.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/bookmark_group_hive_object.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/bookmark_group_repository_hive.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/bookmark_hive_object.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/unified_bookmark_repository.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/unified_bookmark_group_repository.dart';
import 'package:boorusama/core/hive/hive_adapters.dart';
import 'package:boorusama/foundation/data_mutation_coordinator.dart';
import 'package:hive_ce/hive.dart';
import 'package:boorusama/core/bookmarks/src/providers/bookmark_picker_actions.dart';
import 'package:boorusama/core/bookmarks/src/providers/pool_bookmark_provider.dart';
import 'package:boorusama/core/bookmarks/src/providers/related_bookmark_provider.dart';
import 'package:boorusama/core/bookmarks/src/data/bookmark_collection_projection.dart';
import 'package:boorusama/core/bookmarks/src/services/bookmark_library_service.dart';
import 'package:boorusama/core/bookmarks/src/widgets/bookmark_group_picker.dart';
import 'package:boorusama/core/bookmarks/src/widgets/bookmark_multi_selection.dart';
import 'package:boorusama/core/bookmarks/src/widgets/bookmark_pool_card.dart';
import 'package:boorusama/core/bookmarks/src/widgets/bookmark_scroll_view.dart';
import 'package:boorusama/core/bookmarks/src/widgets/bookmark_search_bar.dart';
import 'package:boorusama/core/bookmarks/src/widgets/pool_bookmark_button.dart';
import 'package:boorusama/core/bookmarks/providers.dart';
import 'package:boorusama/core/bookmarks/types.dart';
import 'package:boorusama/core/content/types.dart';
import 'package:boorusama/core/configs/manage/providers.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/posts/listing/widgets.dart';
import 'package:boorusama/core/posts/listing/types.dart';
import 'package:boorusama/core/posts/post/providers.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/router.dart';
import 'package:boorusama/core/widgets/multi_select_button.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurumi/material.dart';
import 'package:oktoast/oktoast.dart';
import 'package:selection_mode/selection_mode.dart';
import 'package:i18n/i18n.dart';

import '../core/bookmarks/pool_bookmark_test_utils.dart';
import '../support/fakes/memory_repositories.dart';
import 'support/app_flow_driver.dart';
import 'support/app_flow_finders.dart';
import 'support/fake_booru_backend.dart';
import 'support/fake_image_dio.dart';
import 'support/headless_app_harness.dart';

void main() {
  testWidgets(
    'saved Related order survives reopening without changing global fallback',
    (tester) async {
      final repository = MemorySettingsRepository();
      final setup = await _mount(
        tester,
        seedRelated: true,
        settingsRepository: repository,
      );
      final harness = setup.harness;
      await AppFlowDriver(tester: tester, harness: harness).openBookmarks();
      await harness.pumpUntilFound(tester, find.byType(BookmarkPoolCard));
      await harness.settle(tester);
      final card = find.byType(BookmarkPoolCard);
      expect(
        find.byTooltip(tester.element(card).t.bookmark.pool_filter_help),
        findsNothing,
      );
      expect(
        tester
            .widget<PoolGridItem>(
              find.descendant(of: card, matching: find.byType(PoolGridItem)),
            )
            .name,
        isNull,
      );
      tester.widget<BookmarkPoolCard>(card).onOpen!();
      await harness.pumpUntilFound(tester, find.byType(RelatedGallery));
      await harness.settle(tester);
      Finder familyGallery() => find.byWidgetPredicate(
        (widget) =>
            widget is RelatedGallery && widget.entry.family.anchorId == 10,
      );
      PostGrid<Post>? maybeGallery() {
        if (familyGallery().evaluate().isEmpty) return null;
        final grids = find.descendant(
          of: familyGallery().last,
          matching: find.byType(PostGrid<Post>),
        );
        if (grids.evaluate().isEmpty) return null;
        return tester.widget<PostGrid<Post>>(grids.last);
      }

      PostGrid<Post> gallery() => maybeGallery()!;
      await harness.pumpUntil(
        tester,
        () => maybeGallery()?.controller.items.isNotEmpty ?? false,
      );
      final original = gallery().controller;
      expect(original.items.first.id, 10);
      gallery().selectionModeController!.enable(initialSelected: [0]);
      await harness.settle(tester);
      await tester.ensureVisible(find.text('Oldest').last);
      await tester.tap(find.text('Oldest').last);
      await harness.settle(tester);
      await tester.tap(find.text('Newest').last);
      await harness.settle(tester);
      await harness.pumpUntil(
        tester,
        () => gallery().controller.items.firstOrNull?.id == 129,
      );
      expect(gallery().selectionModeController!.isActive, isFalse);
      expect(
        repository.settings.relatedPostsOrder,
        RelatedPostsOrder.oldest,
      );
      expect(repository.settings.listing, Settings.defaultSettings.listing);
      await harness.pumpUntilComplete(
        tester,
        gallery().controller.fetchMore(),
      );
      expect(gallery().controller.items.map((p) => p.id).toList(), [
        for (var id = 129; id >= 10; id--) id,
      ]);
      await tester.tap(find.byIcon(Symbols.arrow_back_ios));
      await harness.pumpUntilFound(tester, find.byType(BookmarkPoolCard));
      tester.widget<BookmarkPoolCard>(find.byType(BookmarkPoolCard)).onOpen!();
      await harness.pumpUntilFound(tester, find.byType(RelatedGallery));
      await harness.pumpUntil(tester, () {
        final grid = maybeGallery();
        return grid?.controller.items.firstOrNull?.id == 129;
      });
      expect(repository.settings.relatedPostsOrder, RelatedPostsOrder.oldest);
      await _drainNotifications(tester);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'saved Related order is per family and picker carries the visible order',
    (tester) async {
      final repository = MemorySettingsRepository(
        Settings.defaultSettings.copyWith(
          relatedPostsOrder: RelatedPostsOrder.newest,
        ),
      );
      late _SavedRelatedOrderNotifier notifier;
      final setup = await _mount(
        tester,
        seedRelated: true,
        settingsRepository: repository,
        bookmarkNotifierFactory: (config) =>
            notifier = _SavedRelatedOrderNotifier(
              _savedRelatedState(
                config: config,
                firstOrder: RelatedPostsOrder.oldest,
                secondOrder: RelatedPostsOrder.oldest,
              ),
            ),
      );
      final harness = setup.harness;
      await AppFlowDriver(tester: tester, harness: harness).openBookmarks();
      await harness.pumpUntilFound(tester, find.byType(BookmarkPoolCard));
      await harness.settle(tester);
      final card = find.byWidgetPredicate(
        (widget) =>
            widget is BookmarkPoolCard &&
            widget.pool.isRelated &&
            widget.pool.referenceId == 10,
      );
      tester.widget<BookmarkPoolCard>(card).onOpen!();
      await harness.pumpUntilFound(tester, find.byType(RelatedGallery));
      await harness.settle(tester);
      Finder familyGallery() => find.byWidgetPredicate(
        (widget) =>
            widget is RelatedGallery && widget.entry.family.anchorId == 10,
      );
      PostGrid<Post>? maybeGallery() {
        if (familyGallery().evaluate().isEmpty) return null;
        final grids = find.descendant(
          of: familyGallery().last,
          matching: find.byType(PostGrid<Post>),
        );
        if (grids.evaluate().isEmpty) return null;
        return tester.widget<PostGrid<Post>>(grids.last);
      }

      PostGrid<Post> gallery() => maybeGallery()!;
      await harness.pumpUntil(
        tester,
        () => maybeGallery()?.controller.items.isNotEmpty ?? false,
      );
      expect(gallery().controller.items.first.id, 10);
      await tester.ensureVisible(find.text('Oldest').last);
      await tester.tap(find.text('Oldest').last);
      await harness.settle(tester);
      await tester.tap(find.text('Newest').last);
      await harness.pumpUntil(
        tester,
        () => gallery().controller.items.firstOrNull?.id == 129,
      );
      expect(notifier.orderUpdates, [(901, RelatedPostsOrder.newest)]);
      expect(repository.settings.relatedPostsOrder, RelatedPostsOrder.newest);
      expect(repository.savedSettings, isEmpty);

      final actions = BookmarkPickerActions(
        container: setup.container,
        request: RelatedBookmarkPickerRequest(
          config: harness.booruBackend.config,
          family: RelatedFamilyReference(
            origin: postOriginFromConfig(harness.booruBackend.config),
            anchorId: 10,
          ),
          visibleOrder: RelatedPostsOrder.newest,
        ),
        isActive: () => true,
      );
      await actions.toggle(poolGroupA, onRemoved: (_) {});
      expect(notifier.pickerOrder, RelatedPostsOrder.newest);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Related order rejects an old page completing after the order changes',
    (tester) async {
      final setup = await _mount(tester, seedRelated: true, relatedVisits: 0);
      final harness = setup.harness;
      for (final order in RelatedPostsOrder.values) {
        final ids = [for (var id = 10; id < 130; id++) id];
        harness.booruBackend.enqueuePostSuccess(
          siteUrl: harness.booruBackend.config.url,
          query: 'parent:10 ${order.queryOrder}',
          page: 1,
          result: PostResult(
            posts: (order == RelatedPostsOrder.oldest ? ids : ids.reversed)
                .take(60)
                .map((id) => testRelatedPost(id, parent: id == 10 ? null : 10))
                .toList(),
            total: 120,
            hasMore: true,
          ),
        );
      }
      await AppFlowDriver(tester: tester, harness: harness).openBookmarks();
      await harness.pumpUntilFound(tester, find.byType(BookmarkPoolCard));
      await harness.settle(tester);
      tester.widget<BookmarkPoolCard>(find.byType(BookmarkPoolCard)).onOpen!();
      await harness.pumpUntilFound(tester, find.byType(RelatedGallery));
      await harness.settle(tester);
      PostGrid<Post> gallery() => tester.widget<PostGrid<Post>>(
        find.descendant(
          of: find.byType(RelatedGallery),
          matching: find.byType(PostGrid<Post>),
        ),
      );
      await harness.pumpUntil(
        tester,
        () => gallery().controller.items.isNotEmpty,
      );
      final gate = harness.booruBackend.enqueuePostGate(
        siteUrl: harness.booruBackend.config.url,
        query: 'parent:10 order:id_asc',
        page: 2,
      );
      final pending = gallery().controller.fetchMore();
      await tester.pump();
      await tester.ensureVisible(find.text('Oldest').last);
      await tester.tap(find.text('Oldest').last);
      await harness.settle(tester);
      await tester.tap(find.text('Newest').last);
      await harness.pumpUntil(
        tester,
        () => gallery().controller.items.firstOrNull?.id == 129,
      );
      gate.completeSuccess(
        PostResult(
          posts: [testRelatedPost(42, parent: 10)],
          total: 1,
          hasMore: false,
        ),
      );
      await harness.pumpUntilComplete(tester, pending);
      expect(gallery().controller.items.first.id, 129);
      expect(gallery().controller.items, hasLength(60));
      expect(tester.takeException(), isNull);
    },
  );

  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'Related gallery restores member Back and guards selection at $scale text',
      (tester) async {
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final setup = await _mount(
          tester,
          seedReference: true,
          seedRelated: true,
          seedPosts: true,
          seedMixedSequence: true,
          viewportSize: const Size(320, 844),
        );
        final harness = setup.harness;
        await AppFlowDriver(tester: tester, harness: harness).openBookmarks();
        await harness.pumpUntilFound(tester, find.byType(BookmarkPoolCard));
        await harness.settle(tester);
        expect(
          harness.booruBackend.requests.whereType<FakeBooruPostRequest>().where(
            (r) => r.query == 'parent:10',
          ),
          isEmpty,
        );
        final related = find.byWidgetPredicate(
          (w) => w is BookmarkPoolCard && w.pool.isRelated,
        );
        tester.widget<BookmarkPoolCard>(related).onOpen!();
        await harness.pumpUntilFound(tester, find.byType(RelatedGallery));
        await harness.settle(tester);
        final pager = tester
            .widget<PostDetailsPageView>(find.byType(PostDetailsPageView))
            .controller!;
        expect(pager.totalPage, 6);
        expect(pager.page, 2);
        final gallery = tester.widget<PostGrid<Post>>(
          find.descendant(
            of: find.byType(RelatedGallery),
            matching: find.byType(PostGrid<Post>),
          ),
        );
        await harness.pumpUntil(
          tester,
          () => gallery.controller.items.length == 60,
        );
        await harness.pumpUntilComplete(tester, gallery.controller.fetchMore());
        expect(gallery.controller.items.length, 120);
        expect(gallery.controller.hasMore, isFalse);
        expect(
          find.byTooltip('Bookmark Related').hitTestable(),
          findsOneWidget,
        );
        final source = ProviderScope.containerOf(
          tester.element(find.byType(RelatedGallery)),
          listen: false,
        ).read(currentReadOnlyBooruConfigProvider);
        expect(source.id, harness.booruBackend.config.id);
        gallery.scrollController!.jumpTo(700);
        await harness.settle(tester);
        expect(find.byTooltip('Bookmark Related').hitTestable(), findsNothing);
        final tile = find
            .descendant(
              of: find.byType(RelatedGallery),
              matching: find.byType(SliverPostGridImageGridItem),
            )
            .hitTestable()
            .first;
        await tester.longPress(tile);
        await harness.settle(tester);
        final selection = SelectionMode.of(tester.element(tile));
        expect(selection.isActive, isTrue);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.drag(find.byType(PageView).first, const Offset(-280, 0));
        await harness.settle(tester);
        expect(pager.page, 2);
        selection.disable();
        await harness.settle(tester);
        final offset = gallery.scrollController!.offset;
        await tester.tap(tile);
        await harness.pumpUntil(
          tester,
          () => find.byType(BookmarkDetailsPage).evaluate().isEmpty,
        );
        await harness.settle(tester);
        expect(find.byType(MixedPostDetailsPage), findsOneWidget);
        await tester.tap(find.byIcon(Symbols.arrow_back_ios));
        await harness.pumpUntilFound(tester, find.byType(BookmarkDetailsPage));
        await harness.settle(tester);
        expect(pager.page, 2);
        expect(gallery.scrollController!.offset, offset);
        FocusManager.instance.primaryFocus?.unfocus();
        pager.jumpToPage(5);
        await harness.settle(tester);
        pager.jumpToPage(2);
        await harness.pumpUntilFound(tester, find.byType(RelatedGallery));
        await harness.settle(tester);
        final restored = tester.widget<PostGrid<Post>>(
          find.descendant(
            of: find.byType(RelatedGallery),
            matching: find.byType(PostGrid<Post>),
          ),
        );
        await harness.pumpUntil(
          tester,
          () => restored.controller.items.isNotEmpty,
        );
        await harness.settle(tester);
        expect(restored.scrollController!.offset, offset);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'Related group picker membership removal and Undo leave Post bookmarks intact',
    (tester) async {
      final setup = await _mount(tester, seedRelated: true, seedPosts: true);
      final harness = setup.harness;
      await AppFlowDriver(tester: tester, harness: harness).openBookmarks();
      await harness.pumpUntilFound(tester, find.byType(BookmarkPoolCard));
      await harness.settle(tester);
      tester.widget<BookmarkPoolCard>(find.byType(BookmarkPoolCard)).onOpen!();
      await harness.pumpUntilFound(tester, find.byType(RelatedGallery));
      await harness.settle(tester);
      double? bookmarkFill() => tester
          .widget<Icon>(
            find.descendant(
              of: find.byTooltip('Bookmark Related'),
              matching: find.byType(Icon),
            ),
          )
          .fill;
      expect(bookmarkFill(), 1);
      await tester.tap(find.byTooltip('Bookmark Related'));
      await harness.pumpUntilFound(tester, find.byType(BookmarkGroupPicker));
      await harness.settle(tester);
      final targetRow = find
          .ancestor(
            of: find.text('Pool target'),
            matching: find.byType(BookmarkPickerSplitRow),
          )
          .first;
      final targetBounds = tester.getRect(targetRow);
      await tester.tapAt(
        Offset(
          targetBounds.left + targetBounds.width * .4,
          targetBounds.center.dy,
        ),
      );
      await harness.pumpUntil(
        tester,
        () =>
            setup.container.read(bookmarkProvider).valueOrNull?.pools.isEmpty ??
            false,
      );
      expect(bookmarkFill(), 0);
      expect(setup.postRows.values, hasLength(3));
      await harness.pumpUntilFound(tester, find.text('Undo'));
      await tester.tap(find.text('Undo'));
      await harness.pumpUntil(
        tester,
        () =>
            setup.container.read(bookmarkProvider).valueOrNull?.pools.length ==
            1,
      );
      await harness.settle(tester);
      expect(bookmarkFill(), 1);
      expect(setup.postRows.values, hasLength(3));
      expect(
        setup.container
            .read(bookmarkProvider)
            .valueOrNull!
            .pools
            .single
            .family!
            .anchorId,
        10,
      );
      await _drainNotifications(tester);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'unavailable Related family keeps its reference and surrounding navigation',
    (tester) async {
      final setup = await _mount(
        tester,
        seedRelated: true,
        emptyRelated: true,
        seedPosts: true,
      );
      final harness = setup.harness;
      await AppFlowDriver(tester: tester, harness: harness).openBookmarks();
      await harness.pumpUntilFound(tester, find.byType(BookmarkPoolCard));
      await harness.settle(tester);
      tester.widget<BookmarkPoolCard>(find.byType(BookmarkPoolCard)).onOpen!();
      await harness.pumpUntilFound(tester, find.byType(RelatedGallery));
      await harness.pumpUntilFound(
        tester,
        find.text('Related family unavailable'),
      );
      await harness.settle(tester);
      expect(find.text('Retry').hitTestable(), findsOneWidget);
      await tester.tap(find.text('Retry'));
      await harness.settle(tester);
      expect(
        setup.container.read(bookmarkProvider).valueOrNull!.pools,
        hasLength(1),
      );
      final pager = tester
          .widget<PostDetailsPageView>(find.byType(PostDetailsPageView))
          .controller!;
      pager.jumpToPage(0);
      await harness.settle(tester);
      expect(currentDetailPost(tester).id, 103);
      expect(tester.takeException(), isNull);
    },
  );

  for (final exit in ['cancel', 'remove profile']) {
    testWidgets('pending Related picker rejects writes after $exit', (
      tester,
    ) async {
      final draftGate = Completer<CollectionBookmark>();
      final setup = await _mount(
        tester,
        seedRelated: true,
        relatedVisits: 1,
        relatedDraftGate: draftGate,
      );
      final harness = setup.harness;
      final backend = harness.booruBackend;
      final groupRepo = await setup.container.read(
        bookmarkGroupRepoProvider.future,
      );
      await AppFlowDriver(tester: tester, harness: harness).openBookmarks();
      await harness.pumpUntilFound(tester, find.byType(BookmarkPoolCard));
      await harness.settle(tester);
      tester.widget<BookmarkPoolCard>(find.byType(BookmarkPoolCard)).onOpen!();
      await harness.pumpUntilFound(tester, find.byType(RelatedGallery));
      await harness.settle(tester);
      await harness.pumpUntilComplete(
        tester,
        setup.container
            .read(bookmarkProvider.notifier)
            .removePostsFromGroup(
              backend.config.auth,
              [],
              poolGroupA,
              poolLocalIds: {
                setup.container
                    .read(bookmarkProvider)
                    .requireValue
                    .pools
                    .single
                    .localId,
              },
            ),
      );
      await tester.tap(find.byTooltip('Bookmark Related'));
      await harness.pumpUntilFound(tester, find.byType(BookmarkGroupPicker));
      await harness.settle(tester);
      expect(draftGate.isCompleted, isFalse);
      final targetRow = find
          .ancestor(
            of: find.text('Pool target'),
            matching: find.byType(BookmarkPickerSplitRow),
          )
          .first;
      final targetBounds = tester.getRect(targetRow);
      await tester.tapAt(
        Offset(
          targetBounds.left + targetBounds.width * .4,
          targetBounds.center.dy,
        ),
      );
      await tester.pump();
      if (exit == 'cancel') {
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      } else {
        await setup.container
            .read(booruConfigProvider.notifier)
            .delete(backend.config);
      }
      draftGate.complete(_summaryRelatedDraft(backend.config));
      await harness.settle(tester);
      expect(await groupRepo.getPoolBookmarks(), isEmpty);
      expect(setup.postRows.values, isEmpty);
      if (exit != 'cancel') {
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await harness.settle(tester);
        expect(find.byType(RelatedGallery), findsNothing);
      }
      await _drainNotifications(tester);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'Related picker creates a destination with enlarged text and keyboard open',
    (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final setup = await _mount(
        tester,
        seedRelated: true,
        viewportSize: const Size(320, 844),
      );
      final harness = setup.harness;
      await AppFlowDriver(tester: tester, harness: harness).openBookmarks();
      await harness.pumpUntilFound(tester, find.byType(BookmarkPoolCard));
      await harness.settle(tester);
      tester.widget<BookmarkPoolCard>(find.byType(BookmarkPoolCard)).onOpen!();
      await harness.pumpUntilFound(tester, find.byType(RelatedGallery));
      await harness.settle(tester);
      await harness.pumpUntilComplete(
        tester,
        setup.container
            .read(bookmarkProvider.notifier)
            .removePostsFromGroup(
              harness.booruBackend.config.auth,
              [],
              poolGroupA,
              poolLocalIds: {
                setup.container
                    .read(bookmarkProvider)
                    .requireValue
                    .pools
                    .single
                    .localId,
              },
            ),
      );
      await tester.tap(find.byTooltip('Bookmark Related'));
      await harness.pumpUntilFound(tester, find.byType(BookmarkGroupPicker));
      await harness.settle(tester);
      await tester.tap(
        find.byKey(const ValueKey('bookmark-picker-create-group')),
      );
      await harness.pumpUntilFound(tester, find.byType(TextField));
      await tester.enterText(find.byType(TextField), 'Related review');
      await harness.settle(tester);
      expect(tester.testTextInput.isVisible, isTrue);
      expect(find.text('Save').hitTestable(), findsOneWidget);
      await tester.tap(find.text('Save'));
      await harness.pumpUntil(
        tester,
        () =>
            setup.container.read(bookmarkProvider).valueOrNull?.pools.length ==
            1,
      );
      final library = setup.container.read(bookmarkProvider).requireValue;
      final group = library.groups.singleWhere(
        (g) => g.name == 'Related review',
      );
      expect(library.pools.single.groupIds, contains(group.id));
      expect(library.pools.single.family!.anchorId, 10);
      expect(setup.postRows.values, isEmpty);
      await _drainNotifications(tester);
      expect(tester.takeException(), isNull);
    },
  );

  for (final size in [
    const Size(320, 844),
    const Size(390, 844),
    const Size(844, 390),
    const Size(1280, 800),
  ]) {
    for (final scale in [1.0, 2.0]) {
      for (final pinned in [false, true]) {
        testWidgets(
          'Pool Variant A floats without overlap at $size $scale text pinned=$pinned',
          (tester) async {
            tester.platformDispatcher.textScaleFactorTestValue = scale;
            addTearDown(
              tester.platformDispatcher.clearTextScaleFactorTestValue,
            );
            final setup = await _mount(
              tester,
              seedReference: true,
              seedPosts: true,
              seedMixedSequence: true,
              longGallery: true,
              galleryMemberCount: 120,
              viewportSize: size,
              keepTimelineVisible: pinned,
            );
            final harness = setup.harness;
            await AppFlowDriver(
              tester: tester,
              harness: harness,
            ).openBookmarks();
            await harness.pumpUntilFound(tester, find.byType(BookmarkPoolCard));
            await harness.settle(tester);
            // Exercise the projected viewer route independently of the origin
            // grid's available card height in landscape or enlarged text.
            tester
                .widget<BookmarkPoolCard>(find.byType(BookmarkPoolCard).first)
                .onOpen!();
            await harness.pumpUntilFound(
              tester,
              find.byType(PoolDetailContent),
            );
            await harness.settle(tester);
            final content = find.byType(PoolDetailContent);
            Finder inside(Finder finder) =>
                find.descendant(of: content, matching: finder);
            final back = inside(find.byIcon(Symbols.arrow_back_ios));
            final actionBar = inside(find.byType(NavigationToolbar));
            final timeline = inside(find.byType(PostListConfigurationHeader));
            final selector = inside(find.byType(PoolOrderSelector));
            final grid = tester.widget<PostGrid<Post>>(
              inside(find.byType(PostGrid<Post>)),
            );
            await harness.pumpUntil(
              tester,
              () => grid.controller.items.length >= 60,
            );
            await harness.settle(tester);
            expect(back.hitTestable(), findsOneWidget);
            expect(inside(find.byType(PoolBookmarkButton)), findsOneWidget);
            expect(inside(find.byIcon(Symbols.search)), findsOneWidget);
            expect(inside(find.byIcon(Symbols.download)), findsOneWidget);
            expect(find.byType(PoolOrderToggle), findsNothing);
            final bar = tester.getRect(actionBar);
            final title = tester.getRect(inside(find.text('Series 10')));
            expect(bar.height, 56);
            expect(title.top - bar.bottom, closeTo(8, 1));
            expect(
              tester.getRect(timeline).top - title.bottom,
              lessThan(70 * scale),
            );
            if (scale == 1) {
              expect(
                tester.getTopLeft(inside(postTile(101))).dy,
                lessThan(260),
              );
            }
            final header = inside(find.byType(ViewerEntryNavigationHeader));
            final targets =
                [
                      ...find
                          .descendant(
                            of: header,
                            matching: find.byType(KurumiCircularIconButton),
                          )
                          .evaluate(),
                      ...find
                          .descendant(
                            of: header,
                            matching: find.byType(IconButton),
                          )
                          .evaluate(),
                    ]
                    .map(
                      (element) => tester.getRect(
                        find.byElementPredicate((e) => identical(e, element)),
                      ),
                    )
                    .toList();
            expect(targets, hasLength(4));
            for (var i = 0; i < targets.length; i++) {
              expect(targets[i].width, greaterThanOrEqualTo(48));
              expect(targets[i].height, greaterThanOrEqualTo(48));
              expect(targets[i].left, greaterThanOrEqualTo(0));
              expect(targets[i].right, lessThanOrEqualTo(size.width));
              for (var j = i + 1; j < targets.length; j++) {
                expect(targets[i].overlaps(targets[j]), isFalse);
              }
            }
            grid.scrollController!.jumpTo(1000);
            await harness.settle(tester);
            expect(back.hitTestable(), findsNothing);
            expect(
              timeline.hitTestable(),
              pinned ? findsOneWidget : findsNothing,
            );
            if (pinned) {
              final controls = inside(find.byType(TimelineToolbar));
              expect(
                tester.getTopLeft(controls).dy,
                greaterThanOrEqualTo(
                  tester.view.padding.top / tester.view.devicePixelRatio,
                ),
              );
            }
            final vertical = find
                .descendant(
                  of: content,
                  matching: find.byWidgetPredicate(
                    (widget) =>
                        widget is Scrollable &&
                        widget.axisDirection == AxisDirection.down,
                  ),
                )
                .first;
            await tester.drag(vertical, const Offset(0, 80));
            await harness.settle(tester);
            expect(back.hitTestable(), findsOneWidget);
            expect(timeline.hitTestable(), findsOneWidget);
            expect(
              tester.widget<AppBar>(inside(find.byType(AppBar))).toolbarOpacity,
              1,
            );
            expect(
              tester.getTopLeft(timeline).dy,
              greaterThanOrEqualTo(tester.getBottomLeft(actionBar).dy),
            );
            expect(grid.scrollController!.offset, greaterThan(bar.height * 2));
            final overflow = inside(
              find.byWidgetPredicate(
                (widget) => widget is PostGridConfigIconButton,
              ),
            );
            final overflowBounds = tester.getRect(overflow);
            final horizontal = inside(
              find.byKey(const ValueKey('timeline-toolbar-content')),
            );
            final horizontalState = tester.state<ScrollableState>(
              find
                  .descendant(of: horizontal, matching: find.byType(Scrollable))
                  .first,
            );
            // Only an overflowing toolbar owns horizontal scrolling. At wider
            // widths the same gesture correctly belongs to the outer pager.
            if (horizontalState.position.maxScrollExtent > 0) {
              await tester.drag(horizontal, const Offset(-500, 0));
              await harness.settle(tester);
              expect(horizontalState.position.pixels, greaterThan(0));
            }
            expect(tester.getRect(overflow), overflowBounds);
            expect(overflow.hitTestable(), findsOneWidget);
            await tester.ensureVisible(selector);
            await tester.tap(selector);
            await harness.settle(tester);
            expect(find.text('Latest').hitTestable(), findsOneWidget);
            expect(find.text('Oldest').hitTestable(), findsOneWidget);
            await tester.tap(find.text('Latest'));
            await harness.settle(tester);
            expect(
              tester.widget<PoolOrderSelector>(selector).value,
              PoolDetailsOrder.latest,
            );
            expect(grid.scrollController!.offset, 0);
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }

  testWidgets(
    'long Pool title wraps with one status inset and no empty metadata gap',
    (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final setup = await _mount(
        tester,
        longGallery: true,
        viewportSize: const Size(320, 844),
      );
      const title =
          'Original - A long Collection title that remains completely readable (Artist Name)';
      unawaited(
        setup.container
            .read(routerProvider)
            .push(
              '/danbooru/pools/10',
              extra: (
                pool: _pool(name: title, includeUpdated: false),
                config: setup.harness.booruBackend.config,
              ),
            ),
      );
      await setup.harness.pumpUntilFound(
        tester,
        find.byType(PoolDetailContent),
      );
      await setup.harness.settle(tester);
      final bar = tester.getRect(find.byType(NavigationToolbar).last);
      final heading = find.text(title);
      expect(bar.top, tester.view.padding.top / tester.view.devicePixelRatio);
      expect(tester.getRect(heading).top - bar.bottom, 8);
      expect(tester.getRect(heading).height, greaterThan(100));
      expect(tester.widget<Text>(heading).maxLines, isNull);
      final timeline = find.descendant(
        of: find.byType(PoolDetailContent),
        matching: find.byType(PostListConfigurationHeader),
      );
      final longGrid = tester.widget<PostGrid<Post>>(
        find.byType(PostGrid<Post>).last,
      );
      longGrid.scrollController!.jumpTo(tester.getRect(heading).height);
      await setup.harness.settle(tester);
      await setup.harness.pumpUntilFound(tester, timeline);
      await setup.harness.settle(tester);
      expect(
        tester.getTopLeft(timeline).dy - tester.getBottomLeft(heading).dy,
        closeTo(8, 1),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'standalone Collection uses the same compact action header and sort toolbar',
    (tester) async {
      final setup = await _mount(tester, longGallery: true);
      final harness = setup.harness;
      setup.container
          .read(routerProvider)
          .push(
            '/danbooru/pools/20',
            extra: (
              pool: _pool(category: DanbooruPoolCategory.collection)
                  .copyWith(id: 20),
              config: harness.booruBackend.config,
            ),
          );
      await harness.pumpUntilFound(tester, find.byType(PoolDetailContent));
      await harness.settle(tester);
      expect(find.byType(ViewerEntryNavigationHeader), findsOneWidget);
      expect(find.byType(PoolOrderSelector), findsOneWidget);
      expect(find.text('Pool'), findsNothing);
      expect(find.byType(PoolOrderToggle), findsNothing);
      await tester.tap(find.byIcon(Symbols.arrow_back_ios));
      await harness.settle(tester);
      expect(find.byType(PoolDetailContent), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'an evicted long gallery restores beyond the first loaded member page',
    (tester) async {
      final setup = await _mount(
        tester,
        seedReference: true,
        seedPosts: true,
        seedMixedSequence: true,
        memberPageSize: 2,
      );
      final harness = setup.harness;
      for (var start = 101; start < 121; start += 2) {
        for (var repeat = 0; repeat < 2; repeat++) {
          harness.booruBackend.enqueuePosts(
            page: 1,
            query: 'id:$start,${start + 1}',
            posts: [
              TestPost(id: start),
              TestPost(id: start + 1),
            ],
          );
        }
      }
      await AppFlowDriver(tester: tester, harness: harness).openBookmarks();
      await harness.pumpUntilFound(tester, find.byType(BookmarkPoolCard));
      await harness.settle(tester);
      await tester.tap(find.byType(BookmarkPoolCard).first);
      await harness.pumpUntilFound(tester, find.byType(PoolDetailContent));
      await harness.settle(tester);
      final pager = tester
          .widget<PostDetailsPageView>(find.byType(PostDetailsPageView))
          .controller!;
      PostGrid<Post> gallery() => tester.widget<PostGrid<Post>>(
        find.descendant(
          of: find.byType(PoolDetailContent),
          matching: find.byType(PostGrid<Post>),
        ),
      );
      final firstPageExtent =
          gallery().scrollController!.position.maxScrollExtent;
      for (var i = 0; i < 3; i++)
        await harness.pumpUntilComplete(
          tester,
          gallery().controller.fetchMore(),
        );
      final previous = gallery().scrollController!;
      previous.jumpTo(previous.position.maxScrollExtent * .8);
      await harness.settle(tester);
      final offset = previous.offset;
      final visitedPage = gallery().controller.page;
      expect(offset, greaterThan(firstPageExtent + 1));
      FocusManager.instance.primaryFocus?.unfocus();
      pager.jumpToPage(4);
      await harness.settle(tester);
      expect(find.byType(PoolDetailContent), findsNothing);
      pager.jumpToPage(1);
      await harness.pumpUntilFound(tester, find.byType(PoolDetailContent));
      await harness.settle(tester);
      expect(gallery().scrollController, isNot(same(previous)));
      await harness.pumpUntil(
        tester,
        () => (gallery().scrollController!.offset - offset).abs() < 1,
      );
      expect(gallery().scrollController!.offset, closeTo(offset, 1));
      expect(gallery().controller.page, lessThanOrEqualTo(visitedPage));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Search viewer reuses frozen Series entries while live results append',
    (tester) async {
      final setup = await _mount(
        tester,
        realSearch: true,
        seriesMembers: [101, 102],
      );
      final harness = setup.harness;
      final backend = harness.booruBackend;
      backend.enqueuePosts(
        page: 1,
        query: 'mixed',
        posts: [
          for (var id = 101; id <= 105; id++) TestPost(id: id),
        ],
        hasMore: true,
      );
      final next = backend.enqueuePostGate(
        query: 'mixed',
        page: 2,
        siteUrl: backend.config.url,
      );
      final driver = AppFlowDriver(tester: tester, harness: harness);
      await driver.openSearch();
      await driver.submitSearch('mixed');
      await harness.pumpUntilFound(tester, find.byType(PoolGridItem));
      await harness.settle(tester);
      final grid = tester.widget<SearchSeriesGrid>(
        find.byType(SearchSeriesGrid),
      );
      await tester.tap(find.byType(PoolGridItem).first);
      await harness.pumpUntilFound(tester, find.byType(PoolDetailContent));
      await harness.settle(tester);
      final pager = tester
          .widget<PostDetailsPageView>(find.byType(PostDetailsPageView))
          .controller!;
      expect(pager.page, 0);
      expect(pager.totalPage, 4);
      // Raw 101/102 occupy one Series entry; 103 is the next displayed page.
      pager.jumpToPage(1);
      await harness.settle(tester);
      expect(currentDetailPost(tester).id, 103);
      pager.jumpToPage(3);
      await harness.pumpUntil(
        tester,
        () => backend.requests.whereType<FakeBooruPostRequest>().any(
          (r) => r.query == 'mixed' && r.page == 2 && r.pending,
        ),
      );
      next.completeSuccess(
        PostResult(
          posts: [TestPost(id: 106), TestPost(id: 107)],
          total: 7,
          hasMore: false,
        ),
      );
      await harness.pumpUntil(tester, () => pager.totalPage == 6);
      await harness.settle(tester);
      expect(pager.page, 3);
      expect(currentDetailPost(tester).id, 105);
      pager.jumpToPage(4);
      await harness.settle(tester);
      expect(currentDetailPost(tester).id, 106);
      expect(grid.controller.items, hasLength(7));
      backend.enqueuePosts(
        page: 1,
        query: 'mixed',
        posts: [TestPost(id: 108), TestPost(id: 109)],
        hasMore: false,
      );
      await harness.pumpUntilComplete(tester, grid.controller.refresh());
      expect(pager.totalPage, 6);
      expect(pager.page, 4);
      expect(currentDetailPost(tester).id, 106);
      await tester.tap(find.byIcon(Symbols.arrow_back_ios));
      await harness.pumpUntilFound(tester, find.byType(SearchSeriesGrid));
      await harness.settle(tester);
      expect(grid.controller.items.map((p) => p.id), [108, 109]);
      expect(find.byType(PoolGridItem), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('unavailable Pool retries without losing its mixed sequence', (
    tester,
  ) async {
    final setup = await _mount(
      tester,
      seedReference: true,
      seedPosts: true,
      seedMixedSequence: true,
    );
    final harness = setup.harness;
    setup.adapter.poolFailures = 1;
    await AppFlowDriver(tester: tester, harness: harness).openBookmarks();
    await harness.pumpUntilFound(tester, find.byType(BookmarkPoolCard));
    await harness.settle(tester);
    await tester.tap(find.byType(BookmarkPoolCard).first);
    await harness.pumpUntilFound(tester, find.text('Retry'));
    await harness.settle(tester);
    expect(find.byIcon(Symbols.arrow_back_ios).hitTestable(), findsOneWidget);
    expect(find.byType(PoolBookmarkButton).hitTestable(), findsOneWidget);
    expect(find.byIcon(Symbols.search).hitTestable(), findsOneWidget);
    expect(find.byIcon(Symbols.download).hitTestable(), findsOneWidget);
    final pager = tester
        .widget<PostDetailsPageView>(find.byType(PostDetailsPageView))
        .controller!;
    expect(pager.page, 1);
    expect(pager.totalPage, 5);
    await tester.tap(find.text('Retry'));
    await harness.pumpUntilFound(tester, find.byType(PoolDetailContent));
    await harness.settle(tester);
    expect(pager.page, 1);
    pager.jumpToPage(2);
    await harness.settle(tester);
    expect(currentDetailPost(tester).id, 102);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'removing the origin cancels pending gallery metadata and keeps outer navigation',
    (tester) async {
      final setup = await _mount(
        tester,
        seedReference: true,
        seedPosts: true,
        seedMixedSequence: true,
      );
      final harness = setup.harness;
      setup.adapter.poolGate = Completer<void>();
      await AppFlowDriver(tester: tester, harness: harness).openBookmarks();
      await harness.pumpUntilFound(tester, find.byType(BookmarkPoolCard));
      await harness.settle(tester);
      await tester.tap(find.byType(BookmarkPoolCard).first);
      await harness.pumpUntil(
        tester,
        () => setup.adapter.requests.any((r) => r.path == '/pools/10.json'),
      );
      await harness.settle(tester);
      expect(find.byIcon(Symbols.arrow_back_ios).hitTestable(), findsOneWidget);
      expect(find.byType(PoolBookmarkButton).hitTestable(), findsOneWidget);
      final pager = tester
          .widget<PostDetailsPageView>(find.byType(PostDetailsPageView))
          .controller!;
      await setup.container
          .read(booruConfigProvider.notifier)
          .delete(harness.booruBackend.config);
      await harness.pumpUntil(tester, () => setup.adapter.poolCancelled);
      await harness.settle(tester);
      expect(find.byIcon(Symbols.arrow_back_ios).hitTestable(), findsOneWidget);
      expect(find.byType(PoolBookmarkButton).hitTestable(), findsNothing);
      if (!setup.adapter.poolGate!.isCompleted) {
        setup.adapter.poolGate!.complete();
      }
      await harness.settle(tester);
      expect(find.byType(PoolDetailContent), findsNothing);
      expect(pager.page, 1);
      expect(pager.totalPage, 5);
      pager.jumpToPage(4);
      await harness.settle(tester);
      expect(pager.page, 4);
      expect(
        setup.adapter.requests.where((r) => r.path == '/pools/10.json'),
        hasLength(1),
      );
      expect(tester.takeException(), isNull);
    },
  );

  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'mixed Bookmark sequence restores gallery after member Back at $scale text',
      (tester) async {
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final setup = await _mount(
          tester,
          seedReference: true,
          seedPosts: true,
          seedMixedSequence: true,
          longGallery: true,
        );
        final harness = setup.harness;
        final driver = AppFlowDriver(tester: tester, harness: harness);
        await driver.openBookmarks();
        await harness.pumpUntilFound(tester, find.byType(BookmarkPoolCard));
        await harness.settle(tester);
        // The stored dates interleave Posts and group references deliberately.
        await tester.tap(postTile(103));
        await harness.pumpUntilFound(tester, find.byType(BookmarkDetailsPage));
        await harness.settle(tester);
        final pager = tester
            .widget<PostDetailsPageView>(find.byType(PostDetailsPageView))
            .controller!;
        expect(pager.totalPage, 5);
        expect(pager.page, 0);
        expect(currentDetailPost(tester).id, 103);
        await tester.drag(find.byType(PageView).first, const Offset(-280, 0));
        await harness.pumpUntilFound(tester, find.byType(PoolDetailContent));
        await harness.settle(tester);
        expect(pager.page, 1);
        expect(
          tester
              .widget<PoolDetailContent>(find.byType(PoolDetailContent))
              .pool
              .id,
          10,
        );
        final gallery = tester.widget<PostGrid<Post>>(
          find.descendant(
            of: find.byType(PoolDetailContent),
            matching: find.byType(PostGrid<Post>),
          ),
        );
        await harness.pumpUntil(
          tester,
          () => gallery.controller.items.length == 20,
        );
        gallery.scrollController!.jumpTo(150);
        await harness.settle(tester);
        final firstMember = find
            .descendant(
              of: find.byType(PoolDetailContent),
              matching: find.byType(SliverPostGridImageGridItem),
            )
            .first;
        await tester.ensureVisible(firstMember);
        await tester.longPress(firstMember);
        await harness.settle(tester);
        final selection = SelectionMode.of(tester.element(firstMember));
        expect(selection.isActive, isTrue);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.drag(find.byType(PageView).first, const Offset(-280, 0));
        await harness.settle(tester);
        expect(pager.page, 1);
        selection.disable();
        await harness.settle(tester);
        final scroll = gallery.scrollController!;
        scroll.jumpTo(150);
        await harness.settle(tester);
        final offset = scroll.offset;
        final member = find
            .descendant(
              of: find.byType(PoolDetailContent),
              matching: find.byType(SliverPostGridImageGridItem),
            )
            .first;
        await tester.tap(member);
        await harness.pumpUntil(
          tester,
          () => find.byType(BookmarkDetailsPage).evaluate().isEmpty,
        );
        await harness.settle(tester);
        expect(find.byType(MixedPostDetailsPage), findsOneWidget);
        final beforeShortcut = harness.booruBackend.requests
            .whereType<FakeBooruPostRequest>()
            .where((r) => r.query.startsWith('id:'))
            .length;
        await tester.sendKeyEvent(LogicalKeyboardKey.f5);
        await harness.settle(tester);
        expect(
          harness.booruBackend.requests.whereType<FakeBooruPostRequest>().where(
            (r) => r.query.startsWith('id:'),
          ),
          hasLength(beforeShortcut),
        );
        await tester.tap(find.byIcon(Symbols.arrow_back_ios));
        await harness.pumpUntilFound(tester, find.byType(BookmarkDetailsPage));
        await harness.settle(tester);
        expect(pager.page, 1);
        expect(scroll.offset, offset);
        harness.booruBackend.enqueuePosts(
          page: 1,
          query: 'id:${[for (var id = 101; id <= 120; id++) id].join(',')}',
          posts: [for (var id = 101; id <= 120; id++) TestPost(id: id)],
        );
        FocusManager.instance.primaryFocus?.unfocus();
        pager.jumpToPage(4);
        await harness.settle(tester);
        expect(find.byType(PoolDetailContent), findsNothing);
        pager.jumpToPage(1);
        await harness.pumpUntilFound(tester, find.byType(PoolDetailContent));
        await harness.settle(tester);
        final restoredGallery = tester.widget<PostGrid<Post>>(
          find.descendant(
            of: find.byType(PoolDetailContent),
            matching: find.byType(PostGrid<Post>),
          ),
        );
        await harness.pumpUntil(
          tester,
          () => restoredGallery.controller.items.length == 20,
        );
        await harness.settle(tester);
        expect(restoredGallery.scrollController, isNot(same(scroll)));
        expect(restoredGallery.scrollController!.offset, offset);
        restoredGallery.scrollController!.jumpTo(0);
        await harness.settle(tester);
        await tester.ensureVisible(find.byType(PoolOrderSelector));
        await tester.tap(find.byType(PoolOrderSelector));
        await harness.settle(tester);
        await tester.tap(find.text('Latest'));
        await harness.settle(tester);
        expect(
          tester
              .widget<PoolOrderSelector>(find.byType(PoolOrderSelector))
              .value,
          PoolDetailsOrder.latest,
        );
        pager.jumpToPage(2);
        await harness.settle(tester);
        expect(currentDetailPost(tester).id, 102);
        pager.jumpToPage(3);
        await harness.pumpUntil(
          tester,
          () => find
              .byWidgetPredicate(
                (w) => w is PoolDetailContent && w.pool.id == 20,
              )
              .evaluate()
              .isNotEmpty,
        );
        await harness.settle(tester);
        final collectionOrder = find.descendant(
          of: find.byWidgetPredicate(
            (w) => w is PoolDetailContent && w.pool.id == 20,
          ),
          matching: find.byType(PoolOrderSelector),
        );
        expect(
          tester.widget<PoolOrderSelector>(collectionOrder).value,
          PoolDetailsOrder.order,
        );
        pager.jumpToPage(4);
        await harness.settle(tester);
        expect(currentDetailPost(tester).id, 101);
        pager.jumpToPage(1);
        await harness.pumpUntil(
          tester,
          () => find
              .byWidgetPredicate(
                (w) => w is PoolDetailContent && w.pool.id == 10,
              )
              .evaluate()
              .isNotEmpty,
        );
        await harness.settle(tester);
        expect(
          tester
              .widget<PoolOrderSelector>(find.byType(PoolOrderSelector))
              .value,
          PoolDetailsOrder.latest,
        );
        await tester.tap(find.byIcon(Symbols.arrow_back_ios));
        await harness.pumpUntilFound(tester, find.byType(BookmarkScrollView));
        await harness.settle(tester);
        expect(
          setup.container.read(bookmarkProvider).requireValue.pools,
          hasLength(2),
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'live malberrybush order groups later Series before cached tiles freeze',
    (tester) async {
      final fixture = jsonDecode(
        File('test/application/fixtures/malberrybush-series-20261031.json')
            .readAsStringSync(),
      ) as Map<String, dynamic>;
      final rows = (fixture['posts'] as List).cast<Map<String, dynamic>>();
      final setup = await _mount(
        tester,
        realSearch: true,
        seriesPools: (fixture['pools'] as List)
            .map((p) => Map<String, Object?>.from(p as Map))
            .toList(),
      );
      final harness = setup.harness;
      final posts = [
        for (final row in rows)
          testPoolPost(row['id'] as int).post.copyWith(
            origin: postOriginFromConfig(harness.booruBackend.config),
          ),
      ];
      harness.booruBackend.enqueuePosts(
        page: 1,
        query: 'malberrybush',
        posts: posts.take(60).toList(),
        hasMore: true,
      );
      harness.booruBackend.enqueuePosts(
        page: 2,
        query: 'malberrybush',
        posts: posts.skip(60).toList(),
        hasMore: false,
      );
      final driver = AppFlowDriver(tester: tester, harness: harness);
      await driver.openSearch();
      await driver.submitSearch('malberrybush');
      final series = find.byType(SearchSeriesGrid);
      await harness.pumpUntilFound(tester, find.byType(PoolGridItem));
      final grid = tester.widget<PostGrid<Post>>(
        find.ancestor(of: series, matching: find.byType(PostGrid<Post>)),
      );
      expect(
        tester
            .widget<PoolGridItem>(find.byType(PoolGridItem).first)
            .displayedCount,
        29,
      );
      expect(grid.controller.items.elementAt(16).id, 12398273);
      setup.adapter.delayedPostId = rows[100]['id'] as int;
      setup.adapter.tailGate = Completer<void>();
      final more = grid.controller.fetchMore();
      await tester.pump(grid.controller.debounceDuration);
      await harness.settle(tester);
      final later = find.byWidgetPredicate(
        (w) => w is PoolGridItem && w.total == 18,
      );
      if (grid.controller.loadingMore) {
        expect(grid.controller.items, hasLength(60));
        expect(setup.adapter.tailRequested.isCompleted, isTrue);
      } else {
        // The old first-40 admission lets cached tail tiles freeze while the
        // viewport's metadata response is pending.
        for (var step = 0; step < 100 && later.evaluate().isEmpty; step++) {
          final scroll = grid.scrollController!;
          scroll.jumpTo(
            (scroll.offset + 250).clamp(0, scroll.position.maxScrollExtent),
          );
          await harness.settle(tester);
        }
      }
      setup.adapter.tailGate!.complete();
      await harness.settle(tester);
      await more;
      for (var step = 0; step < 100 && later.evaluate().isEmpty; step++) {
        final scroll = grid.scrollController!;
        scroll.jumpTo(
          (scroll.offset + 250).clamp(0, scroll.position.maxScrollExtent),
        );
        await harness.settle(tester);
      }
      await harness.pumpUntilFound(tester, later);
      expect(tester.widget<PoolGridItem>(later).displayedCount, 18);
      expect(grid.controller.items.map((p) => p.id), rows.map((p) => p['id']));
      expect(grid.controller.items.map((p) => p.id).toSet(), hasLength(120));
      final scroll = grid.scrollController!;
      final offset = scroll.offset;
      await harness.settle(tester);
      expect(scroll.offset, offset);
      final calls = setup.adapter.requests
          .where((r) => r.path == '/pools.json')
          .toList();
      expect(calls, hasLength(2));
      for (final call in calls) {
        expect(
          (call.queryParameters['search[post_ids_include_any]'] as String)
              .split(' ')
              .length,
          lessThanOrEqualTo(200),
        );
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'normal Search collapses confirmed Series and explicit pool Search stays expanded',
    (tester) async {
      final setup = await _mount(tester, realSearch: true);
      final harness = setup.harness;
      harness.booruBackend.enqueuePosts(
        page: 1,
        query: 'malberrybush',
        posts: harness.booruBackend.posts,
      );
      final driver = AppFlowDriver(tester: tester, harness: harness);
      await driver.openSearch();
      await driver.submitSearch('malberrybush');
      final seriesGrid = find.byType(SearchSeriesGrid);
      await harness.pumpUntilFound(tester, seriesGrid);
      final card = find.descendant(
        of: seriesGrid,
        matching: find.byType(PoolGridItem),
      );
      await harness.pumpUntilFound(tester, card);
      expect(tester.widget<PoolGridItem>(card).total, 20);
      expect(tester.widget<PoolGridItem>(card).category, 'Series');
      expect(
        find.byWidgetPredicate(
          (w) => w is PoolGridItem && w.displayedCount == 2 && w.total == 20,
        ),
        findsOneWidget,
      );
      final grid = tester.widget<SearchSeriesGrid>(seriesGrid);
      expect(grid.controller.items.map((p) => p.id), [101, 102]);
      expect(
        setup.adapter.requests.where((r) => r.path == '/pools.json'),
        hasLength(1),
      );
      final selection = SelectionMode.of(tester.element(card));
      await tester.longPress(card);
      await harness.settle(tester);
      expect(card, findsNothing);
      expect(grid.controller.items, hasLength(2));
      selection.disable();
      await harness.settle(tester);
      expect(card, findsOneWidget);
      await tester.tap(card);
      await harness.pumpUntilFound(tester, find.byType(PoolDetailContent));
      expect(
        find.descendant(
          of: find.byType(PoolDetailContent),
          matching: find.byType(SearchSeriesGrid),
        ),
        findsNothing,
      );
      await tester.tap(find.byIcon(Symbols.arrow_back_ios));
      await harness.settle(tester);
      expect(card, findsOneWidget);
      expect(
        tester.widget<SearchSeriesGrid>(seriesGrid).controller.items,
        hasLength(2),
      );
      await driver.clearSelectedSearchTags();
      await driver.submitSearch('pool:10');
      await harness.settle(tester);
      expect(
        find.descendant(of: seriesGrid, matching: find.byType(PoolGridItem)),
        findsNothing,
      );
      expect(
        tester.widget<SearchSeriesGrid>(seriesGrid).controller.items,
        hasLength(2),
      );
      expect(
        setup.adapter.requests.where((r) => r.path == '/pools.json'),
        hasLength(1),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'normal Search admits bounded later metadata without moving the visible anchor',
    (tester) async {
      final setup = await _mount(
        tester,
        realSearch: true,
        seriesMembers: [114, 113],
      );
      final harness = setup.harness;
      final config = harness.booruBackend.config;
      final posts = [
        for (var id = 190; id >= 101; id--)
          testPoolPost(id).post.copyWith(origin: postOriginFromConfig(config)),
      ];
      harness.booruBackend.enqueuePosts(page: 1, query: 'cat', posts: posts);
      final driver = AppFlowDriver(tester: tester, harness: harness);
      await driver.openSearch();
      await driver.submitSearch('cat');
      final series = find.byType(SearchSeriesGrid);
      await harness.pumpUntilFound(tester, series);
      final grid = tester.widget<PostGrid<Post>>(
        find.ancestor(of: series, matching: find.byType(PostGrid<Post>)),
      );
      final scroll = grid.scrollController!;
      final card = find.descendant(
        of: series,
        matching: find.byType(PoolGridItem),
      );
      for (var step = 0; step < 30 && card.evaluate().isEmpty; step++) {
        scroll.jumpTo(
          (scroll.offset + 250).clamp(0, scroll.position.maxScrollExtent),
        );
        await harness.settle(tester);
      }
      expect(card, findsOneWidget);
      expect(grid.controller.items, hasLength(90));
      final offset = scroll.offset;
      await harness.settle(tester);
      expect(scroll.offset, offset);
      final requests = setup.adapter.requests
          .where((r) => r.path == '/pools.json')
          .toList();
      expect(requests, hasLength(1));
      for (final request in requests) {
        expect(
          (request.queryParameters['search[post_ids_include_any]'] as String)
              .split(' ')
              .length,
          lessThanOrEqualTo(200),
        );
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'rolling Search groups across pages, preserves holes and raw selection indices',
    (tester) async {
      final setup = await _mount(
        tester,
        realSearch: true,
        seriesMembers: [101, 103, 105],
      );
      final harness = setup.harness;
      List<Post> posts(List<int> ids) => [
        for (final id in ids)
          testPoolPost(id).post.copyWith(
            origin: postOriginFromConfig(harness.booruBackend.config),
          ),
      ];
      harness.booruBackend.enqueuePosts(
        page: 1,
        query: 'cat',
        posts: posts([101, 102, 103]),
        hasMore: true,
      );
      harness.booruBackend.enqueuePosts(
        page: 2,
        query: 'cat',
        posts: posts([104, 105]),
        hasMore: false,
      );
      final driver = AppFlowDriver(tester: tester, harness: harness);
      await driver.openSearch();
      await driver.submitSearch('cat');
      await harness.pumpUntilFound(
        tester,
        find.byWidgetPredicate(
          (w) => w is PoolGridItem && w.displayedCount == 3 && w.total == 20,
        ),
      );
      final series = find.byType(SearchSeriesGrid);
      final controller = tester.widget<SearchSeriesGrid>(series).controller;
      expect(controller.page, 2);
      expect(controller.hasMore, isFalse);
      expect(controller.items.map((p) => p.id), [101, 102, 103, 104, 105]);
      expect(postTile(102), findsOneWidget);
      expect(postTile(104), findsOneWidget);
      final grid = tester.widget<PostGrid<Post>>(
        find.ancestor(of: series, matching: find.byType(PostGrid<Post>)),
      );
      expect(grid.scrollController!.tagMap.keys, containsAll([0, 1, 2, 3, 4]));
      final card = find.descendant(
        of: series,
        matching: find.byType(PoolGridItem),
      );
      final cover = tester.widget<FeedPostThumbnail>(
        find.descendant(of: card, matching: find.byType(FeedPostThumbnail)),
      );
      expect(cover.post.id, 101);
      final selection = SelectionMode.of(tester.element(card));
      await tester.longPress(card);
      await harness.settle(tester);
      expect(
        selection
            .selectedFrom(controller.items.toList())
            .toList()
            .map((p) => p.id)
            .toList(),
        [101],
      );
      expect(card, findsNothing);
      expect(
        tester
            .widget<PostGridSliver<Post>>(
              find.descendant(
                of: series,
                matching: find.byType(PostGridSliver<Post>),
              ),
            )
            .displayItemCount,
        5,
      );
      await harness.pumpUntilComplete(
        tester,
        grid.scrollController!.scrollToIndex(4),
      );
      expect(postTile(105), findsOneWidget);
      selection.replaceSelection(3);
      expect(
        selection
            .selectedFrom(controller.items.toList())
            .toList()
            .map((p) => p.id)
            .toList(),
        [104],
      );
      selection.disable();
      grid.scrollController!.jumpTo(0);
      await harness.settle(tester);
      expect(
        find.byWidgetPredicate(
          (w) => w is PoolGridItem && w.displayedCount == 3 && w.total == 20,
        ),
        findsOneWidget,
      );
      expect(
        identical(
          grid.scrollController!.tagMap[0],
          grid.scrollController!.tagMap[4],
        ),
        isTrue,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'collapsed viewport fill stops after three pages and manual Load More can continue',
    (tester) async {
      final setup = await _mount(tester, realSearch: true, gridPadding: 16);
      final harness = setup.harness;
      for (var page = 1; page <= 6; page++) {
        harness.booruBackend.enqueuePosts(
          page: page,
          query: 'cat',
          posts: [
            for (var id = 99 + page * 2; id <= 100 + page * 2; id++)
              testPoolPost(id).post.copyWith(
                origin: postOriginFromConfig(harness.booruBackend.config),
              ),
          ],
          hasMore: page < 6,
        );
      }
      final driver = AppFlowDriver(tester: tester, harness: harness);
      await driver.openSearch();
      await driver.submitSearch('cat');
      await harness.pumpUntilFound(
        tester,
        find.byWidgetPredicate(
          (w) => w is PoolGridItem && w.displayedCount == 8 && w.total == 20,
        ),
      );
      await harness.settle(tester);
      final controller = tester
          .widget<SearchSeriesGrid>(find.byType(SearchSeriesGrid))
          .controller;
      expect(controller.page, 4);
      expect(controller.hasMore, isTrue);
      expect(controller.loadingMore, isFalse);
      await tester.pump(const Duration(seconds: 2));
      expect(
        controller.page,
        4,
        reason: 'rebuilds cannot renew an automatic request budget',
      );
      final load = find.widgetWithText(FilledButton, 'Load More');
      expect(load, findsOneWidget);
      // Fix the underfilled/manual-footer geometry independently of defaults.
      // Scrolling the larger 4 dp-default tile exercises automatic loading instead.
      await tester.tapAt(tester.getTopLeft(load) + const Offset(60, 4));
      await harness.pumpUntilFound(
        tester,
        find.byWidgetPredicate(
          (w) => w is PoolGridItem && w.displayedCount == 12 && w.total == 20,
        ),
      );
      await harness.settle(tester);
      expect(controller.page, 6);
      expect(controller.hasMore, isFalse);
      expect(controller.items, hasLength(12));
      expect(tester.takeException(), isNull);
    },
  );

  for (final error in <BooruError>[
    ServerError(httpStatusCode: 503, message: 'unavailable'),
    RequestCancelledError(),
  ]) {
    testWidgets(
      'collapsed viewport fill stops on ${error.runtimeType} and explicit retry retains raw state',
      (tester) async {
        final setup = await _mount(tester, realSearch: true);
        final harness = setup.harness;
        harness.booruBackend.enqueuePosts(
          page: 1,
          query: 'cat',
          posts: harness.booruBackend.posts,
          hasMore: true,
        );
        final gate = harness.booruBackend.enqueuePostGate(
          siteUrl: harness.booruBackend.config.url,
          query: 'cat',
          page: 2,
        );
        final driver = AppFlowDriver(tester: tester, harness: harness);
        await driver.openSearch();
        await driver.submitSearch('cat');
        await harness.pumpUntil(
          tester,
          () => harness.booruBackend.requests
              .whereType<FakeBooruPostRequest>()
              .any((r) => r.query == 'cat' && r.page == 2),
        );
        final controller = tester
            .widget<SearchSeriesGrid>(find.byType(SearchSeriesGrid))
            .controller;
        gate.completeFailure(error);
        await harness.pumpUntil(
          tester,
          () => controller.errors.value != null && !controller.loadingMore,
        );
        expect(controller.errors.value, error);
        expect(controller.page, 1);
        expect(controller.items.map((p) => p.id), [101, 102]);
        final count = harness.booruBackend.requests
            .whereType<FakeBooruPostRequest>()
            .where((r) => r.query == 'cat')
            .length;
        await tester.pump(const Duration(seconds: 2));
        expect(
          harness.booruBackend.requests.whereType<FakeBooruPostRequest>().where(
            (r) => r.query == 'cat',
          ),
          hasLength(count),
        );
        harness.booruBackend.enqueuePosts(
          page: 2,
          query: 'cat',
          posts: [
            testPoolPost(103).post.copyWith(
              origin: postOriginFromConfig(harness.booruBackend.config),
            ),
          ],
          hasMore: false,
        );
        await harness.pumpUntilComplete(tester, controller.fetchMore());
        expect(controller.errors.value, isNull);
        expect(controller.page, 2);
        expect(controller.hasMore, isFalse);
        expect(
          find.byWidgetPredicate(
            (w) => w is PoolGridItem && w.displayedCount == 3 && w.total == 20,
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'query replacement cancels an in-flight fill without publishing old posts or restarting its cycle',
    (tester) async {
      final setup = await _mount(tester, realSearch: true);
      final harness = setup.harness;
      final backend = harness.booruBackend;
      backend.enqueuePosts(
        page: 1,
        query: 'cat',
        posts: backend.posts,
        hasMore: true,
      );
      final gate = backend.enqueuePostGate(
        siteUrl: backend.config.url,
        query: 'cat',
        page: 2,
      );
      final driver = AppFlowDriver(tester: tester, harness: harness);
      await driver.openSearch();
      await driver.submitSearch('cat');
      await harness.pumpUntil(
        tester,
        () => backend.requests.whereType<FakeBooruPostRequest>().any(
          (r) => r.query == 'cat' && r.page == 2,
        ),
      );
      backend.enqueuePosts(
        page: 1,
        query: 'dog',
        posts: [
          for (final id in [201, 202])
            testPoolPost(id).post
                .copyWith(origin: postOriginFromConfig(backend.config)),
        ],
        hasMore: false,
      );
      await driver.clearSelectedSearchTags();
      await driver.submitSearch('dog');
      await harness.pumpUntilFound(tester, postTile(201));
      gate.completeSuccess(
        PostResult(posts: [testPoolPost(103).post], total: null, hasMore: true),
      );
      await harness.settle(tester);
      final current = tester.widget<SearchSeriesGrid>(
        find.byType(SearchSeriesGrid),
      );
      expect(current.query, 'dog');
      expect(current.controller.items.map((p) => p.id), [201, 202]);
      expect(
        backend.requests.whereType<FakeBooruPostRequest>().where(
          (r) => r.query == 'cat' && r.page > 1,
        ),
        hasLength(1),
      );
      expect(find.byType(PoolGridItem), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'paginated Search keeps a collapsed page without automatic viewport fill',
    (tester) async {
      final setup = await _mount(tester, realSearch: true);
      final harness = setup.harness;
      await harness.pumpUntilComplete(
        tester,
        setup.container
            .read(settingsNotifierProvider.notifier)
            .updateWith(
              (s) => s.copyWith(
                listing: s.listing.copyWith(pageMode: PageMode.paginated),
              ),
            ),
      );
      harness.booruBackend.enqueuePosts(
        page: 1,
        query: 'cat',
        posts: harness.booruBackend.posts,
        hasMore: true,
      );
      final driver = AppFlowDriver(tester: tester, harness: harness);
      await driver.openSearch();
      await driver.submitSearch('cat');
      await harness.pumpUntilFound(
        tester,
        find.byWidgetPredicate(
          (w) => w is PoolGridItem && w.displayedCount == 2 && w.total == 20,
        ),
      );
      await harness.settle(tester);
      final controller = tester
          .widget<SearchSeriesGrid>(find.byType(SearchSeriesGrid))
          .controller;
      expect(controller.pageMode, PageMode.paginated);
      expect(controller.page, 1);
      expect(controller.hasMore, isTrue);
      expect(
        harness.booruBackend.requests.whereType<FakeBooruPostRequest>().where(
          (r) => r.query == 'cat' && r.page > 1,
        ),
        isEmpty,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Search waits for bounded initial metadata and timeout keeps built raw tiles stable',
    (tester) async {
      final setup = await _mount(tester, realSearch: true, holdSeries: true);
      final harness = setup.harness;
      harness.booruBackend.enqueuePosts(
        page: 1,
        query: 'cat',
        posts: harness.booruBackend.posts,
      );
      final driver = AppFlowDriver(tester: tester, harness: harness);
      await driver.openSearch();
      await driver.submitSearch('cat');
      await harness.pumpUntil(
        tester,
        () => setup.adapter.membershipRequested.isCompleted,
      );
      final grid = find.byType(SearchSeriesGrid);
      final controller = tester.widget<SearchSeriesGrid>(grid).controller;
      expect(controller.refreshing, isTrue);
      expect(controller.items, isEmpty);
      expect(
        setup.adapter.requests.where((r) => r.path == '/pools.json'),
        hasLength(1),
      );
      await tester.pump(const Duration(seconds: 11));
      await harness.settle(tester);
      expect(controller.refreshing, isFalse);
      expect(controller.items, hasLength(2));
      expect(
        find.descendant(of: grid, matching: find.byType(PoolGridItem)),
        findsNothing,
      );
      final bounds = tester.getRect(postTile(101));
      setup.adapter.seriesGate!.complete();
      await harness.settle(tester);
      expect(tester.getRect(postTile(101)), bounds);
      expect(
        find.descendant(of: grid, matching: find.byType(PoolGridItem)),
        findsNothing,
      );
      expect(
        setup.adapter.requests.where((r) => r.path == '/pools.json').length,
        lessThanOrEqualTo(2),
      );
      expect(tester.takeException(), isNull);
    },
  );

  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'Series whole and partial labels stay bounded at 320dp ${scale}x',
      (tester) async {
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final setup = await _mount(tester, realSearch: true);
        final harness = setup.harness;
        harness.booruBackend.enqueuePosts(
          page: 1,
          query: 'cat',
          posts: [
            for (var id = 101; id <= 120; id++)
              testPoolPost(id).post.copyWith(
                origin: postOriginFromConfig(harness.booruBackend.config),
              ),
          ],
        );
        final driver = AppFlowDriver(tester: tester, harness: harness);
        await driver.openSearch();
        await driver.submitSearch('cat');
        await harness.pumpUntilFound(
          tester,
          find.byWidgetPredicate(
            (w) => w is PoolGridItem && w.displayedCount == 20 && w.total == 20,
          ),
        );
        expect(find.text('20/20'), findsNothing);
        final card = find.byType(PoolGridItem);
        expect(
          tester.getRect(find.byKey(const ValueKey('pool-badge'))).right,
          lessThanOrEqualTo(tester.getRect(card).right),
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'an existing persisted cover resolves High and changes quality without changing the reference',
    (tester) async {
      final setup = await _mount(
        tester,
        seedReference: true,
        legacyCover: true,
      );
      final harness = setup.harness;
      final library = await harness.pumpUntilComplete(
        tester,
        setup.container.read(bookmarkProvider.future),
      );
      final saved = library.pools.single;
      expect(saved.cover, isNull);
      await AppFlowDriver(tester: tester, harness: harness).openBookmarks();
      final notifier = setup.container.read(settingsNotifierProvider.notifier);
      Future<void> quality(ImageQuality value) => harness.pumpUntilComplete(
        tester,
        notifier.updateWith(
          (settings) => settings.copyWith(
            listing: settings.listing.copyWith(imageQuality: value),
          ),
        ),
      );
      final image = find.descendant(
        of: find.byType(BookmarkPoolCoverImage),
        matching: find.byType(BooruImage),
      );
      await quality(ImageQuality.high);
      await harness.pumpUntil(
        tester,
        () =>
            image.evaluate().length == 1 &&
            tester.widget<BooruImage>(image).imageUrl ==
                harness.booruBackend.posts.first.sampleImageUrl,
      );
      expect(
        tester.widget<BooruImage>(image).config,
        harness.booruBackend.config.auth,
      );
      final calls = harness.booruBackend.requests.length;
      await quality(ImageQuality.low);
      await harness.settle(tester);
      expect(
        tester.widget<BooruImage>(image).imageUrl,
        harness.booruBackend.posts.first.thumbnailImageUrl,
      );
      await quality(ImageQuality.high);
      await harness.settle(tester);
      expect(
        tester.widget<BooruImage>(image).imageUrl,
        harness.booruBackend.posts.first.sampleImageUrl,
      );
      expect(harness.booruBackend.requests.length, calls);
      expect(
        setup.container.read(bookmarkProvider).requireValue.pools.single,
        saved,
      );
      expect(setup.postRows.values, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('individual Bookmarks never request Series grouping metadata', (
    tester,
  ) async {
    final setup = await _mount(tester, seedPosts: true, seedPostCount: 90);
    final harness = setup.harness;
    await AppFlowDriver(tester: tester, harness: harness).openBookmarks();
    await harness.settle(tester);
    final grid = tester.widget<PostGrid<Post>>(
      find.descendant(
        of: find.byType(BookmarkScrollView),
        matching: find.byType(PostGrid<Post>),
      ),
    );
    expect(grid.controller.items, hasLength(90));
    expect(find.byType(BookmarkPoolCard), findsNothing);
    grid.scrollController!.jumpTo(1200);
    await harness.settle(tester);
    await harness.pumpUntilComplete(tester, grid.controller.refresh());
    expect(grid.controller.items, hasLength(90));
    expect(
      setup.adapter.requests.where((r) => r.path == '/pools.json'),
      isEmpty,
    );
    expect(find.byType(BookmarkPoolCard), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('re-adding a Pool supersedes an older removal Undo', (
    tester,
  ) async {
    final setup = await _mount(tester, seedReference: true);
    final notifier = setup.container.read(bookmarkProvider.notifier);
    final library = await setup.harness.pumpUntilComplete(
      tester,
      setup.container.read(bookmarkProvider.future),
    );
    final saved = library.pools.single;
    final removal = await setup.harness.pumpUntilComplete(
      tester,
      notifier.removePostsFromGroup(
        setup.harness.booruBackend.config.auth,
        const [],
        poolGroupA,
        poolLocalIds: {saved.localId},
      ),
    );
    expect(setup.container.read(bookmarkProvider).requireValue.pools, isEmpty);
    await setup.harness.pumpUntilComplete(
      tester,
      notifier.togglePoolTarget(
        saved.copyWith(
          bookmarkId: () => null,
          localId: '550e8400-e29b-41d4-a716-000000000999',
        ),
        groupId: poolGroupA,
      ),
    );
    final rejected = await setup.harness.pumpUntilComplete(
      tester,
      notifier
          .undoRemoval(removal)
          .then((_) => false, onError: (Object _) => true),
    );
    expect(rejected, isTrue);
    final current = setup.container
        .read(bookmarkProvider)
        .requireValue
        .pools
        .single;
    expect(current.localId, isNot(saved.localId));
    expect(current.groupIds, {poolGroupA});
    expect(setup.postRows.values, isEmpty);
  });

  testWidgets(
    'Pool picker saves its summary without indexing members',
    (tester) async {
      final setup = await _mount(tester, holdIndex: true);
      final harness = setup.harness;
      unawaited(
        setup.container
            .read(routerProvider)
            .push(
              '/danbooru/pools/10',
              extra: (pool: _pool(), config: harness.booruBackend.config),
            ),
      );
      await harness.pumpUntilFound(tester, find.byType(PoolBookmarkButton));
      await harness.settle(tester);
      await tester.tap(find.byType(PoolBookmarkButton));
      await harness.pumpUntilFound(tester, find.byType(BookmarkGroupPicker));
      expect(find.byType(BookmarkGroupPicker), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(PoolBookmarkButton),
          matching: find.byType(CircularProgressIndicator),
        ),
        findsNothing,
      );
      expect(
        setup.container.read(bookmarkProvider).requireValue.pools,
        isEmpty,
      );
      await harness.settle(tester);
      await tester.tap(find.text('Pool target'));
      await harness.pumpUntil(
        tester,
        () =>
            setup.container.read(bookmarkProvider).valueOrNull?.pools.length ==
            1,
        description: 'completed asynchronous Pool bookmark',
      );
      final saved = setup.container
          .read(bookmarkProvider)
          .requireValue
          .pools
          .single;
      expect(saved.total, 20);
      expect(saved.coverage, PoolTagCoverage.unknown);
      expect(saved.tags, isEmpty);
      expect(saved.loadedDetails!.description!.text, '');
      expect(saved.loadedDetails!.description!.format, GroupTextFormat.dtext);
      expect(saved.loadedDetails!.sourceDates!.createdAt, DateTime.utc(2000));
      expect(saved.loadedDetails!.sourceDates!.updatedAt, DateTime.utc(2026));
      expect(
        harness.booruBackend.requests.whereType<FakeBooruPostRequest>().where(
          (request) => request.query == 'pool:10',
        ),
        isEmpty,
      );
      expect(setup.postRows.values, isEmpty);
      await _drainNotifications(tester);
      expect(tester.takeException(), isNull);
    },
  );

  for (final exit in [
    'cancel',
    'cancel after choosing a group',
    'remove profile',
  ]) {
    testWidgets('pending Pool metadata does not save after $exit', (
      tester,
    ) async {
      final draftGate = Completer<CollectionBookmark>();
      final setup = await _mount(tester, poolDraftGate: draftGate);
      final harness = setup.harness;
      final groupRepository = (await setup.container.read(
        bookmarkGroupRepoProvider.future,
      )) as UnifiedBookmarkGroupRepository;
      unawaited(
        setup.container
            .read(routerProvider)
            .push(
              '/danbooru/pools/10',
              extra: (pool: _pool(), config: harness.booruBackend.config),
            ),
      );
      await harness.pumpUntilFound(tester, find.byType(PoolBookmarkButton));
      await harness.settle(tester);
      await tester.tap(find.byType(PoolBookmarkButton));
      await harness.pumpUntilFound(tester, find.byType(BookmarkGroupPicker));
      await harness.settle(tester);
      expect(draftGate.isCompleted, isFalse);
      if (exit != 'cancel') {
        await tester.tap(find.text('Pool target'));
        await tester.pump();
      }
      if (exit == 'remove profile') {
        await setup.container
            .read(booruConfigProvider.notifier)
            .delete(harness.booruBackend.config);
      } else {
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      }
      // Complete while the anchor's reverse transition still owns its widget.
      await tester.pump();
      draftGate.complete(_summaryPoolDraft(harness.booruBackend.config));
      await harness.settle(tester);
      expect(await groupRepository.readPoolBookmarks(), isEmpty);
      expect(setup.postRows.values, isEmpty);
      if (exit == 'remove profile') {
        if (find.byType(BookmarkGroupPicker).evaluate().isNotEmpty) {
          await tester.sendKeyEvent(LogicalKeyboardKey.escape);
          await harness.settle(tester);
        }
      }
      expect(find.byType(BookmarkGroupPicker), findsNothing);
      await _drainNotifications(tester);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'explicit refresh replaces a stored tag union without bookmarking members',
    (tester) async {
      final setup = await _mount(tester, seedReference: true);
      final harness = setup.harness;
      await AppFlowDriver(tester: tester, harness: harness).openBookmarks();
      await harness.pumpUntilFound(tester, find.byType(BookmarkPoolCard));
      await harness.settle(tester);
      await tester.tap(
        find.byType(BookmarkPoolCard),
        kind: PointerDeviceKind.mouse,
        buttons: kSecondaryMouseButton,
      );
      await harness.pumpUntilFound(tester, find.text('Refresh metadata'));
      await tester.tap(find.text('Refresh metadata'));
      await harness.pumpUntil(
        tester,
        () =>
            setup.container
                .read(bookmarkProvider)
                .valueOrNull
                ?.pools
                .single
                .tags
                .contains('cat') ??
            false,
      );
      final saved = setup.container
          .read(bookmarkProvider)
          .requireValue
          .pools
          .single;
      expect(saved.tags, containsAll(['cat', 'landscape']));
      expect(saved.tags, isNot(contains('alpha')));
      expect(saved.groupIds, {poolGroupA});
      expect(saved.localId, '0');
      expect(setup.postRows.values, isEmpty);
      await _drainNotifications(tester);
      expect(tester.takeException(), isNull);
    },
  );

  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'Pool Bookmark uses the shared picker and stays one selectable entry at ${scale}x',
      (tester) async {
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final setup = await _mount(tester);
        final harness = setup.harness;
        final container = setup.container;
        unawaited(
          container
              .read(routerProvider)
              .push(
                '/danbooru/pools/10',
                extra: (pool: _pool(), config: harness.booruBackend.config),
              ),
        );
        await harness.pumpUntilFound(tester, find.byType(PoolBookmarkButton));
        await harness.settle(tester);
        if (scale == 1) {
          await tester.tap(find.byType(PoolBookmarkButton));
        } else {
          await tester.longPress(find.byType(PoolBookmarkButton));
        }
        await harness.pumpUntilFound(tester, find.byType(BookmarkGroupPicker));
        expect(tester.takeException(), isNull);
        await harness.settle(tester);
        await tester.scrollUntilVisible(
          find.text('Pool target'),
          100,
          scrollable: find
              .descendant(
                of: find.byType(BookmarkGroupPicker),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await harness.settle(tester);
        await tester.tap(find.text('Pool target'));
        await harness.pumpUntil(
          tester,
          () => container.read(bookmarkProvider).valueOrNull?.pools.length == 1,
        );
        expect(setup.postRows.values, isEmpty);
        final saved = container
            .read(bookmarkProvider)
            .requireValue
            .pools
            .single;
        expect(saved.groupIds, {poolGroupA});
        expect(saved.total, 20);
        expect(saved.coverage, PoolTagCoverage.unknown);
        expect(saved.tags, isEmpty);
        await AppFlowDriver(tester: tester, harness: harness).goBack();
        await AppFlowDriver(tester: tester, harness: harness).openBookmarks();
        await harness.pumpUntilFound(tester, find.byType(BookmarkPoolCard));
        expect(
          find.byWidgetPredicate(
            (w) =>
                w is PoolGridItem && w.displayedCount == null && w.total == 20,
          ),
          findsOneWidget,
        );
        await harness.settle(tester);
        expect(tester.takeException(), isNull);
        await tester.longPress(find.byType(BookmarkPoolCard));
        await harness.settle(tester);
        final selection = SelectionMode.of(
          tester.element(find.byType(BookmarkPoolCard)),
        );
        expect(selection.selection, {0});
        expect(find.text('Download'), findsNothing);
        expect(setup.postRows.values, isEmpty);
        selection.disable();
        await harness.settle(tester);

        final beforeMetadata = setup.adapter.requests.length;
        final field = find
            .descendant(
              of: find.byType(BookmarkSearchBar),
              matching: find.byType(TextField),
            )
            .first;
        await tester.tap(field);
        await tester.enterText(field, 'cat -landscape');
        harness.keyboard.sync();
        expect(harness.keyboard.isShown, isTrue);
        expect(tester.takeException(), isNull);
        await tester.testTextInput.receiveAction(TextInputAction.search);
        await harness.pumpUntil(
          tester,
          () => find.byType(BookmarkPoolCard).evaluate().isEmpty,
        );
        expect(setup.adapter.requests, hasLength(beforeMetadata));
        expect(
          container.read(bookmarkProvider).requireValue.pools,
          hasLength(1),
        );
      },
    );
  }

  testWidgets(
    'a Pool card opens the full remote Pool under its origin while another profile is active',
    (tester) async {
      final setup = await _mount(
        tester,
        initialOtherProfile: true,
        seedReference: true,
      );
      final harness = setup.harness;
      await AppFlowDriver(tester: tester, harness: harness).openBookmarks();
      await harness.pumpUntilFound(tester, find.byType(BookmarkPoolCard));
      await harness.settle(tester);
      await tester.tap(find.byType(BookmarkPoolCard));
      await harness.pumpUntilFound(tester, find.byType(PoolDetailContent));
      final page = tester.widget<PoolDetailContent>(
        find.byType(PoolDetailContent),
      );
      expect(page.pool.id, 10);
      expect(page.pool.postIds, hasLength(20));
      final scoped = ProviderScope.containerOf(
        tester.element(find.byType(PoolDetailContent)),
        listen: false,
      );
      expect(
        scoped.read(currentReadOnlyBooruConfigProvider).id,
        harness.booruBackend.config.id,
      );
      final detail = setup.adapter.requests
          .where((r) => r.path == '/pools/10.json')
          .single;
      expect(detail.uri.host, Uri.parse(harness.booruBackend.config.url).host);
      expect(
        detail.uri.host,
        isNot(Uri.parse(harness.booruBackend.configB.url).host),
      );
      expect(setup.postRows.values, isEmpty);
      await _drainNotifications(tester);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'individual Posts and an explicit Series remain independent selectable Bookmarks',
    (tester) async {
      final setup = await _mount(tester, seedReference: true, seedPosts: true);
      final harness = setup.harness;
      await AppFlowDriver(tester: tester, harness: harness).openBookmarks();
      await harness.pumpUntilFound(tester, find.byType(BookmarkPoolCard));
      final grid = tester.widget<PostGrid<Post>>(
        find
            .descendant(
              of: find.byType(BookmarkScrollView),
              matching: find.byType(PostGrid<Post>),
            )
            .first,
      );
      await harness.pumpUntilComplete(tester, grid.controller.refresh());
      await harness.settle(tester);
      expect(find.byType(BookmarkPoolCard), findsOneWidget);
      expect(grid.controller.items, hasLength(3));
      expect(
        setup.adapter.requests.where((r) => r.path == '/pools.json'),
        isEmpty,
      );
      await tester.longPress(find.byType(BookmarkPoolCard));
      await harness.settle(tester);
      final selection = SelectionMode.of(
        tester.element(find.byType(BookmarkPoolCard)),
      );
      expect(selection.selection, hasLength(1));
      final bookmarkActionIcon = find.descendant(
        of: find.byType(MultiSelectPopupButton).first,
        matching: find.byType(Icon),
      );
      Focus.of(tester.element(bookmarkActionIcon.first)).requestFocus();
      await tester.pump();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await harness.settle(tester);
      expect(selection.selection, hasLength(4));
      await tester.tap(find.byType(MultiSelectPopupButton).first);
      await harness.pumpUntilFound(
        tester,
        find.byType(BookmarkMultiSelectionMenu),
      );
      final menu = tester.widget<BookmarkMultiSelectionMenu>(
        find.byType(BookmarkMultiSelectionMenu),
      );
      expect(menu.posts, hasLength(3));
      expect(menu.pools, hasLength(1));
      expect(setup.postRows.values, hasLength(3));
      await tester.tap(find.text('Remove From'));
      await harness.pumpUntilFound(tester, find.text('Pool target'));
      await harness.settle(tester);
      await tester.tap(find.text('Pool target'));
      await harness.pumpUntil(tester, () {
        final state = setup.container.read(bookmarkProvider).valueOrNull;
        return state != null && state.items.isEmpty && state.pools.isEmpty;
      });
      expect(selection.isActive, isFalse);
      await harness.pumpUntilFound(tester, find.text('Undo'));
      await tester.tap(find.text('Undo'));
      await harness.pumpUntil(tester, () {
        final state = setup.container.read(bookmarkProvider).valueOrNull;
        return state?.items.length == 3 && state?.pools.length == 1;
      });
      await harness.settle(tester);
      await _drainNotifications(tester);
      expect(tester.takeException(), isNull);
    },
  );
}

DanbooruPool _pool({
  DanbooruPoolCategory category = DanbooruPoolCategory.series,
  String name = 'Series_10',
  bool includeUpdated = true,
}) => DanbooruPool(
  id: 10,
  postIds: [for (var id = 101; id <= 120; id++) id],
  category: category,
  description: '',
  postCount: 20,
  name: name,
  createdAt: DateTime.utc(2000),
  updatedAt: includeUpdated ? DateTime.utc(2026) : null,
);

Future<
  ({
    HeadlessAppHarness harness,
    ProviderContainer container,
    Box<BookmarkHiveObject> postRows,
    _PoolAdapter adapter,
    FakeBooruPostGate? indexGate,
  })
>
_mount(
  WidgetTester tester, {
  Size? viewportSize,
  bool? keepTimelineVisible,
  bool initialOtherProfile = false,
  bool realSearch = false,
  bool seedReference = false,
  bool seedRelated = false,
  bool emptyRelated = false,
  int relatedVisits = 8,
  bool seedMixedSequence = false,
  bool longGallery = false,
  int galleryMemberCount = 20,
  int? memberPageSize,
  double? gridPadding,
  bool legacyCover = false,
  bool seedPosts = false,
  bool holdIndex = false,
  bool holdSeries = false,
  int seedPostCount = 3,
  List<int>? seriesMembers,
  List<Map<String, Object?>>? seriesPools,
  SettingsRepository? settingsRepository,
  BookmarkLibraryNotifier Function(BooruConfig)? bookmarkNotifierFactory,
  Completer<CollectionBookmark>? poolDraftGate,
  Completer<CollectionBookmark>? relatedDraftGate,
}) async {
  final backend = FakeBooruBackend();
  if (seedRelated) {
    for (var visit = 0; visit < relatedVisits; visit++) {
      for (final oldest in [true, false]) {
        final ids = [for (var id = 10; id < 130; id++) id];
        final ordered = oldest ? ids : ids.reversed.toList();
        final query = 'parent:10 order:${oldest ? 'id_asc' : 'id_desc'}';
        backend.enqueuePosts(
          page: 1,
          query: query,
          posts: emptyRelated
              ? []
              : [
                  for (final id in ordered.take(60))
                    testRelatedPost(id, parent: id == 10 ? null : 10),
                ],
          hasMore: !emptyRelated,
        );
        backend.enqueuePosts(
          page: 2,
          query: query,
          posts: [
            for (final id in ordered.skip(60))
              testRelatedPost(id, parent: id == 10 ? null : 10),
          ],
          hasMore: false,
        );
      }
    }
  }
  final indexGate = holdIndex
      ? backend.enqueuePostGate(
          siteUrl: backend.config.url,
          query: 'pool:10',
          page: 1,
        )
      : null;
  if (!holdIndex)
    backend.enqueuePosts(page: 1, query: 'pool:10', posts: backend.posts);
  backend.enqueuePosts(
    page: 1,
    query: 'pool:10 order:created_at',
    posts: [backend.posts.first],
  );
  backend.enqueuePosts(
    page: 1,
    query: 'pool:10 order:created_at_asc',
    posts: [backend.posts.last],
  );
  backend.enqueuePosts(
    page: 1,
    query: 'id:${[for (var id = 101; id <= 120; id++) id].join(',')}',
    posts: longGallery
        ? [for (var id = 101; id <= 120; id++) TestPost(id: id)]
        : backend.posts,
  );
  if (galleryMemberCount > 20) {
    final pageSize =
        memberPageSize ?? Settings.defaultSettings.listing.postsPerPage;
    for (var start = 101; start < 101 + galleryMemberCount; start += pageSize) {
      final ids = [
        for (
          var id = start;
          id < start + pageSize && id < 101 + galleryMemberCount;
          id++
        )
          id,
      ];
      backend.enqueuePosts(
        page: 1,
        query: 'id:${ids.join(',')}',
        posts: [for (final id in ids) TestPost(id: id)],
      );
    }
  }
  // Exercise the production unified facade and Hive codecs without OS I/O
  // during fake-clock UI actions. Real durability/restart tests live in core.
  Hive.init('/pool-flow-memory');
  if (!Hive.isAdapterRegistered(4)) {
    Hive.registerAdapter(BookmarkHiveObjectAdapter());
  }
  if (!Hive.isAdapterRegistered(5)) {
    Hive.registerAdapter(BookmarkGroupHiveObjectAdapter());
  }
  final postRows = await Hive.openBox<BookmarkHiveObject>(
    'posts',
    bytes: Uint8List(0),
  );
  final payloads = await Hive.openBox<dynamic>('payloads', bytes: Uint8List(0));
  final metadata = await Hive.openBox<dynamic>('metadata', bytes: Uint8List(0));
  const groupName = 'groups_unified_v2';
  const organizationName = 'organization_unified_v2';
  final groupRows = await Hive.openBox<BookmarkGroupHiveObject>(
    groupName,
    bytes: Uint8List(0),
  );
  final organization = await Hive.openBox<dynamic>(
    organizationName,
    bytes: Uint8List(0),
  );
  final coordinator = DataMutationCoordinator();
  final posts = BookmarkHiveRepository(
    postRows,
    groupPayloadBox: payloads,
    metadataBox: metadata,
    coordinator: coordinator,
    postDataCodec: (_) => const EmptyPostDataCodec('test'),
    syncBoxes: (_) async {},
  );
  await metadata.put('activeOrganization', {
    'version': 2,
    'generation': {'groups': groupName, 'organization': organizationName},
  });
  // Only the initial generation-file existence probe crosses the IO API.
  // Its boxes are already open in memory; keep the whole fixture on the
  // controlled test clock rather than mixing real/fake async lock chains.
  await IOOverrides.runZoned(
    posts.readAll,
    createFile: (path) {
      if (path == '/pool-flow-memory/$groupName.hive' ||
          path == '/pool-flow-memory/$organizationName.hive') {
        return _PresentGenerationFile();
      }
      throw StateError(
        'Unexpected filesystem access in memory UI fixture: $path',
      );
    },
  );
  final groups = UnifiedBookmarkGroupRepository(
    bookmarks: posts,
    reader: BookmarkGroupRepositoryHive(
      groupRows,
      organizationBox: organization,
    ),
  );
  addTearDown(Hive.close);
  await groups.createGroup('Pool target', id: poolGroupA);
  if (seedReference || seedRelated)
    await groups.writePoolBookmarks([
      if (seedRelated)
        RelatedCollectionBookmark(
          family: RelatedFamilyReference(
            origin: postOriginFromConfig(backend.config),
            anchorId: 10,
          ),
          localId: poolGroupB,
          createdAt: testPoolPost(102).createdAt.add(const Duration(hours: 6)),
          observedAt: DateTime.utc(2026),
          groupIds: {poolGroupA},
        ),
      if (seedReference)
        PoolBookmark.fromJson({
          ...testPool()
              .copyWith(origin: postOriginFromConfig(backend.config))
              .toJson(),
          if (seedMixedSequence) ...{
            'createdAt': testPoolPost(102).createdAt
                .add(const Duration(hours: 12))
                .toIso8601String(),
            'addedAt': {
              poolGroupA: testPoolPost(102).createdAt
                  .add(const Duration(hours: 12))
                  .toIso8601String(),
            },
          },
          if (legacyCover) ...{
            'coverUrl': backend.posts.first.thumbnailImageUrl,
            'coverPolicy': poolCoverPolicy(backend.config, {}),
          },
        }),
      if (seedMixedSequence)
        PoolBookmark.fromJson({
          ...testPool(
            id: 20,
            category: BookmarkedPoolCategory.collection,
          ).copyWith(origin: postOriginFromConfig(backend.config)).toJson(),
          'createdAt': testPoolPost(101).createdAt
              .add(const Duration(hours: 12))
              .toIso8601String(),
          'addedAt': {
            poolGroupA: testPoolPost(101).createdAt
                .add(const Duration(hours: 12))
                .toIso8601String(),
          },
        }),
    ]);
  if (seedPosts) {
    final bookmarks = [
      for (var id = 101; id < 101 + seedPostCount; id++)
        (() {
          final old = testPoolPost(id);
          final post = (seedMixedSequence ? TestPost(id: id) : old.post)
              .copyWith(
                origin: postOriginFromConfig(backend.config),
              );
          return old.copyWith(
            post: post,
            snapshot: const StoredPostCodec().encode(
              post,
              dataCodec: seedMixedSequence
                  ? const EmptyPostDataCodec('test')
                  : null,
            ),
          );
        })(),
    ];
    final saved = await posts.addBookmarkWithBookmarks(bookmarks);
    // Seed saved history explicitly; creating fixtures must not assign now to
    // every Post membership and change the mixed viewer's chronological order.
    await groups.replaceMemberships(
      poolGroupA,
      {
        ...(await groups.getGroup(poolGroupA))!.bookmarkIds,
        ...saved.map((b) => b.id),
      },
      addedAt: {
        ...(await groups.getGroup(poolGroupA))!.addedAt,
        for (final bookmark in saved) bookmark.id: bookmark.createdAt,
      },
    );
  }
  final adapter = _PoolAdapter(
    poolMemberCount: galleryMemberCount,
    holdSeries: holdSeries,
    seriesMembers: seriesMembers,
    seriesPools: seriesPools,
  );
  final runtime = backend.createRuntime(
    configs: [backend.config, backend.configB],
    initialConfig: initialOtherProfile ? backend.configB : backend.config,
    bookmarkRepository: posts,
    settingsRepository: settingsRepository,
  );
  final harness = await HeadlessAppHarness.mount(
    tester,
    runtime: runtime,
    booruBackend: backend,
    phone: viewportSize == null
        ? TestPhone.smallPortrait
        : viewportSize.width >= 1100
        ? null
        : TestPhone(
            name: 'Pool layout $viewportSize',
            size: viewportSize,
            keyboardHeight: viewportSize.height >= 550 ? 260 : 200,
            safeArea: viewportSize.width > viewportSize.height
                ? const EdgeInsets.only(left: 20, right: 20, bottom: 16)
                : const EdgeInsets.only(top: 24, bottom: 16),
          ),
    viewportSize: viewportSize,
    additionalOverrides: [
      if (memberPageSize != null ||
          keepTimelineVisible != null ||
          gridPadding != null)
        imageListingSettingsProvider.overrideWith(
          (ref) => Settings.defaultSettings.listing.copyWith(
            postsPerPage: memberPageSize,
            imageGridPadding: gridPadding,
            keepTimelineToolbarVisible: keepTimelineVisible,
          ),
        ),
      if (realSearch)
        booruBuilderProvider.overrideWith(
          (ref, auth) => _SeriesSearchBuilder(),
        ),
      viewerEntryContentCapabilityProvider.overrideWith(
        (ref, config) => DanbooruRepository(ref: ref),
      ),
      deterministicImageDioOverride(),
      deterministicFaviconDioOverride(),
      dataMutationCoordinatorProvider.overrideWithValue(coordinator),
      bookmarkGroupRepoProvider.overrideWith((_) async => groups),
      if (bookmarkNotifierFactory != null)
        bookmarkProvider.overrideWith(
          () => bookmarkNotifierFactory(backend.config),
        ),
      if (poolDraftGate != null)
        poolBookmarkDraftProvider.overrideWith(
          (ref, request) => poolDraftGate.future,
        ),
      if (relatedDraftGate != null)
        relatedBookmarkDraftProvider.overrideWith(
          (ref, request) => relatedDraftGate.future,
        ),
      blacklistTagsProvider.overrideWith((_, _) async => <String>{}),
      poolBookmarkCapabilityProvider.overrideWith(
        (ref, _) => DanbooruPoolBookmarks(ref),
      ),
      danbooruClientProvider.overrideWith((ref, config) {
        final dio = Dio(BaseOptions(baseUrl: config.url))
          ..httpClientAdapter = adapter;
        ref.onDispose(dio.close);
        return api.DanbooruClient(baseUrl: config.url, dio: dio);
      }),
    ],
  );
  await harness.pumpUntilFound(
    tester,
    postTile(initialOtherProfile ? 201 : 101),
  );
  final container = ProviderScope.containerOf(
    tester.element(find.byType(PostGrid<Post>).first),
    listen: false,
  );
  return (
    harness: harness,
    container: container,
    postRows: postRows,
    adapter: adapter,
    indexGate: indexGate,
  );
}

BookmarkLibraryState _savedRelatedState({
  required BooruConfig config,
  required RelatedPostsOrder firstOrder,
  required RelatedPostsOrder secondOrder,
}) {
  final first = _nativeRelatedRecord(
    config: config,
    id: 901,
    anchorId: 10,
    order: firstOrder,
  );
  final second = _nativeRelatedRecord(
    config: config,
    id: 902,
    anchorId: 11,
    order: secondOrder,
  );
  return BookmarkLibraryState(
    bookmarks: const [],
    groups: [
      BookmarkGroup(
        id: poolGroupA,
        name: 'Pool target',
        bookmarkIds: {first.id, second.id},
      ),
    ],
    records: [first, second],
  );
}

PoolBookmark _summaryPoolDraft(BooruConfig config) {
  final now = DateTime.utc(2026);
  return PoolBookmark(
    localId: 'pending-pool-draft',
    sourceSite: Uri.parse(config.url),
    origin: postOriginFromConfig(config),
    poolId: 10,
    category: BookmarkedPoolCategory.series,
    title: 'Series_10',
    createdAt: now,
    observedAt: now,
    groupIds: const {},
    tags: const {},
    coverage: PoolTagCoverage.unknown,
    total: 20,
  );
}

RelatedCollectionBookmark _summaryRelatedDraft(BooruConfig config) {
  final now = DateTime.utc(2026);
  return RelatedCollectionBookmark(
    family: RelatedFamilyReference(
      origin: postOriginFromConfig(config),
      anchorId: 10,
    ),
    localId: 'pending-related-draft',
    sourceSite: Uri.parse(config.url),
    createdAt: now,
    observedAt: now,
    groupIds: const {},
  );
}

RelatedBookmark _nativeRelatedRecord({
  required BooruConfig config,
  required int id,
  required int anchorId,
  required RelatedPostsOrder order,
}) {
  final origin = postOriginFromConfig(config);
  final family = RelatedFamilyReference(origin: origin, anchorId: anchorId);
  final metadata = RelatedCollectionBookmark(
    family: family,
    localId: '$id',
    sourceSite: Uri.parse(config.url),
    createdAt: DateTime.utc(2024),
    observedAt: DateTime.utc(2026),
    groupIds: const {poolGroupA},
  );
  return collectionRecordForSave(
    metadata,
    id: id,
    initialRelatedOrder: order,
  ) as RelatedBookmark;
}

final class _SavedRelatedOrderNotifier extends BookmarkLibraryNotifier {
  _SavedRelatedOrderNotifier(this.library);

  final BookmarkLibraryState library;
  final orderUpdates = <(int, RelatedPostsOrder)>[];
  RelatedPostsOrder? pickerOrder;

  @override
  FutureOr<BookmarkLibraryState> build() => library;

  @override
  Future<void> setRelatedOrder(int bookmarkId, RelatedPostsOrder order) async {
    orderUpdates.add((bookmarkId, order));
  }

  @override
  Future<BookmarkToggleOutcome> togglePoolTarget(
    CollectionBookmark draft, {
    required String groupId,
    RelatedPostsOrder? initialRelatedOrder,
    void Function(BookmarkGroupRemovalResult)? onRemoved,
  }) async {
    pickerOrder = initialRelatedOrder;
    return BookmarkToggleOutcome.added;
  }
}

class _PoolAdapter implements HttpClientAdapter {
  _PoolAdapter({
    bool holdSeries = false,
    this.poolMemberCount = 20,
    this.seriesMembers,
    this.seriesPools,
  }) : seriesGate = holdSeries ? Completer<void>() : null;
  final int poolMemberCount;
  final Completer<void>? seriesGate;
  final List<int>? seriesMembers;
  final List<Map<String, Object?>>? seriesPools;
  final requests = <RequestOptions>[];
  final membershipRequested = Completer<void>();
  final tailRequested = Completer<void>();
  int? delayedPostId;
  Completer<void>? tailGate;
  Completer<void>? poolGate;
  var poolFailures = 0;
  var poolCancelled = false;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (RegExp(r'^/pools/\d+\.json$').hasMatch(options.path)) {
      if (poolFailures > 0) {
        poolFailures--;
        return ResponseBody.fromString('Unavailable', 503);
      }
      if (poolGate != null) {
        unawaited(
          cancelFuture?.then((_) {
            poolCancelled = true;
          }),
        );
        await poolGate!.future;
      }
    }
    final json = {
      'id': 10,
      'name': 'Series_10',
      'category': 'series',
      'post_count': poolMemberCount,
      'post_ids':
          seriesMembers ??
          [for (var id = 101; id < 101 + poolMemberCount; id++) id],
      'created_at': '2000-01-01T00:00:00Z',
      'updated_at': '2026-01-01T00:00:00Z',
    };
    if (options.path == '/pools.json') {
      if (!membershipRequested.isCompleted) membershipRequested.complete();
      await seriesGate?.future;
      final ids =
          (options.queryParameters['search[post_ids_include_any]'] as String?)
              ?.split(' ') ??
          const [];
      if (delayedPostId != null && ids.contains('$delayedPostId')) {
        if (!tailRequested.isCompleted) tailRequested.complete();
        await tailGate?.future;
      }
      return ResponseBody.fromString(
        jsonEncode(seriesPools ?? [json]),
        200,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );
    }
    if (options.path.endsWith('.json'))
      return ResponseBody.fromString(
        jsonEncode({
          ...json,
          'id':
              int.tryParse(options.path.split('/').last.split('.').first) ?? 10,
          if (options.path == '/pools/20.json') 'category': 'collection',
        }),
        200,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );
    return ResponseBody.fromString(
      '<div id="description"></div>',
      200,
      headers: {
        Headers.contentTypeHeader: ['text/html'],
      },
    );
  }

  @override
  void close({bool force = false}) {
    if (seriesGate != null && !seriesGate!.isCompleted) seriesGate!.complete();
    if (poolGate != null && !poolGate!.isCompleted) poolGate!.complete();
    if (tailGate != null && !tailGate!.isCompleted) tailGate!.complete();
  }
}

Future<void> _drainNotifications(WidgetTester tester) async {
  dismissAllToast(showAnim: false);
  // Drain notification lifetimes using the widget's controlled clock.
  await tester.pump(const Duration(seconds: 6));
}

class _SeriesSearchBuilder extends BaseBooruBuilder {
  @override
  SearchPageBuilder get searchPageBuilder =>
      (context, params) => DanbooruSearchPage(params: params);
}

// The production facade still validates its active generation; only the
// existence result for the two already-open in-memory boxes is substituted.
class _PresentGenerationFile implements File {
  @override
  Future<bool> exists() async => true;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
