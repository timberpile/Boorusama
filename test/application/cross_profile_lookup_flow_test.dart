import 'package:boorusama/core/configs/manage/providers.dart';
import 'package:boorusama/core/posts/cross_profile_lookup/page.dart';
import 'package:boorusama/core/posts/details_parts/widgets.dart';
import 'package:boorusama/core/router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurumi/material.dart';

import '../support/boorusama_test_runtime.dart';
import 'support/app_flow_driver.dart';
import 'support/app_flow_finders.dart';
import 'support/fake_booru_backend.dart';
import 'support/headless_app_harness.dart';

void main() {
  testWidgets(
    'single-post menu opens target-scoped viewer and returns to source browsing',
    (tester) async {
      const hash = '0123456789abcdef0123456789abcdef';
      final backend = FakeBooruBackend();
      backend.posts[0] = TestPost(id: 101, md5: hash);
      backend.enqueuePosts(
        page: 1,
        siteUrl: backend.configB.url,
        query: 'md5:$hash',
        posts: [TestPost(id: 201, md5: hash)],
      );
      final downloads = MemoryDownloadService();
      final harness = await HeadlessAppHarness.mount(
        tester,
        booruBackend: backend,
        runtime: backend.createRuntime(
          configs: [backend.config, backend.configB],
          downloadService: downloads,
        ),
      );
      final driver = AppFlowDriver(tester: tester, harness: harness);
      await harness.pumpUntilFound(tester, postTile(101));
      await driver.openPostMenu(101, via: PostMenuOpener.rightClick);
      await tester.tap(find.text('Find on Other Profiles'));
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
      expect(postDetailsScaffold(), findsNothing);
      await tester.tap(match);
      await harness.pumpUntil(
        tester,
        () =>
            postDetailsScaffold().evaluate().isNotEmpty &&
            currentDetailPost(tester).id == 201,
      );
      await harness.settle(tester);
      final viewerContext = tester.element(
        find.byType(DownloadPostButton).last,
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
            .single
            .siteUrl,
        backend.configB.url,
      );
      await tester.tap(
        find
            .descendant(
              of: find.byType(DownloadPostButton).last,
              matching: find.byType(IconButton),
            )
            .first,
      );
      await harness.pumpUntil(tester, () => downloads.requests.isNotEmpty);
      expect(
        downloads.requests.single.url,
        'https://headless-b.booru.test/posts/201.jpg',
      );
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
