import 'package:boorusama/core/bookmarks/src/widgets/bookmark_group_picker.dart';
import 'package:boorusama/core/configs/manage/providers.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/configs/manage/widgets.dart';
import 'package:boorusama/core/downloads/urls/providers.dart';
import 'package:boorusama/core/posts/details_parts/src/toolbars/bookmark_post_button.dart';
import 'package:boorusama/core/posts/details_parts/src/toolbars/customizable_post_toolbar.dart';
import 'package:boorusama/core/posts/details_parts/src/toolbars/download_post_button.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/posts/shares/src/share_post_button.dart';
import 'package:boorusama/core/posts/shares/src/unified_post_share_sheet.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:boorusama/core/settings/src/pages/settings_page.dart';
import 'package:boorusama/core/settings/src/pages/image_viewer_page.dart';
import 'package:boorusama/core/settings/src/pages/viewer_toolbar_layout_page.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurumi/material.dart';

import '../support/boorusama_test_runtime.dart';
import 'support/app_flow_finders.dart';
import 'support/fake_booru_backend.dart';
import 'support/headless_app_harness.dart';

void main() {
  testWidgets('Android Back from the editor returns to Image Viewer settings', (
    tester,
  ) async {
    final harness = await HeadlessAppHarness.mount(
      tester,
      viewportSize: kMobileViewport,
    );
    await harness.pumpUntilFound(tester, postTile(101));
    Navigator.of(tester.element(postTile(101)), rootNavigator: true).push(
      MaterialPageRoute<void>(
        builder: (_) => const SettingsPage(initial: 'viewer'),
      ),
    );
    await harness.settle(tester);
    await tester.tap(find.text('Toolbar'));
    await harness.settle(tester);
    expect(find.byType(ViewerToolbarLayoutPage), findsOneWidget);
    await tester.binding.handlePopRoute();
    await harness.settle(tester);
    expect(find.byType(ViewerToolbarLayoutPage), findsNothing);
    expect(find.byType(ImageViewerPage), findsOneWidget);
  });

  testWidgets(
    'overflow actions use the displayed source while another profile is active',
    (tester) async {
      final backend = FakeBooruBackend();
      final downloads = MemoryDownloadService();
      final source = backend.configB;
      final post = TestPost(
        id: 42,
        originalImageUrl: 'https://headless-b.booru.test/posts/42.jpg',
        sampleImageUrl: 'https://headless-b.booru.test/posts/42-sample.jpg',
        origin: PostOrigin.fromSource(
          booruType: source.auth.booruType,
          booruId: source.booruId,
          source: source.url,
          profileIdHint: source.id,
        ),
      );
      final harness = await HeadlessAppHarness.mount(
        tester,
        booruBackend: backend,
        viewportSize: kMobileViewport,
        runtime: backend.createRuntime(
          configs: [backend.config, source],
          downloadService: downloads,
        ),
        additionalOverrides: [
          downloadSourceProvider(source.auth)
              .overrideWithValue(const DefaultDownloadSource()),
        ],
      );
      await harness.pumpUntilFound(tester, postTile(101));
      final context = tester.element(postTile(101));
      final container = ProviderScope.containerOf(context);
      Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute<void>(
          builder: (_) => CurrentBooruConfigScope(
            config: source,
            child: Scaffold(
              body: Align(
                alignment: Alignment.bottomCenter,
                child: ConfiguredPostToolbar(
                  layout: ViewerToolbarLayout(toolbar: const []),
                  buttons: [
                    ViewerToolbarButtonData(
                      action: ViewerToolbarAction.download,
                      title: 'Download',
                      widget: const SizedBox.shrink(),
                      menuBuilder: (_, close) => DownloadPostButton(
                        post: post,
                        menuItem: true,
                        onMenuAction: close,
                      ),
                    ),
                    ViewerToolbarButtonData(
                      action: ViewerToolbarAction.bookmark,
                      title: 'Bookmark',
                      widget: const SizedBox.shrink(),
                      menuBuilder: (_, _) => BookmarkPostButton(
                        post: post,
                        config: source.auth,
                        menuItem: true,
                      ),
                    ),
                    ViewerToolbarButtonData(
                      action: ViewerToolbarAction.share,
                      title: 'Share',
                      widget: const SizedBox.shrink(),
                      menuBuilder: (_, _) => SharePostButton(
                        post: post,
                        auth: source.auth,
                        configViewer: source.viewer,
                        download: source.download,
                        menuItem: true,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await harness.settle(tester);
      Future<void> open() async {
        await tester.tap(find.byKey(const Key('viewer-toolbar-more')));
        await harness.settle(tester);
      }

      await open();
      await tester.tap(
        find.byTooltip(appStrings(tester).settings.download.quality),
      );
      await harness.settle(tester);
      await tester.tap(find.text('Original'));
      await harness.pumpUntil(tester, () => downloads.requests.length == 1);
      await harness.settle(tester);
      expect(downloads.requests.single.url, post.originalImageUrl);
      expect(
        find.byKey(const Key('viewer-toolbar-menu-download')),
        findsNothing,
      );
      await open();
      await tester.tap(find.byKey(const Key('viewer-toolbar-menu-bookmark')));
      await harness.pumpUntilFound(tester, find.byType(BookmarkGroupPicker));
      await tester.binding.handlePopRoute();
      await harness.settle(tester);
      await open();
      await tester.tap(find.byKey(const Key('viewer-toolbar-menu-share')));
      await harness.pumpUntilFound(tester, find.byType(UnifiedPostShareSheet));
      expect(
        tester
            .widget<UnifiedPostShareSheet>(find.byType(UnifiedPostShareSheet))
            .auth,
        source.auth,
      );
      expect(
        container.read(currentReadOnlyBooruConfigProvider).id,
        backend.config.id,
      );
      expect(downloads.requests, hasLength(1));
    },
  );
}
