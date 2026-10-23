import 'package:boorusama/core/bookmarks/src/providers/suggestion_provider.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_tag_index.dart';
import 'package:boorusama/core/bookmarks/src/widgets/bookmark_search_bar.dart';
import 'package:boorusama/core/posts/listing/providers.dart';
import 'package:boorusama/core/search/search/widgets.dart';
import 'package:boorusama/core/themes/colors/src/colors.dart';
import 'package:boorusama/core/themes/colors/providers.dart';
import 'package:boorusama/core/themes/colors/types.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:mocktail/mocktail.dart';

class _PostController extends Mock implements PostGridController {}

final _index = BookmarkTagIndex([
  for (final tag in ['blue_hair', 'one_piece', 'glasses', 'red_eyes', 'smile'])
    BookmarkTagEntry(tag: tag, count: 2, sources: const {}),
]);

Widget _app(
  TextEditingController query,
  PostGridController posts, {
  double scale = 1,
  BookmarkTagIndex? index,
  VoidCallback? onIndexRequested,
}) {
  final theme = ThemeData(
    extensions: const [KurumiExtendedColorScheme()],
  ).withBoorusamaColors();
  return ProviderScope(
    overrides: [
      bookmarkTagIndexProvider.overrideWith((ref, view) {
        onIndexRequested?.call();
        return index ?? _index;
      }),
      bookmarkTagColorProvider.overrideWith((ref, request) => Colors.purple),
      booruChipColorsProvider.overrideWithValue(
        BooruChipColors.colorScheme(theme.colorScheme),
      ),
    ],
    child: BooruLocalization(
      child: MaterialApp(
        theme: theme,
        builder: (context, child) => KurumiTheme(
          data: KurumiThemeData.fromMaterial(Theme.of(context)),
          child: MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
        ),
        home: Scaffold(
          body: BookmarkSearchBar(controller: query, postController: posts),
        ),
      ),
    ),
  );
}

void main() {
  late TextEditingController query;
  late _PostController posts;

  setUp(() {
    query = TextEditingController(text: 'blue_hair');
    posts = _PostController();
    when(() => posts.refresh()).thenAnswer((_) async {});
  });
  tearDown(() => query.dispose());

  testWidgets(
    'diagnostic suppression affects only the idle index subscription',
    (tester) async {
      query.clear();
      var requested = 0;
      await tester.pumpWidget(
        _app(query, posts, onIndexRequested: () => requested++),
      );
      await tester.pumpAndSettle();
      const suppressed = bool.fromEnvironment(
        'BOORUSAMA_PERF_SKIP_IDLE_BOOKMARK_INDEX',
      );
      expect(requested, suppressed ? 0 : 1);
      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();
      expect(requested, 1);
      expect(
        find.byKey(const ValueKey('bookmark-suggestion-blue_hair')),
        findsOneWidget,
      );
    },
  );

  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'browses and selects all tags from an empty field at scale $scale',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        tester.view.viewInsets = const FakeViewPadding(bottom: 260);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetViewInsets);
        query.clear();
        final ranked = BookmarkTagIndex([
          for (var i = 7; i >= 0; i--)
            BookmarkTagEntry(tag: 'tag_$i', count: 8 - i, sources: const {}),
        ]);
        await tester.pumpWidget(
          _app(query, posts, scale: scale, index: ranked),
        );
        await tester.tap(find.byType(TextField));
        await tester.pumpAndSettle();
        final first = find.byKey(const ValueKey('bookmark-suggestion-tag_0'));
        expect(first, findsOneWidget);
        await tester.enterText(find.byType(TextField), 'no_matching_tag');
        await tester.pumpAndSettle();
        expect(first, findsNothing);
        await tester.enterText(find.byType(TextField), '');
        await tester.pumpAndSettle();
        expect(first, findsOneWidget);
        final last = find.byKey(const ValueKey('bookmark-suggestion-tag_7'));
        await tester.scrollUntilVisible(
          last,
          60,
          scrollable: find.descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          ),
        );
        await tester.tap(last);
        await tester.pumpAndSettle();
        expect(query.text, 'tag_7');
        verify(() => posts.refresh()).called(1);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );

    testWidgets(
      'selects a readable negative tag with keyboard at scale $scale',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        tester.view.viewInsets = const FakeViewPadding(bottom: 260);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetViewInsets);
        await tester.pumpWidget(_app(query, posts, scale: scale));
        await tester.pumpAndSettle();
        expect(find.byType(SelectedTagChip), findsOneWidget);
        await tester.enterText(find.byType(TextField), '-one piece');
        await tester.pumpAndSettle();
        expect(query.text, 'blue_hair');
        await tester.tap(
          find.byKey(const ValueKey('bookmark-suggestion-one_piece')),
        );
        await tester.pumpAndSettle();
        expect(query.text, 'blue_hair -one_piece');
        expect(find.byType(SelectedTagChip), findsNWidgets(2));
        final labels = tester.widgetList<RichText>(
          find.descendant(
            of: find.byType(SelectedTagChip),
            matching: find.byType(RichText),
          ),
        );
        expect(
          labels.any((label) => label.text.toPlainText().contains('one piece')),
          isTrue,
        );
        final tagLabel = labels.firstWhere(
          (label) => label.text.toPlainText().contains('one piece'),
        );
        expect(
          (tagLabel.text as TextSpan).children!
              .whereType<TextSpan>()
              .firstWhere((span) => span.text == 'one piece')
              .style!
              .color,
          ProviderScope.containerOf(
                tester.element(find.byType(SelectedTagChip).first),
              )
              .read(booruChipColorsProvider)
              .fromColor(Colors.purple)!
              .foregroundColor,
        );
        verify(() => posts.refresh()).called(1);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets('submits a pasted query as removable chips', (tester) async {
    await tester.pumpWidget(_app(query, posts));
    await tester.enterText(find.byType(TextField), 'red_eyes smile');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(query.text, 'blue_hair red_eyes smile');
    expect(find.byType(SelectedTagChip), findsNWidgets(3));
    await tester.tap(
      find.descendant(
        of: find.byType(SelectedTagChip).first,
        matching: find.byIcon(Symbols.close),
      ),
    );
    await tester.pumpAndSettle();
    expect(query.text, 'red_eyes smile');
    verify(() => posts.refresh()).called(2);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'keeps a long chip removable at narrow width with large text and keyboard',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      tester.view.viewInsets = const FakeViewPadding(bottom: 260);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      query.text = List.filled(20, 'long_tag').join('_');
      await tester.pumpWidget(_app(query, posts, scale: 2));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(
        find.descendant(
          of: find.byType(SelectedTagChip),
          matching: find.byIcon(Symbols.close),
        ),
      );
      await tester.pumpAndSettle();
      expect(query.text, isEmpty);
      verify(() => posts.refresh()).called(1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'edits a chip through local autocomplete and preserves its position',
    (tester) async {
      query.text = 'blue_hair glasses';
      await tester.pumpWidget(_app(query, posts));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('blue_hair')));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'blue hair',
      );
      expect(query.text, 'blue_hair glasses');
      await tester.enterText(find.byType(TextField), 'one piece');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(query.text, 'one_piece glasses');
      verify(() => posts.refresh()).called(1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'backspace edits the last chip and escape cancels without filtering',
    (tester) async {
      await tester.pumpWidget(_app(query, posts));
      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'blue hair',
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );
      expect(query.text, 'blue_hair');
      verifyNever(() => posts.refresh());
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('clears both draft and selected tags in one refresh', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 260);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpWidget(_app(query, posts, scale: 2));
    await tester.enterText(find.byType(TextField), 'one piece');
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(BooruSearchBar),
        matching: find.byIcon(Symbols.clear),
      ),
    );
    await tester.pumpAndSettle();
    expect(query.text, isEmpty);
    expect(find.byType(SelectedTagChip), findsNothing);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      isEmpty,
    );
    verify(() => posts.refresh()).called(1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('search button submits with autocomplete and keyboard open', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 260);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpWidget(_app(query, posts, scale: 2));
    await tester.enterText(find.byType(TextField), 'one piece');
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Symbols.search));
    await tester.pumpAndSettle();
    expect(query.text, 'blue_hair one_piece');
    verify(() => posts.refresh()).called(1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('resynchronizes chips when the owning query controller changes', (
    tester,
  ) async {
    final replacement = TextEditingController(text: '-glasses');
    addTearDown(replacement.dispose);
    await tester.pumpWidget(_app(query, posts));
    await tester.enterText(find.byType(TextField), 'unfinished');
    await tester.pumpWidget(_app(replacement, posts));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      isEmpty,
    );
    expect(
      tester
          .widget<SelectedTagChip>(find.byType(SelectedTagChip))
          .tagSearchItem
          .toString(),
      '-glasses',
    );
    query.text = 'one_piece';
    await tester.pumpAndSettle();
    expect(replacement.text, '-glasses');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
