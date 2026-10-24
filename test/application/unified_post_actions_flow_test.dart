import 'package:oktoast/oktoast.dart';
import 'package:boorusama/core/posts/listing/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/configs/manage/providers.dart';
import 'package:boorusama/core/posts/listing/src/types/post_action_snapshot.dart';
import 'package:boorusama/core/posts/listing/src/widgets/post_actions.dart';
import 'package:boorusama/core/posts/post/types.dart';

import '../support/boorusama_test_runtime.dart';
import 'support/app_flow_finders.dart';
import 'support/fake_booru_backend.dart';
import 'support/headless_app_harness.dart';

void main() {
  testWidgets(
    'mixed-source equal IDs dispatch through each source without changing the active profile',
    (tester) async {
      final backend = FakeBooruBackend();
      final downloads = MemoryDownloadService();
      final harness = await HeadlessAppHarness.mount(
        tester,
        booruBackend: backend,
        runtime: backend.createRuntime(
          configs: [backend.config, backend.configB],
          downloadService: downloads,
        ),
      );
      await harness.pumpUntilFound(tester, postTile(101));
      final targets = <Post>[
        for (final config in [backend.config, backend.configB])
          TestPost(
            id: 42,
            origin: PostOrigin.fromSource(
              booruType: config.auth.booruType,
              booruId: config.booruId,
              source: config.url,
              profileIdHint: config.id,
            ),
          ),
      ];
      final snapshot = PostActionSnapshot(targets, [
        backend.config,
        backend.configB,
      ]);
      final context = tester.element(postTile(101));
      final container = ProviderScope.containerOf(context, listen: false);
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => Consumer(
            builder: (context, ref, _) {
              final actions = postActionDefinitions(context, ref, snapshot);
              return Scaffold(
                body: Column(
                  children: [
                    for (final action in actions)
                      TextButton(
                        onPressed: action.execute,
                        child: Text(action.label),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      );
      await harness.settle(tester);
      expect(find.text('View in Browser'), findsNothing);
      expect(find.text('View Tags'), findsNothing);
      expect(find.text('Download'), findsOneWidget);
      targets.clear();
      await tester.tap(find.text('Download'));
      await harness.pumpUntil(tester, () => downloads.requests.length == 2);
      expect(
        downloads.requests.map((r) => r.url),
        unorderedEquals([
          'https://headless.booru.test/posts/42.jpg',
          'https://headless-b.booru.test/posts/42.jpg',
        ]),
      );
      expect(
        container.read(currentReadOnlyBooruConfigProvider).id,
        backend.config.id,
      );
    },
  );

  testWidgets('a failed shared action keeps its snapshot available for retry', (
    tester,
  ) async {
    final backend = FakeBooruBackend();
    final harness = await HeadlessAppHarness.mount(
      tester,
      booruBackend: backend,
    );
    await harness.pumpUntilFound(tester, postTile(101));
    final context = tester.element(postTile(101));
    final posts = [
      tester.widget<SliverPostGridImageGridItem<Post>>(postTile(101)).post,
    ];
    final snapshot = PostActionSnapshot(posts, [backend.config]);
    var attempts = 0;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Consumer(
          builder: (context, ref, _) {
            final action = postActionDefinitions(
              context,
              ref,
              snapshot,
              downloadOverride: () async {
                attempts++;
                if (attempts == 1) throw StateError('offline');
              },
            ).firstWhere((action) => action.id == PostActionId.download);
            return Scaffold(
              body: TextButton(
                onPressed: action.execute,
                child: Text(action.label),
              ),
            );
          },
        ),
      ),
    );
    await harness.settle(tester);
    await tester.tap(find.text('Download'));
    await harness.settle(tester);
    expect(attempts, 1);
    expect(
      find.text('Could not complete the post action. Try again.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Download'));
    await harness.settle(tester);
    expect(attempts, 2);
    expect(snapshot.posts, posts);
    dismissAllToast(showAnim: false);
    // Advance the widget clock through oktoast's four-second fade lifetime.
    await tester.pump(const Duration(seconds: 4));
  });
}
