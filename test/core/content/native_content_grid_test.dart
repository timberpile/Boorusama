import 'dart:async';

import 'package:boorusama/core/content/types.dart';
import 'package:boorusama/core/content/widgets/native_content_grid.dart';
import 'package:boorusama/core/navigation/destination_activity.dart';
import 'package:boorusama/core/posts/listing/src/types/page_mode.dart';
import 'package:boorusama/core/posts/listing/src/widgets/post_grid_prefetch.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../boorus/nhentai/fixtures.dart';

GroupContentEntry entry(int id) => GroupContentEntry(
  summary: ContentGroupSummary(
    reference: const ContentReferenceCodec().parse(
      engine: galleryAccess().key.engine,
      site: Uri.parse('https://nhentai.net'),
      kind: ContentKind.group,
      sourceKey: 'gallery:$id',
    ),
    title: 'Fixture $id',
    memberCount: 3,
  ),
);

void main() {
  test(
    'filtered empty continuation advances and a nonempty terminal batch stops',
    () async {
      final pages = <int>[];
      final controller = NativeContentController(
        access: galleryAccess(),
        current: () => true,
        fetchPage: (page) async {
          pages.add(page);
          return NativeContentPage(
            entries: page == 1 ? const [] : [entry(101)],
            hasMore: page == 1,
            rawCount: 25,
          );
        },
      );
      addTearDown(controller.dispose);
      await controller.refresh();
      expect(controller.entries, isEmpty);
      expect(controller.hasMore, isTrue);
      await controller.fetchMore();
      expect(controller.entries, hasLength(1));
      expect(controller.hasMore, isFalse);
      await controller.fetchMore();
      expect(pages, [1, 2]);
    },
  );

  test('refresh rejects late earlier results and preserves each occurrence identity', () async {
    final first = Completer<NativeContentPage>();
    final second = Completer<NativeContentPage>();
    var count = 0;
    final controller = NativeContentController(
      access: galleryAccess(),
      current: () => true,
      fetchPage: (_) => (++count == 1 ? first : second).future,
    );
    addTearDown(controller.dispose);
    final old = controller.refresh();
    final fresh = controller.refresh();
    second.complete(
      NativeContentPage(entries: [entry(101), entry(101)], hasMore: false),
    );
    await fresh;
    expect(controller.viewerEntries, hasLength(2));
    expect(
      controller.viewerEntries[0].occurrenceId,
      isNot(controller.viewerEntries[1].occurrenceId),
    );
    first.complete(NativeContentPage(entries: [entry(999)], hasMore: false));
    await old;
    expect(controller.entries.map((entry) => entry.reference.sourceKey), [
      'gallery:101',
      'gallery:101',
    ]);
  });

  test('revocation and delayed dispatch do not issue a request under another actor', () async {
    var current = true;
    var allowed = true;
    var calls = 0;
    final controller = NativeContentController(
      access: galleryAccess(),
      current: () => current,
      fetchPage: (_) async {
        calls++;
        return NativeContentPage(entries: [entry(101)], hasMore: true);
      },
    );
    addTearDown(controller.dispose);
    await controller.refresh();
    current = false;
    await controller.fetchMore();
    expect(calls, 1);
    current = true;
    allowed = false;
    await controller.fetchMore(canStart: () => allowed);
    expect(calls, 1);
  });

  test('paginated retry retains the failing previous page and page requests never overlap', () async {
    final requested = <int>[];
    var fail = true;
    final controller = NativeContentController(
      access: galleryAccess(),
      current: () => true,
      initialPage: 3,
      pageMode: PageMode.paginated,
      fetchPage: (page) async {
        requested.add(page);
        if (page == 2 && fail) throw StateError('fixture');
        return NativeContentPage(entries: [entry(100 + page)], hasMore: true);
      },
    );
    addTearDown(controller.dispose);
    await controller.refresh();
    await controller.loadPage(2);
    expect(controller.errors.value, isNotNull);
    fail = false;
    await controller.retry();
    expect(requested, [3, 2, 2]);
    expect(controller.page, 2);
    expect(controller.entries.single.reference.sourceKey, 'gallery:102');
  });

  testWidgets(
    'native timeline uses the same bounded viewport continuation and manual retry',
    (tester) async {
      final requests = <int>[];
      final replies = <Completer<NativeContentPage>>[];
      final scroll = ScrollController();
      final active = ValueNotifier(true);
      final controller = NativeContentController(
        access: galleryAccess(),
        current: () => true,
        fetchPage: (page) {
          requests.add(page);
          final reply = Completer<NativeContentPage>();
          replies.add(reply);
          return reply.future;
        },
      );
      addTearDown(() {
        controller.dispose();
        scroll.dispose();
        active.dispose();
      });
      final first = controller.refresh();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ValueListenableBuilder<bool>(
              valueListenable: active,
              builder: (_, enabled, _) => NavigationActivity(
                active: enabled,
                child: PostGridPrefetch(
                  controller: controller,
                  scrollController: scroll,
                  child: ListView(
                    controller: scroll,
                    children: const [SizedBox(height: 1)],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      for (var i = 0; i < 4; i++) {
        expect(requests.last, i + 1);
        replies[i].complete(
          NativeContentPage(entries: const [], hasMore: true, rawCount: 25),
        );
        await tester.pump();
        await tester.pump();
      }
      await first;
      expect(requests, [1, 2, 3, 4]);
      await tester.pump();
      expect(requests, [1, 2, 3, 4]);
      final manual = controller.fetchMore();
      expect(requests.last, 5);
      replies[4].completeError(StateError('fixture unavailable'));
      await manual;
      await tester.pump();
      expect(requests, [1, 2, 3, 4, 5]);
      final retry = controller.retry();
      expect(requests.last, 5);
      replies[5].complete(
        NativeContentPage(entries: [entry(101)], hasMore: false),
      );
      await retry;
      await tester.pump();
      expect(controller.hasMore, isFalse);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
