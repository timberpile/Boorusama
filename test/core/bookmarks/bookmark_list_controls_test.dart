import 'package:boorusama/core/bookmarks/src/providers/bookmark_shuffle_provider.dart';
import 'package:boorusama/core/bookmarks/src/providers/local_providers.dart';
import 'package:boorusama/core/bookmarks/src/widgets/bookmark_list_controls.dart';
import 'package:boorusama/core/themes/colors/src/colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';

const _longSource = 'very-long-source-with-a-full-host-name.example.com';

void main() {
  Future<ProviderContainer> pumpControls(
    WidgetTester tester, {
    double scale = 1,
    List<String> sources = const ['one.example', _longSource],
  }) async {
    final container = ProviderContainer(
      overrides: [
        availableBooruUrlsProvider.overrideWith(
          (ref) => Future.value(sources),
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: BooruLocalization(
          child: MaterialApp(
            theme: ThemeData(
              extensions: const [KurumiExtendedColorScheme()],
            ).withBoorusamaColors(),
            builder: (context, child) => KurumiTheme(
              data: KurumiThemeData.fromMaterial(Theme.of(context)),
              child: MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(scale),
                ),
                child: child!,
              ),
            ),
            home: const Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: BookmarkListControls(
                  count: 12,
                  gridConfig: Icon(Icons.settings),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  for (final width in [800.0, 320.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'scrolling keeps complete labels and count before menu at width $width / scale $scale',
        (
          tester,
        ) async {
          tester.view.physicalSize = Size(width, 640);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final container = await pumpControls(tester, scale: scale);
          container.read(selectedBookmarkSortTypeProvider.notifier).state =
              BookmarkSortType.random;
          await tester.pumpAndSettle();
          container.read(selectedBooruUrlProvider.notifier).state =
              '$_longSource/$_longSource';
          await tester.pumpAndSettle();
          final count = find.text('12 bookmarks');
          final countCenter = tester.getCenter(count);
          final menu = find.byIcon(Icons.settings);
          final menuRect = tester.getRect(menu);
          expect(
            (countCenter.dy - tester.getCenter(menu).dy).abs(),
            lessThanOrEqualTo(1),
          );
          final source = tester.widget<Text>(
            find.text('Source: $_longSource/$_longSource'),
          );
          expect(source.overflow, isNull);
          expect(tester.widget<Text>(count).overflow, isNull);
          final viewport = find.byWidgetPredicate(
            (widget) =>
                widget is SingleChildScrollView &&
                widget.scrollDirection == Axis.horizontal,
          );
          final scrollable = tester.state<ScrollableState>(
            find.descendant(of: viewport, matching: find.byType(Scrollable)),
          );
          expect(scrollable.position.maxScrollExtent, greaterThan(0));
          await tester.drag(viewport, const Offset(-300, 0));
          await tester.pumpAndSettle();
          expect(scrollable.position.pixels, greaterThan(0));
          expect(tester.getRect(menu), menuRect);
          scrollable.position.jumpTo(scrollable.position.maxScrollExtent);
          await tester.pumpAndSettle();
          expect(tester.getRect(menu).right, closeTo(width - 8, 0.01));
          expect(
            tester.getRect(count).right,
            lessThan(tester.getRect(menu).left),
          );
          final theme = Kurumi.themeOf(tester.element(count));
          final style = tester.widget<Text>(count).style!;
          expect(
            style.fontSize,
            lessThan(theme.textTheme.bodyMedium!.fontSize!),
          );
          expect(style.color, theme.colorScheme.onSurfaceVariant);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets('source popup shows full values and All clears the filter', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final container = await pumpControls(tester);
    await _tapFilter(tester, 'Source: All');
    await tester.pumpAndSettle();
    expect(find.text('All'), findsOneWidget);
    expect(find.text(_longSource), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    await tester.tap(
      find.ancestor(
        of: find.text(_longSource),
        matching: find.byType(KurumiPopupMenuItem),
      ),
    );
    await tester.pumpAndSettle();
    expect(container.read(selectedBooruUrlProvider), _longSource);
    expect(find.bySemanticsLabel('Source: $_longSource'), findsOneWidget);
    final selectedLabel = tester.widget<Text>(
      find.text('Source: $_longSource'),
    );
    expect(selectedLabel.overflow, isNull);
    await _tapFilter(tester, 'Source: $_longSource');
    await tester.pumpAndSettle();
    await tester.tap(
      find.ancestor(
        of: find.text('All'),
        matching: find.byType(KurumiPopupMenuItem),
      ),
    );
    await tester.pumpAndSettle();
    expect(container.read(selectedBooruUrlProvider), isNull);
    semantics.dispose();
  });

  testWidgets('long source menus scroll and mark the current choice', (
    tester,
  ) async {
    final sources = List.generate(30, (i) => 'source-$i.example');
    final container = await pumpControls(tester, sources: sources);
    await _tapFilter(tester, 'Source: All');
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.check), findsOneWidget);
    final lastOption = find.ancestor(
      of: find.text(sources.last),
      matching: find.byType(KurumiPopupMenuItem),
    );
    await tester.ensureVisible(lastOption);
    await tester.pumpAndSettle();
    await tester.tap(lastOption);
    await tester.pumpAndSettle();
    expect(container.read(selectedBooruUrlProvider), sources.last);
    expect(find.byType(KurumiPopupMenuItem), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dismissal preserves the source choice', (tester) async {
    final container = await pumpControls(tester);
    container.read(selectedBooruUrlProvider.notifier).state = 'one.example';
    await tester.pumpAndSettle();
    await _tapFilter(tester, 'Source: one.example');
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(790, 590));
    await tester.pumpAndSettle();
    expect(container.read(selectedBooruUrlProvider), 'one.example');
  });

  testWidgets('Random shuffles once, reshuffles separately, and sort resets', (
    tester,
  ) async {
    final container = await pumpControls(tester);
    container.read(selectedBooruUrlProvider.notifier).state = 'one.example';
    final seeds = <int?>[];
    final subscription = container.listen(
      bookmarkShuffleProvider,
      (_, next) => seeds.add(next.seed),
    );
    addTearDown(subscription.close);
    expect(find.byTooltip('Shuffle bookmarks'), findsNothing);
    await _tapFilter(tester, 'Newest');
    await tester.pumpAndSettle();
    await tester.tap(
      find.ancestor(
        of: find.text('Random'),
        matching: find.byType(KurumiPopupMenuItem),
      ),
    );
    await tester.pumpAndSettle();
    expect(seeds, hasLength(1));
    final first = container.read(bookmarkShuffleProvider);
    expect(first.seed, isNotNull);
    await tester.tap(find.byTooltip('Shuffle bookmarks'));
    await tester.pumpAndSettle();
    final second = container.read(bookmarkShuffleProvider);
    expect(second.seed, isNot(first.seed));
    expect(
      second.applyShuffleToList(List.generate(40, (i) => i)),
      isNot(first.applyShuffleToList(List.generate(40, (i) => i))),
    );
    expect(container.read(selectedBooruUrlProvider), 'one.example');
    await _tapFilter(tester, 'Random');
    await tester.pumpAndSettle();
    await tester.tap(
      find.ancestor(
        of: find.text('Random'),
        matching: find.byType(KurumiPopupMenuItem),
      ),
    );
    await tester.pumpAndSettle();
    expect(seeds, hasLength(2));
    await _tapFilter(tester, 'Random');
    await tester.pumpAndSettle();
    await tester.tap(
      find.ancestor(
        of: find.text('Oldest'),
        matching: find.byType(KurumiPopupMenuItem),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      container.read(selectedBookmarkSortTypeProvider),
      BookmarkSortType.oldest,
    );
    expect(container.read(bookmarkShuffleProvider).seed, isNull);
    expect(find.byTooltip('Shuffle bookmarks'), findsNothing);
    await _tapFilter(tester, 'Oldest');
    await tester.pumpAndSettle();
    await tester.tap(
      find.ancestor(
        of: find.text('Newest'),
        matching: find.byType(KurumiPopupMenuItem),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      container.read(selectedBookmarkSortTypeProvider),
      BookmarkSortType.newest,
    );
  });

  testWidgets(
    'narrow enlarged controls and source popup fit with keyboard',
    (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final container = await pumpControls(tester, scale: 2);
      container.read(selectedBooruUrlProvider.notifier).state = _longSource;
      container.read(selectedBookmarkSortTypeProvider.notifier).state =
          BookmarkSortType.random;
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.byTooltip('Shuffle bookmarks'));
      await tester.tap(find.byTooltip('Shuffle bookmarks'));
      tester.view.viewInsets = const FakeViewPadding(bottom: 260);
      addTearDown(tester.view.resetViewInsets);
      await _tapFilter(tester, 'Source: $_longSource');
      await tester.pumpAndSettle();
      expect(find.text(_longSource), findsOneWidget);
      expect(tester.takeException(), isNull);
      final option = find.ancestor(
        of: find.text(_longSource),
        matching: find.byType(KurumiPopupMenuItem),
      );
      await tester.ensureVisible(option);
      await tester.tapAt(tester.getTopLeft(option) + const Offset(12, 12));
      await tester.pumpAndSettle();
      expect(find.text(_longSource), findsNothing);
      expect(find.byType(TextField), findsNothing);
      expect(tester.takeException(), isNull);
      await _tapFilter(tester, 'Random');
      await tester.pumpAndSettle();
      await tester.tap(
        find.ancestor(
          of: find.text('Oldest'),
          matching: find.byType(KurumiPopupMenuItem),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        container.read(selectedBookmarkSortTypeProvider),
        BookmarkSortType.oldest,
      );
      expect(find.byTooltip('Shuffle bookmarks'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  test('rapid shuffle seeds always change and seeded orders are stable', () {
    var state = const BookmarkShuffleState();
    final items = List.generate(40, (i) => i);
    for (var i = 0; i < 100; i++) {
      final next = state.withNewShuffle();
      expect(next.seed, isNot(state.seed));
      expect(next.applyShuffleToList(items), next.applyShuffleToList(items));
      state = next;
    }
  });
}

Future<void> _tapFilter(WidgetTester tester, String label) async {
  final button = find.ancestor(
    of: find.text(label),
    matching: find.byType(KurumiPopupMenuButton),
  );
  await tester.ensureVisible(button);
  await tester.pump();
  final viewport = find.byWidgetPredicate(
    (widget) =>
        widget is SingleChildScrollView &&
        widget.scrollDirection == Axis.horizontal,
  );
  final visible = tester.getRect(button).intersect(tester.getRect(viewport));
  expect(visible.isEmpty, isFalse);
  await tester.tapAt(visible.center);
}
