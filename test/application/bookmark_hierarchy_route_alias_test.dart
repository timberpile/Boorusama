import 'package:boorusama/core/bookmarks/src/pages/bookmark_group_browser_page.dart';
import 'package:boorusama/core/bookmarks/src/providers/bookmark_provider.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_group.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_library_state.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_view.dart';
import 'package:boorusama/core/bookmarks/src/types/post_bookmark.dart';
import 'package:boorusama/core/bookmarks/src/widgets/bookmark_local_group_card.dart';
import 'package:boorusama/core/bookmarks/src/widgets/bookmark_scroll_view.dart';
import 'package:boorusama/core/cache/misc_data_store.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/app_flow_finders.dart';
import 'support/fake_booru_backend.dart';
import 'support/headless_app_harness.dart';

const _collidingOriginalGroupId = '15800000-0000-4000-8000-000000000101';
const _convertedFolderGroupId = '15800000-0000-4000-8000-000000000102';
const _convertedDefaultFolderGroupId = '15800000-0000-4000-8000-000000000103';

void main() {
  testWidgets(
    'canonical colliding group ID opens its original direct timeline',
    (tester) async {
      final scenario = await _mount(tester);
      await _openBrowser(
        tester,
        scenario.harness,
        const BookmarkGroupBrowserPage(groupId: _collidingOriginalGroupId),
      );

      final view = tester.widget<BookmarkScrollView>(
        find.byType(BookmarkScrollView),
      );
      expect(view.view, BookmarkView.group(_collidingOriginalGroupId));
      await scenario.harness.pumpUntilFound(tester, postTile(101));
      expect(postTile(101), findsOneWidget);
      expect(postTile(102), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'legacy folder alias opens converted folder and its canonical child opens the original group',
    (tester) async {
      final scenario = await _mount(tester);
      await _openBrowser(
        tester,
        scenario.harness,
        const BookmarkGroupBrowserPage(folderId: _collidingOriginalGroupId),
      );

      var view = tester.widget<BookmarkScrollView>(
        find.byType(BookmarkScrollView),
      );
      expect(view.view, BookmarkView.group(_convertedFolderGroupId));
      await scenario.harness.pumpUntilFound(tester, postTile(102));
      expect(postTile(102), findsOneWidget);
      expect(
        find
            .byType(BookmarkLocalGroupCard)
            .evaluate()
            .map(
              (element) => (element.widget as BookmarkLocalGroupCard).title,
            ),
        contains('Original canonical group'),
      );

      await tester.tap(
        find.byWidgetPredicate(
          (widget) =>
              widget is BookmarkLocalGroupCard &&
              widget.title == 'Original canonical group',
        ),
      );
      await scenario.harness.settle(tester);

      view = tester.widget<BookmarkScrollView>(
        find.byType(BookmarkScrollView),
      );
      expect(view.view, BookmarkView.group(_collidingOriginalGroupId));
      await scenario.harness.pumpUntilFound(tester, postTile(101));
      expect(postTile(101), findsOneWidget);
      expect(postTile(102), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('canonical Default navigation ignores a folder alias', (
    tester,
  ) async {
    final scenario = await _mount(tester);
    await _openBrowser(
      tester,
      scenario.harness,
      const BookmarkGroupBrowserPage(groupId: defaultBookmarkGroupId),
    );

    final view = tester.widget<BookmarkScrollView>(
      find.byType(BookmarkScrollView),
    );
    expect(view.view, const BookmarkView.defaultGroup());
    await scenario.harness.pumpUntilFound(tester, postTile(103));
    expect(postTile(103), findsOneWidget);
    expect(postTile(104), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

Future<_Scenario> _mount(WidgetTester tester) async {
  final backend = FakeBooruBackend();
  final groups = [
    BookmarkGroup(
      id: defaultBookmarkGroupId,
      name: 'Default',
      bookmarkIds: const {103},
    ),
    BookmarkGroup(
      id: _collidingOriginalGroupId,
      name: 'Original canonical group',
      bookmarkIds: const {101},
      parentGroupId: _convertedFolderGroupId,
    ),
    BookmarkGroup(
      id: _convertedFolderGroupId,
      name: 'Converted legacy folder',
      bookmarkIds: const {102},
      position: 1,
    ),
    BookmarkGroup(
      id: _convertedDefaultFolderGroupId,
      name: 'Converted Default folder collision',
      bookmarkIds: const {104},
      position: 2,
    ),
  ];
  final posts = [
    for (final id in [101, 102, 103, 104]) _post(backend.config, id),
  ];
  final state = BookmarkLibraryState(
    bookmarks: posts,
    records: posts,
    groups: groups,
    legacyFolderGroupIds: const {
      _collidingOriginalGroupId: _convertedFolderGroupId,
      defaultBookmarkGroupId: _convertedDefaultFolderGroupId,
    },
  );
  final harness = await HeadlessAppHarness.mount(
    tester,
    booruBackend: backend,
    viewportSize: kMobileViewport,
    additionalOverrides: [
      bookmarkProvider.overrideWith(() => _MutableBookmarks(state)),
      miscDataStoreProvider.overrideWithValue(_MemoryMiscDataStore()),
    ],
  );
  return _Scenario(harness);
}

Future<void> _openBrowser(
  WidgetTester tester,
  HeadlessAppHarness harness,
  BookmarkGroupBrowserPage page,
) async {
  await harness.pumpUntilFound(tester, postTile(101));
  final context = tester.element(postTile(101));
  Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
  await harness.pumpUntilFound(tester, find.byType(BookmarkGroupBrowserPage));
  await harness.settle(tester);
}

PostBookmark _post(BooruConfig config, int id) => PostBookmark(
  id: id,
  booruId: config.booruId,
  createdAt: DateTime.utc(2026, 11, 7),
  updatedAt: DateTime.utc(2026, 11, 7),
  thumbnailUrl: '',
  sampleUrl: '',
  originalUrl: '',
  sourceUrl: config.url,
  width: 100,
  height: 100,
  md5: '',
  tags: {'route_alias_$id'},
  realSourceUrl: null,
  format: 'jpg',
  imageUrlResolver: const DefaultImageUrlResolver(),
  postId: id,
  metadata: const {},
);

final class _Scenario {
  const _Scenario(this.harness);

  final HeadlessAppHarness harness;
}

final class _MutableBookmarks extends BookmarkLibraryNotifier {
  _MutableBookmarks(this.initial);

  final BookmarkLibraryState initial;

  @override
  BookmarkLibraryState build() => initial;
}

final class _MemoryMiscDataStore implements MiscDataStore {
  final values = <String, String>{};

  @override
  String? get(String key) => values[key];

  @override
  Future<void> put(String key, String value) async {
    values[key] = value;
  }
}
