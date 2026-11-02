import 'package:boorusama/core/posts/details/src/widgets/lazy_post_details_pager.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i18n/i18n.dart';

void main() {
  testWidgets(
    'vertical content scrolling preserves horizontal post navigation',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final scroll = ScrollController();
      addTearDown(scroll.dispose);
      var page = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: LazyPostDetailsPager(
            source: LazyPostDetailsSource(
              changes: const AlwaysStoppedAnimation(0),
              postIds: () => [10, 20],
              hasMore: () => false,
              fetchMore: () async {},
            ),
            initialIndex: 0,
            onPageChanged: (value) => page = value,
            itemBuilder: (context, id) => id == 10
                ? ListView.builder(
                    controller: scroll,
                    itemCount: 40,
                    itemExtent: 60,
                    itemBuilder: (_, index) => Text('Detail $index'),
                  )
                : const Center(child: Text('Post 20')),
          ),
        ),
      );

      await tester.drag(find.byType(ListView), const Offset(0, -300));
      await tester.pumpAndSettle();
      expect(scroll.offset, greaterThan(0));
      expect(page, 0);
      await tester.drag(find.byType(PageView), const Offset(-300, 0));
      await tester.pumpAndSettle();
      expect(page, 1);
      expect(find.text('Post 20'), findsOneWidget);
    },
  );

  testWidgets('opening a large list builds only nearby posts', (tester) async {
    final ids = List.generate(1000, (index) => index + 1);
    final built = <int>{};

    await tester.pumpWidget(
      MaterialApp(
        home: LazyPostDetailsPager(
          source: LazyPostDetailsSource(
            changes: const AlwaysStoppedAnimation(0),
            postIds: () => ids,
            hasMore: () => false,
            fetchMore: () async {},
          ),
          initialIndex: 500,
          itemBuilder: (context, id) {
            built.add(id);
            return Center(child: Text('Post $id'));
          },
        ),
      ),
    );

    expect(find.text('Post 501'), findsOneWidget);
    expect(built.length, lessThan(10));
  });

  testWidgets('swiping preserves the selected post and list order', (
    tester,
  ) async {
    final ids = ValueNotifier<List<int>>([10, 20, 30]);
    addTearDown(ids.dispose);
    final page = ValueNotifier<int>(-1);
    addTearDown(page.dispose);

    await tester.pumpWidget(
      BooruLocalization(
        child: MaterialApp(
          home: LazyPostDetailsPager(
            source: LazyPostDetailsSource(
              changes: ids,
              postIds: () => ids.value,
              hasMore: () => false,
              fetchMore: () async {},
            ),
            initialIndex: 1,
            onPageChanged: (index) => page.value = index,
            itemBuilder: (context, id) => Center(child: Text('Post $id')),
          ),
        ),
      ),
    );

    expect(find.text('Post 20'), findsOneWidget);
    await tester.drag(find.byType(PageView), const Offset(-700, 0));
    await tester.pumpAndSettle();
    expect(page.value, 2);
    expect(find.text('Post 30'), findsOneWidget);
    await tester.drag(find.byType(PageView), const Offset(700, 0));
    await tester.pumpAndSettle();
    expect(page.value, 1);
  });

  testWidgets('browsing near the end loads more posts once and continues', (
    tester,
  ) async {
    final ids = ValueNotifier<List<int>>([10, 20, 30]);
    addTearDown(ids.dispose);
    var calls = 0;
    var hasMore = true;

    await tester.pumpWidget(
      MaterialApp(
        home: LazyPostDetailsPager(
          source: LazyPostDetailsSource(
            changes: ids,
            postIds: () => ids.value,
            hasMore: () => hasMore,
            fetchMore: () async {
              calls++;
              ids.value = [10, 20, 30, 40];
              hasMore = false;
            },
          ),
          initialIndex: 1,
          itemBuilder: (context, id) => Center(child: Text('Post $id')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(calls, 1);
    await tester.drag(find.byType(PageView), const Offset(-700, 0));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(PageView), const Offset(-700, 0));
    await tester.pumpAndSettle();
    expect(find.text('Post 40'), findsOneWidget);
    expect(calls, 1);
  });

  testWidgets('failed pagination can be retried without losing the post', (
    tester,
  ) async {
    final ids = ValueNotifier<List<int>>([10, 20, 30]);
    addTearDown(ids.dispose);
    var calls = 0;
    var hasMore = true;

    await tester.pumpWidget(
      BooruLocalization(
        child: MaterialApp(
          home: LazyPostDetailsPager(
            source: LazyPostDetailsSource(
              changes: ids,
              postIds: () => ids.value,
              hasMore: () => hasMore,
              fetchMore: () async {
                calls++;
                if (calls == 1) throw StateError('offline');
                ids.value = [10, 20, 30, 40];
                hasMore = false;
              },
            ),
            initialIndex: 1,
            itemBuilder: (context, id) => Center(child: Text('Post $id')),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Post 20'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(calls, 2);
    await tester.drag(find.byType(PageView), const Offset(-700, 0));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(PageView), const Offset(-700, 0));
    await tester.pumpAndSettle();
    expect(find.text('Post 40'), findsOneWidget);
  });
}
