import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:boorusama/core/bookmarks/src/pages/bookmark_page.dart';
import 'package:boorusama/core/bookmarks/src/pages/bookmark_group_browser_page.dart';
import 'package:boorusama/core/bookmarks/src/pages/bookmark_details_page.dart';
import 'package:boorusama/core/bookmarks/src/widgets/bookmark_group_picker.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/posts/details_parts/widgets.dart';
import 'package:boorusama/core/posts/listing/widgets.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/posts/sources/types.dart';

import 'support/app_flow_driver.dart';
import 'support/app_flow_finders.dart';
import 'support/application_test_store.dart';
import 'support/fake_booru_backend.dart';
import 'support/fake_image_dio.dart';
import 'support/headless_app_harness.dart';

void main() {
  testWidgets(
    'bookmarks a source post, opens its library details, and removes it',
    (tester) async {
      final backend = FakeBooruBackend(strictPostScripts: true);
      final post = _post(
        101,
        tags: const {'bookmark_marker', 'cat'},
        sourceUrl: 'https://source.test/a/101',
      );
      _queueHome(backend, backend.config.url, post);
      final store = ApplicationTestStore.withProfiles(backend.config);
      final harness = await _mount(tester, backend, store);

      await _waitForSourcePost(harness, tester, 101);
      final driver = AppFlowDriver(tester: tester, harness: harness);
      await driver.openPost(101);
      await _tapBookmark(tester);
      await harness.pumpUntil(
        tester,
        () => store.bookmarkRepository.bookmarks.length == 1,
        description: 'post 101 bookmark to persist',
      );

      final saved = store.bookmarkRepository.bookmarks.single;
      expect(saved.postId, 101);
      expect(saved.booruId, backend.config.auth.booruIdHint);
      expect(saved.tags, contains('bookmark_marker'));
      expect(saved.realSourceUrl, 'https://source.test/a/101');
      expect(saved.sourceUrl, contains('headless.booru.test'));
      expect(saved.sourceUrl, contains('101'));

      await driver.goBack();
      await harness.pumpUntilFound(tester, find.byType(PostGrid<Post>));
      await driver.openBookmarks();
      await harness.pumpUntilFound(
        tester,
        bookmarkTile(postId: 101, booruId: saved.booruId),
      );
      await driver.openBookmarkDetails(
        postId: 101,
        booruId: saved.booruId,
        sourceUrl: saved.post.origin.sourceHost,
      );
      final detailPost = currentDetailPost(tester);
      expect(detailPost.id, 101);
      expect(detailPost.tags, contains('bookmark_marker'));
      expect(detailPost.source.url, 'https://source.test/a/101');

      await _removeBookmarkFromAllView(tester, harness);
      await harness.pumpUntil(
        tester,
        () => store.bookmarkRepository.bookmarks.isEmpty,
        description: 'removal from bookmark details to reach the repository',
      );
      await driver.goBack();
      await harness.pumpUntil(
        tester,
        () => bookmarkTile(
          postId: 101,
          booruId: saved.booruId,
        ).evaluate().isEmpty,
        description: 'removed bookmark tile to leave the library',
      );
      expect(
        find.byType(BookmarkPage).evaluate().isNotEmpty ||
            find.byType(BookmarkGroupBrowserPage).evaluate().isNotEmpty,
        isTrue,
      );
    },
  );

  testWidgets('bookmark library data survives an app remount', (
    tester,
  ) async {
    final backend = FakeBooruBackend(strictPostScripts: true);
    final post = _post(
      101,
      tags: const {'persisted_bookmark'},
      sourceUrl: 'https://source.test/persisted/101',
    );
    _queueHome(backend, backend.config.url, post);
    final store = ApplicationTestStore.withProfiles(backend.config);
    final harness = await _mount(tester, backend, store);

    await _waitForSourcePost(harness, tester, 101);
    await AppFlowDriver(tester: tester, harness: harness).openPost(101);
    await _tapBookmark(tester);
    await harness.pumpUntil(
      tester,
      () => store.bookmarkRepository.bookmarks.length == 1,
      description: 'bookmark to be stored before remount',
    );
    final saved = store.bookmarkRepository.bookmarks.single;
    _queueHome(backend, backend.config.url, post);

    final remounted = await store.remount(tester, previous: harness);
    await _waitForSourcePost(remounted, tester, 101);
    final driver = AppFlowDriver(tester: tester, harness: remounted);
    await driver.openBookmarks();
    await driver.openBookmarkDetails(
      postId: 101,
      booruId: saved.booruId,
      sourceUrl: saved.post.origin.sourceHost,
    );

    expect(store.bookmarkRepository.bookmarks, hasLength(1));
    final restored = currentDetailPost(tester);
    expect(restored.id, 101);
    expect(restored.tags, contains('persisted_bookmark'));
    expect(restored.origin.sourceHost, saved.post.origin.sourceHost);
  });

  testWidgets(
    'reopened details stay synchronized across remove and re-add',
    (tester) async {
      final backend = FakeBooruBackend(strictPostScripts: true);
      final post = _post(
        101,
        tags: const {'repeat_bookmark'},
        sourceUrl: 'https://source.test/repeat/101',
      );
      _queueHome(backend, backend.config.url, post);
      final store = ApplicationTestStore.withProfiles(backend.config);
      final harness = await _mount(tester, backend, store);

      await _waitForSourcePost(harness, tester, 101);
      final driver = AppFlowDriver(tester: tester, harness: harness);
      await driver.openPost(101);
      await _tapBookmark(tester);
      await harness.pumpUntil(
        tester,
        () => store.bookmarkRepository.bookmarks.length == 1,
        description: 'first visit bookmark to persist',
      );

      await driver.goBack();
      await harness.pumpUntilFound(tester, find.byType(PostGrid<Post>));
      await driver.openPost(101);
      expect(_bookmarkFilled(tester), isTrue);
      await _tapBookmark(tester);
      await harness.pumpUntil(
        tester,
        () => store.bookmarkRepository.bookmarks.isEmpty,
        description: 'removal from reopened details to persist',
      );
      expect(_bookmarkFilled(tester), isFalse);

      await _tapBookmark(tester);
      await harness.pumpUntil(
        tester,
        () => store.bookmarkRepository.bookmarks.length == 1,
        description: 're-added bookmark to persist',
      );
      expect(store.bookmarkRepository.bookmarks.single.postId, 101);
      expect(store.bookmarkRepository.bookmarks, hasLength(1));
      expect(_bookmarkFilled(tester), isTrue);
    },
  );

  testWidgets(
    'same numeric post IDs from two sites remain separate bookmarks',
    (tester) async {
      final backend = FakeBooruBackend(strictPostScripts: true);
      final profileB = backend.configB.copyWith(name: 'Second site');
      final postA = _post(
        101,
        tags: const {'site_a_marker'},
        sourceUrl: 'https://source.test/site-a/101',
        imageUrl: 'https://images.test/site-a-101.png',
      );
      final postB = _post(
        101,
        tags: const {'site_b_marker'},
        sourceUrl: 'https://source.test/site-b/101',
        imageUrl: 'https://images.test/site-b-101.png',
      );
      _queueHome(backend, backend.config.url, postA);
      _queueHome(backend, profileB.url, postB);
      _queueHome(backend, backend.config.url, postA);
      final store = ApplicationTestStore.withProfiles(
        backend.config,
        additional: [profileB],
      );
      final harness = await _mount(tester, backend, store);

      await _waitForSourcePost(harness, tester, 101);
      final driver = AppFlowDriver(tester: tester, harness: harness);
      await driver.openPost(101);
      await _tapBookmark(tester);
      await harness.pumpUntil(
        tester,
        () => store.bookmarkRepository.bookmarks.length == 1,
        description: 'site A post 101 bookmark to persist',
      );
      final bookmarkA = store.bookmarkRepository.bookmarks.single;
      await driver.goBack();
      await harness.pumpUntilFound(tester, find.byType(PostGrid<Post>));
      await driver.selectProfile(profileB);
      await harness.pumpUntilFound(tester, listingPostWithTag('site_b_marker'));
      await driver.openPost(101);
      await _tapBookmark(tester);
      await harness.pumpUntil(
        tester,
        () => store.bookmarkRepository.bookmarks.length == 2,
        description: 'site B post 101 bookmark to persist separately',
      );
      final bookmarkB = store.bookmarkRepository.bookmarks.singleWhere(
        (bookmark) => bookmark.tags.contains('site_b_marker'),
      );

      expect(bookmarkA.postId, bookmarkB.postId);
      expect(bookmarkA.booruId, bookmarkB.booruId);
      expect(bookmarkA.originalUrl, isNot(bookmarkB.originalUrl));
      expect(bookmarkA.sourceUrl, isNot(bookmarkB.sourceUrl));

      await driver.goBack();
      await harness.pumpUntilFound(tester, find.byType(PostGrid<Post>));
      await driver.openBookmarks();
      final siteBTile = listingPostWithTag('site_b_marker').hitTestable();
      await harness.pumpUntilFound(tester, siteBTile);
      expect(store.bookmarkRepository.bookmarks, hasLength(2));

      await tester.tap(siteBTile);
      await harness.pumpUntilFound(tester, find.byType(BookmarkDetailsPage));
      final selectedB = currentDetailPost(tester);
      expect(selectedB.tags, contains('site_b_marker'));
      await _removeBookmarkFromAllView(tester, harness);
      await harness.pumpUntil(
        tester,
        () => store.bookmarkRepository.bookmarks.length == 1,
        description: 'site B bookmark to be removed independently',
      );
      expect(
        store.bookmarkRepository.bookmarks.single.sourceUrl,
        bookmarkA.sourceUrl,
      );
      expect(
        store.bookmarkRepository.bookmarks.single.post.tags,
        contains('site_a_marker'),
      );
    },
  );
}

Future<HeadlessAppHarness> _mount(
  WidgetTester tester,
  FakeBooruBackend backend,
  ApplicationTestStore store,
) => store.mount(
  tester,
  backend: backend,
  viewportSize: const Size(720, 1000),
  additionalOverrides: [deterministicImageDioOverride()],
);

TestPost _post(
  int id, {
  required Set<String> tags,
  required String sourceUrl,
  String? imageUrl,
}) => TestPost(
  id: id,
  tags: tags,
  source: RawWebSource(
    faviconUrl: null,
    url: sourceUrl,
    uri: Uri.parse(sourceUrl),
  ),
  thumbnailImageUrl: imageUrl ?? '',
  sampleImageUrl: imageUrl ?? '',
  originalImageUrl: imageUrl ?? '',
);

void _queueHome(FakeBooruBackend backend, String siteUrl, TestPost post) =>
    backend
      ..enqueuePosts(siteUrl: siteUrl, page: 1, posts: [post])
      ..enqueuePosts(siteUrl: siteUrl, page: 2, posts: const []);

Future<void> _waitForSourcePost(
  HeadlessAppHarness harness,
  WidgetTester tester,
  int id,
) => harness.pumpUntil(
  tester,
  () => find
      .byWidgetPredicate(
        (widget) =>
            widget is SliverPostGridImageGridItem && widget.post.id == id,
      )
      .evaluate()
      .isNotEmpty,
  description: 'source post $id to render',
);

Future<void> _tapBookmark(WidgetTester tester) async {
  final bookmarkButton = find.descendant(
    of: find.byType(BookmarkPostButton),
    matching: find.byType(IconButton),
  );
  await tester.tap(bookmarkButton);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(seconds: 5));
}

Future<void> _removeBookmarkFromAllView(
  WidgetTester tester,
  HeadlessAppHarness harness,
) async {
  await _tapBookmark(tester);
  await harness.pumpUntilFound(tester, find.byType(BookmarkGroupPicker));
  final defaultGroup = find.text(
    appStrings(tester).bookmark.groups.default_group,
  );
  await tester.tap(defaultGroup.last);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(seconds: 5));
}

bool _bookmarkFilled(WidgetTester tester) =>
    (tester
                .widget<CustomPaint>(
                  find.byWidgetPredicate(
                    (widget) =>
                        widget is CustomPaint &&
                        widget.painter is BookmarkWithDropdownIconPainter,
                  ),
                )
                .painter
            as BookmarkWithDropdownIconPainter)
        .fill;
