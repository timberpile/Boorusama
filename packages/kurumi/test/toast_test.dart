import 'package:flutter_test/flutter_test.dart';
import 'package:kurumi/kurumi.dart';
import 'package:material_ui/material_ui.dart';
import 'package:oktoast/oktoast.dart';

void main() {
  testWidgets(
    'ordinary success toast follows the same live obstruction as Undo',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      addTearDown(dismissAllToast);
      final bottom = ValueNotifier<double>(100);
      addTearDown(bottom.dispose);
      late BuildContext context;
      await tester.pumpWidget(
        OKToast(
          child: MaterialApp(
            home: KurumiOverlayInsetsScope(
              bottomPadding: 100,
              bottomViewPadding: 100,
              bottomPaddingListenable: bottom,
              child: Builder(
                builder: (value) {
                  context = value;
                  return const SizedBox.expand();
                },
              ),
            ),
          ),
        ),
      );
      Kurumi.showSuccessToast(
        context,
        'Bookmark added',
        duration: const Duration(seconds: 5),
      );
      await tester.pumpAndSettle();
      final initial = tester.getRect(find.text('Bookmark added')).bottom;
      bottom.value = 200;
      await tester.pumpAndSettle();
      expect(
        initial - tester.getRect(find.text('Bookmark added')).bottom,
        closeTo(100, .5),
      );
      bottom.value = 0;
      await tester.pumpAndSettle();
      expect(
        tester.getRect(find.text('Bookmark added')).bottom - initial,
        closeTo(100, .5),
      );
      dismissAllToast(showAnim: false);
      await tester.pump(const Duration(seconds: 5));
    },
  );

  for (final textScale in [1.0, 1.8, 2.0]) {
    testWidgets(
      'success toast action preserves styling and an accessible target at ${textScale}x text and dismisses on tap',
      (
        tester,
      ) async {
        late BuildContext context;
        await tester.pumpWidget(
          MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
            child: OKToast(
              child: MaterialApp(
                home: Builder(
                  builder: (value) {
                    context = value;
                    return const SizedBox.expand();
                  },
                ),
              ),
            ),
          ),
        );
        Kurumi.showSuccessToast(context, 'Bookmark added');
        await tester.pumpAndSettle();
        Container surfaceFor(String text) => tester.widget<Container>(
          find.ancestor(
            of: find.text(text),
            matching: find.byWidgetPredicate(
              (widget) =>
                  widget is Container && widget.decoration is BoxDecoration,
            ),
          ),
        );
        final addedDecoration = surfaceFor('Bookmark added').decoration;
        final addedStyle = tester
            .widget<Text>(find.text('Bookmark added'))
            .style;
        double surfaceHeight(String text) => tester
            .getSize(
              find.ancestor(
                of: find.text(text),
                matching: find.byWidgetPredicate(
                  (widget) =>
                      widget is Container && widget.decoration is BoxDecoration,
                ),
              ),
            )
            .height;
        final addedHeight =
            surfaceHeight('Bookmark added') -
            (surfaceFor(
                  'Bookmark added',
                ).margin?.resolve(TextDirection.ltr).vertical ??
                0);
        var actions = 0;
        Kurumi.showSuccessToast(
          context,
          '2 bookmarks removed',
          duration: const Duration(seconds: 5),
          actionLabel: 'Undo',
          onAction: () => actions++,
        );
        await tester.pumpAndSettle();
        expect(find.text('Bookmark added'), findsNothing);
        expect(surfaceFor('2 bookmarks removed').decoration, addedDecoration);
        expect(
          tester.widget<Text>(find.text('2 bookmarks removed')).style,
          addedStyle,
        );
        expect(find.textContaining('|'), findsNothing);
        expect(
          surfaceHeight('2 bookmarks removed'),
          greaterThanOrEqualTo(addedHeight),
        );
        expect(
          tester.getSize(find.widgetWithText(TextButton, 'Undo')).height,
          greaterThanOrEqualTo(48),
        );
        await tester.tap(find.text('Undo'));
        await tester.pumpAndSettle();
        expect(actions, 1);
        expect(find.text('Undo'), findsNothing);
        // Drain OKToast's animation callbacks after manual dismissal.
        await tester.pump(const Duration(seconds: 5));
      },
    );
  }

  testWidgets('success toast action expires without invoking the action', (
    tester,
  ) async {
    late BuildContext context;
    await tester.pumpWidget(
      OKToast(
        child: MaterialApp(
          home: Builder(
            builder: (value) {
              context = value;
              return const SizedBox.expand();
            },
          ),
        ),
      ),
    );
    var actions = 0;
    Kurumi.showSuccessToast(
      context,
      '2 bookmarks removed',
      duration: const Duration(seconds: 5),
      actionLabel: 'Undo',
      onAction: () => actions++,
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 4));
    expect(find.text('Undo'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('Undo'), findsNothing);
    expect(actions, 0);
  });
}
