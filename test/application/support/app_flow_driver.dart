import 'package:flutter/gestures.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurumi/kurumi.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:boorusama/core/bookmarks/src/pages/bookmark_details_page.dart';
import 'package:boorusama/core/bookmarks/src/pages/bookmark_group_browser_page.dart';
import 'package:boorusama/core/bookmarks/src/pages/bookmark_page.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/configs/create/src/pages/add_booru_page.dart';
import 'package:boorusama/core/navigation/profile_management_page.dart';
import 'package:boorusama/core/download_manager/src/pages/download_manager_page.dart';
import 'package:boorusama/core/home/src/widgets/home_search_bar.dart';
import 'package:boorusama/core/posts/details/widgets.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/search/search/src/widgets/search_app_bar.dart';
import 'package:boorusama/core/search/search/src/widgets/search_button.dart';
import 'package:boorusama/core/search/search/widgets.dart';

import 'app_flow_finders.dart';
import 'fake_booru_backend.dart';
import 'headless_app_harness.dart';

/// Ways a user opens the context menu of a post in the grid.
enum PostMenuOpener {
  longPress('long press'),
  rightClick('right click');

  const PostMenuOpener(this.label);

  final String label;
}

/// Common real-widget actions used by application-flow tests.
final class AppFlowDriver {
  const AppFlowDriver({
    required this.tester,
    required this.harness,
  });

  final WidgetTester tester;
  final HeadlessAppHarness harness;

  FakeBooruBackend get backend => harness.booruBackend;

  Iterable<FakeBooruPostRequest> get _postRequests =>
      backend.requests.whereType<FakeBooruPostRequest>();

  Future<void> scrollToLoadPage(int page) async {
    final before = _postRequests.where((r) => r.page == page).length;
    final scrollable = postGridScrollable();

    // Each fling outlasts the grid's 500 ms load-more debounce.
    for (var attempt = 0; attempt < 6; attempt++) {
      await tester.fling(scrollable, const Offset(0, -2400), 9000);
      await tester.pump(const Duration(milliseconds: 510));
      await tester.pump(const Duration(milliseconds: 30));
      if (_postRequests.where((r) => r.page == page).length > before) return;
    }

    throw TestFailure(
      'Scrolling did not start page $page. '
      'postCount=${postController(tester).allItems.length}, '
      'requests=${_postRequests.map((r) => '#${r.id}:${r.query}:${r.page}:${r.pending}').toList()}',
    );
  }

  Future<void> openPost(int id) async {
    final tile = await _revealPost(id);
    await tester.tap(tile);
    await tester.pump();
    await harness.pumpUntil(
      tester,
      () =>
          postDetailsScaffold().evaluate().isNotEmpty &&
          currentDetailPost(tester).id == id,
      description: 'details for post $id to become current',
    );
  }

  Future<void> openPostMenu(
    int id, {
    PostMenuOpener via = PostMenuOpener.longPress,
  }) async {
    final tile = await _revealPost(id);
    switch (via) {
      case PostMenuOpener.longPress:
        await tester.longPress(tile);
      case PostMenuOpener.rightClick:
        await tester.tap(
          tile,
          buttons: kSecondaryMouseButton,
          kind: PointerDeviceKind.mouse,
        );
    }
    await tester.pump();
    await harness.pumpUntilFound(tester, find.byType(KurumiContextMenuTile));
  }

  Future<void> choosePostMenuAction(String label) async {
    await tester.tap(
      find.descendant(
        of: find.byType(KurumiContextMenuTile),
        matching: find.text(label),
      ),
    );
    await tester.pump();
    await harness.settle(tester);
  }

  Future<void> openSearch() async {
    await tester.tap(find.byType(HomeSearchBar));
    await tester.pump();
    await harness.pumpUntilFound(tester, find.byType(SearchPageScaffold));
    await harness.settle(tester);
  }

  Future<void> submitSearch(
    String query, {
    bool waitForRequest = true,
  }) async {
    final field = find.descendant(
      of: find.byType(SearchAppBar),
      matching: find.byType(EditableText),
    );
    await tester.enterText(field, query);
    await tester.tap(field);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await harness.settle(tester);
    await tester.pump(const Duration(milliseconds: 300));
    final searchButton = find.byType(SearchButton2);
    await tester.ensureVisible(searchButton);
    await tester.tap(searchButton);
    await tester.pump();
    if (waitForRequest) {
      await harness.pumpUntil(
        tester,
        () => _postRequests.any((request) => request.query == query),
        description: 'search request for "$query" to start',
      );
    }
  }

  Future<void> clearSelectedSearchTags() async {
    final close = find.byIcon(Symbols.close);
    if (close.evaluate().isNotEmpty) {
      await tester.tap(close.last);
      await tester.pump();
    }
  }

  Future<void> openBookmarks() async {
    await harness.settle(tester);
    final shortcut = find.byKey(const Key('nav-shortcut-bookmarks'));
    if (shortcut.evaluate().isNotEmpty) {
      await tester.tap(shortcut);
    } else {
      await tester.tap(
        find.text(appStrings(tester).navigation.bookmarks).first,
      );
    }
    await harness.pumpUntil(
      tester,
      () =>
          find.byType(BookmarkPage).evaluate().isNotEmpty ||
          find.byType(BookmarkGroupBrowserPage).evaluate().isNotEmpty,
      description: 'bookmark library to open',
    );
    await harness.settle(tester);
    if (find.byType(BookmarkGroupBrowserPage).evaluate().isNotEmpty) {
      await tester.tap(find.text(appStrings(tester).bookmark.groups.all));
      await harness.pumpUntilFound(tester, find.byType(BookmarkPage));
    }
  }

  Future<void> openBookmarkDetails({
    required int postId,
    required int booruId,
    required String sourceUrl,
  }) async {
    final tile = bookmarkTile(
      postId: postId,
      booruId: booruId,
      sourceUrl: sourceUrl,
    ).hitTestable().first;
    await harness.pumpUntilFound(tester, tile);
    await tester.ensureVisible(tile);
    await tester.tap(tile);
    await harness.pumpUntilFound(tester, find.byType(BookmarkDetailsPage));
    await harness.pumpUntil(
      tester,
      () =>
          postDetailsScaffold().evaluate().isNotEmpty &&
          _matchesBookmarkPost(
            currentDetailPost(tester),
            postId: postId,
            booruId: booruId,
            sourceUrl: sourceUrl,
          ),
      description: 'bookmark details for post $postId from booru $booruId',
    );
  }

  bool _matchesBookmarkPost(
    Post post, {
    required int postId,
    required int booruId,
    required String sourceUrl,
  }) =>
      post.id == postId &&
      post.origin.booruId == booruId &&
      post.origin.sourceHost == normalizePostSourceHost(sourceUrl);

  Future<void> openDownloadManager() async {
    await _tapDrawerAction(appStrings(tester).sideMenu.download_manager);
    await harness.pumpUntilFound(tester, find.byType(DownloadManagerPage));
  }

  Future<void> goBack() async {
    const routeTypes = [
      BookmarkDetailsPage,
      PostDetailsPageScaffold,
      BookmarkPage,
      DownloadManagerPage,
    ];
    final activeRouteType = routeTypes
        .where((type) => find.byType(type).evaluate().isNotEmpty)
        .firstOrNull;

    await tester.binding.handlePopRoute();
    switch (activeRouteType) {
      case final routeType?:
        await harness.pumpUntil(
          tester,
          () => find.byType(routeType).evaluate().isEmpty,
          description: '$routeType route to pop',
        );
      case null:
        await tester.pump(const Duration(milliseconds: 500));
    }
  }

  Future<void> selectProfile(BooruConfig config) async {
    await harness.settle(tester);
    final shortcut = find.byKey(const Key('nav-shortcut-browse'));
    await tester.tap(
      shortcut.evaluate().isNotEmpty
          ? shortcut
          : find.text(appStrings(tester).navigation.browse).first,
    );
    await harness.settle(tester);
    final picker = find.byTooltip(appStrings(tester).navigation.choose_profile);
    if (picker.evaluate().isNotEmpty) {
      await tester.tap(picker);
      await harness.settle(tester);
    }
    await tester.tap(find.text(config.name).last);
    await tester.pump();
    await harness.pumpUntil(
      tester,
      () => _postRequests.any((request) => request.siteUrl == config.url),
      description: 'listing request for ${config.name}',
    );
  }

  /// Opens the edit/delete context menu of a profile in the selector.
  Future<void> openProfileMenu(BooruConfig config) async {
    await openProfiles();
    final selector = find.descendant(
      of: find.byType(ProfileManagementPage),
      matching: find.byKey(ValueKey(config.id)),
    );
    await tester.tap(selector, buttons: kSecondaryMouseButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> openAddProfile() async {
    await openProfiles();
    final add = find.text(appStrings(tester).generic.action.add);
    await tester.tap(add);
    await tester.pump();
    await harness.pumpUntilFound(tester, find.byType(AddBooruPageInternal));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(
      find.text(appStrings(tester).booru.quick_setup.custom_site),
    );
    await tester.pump();
  }

  Future<Finder> _revealPost(int id) async {
    final tile = postTile(id);
    await tester.scrollUntilVisible(
      tile,
      350,
      scrollable: postGridScrollable(),
    );
    await tester.ensureVisible(tile);
    await tester.pump();
    return tile;
  }

  Future<void> _tapDrawerAction(String label) async {
    final action = await _reveal(
      find.descendant(
        of: find.byKey(const Key('nav-catalog-list')),
        matching: find.text(label),
      ),
      description: 'drawer action "$label"',
    );
    await tester.tap(action);
    await harness.settle(tester);
  }

  Future<void> openProfiles() async {
    if (find.byType(ProfileManagementPage).evaluate().isNotEmpty) return;
    await _tapDrawerAction(appStrings(tester).sideMenu.settings);
    await harness.settle(tester);
    await tester.tap(
      find.byKey(const ValueKey('settings-navigation-profiles')),
    );
    await harness.settle(tester);
    await harness.pumpUntilFound(tester, find.byType(ProfileManagementPage));
  }

  /// Returns the first on-screen match of [finder], opening the side menu
  /// first when the match lives in a closed drawer.
  Future<Finder> _reveal(Finder finder, {required String description}) async {
    await harness.settle(tester);
    if (_firstOnScreen(finder) case final match?) return match;

    final menuButton = find.byKey(const Key('nav-menu-toggle')).hitTestable();
    if (menuButton.evaluate().isNotEmpty) {
      await tester.tap(menuButton.first);
    }
    await harness.settle(tester);

    final scrollable = find.descendant(
      of: find.byKey(const Key('nav-catalog-list')),
      matching: find.byType(Scrollable),
    );
    // Footer actions follow all profile tools and may be outside the viewport.
    if (scrollable.evaluate().isNotEmpty && _firstOnScreen(finder) == null) {
      tester.state<ScrollableState>(scrollable).position.jumpTo(0);
      await tester.pump();
      await tester.scrollUntilVisible(
        finder,
        160,
        scrollable: scrollable,
      );
      await harness.settle(tester);
    }

    await harness.pumpUntil(
      tester,
      () => _firstOnScreen(finder) != null,
      description: '$description to become visible',
    );
    return _firstOnScreen(finder)!;
  }

  Finder? _firstOnScreen(Finder finder) {
    final size = tester.view.physicalSize / tester.view.devicePixelRatio;
    final screen = Offset.zero & size;
    final count = finder.evaluate().length;
    for (var index = 0; index < count; index++) {
      final candidate = finder.at(index);
      final rect = tester.getRect(candidate);
      if (screen.contains(rect.topLeft) &&
          screen.contains(rect.bottomRight - const Offset(0.5, 0.5))) {
        return candidate;
      }
    }
    return null;
  }
}
