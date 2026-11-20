import 'package:boorusama/core/posts/details/src/widgets/post_details_page_view_scope.dart';
import 'package:boorusama/core/posts/details/src/widgets/group_reading_controls.dart';
import 'package:boorusama/core/posts/details_pageview/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurumi/material.dart';
import 'package:boorusama/core/posts/details/widgets.dart';
import 'package:boorusama/core/content/groups/group_capability.dart';
import 'package:boorusama/core/posts/details/src/providers/group_reading_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'headless_app_harness.dart';

/// Gallery tests explicitly choose Timeline now that Series and Related
/// default to Single. Back assertions should wait for the gallery directly.
Future<void> showGroupTimeline(
  WidgetTester tester,
  HeadlessAppHarness harness,
  Finder timeline,
) async {
  await harness.pumpUntilFound(tester, find.byType(PostDetailsPageView));
  await harness.settle(tester);
  if (timeline.evaluate().isNotEmpty) return;
  final toggle = find.byType(GroupViewToggle).hitTestable();
  if (toggle.evaluate().isEmpty) {
    final viewer = find.byType(PostDetailsPageScaffold).hitTestable().first;
    final pager = PostDetailsPageViewScope.of(tester.element(viewer));
    final media = find
        .byKey(ValueKey(('viewer-media', pager.page)))
        .hitTestable();
    final frame = tester.getRect(media);
    // The center may contain Retry. Reveal chrome through an empty media area.
    await tester.tapAt(
      frame.topLeft + Offset(frame.width * .25, frame.height * .35),
    );
    await harness.pumpUntilFound(tester, toggle);
  }
  final target = toggle.last;
  final entry = tester.widget<GroupViewToggle>(target).entry;
  final reading = ProviderScope.containerOf(
    tester.element(target),
  ).read(groupReadingProvider(entry));
  if (reading.layout == GroupLayout.mediaPager) await tester.tap(target);
  await harness.pumpUntilFound(tester, timeline);
  await harness.settle(tester);
}
