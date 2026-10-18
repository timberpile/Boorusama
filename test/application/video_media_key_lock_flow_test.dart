import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:boorusama/core/changelogs/providers.dart';
import 'package:boorusama/core/changelogs/types.dart';
import 'package:boorusama/core/posts/details/widgets.dart';
import 'package:boorusama/core/posts/details/src/widgets/post_details_page_view_scope.dart';
import 'package:boorusama/core/videos/lock/providers.dart';
import 'package:boorusama/core/videos/lock/widgets.dart';

import 'support/app_flow_finders.dart';
import 'support/fake_booru_backend.dart';
import 'support/fake_image_dio.dart';
import 'support/headless_app_harness.dart';
import 'support/keyboard_flow_driver.dart';

void main() {
  testWidgets(
    'production video viewer gates Play Pause and Toggle across lock cycles',
    (
      tester,
    ) async {
      final backend = FakeBooruBackend()
        ..enqueuePosts(page: 1, posts: [TestPost(id: 101, format: '.mp4')]);
      final harness = await HeadlessAppHarness.mount(
        tester,
        booruBackend: backend,
        viewportSize: kTvViewport,
        additionalOverrides: [
          changelogRepositoryProvider.overrideWith(
            (ref) => _NoChangelogRepository(),
          ),
          deterministicFaviconDioOverride(),
          deterministicImageDioOverride(),
        ],
      );
      await harness.pumpUntilFound(tester, postTile(101));
      await harness.settle(tester);
      final keys = KeyboardFlowDriver(tester: tester, harness: harness);
      await keys.navigateTo(postTile(101));
      await keys.select();
      await harness.pumpUntilFound(tester, postDetailsScaffold());
      await harness.settle(tester);

      final scaffold = tester.widget<PostDetailsPageScaffold>(
        postDetailsScaffold().first,
      );
      final details = scaffold.controller;
      expect(details.currentPost.value.isVideo, isTrue);

      final locker = find.byType(VideoScreenLocker);
      expect(locker, findsOneWidget);
      final container = ProviderScope.containerOf(tester.element(locker));
      final pages = PostDetailsPageViewScope.of(
        tester.element(postDetailsScaffold().first),
      );
      for (final key in [
        LogicalKeyboardKey.mediaPlay,
        LogicalKeyboardKey.mediaPause,
        LogicalKeyboardKey.mediaPlayPause,
      ]) {
        for (final playing in [false, true]) {
          for (final locked in [false, true, false]) {
            if (locked) {
              container.read(screenLockProvider.notifier).lock();
            } else {
              container.read(screenLockProvider.notifier).unlock();
            }
            await harness.settle(tester);
            expect(container.read(screenLockProvider), locked);
            expect(pages.keyboardShortcutsEnabled.value, !locked);
            await details.setCurrentVideoPlaying(playing);
            await harness.settle(tester);
            expect(details.isVideoPlaying.value, playing);
            await keys.press(key);
            final expected = locked
                ? playing
                : key == LogicalKeyboardKey.mediaPlay
                ? true
                : key == LogicalKeyboardKey.mediaPause
                ? false
                : !playing;
            expect(
              details.isVideoPlaying.value,
              expected,
              reason: '$key playing=$playing locked=$locked',
            );
          }
        }
      }
    },
  );
}

final class _NoChangelogRepository implements ChangelogRepository {
  @override
  Future<ChangelogData> loadLatestChangelog() async => ChangelogData(
    previousVersion: null,
    version: ReleaseVersion.fromText('9.0.0'),
    content: '',
  );

  @override
  Future<String> loadFullChangelog() async => '';

  @override
  Future<void> markChangelogAsSeen(ReleaseVersion version) async {}

  @override
  Future<bool> shouldShowChangelog(ReleaseVersion version) async => false;
}
