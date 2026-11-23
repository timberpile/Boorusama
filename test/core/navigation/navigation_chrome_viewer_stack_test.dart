import 'package:boorusama/core/navigation/navigation_chrome_controller.dart';
import 'package:boorusama/core/navigation/destination_activity.dart';
import 'package:boorusama/core/navigation/destination_id.dart';
import 'package:boorusama/core/navigation/destination_profile_scope.dart';
import 'package:boorusama/core/posts/details/src/types/viewer_entry.dart';
import 'package:boorusama/core/posts/details/src/widgets/post_details_scope.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/settings/providers.dart';
import 'package:boorusama/core/settings/types.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurumi/material.dart';

void main() {
  late ProviderContainer container;
  late NavigationChromeController chrome;
  setUp(() {
    container = ProviderContainer();
    chrome = container.read(navigationChromeProvider.notifier);
  });
  tearDown(() => container.dispose());
  NavigationChromeState state() => container.read(navigationChromeProvider);

  test('returning from Work restores the still-open Page Viewer', () {
    final page = Object();
    final work = Object();
    chrome.setViewerFor(
      page,
      active: true,
      immersive: true,
      bottomObstruction: 84,
    );
    chrome.setViewerFor(
      work,
      active: true,
      immersive: false,
      bottomObstruction: 120,
      routeProgress: 0,
    );
    expect(chrome.viewerRouteProgress.value, 1);
    chrome.setViewerFor(
      work,
      active: true,
      immersive: false,
      closing: true,
      bottomObstruction: 120,
      routeProgress: 0.4,
    );
    expect(state().viewerClosing, isFalse);
    expect(chrome.viewerRouteProgress.value, 1);
    chrome.setViewerFor(work, active: false, immersive: false);
    expect(state().viewerOpen, isTrue);
    expect(state().viewerImmersive, isTrue);
    expect(state().viewerBottomObstruction, 84);
    expect(chrome.viewerRouteProgress.value, 1);
  });

  test(
    'covered Viewer updates retain their order and cannot replace the top',
    () {
      final page = Object();
      final work = Object();
      chrome.setViewerFor(page, active: true, immersive: false);
      chrome.setViewerFor(
        work,
        active: true,
        immersive: false,
        bottomObstruction: 120,
      );
      chrome.setViewerFor(
        page,
        active: true,
        immersive: true,
        bottomObstruction: 92,
      );
      expect(state().viewerImmersive, isFalse);
      expect(state().viewerBottomObstruction, 120);
      chrome.setViewerImmersive(true);
      expect(state().viewerImmersive, isTrue);
      chrome.setViewerFor(work, active: false, immersive: false);
      expect(state().viewerImmersive, isTrue);
      expect(state().viewerBottomObstruction, 92);
    },
  );

  test('three nested Viewers survive out-of-order and delayed cleanup', () {
    final page = Object();
    final work = Object();
    final nested = Object();
    for (final owner in [page, work, nested]) {
      chrome.setViewerFor(owner, active: true, immersive: false);
    }
    chrome.setViewerFor(work, active: false, immersive: false);
    expect(state().viewerOpen, isTrue);
    chrome.setViewerFor(nested, active: false, immersive: false);
    expect(state().viewerOpen, isTrue);
    chrome.setViewerProgressFor(work, 0);
    chrome.setViewerProgressFor(nested, 0);
    chrome.setViewerFor(nested, active: false, immersive: false);
    expect(chrome.viewerRouteProgress.value, 1);
    expect(state().viewerOpen, isTrue);
    chrome.setViewerFor(page, active: false, immersive: false);
    expect(state().viewerOpen, isFalse);
    expect(state().viewerBottomObstruction, 0);
    expect(chrome.viewerRouteProgress.value, 0);
  });

  for (final hidden in [false, true]) {
    test('only final exit restores feed chrome, hidden=$hidden', () {
      if (hidden) {
        chrome.userScroll(delta: 100, pixels: 200, outOfRange: false);
        chrome.endScroll(pixels: 200);
      }
      final page = Object();
      final work = Object();
      chrome.setViewerFor(page, active: true, immersive: false);
      chrome.setViewerFor(work, active: true, immersive: false);
      chrome.setViewerFor(work, active: false, immersive: false);
      expect(state().viewerOpen, isTrue);
      chrome.setViewerFor(
        page,
        active: true,
        immersive: false,
        closing: true,
      );
      chrome.setViewerProgressFor(page, 0.5);
      expect(state().viewerClosing, isTrue);
      expect(chrome.viewerRouteProgress.value, 0.5);
      chrome.setViewerFor(page, active: false, immersive: false);
      expect(state().viewerOpen, isFalse);
      expect(state().barHiddenFraction, hidden ? 1 : 0);
    });
  }

  testWidgets(
    'covered Viewer releases chrome when its destination deactivates',
    (
      tester,
    ) async {
      final scoped = ProviderContainer(
        overrides: [
          settingsProvider.overrideWithValue(Settings.defaultSettings),
          imageViewerSettingsProvider.overrideWithValue(
            Settings.defaultSettings.viewer,
          ),
        ],
      );
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        scoped.dispose();
      });
      final scopedChrome = scoped.read(navigationChromeProvider);
      expect(scopedChrome.viewerOpen, isFalse);
      final child = PostDetailsScope<Post>(
        initialIndex: 0,
        initialThumbnailUrl: null,
        posts: const [],
        sequence: ViewerEntrySequence(const []),
        dislclaimer: null,
        scrollController: null,
        child: const SizedBox(),
      );
      Widget host(bool active) => UncontrolledProviderScope(
        container: scoped,
        child: MaterialApp(
          home: NavigationActivity(
            // Already covered by another Viewer, so this signal does not change.
            active: false,
            child: DestinationScope(
              id: const DestinationId.app(AppDestination.bookmarks),
              active: active,
              child: child,
            ),
          ),
        ),
      );
      await tester.pumpWidget(host(true));
      await tester.pump();
      expect(scoped.read(navigationChromeProvider).viewerOpen, isTrue);
      await tester.pumpWidget(host(false));
      await tester.pump();
      expect(scoped.read(navigationChromeProvider).viewerOpen, isFalse);
    },
  );
}
