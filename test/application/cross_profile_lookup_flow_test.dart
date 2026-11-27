import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/configs/manage/providers.dart';
import 'package:boorusama/core/posts/cross_profile_lookup/page.dart';
import 'package:boorusama/core/posts/details_parts/widgets.dart';
import 'package:boorusama/core/posts/sources/types.dart';
import 'package:boorusama/core/router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurumi/material.dart';
import 'package:kurumi/kurumi.dart';

import '../support/boorusama_test_runtime.dart';
import 'support/app_flow_driver.dart';
import 'support/app_flow_finders.dart';
import 'support/fake_booru_backend.dart';
import 'support/headless_app_harness.dart';

void main() {
  testWidgets('local file route searches the configured profile by MD5', (
    tester,
  ) async {
    const hash = 'fedcba9876543210fedcba9876543210';
    final backend = FakeBooruBackend();
    backend.enqueuePosts(
      page: 1,
      siteUrl: backend.config.url,
      query: 'md5:$hash',
      posts: [TestPost(id: 205, md5: hash)],
    );
    late WidgetRef ref;
    final harness = await HeadlessAppHarness.mount(
      tester,
      booruBackend: backend,
      appWrapper: (child) => Consumer(
        builder: (context, widgetRef, _) {
          ref = widgetRef;
          return child;
        },
      ),
    );
    await harness.pumpUntilFound(tester, postTile(101));
    findLocalFileOnOtherProfiles(ref, hash, [backend.config]);
    final lookup = find.byType(CrossProfileLookupPage);
    await harness.pumpUntilFound(tester, lookup);
    await harness.pumpUntilFound(
      tester,
      find.byKey(ValueKey('match-${backend.config.id}-205')),
    );
    expect(
      backend.requests
          .whereType<FakeBooruPostRequest>()
          .where((request) => request.query.isNotEmpty)
          .map((request) => request.query),
      ['md5:$hash'],
    );
    ref.read(routerProvider).pop();
    await harness.pumpUntilFound(tester, postTile(101));
    expect(lookup, findsNothing);
  });

  testWidgets(
    'single-post menu opens target-scoped viewer and returns to source browsing',
    (tester) async {
      const hash = '0123456789abcdef0123456789abcdef';
      final backend = FakeBooruBackend();
      final third = BooruConfig.fromJson({
        ...backend.configB.toJson(),
        'id': '00000000-0000-4000-8000-000000000003',
        'url': FakeBooruBackend.secondSiteUrl,
        'name': 'Third profile',
      });
      final source = PostSource.pixiv(123456);
      backend.posts[0] = TestPost(id: 101, md5: hash, source: source);
      backend.enqueuePosts(
        page: 1,
        siteUrl: backend.configB.url,
        query: 'md5:$hash',
        posts: [TestPost(id: 201, md5: hash)],
      );
      backend.enqueuePosts(
        page: 1,
        siteUrl: backend.configB.url,
        query: 'pixiv_id:123456',
        posts: [TestPost(id: 202, source: source)],
      );
      backend.enqueuePosts(
        page: 1,
        siteUrl: third.url,
        query: 'md5:$hash',
        posts: [TestPost(id: 301, md5: hash)],
      );
      final downloads = MemoryDownloadService();
      final harness = await HeadlessAppHarness.mount(
        tester,
        booruBackend: backend,
        runtime: backend.createRuntime(
          configs: [backend.config, backend.configB, third],
          downloadService: downloads,
        ),
      );
      final driver = AppFlowDriver(tester: tester, harness: harness);
      await harness.pumpUntilFound(tester, postTile(101));
      await driver.openPostMenu(101, via: PostMenuOpener.rightClick);
      await tester.tap(find.text('Find on Other Profiles'));
      final search = find.widgetWithText(FilledButton, 'Search').hitTestable();
      await harness.pumpUntilFound(tester, search);
      expect(
        find.widgetWithText(ListTile, backend.config.name),
        findsNothing,
      );
      expect(
        backend.requests.whereType<FakeBooruPostRequest>().where(
          (request) => request.query.startsWith('md5:'),
        ),
        isEmpty,
      );
      await tester.tap(
        find
            .descendant(
              of: find.widgetWithText(ListTile, backend.configB.name),
              matching: find.widgetWithText(FilterChip, 'Pixiv Artwork ID'),
            )
            .hitTestable(),
      );
      await tester.tap(search);
      await harness.pumpUntilFound(
        tester,
        find.byType(CrossProfileLookupPage),
      );
      final container = ProviderScope.containerOf(
        tester.element(find.byType(CrossProfileLookupPage)),
        listen: false,
      );
      final match = find.byKey(ValueKey('match-${backend.configB.id}-201'));
      await harness.pumpUntilFound(tester, match);
      await harness.pumpUntilFound(
        tester,
        find.byKey(ValueKey('match-${backend.configB.id}-202')),
      );
      await harness.pumpUntil(
        tester,
        () => backend.requests.whereType<FakeBooruPostRequest>().any(
          (request) =>
              request.siteUrl == third.url &&
              request.completed &&
              request.resultIds.contains(301),
        ),
      );
      final resultPage = find.byType(CrossProfileLookupPage);
      expect(
        find.descendant(of: resultPage, matching: find.text('Exact MD5')),
        findsWidgets,
      );
      expect(
        find.descendant(
          of: resultPage,
          matching: find.text('Pixiv Artwork ID'),
        ),
        findsOneWidget,
      );
      expect(
        backend.requests.whereType<FakeBooruPostRequest>().where(
          (request) => request.query.startsWith('source:'),
        ),
        isEmpty,
      );
      expect(postDetailsScaffold(), findsNothing);
      await tester.tap(match);
      await harness.pumpUntil(
        tester,
        () =>
            postDetailsScaffold().evaluate().isNotEmpty &&
            currentDetailPost(tester).id == 201,
      );
      await harness.settle(tester);
      await harness.showViewerControls(tester);
      final viewerContext = tester.element(
        find.byType(DownloadPostButton).hitTestable().first,
      );
      final viewerScope = ProviderScope.containerOf(
        viewerContext,
        listen: false,
      );
      expect(
        viewerScope.read(currentReadOnlyBooruConfigProvider).id,
        backend.configB.id,
      );
      expect(
        container.read(currentReadOnlyBooruConfigProvider).id,
        backend.config.id,
      );
      expect(
        backend.requests
            .whereType<FakeBooruPostRequest>()
            .where((r) => r.query.startsWith('md5:'))
            .map((request) => request.siteUrl),
        unorderedEquals([backend.configB.url, third.url]),
      );
      await tester.tap(
        find
            .descendant(
              of: find.byType(DownloadPostButton).hitTestable().first,
              matching: find.byType(KurumiActionIconButton),
            )
            .first,
      );
      await harness.pumpUntil(tester, () => downloads.requests.isNotEmpty);
      expect(
        downloads.requests.single.url,
        'https://headless-b.booru.test/posts/201.jpg',
      );
      for (final id in [202, 301]) {
        await tester.fling(
          postDetailsScaffold().hitTestable().first,
          const Offset(-600, 0),
          1000,
        );
        await harness.pumpUntil(
          tester,
          () => currentDetailPost(tester).id == id,
        );
      }
      await harness.showViewerControls(tester);
      final thirdViewer = ProviderScope.containerOf(
        tester.element(find.byType(DownloadPostButton).hitTestable().first),
        listen: false,
      );
      expect(thirdViewer.read(currentReadOnlyBooruConfigProvider).id, third.id);
      container.read(routerProvider).pop();
      await harness.pumpUntilFound(
        tester,
        find.byType(CrossProfileLookupPage),
      );
      container.read(routerProvider).pop();
      await harness.pumpUntilFound(tester, postTile(101));
      expect(
        container.read(currentReadOnlyBooruConfigProvider).id,
        backend.config.id,
      );
    },
  );
}
