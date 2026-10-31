import 'package:flutter_test/flutter_test.dart';
import 'package:kurumi/kurumi.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  const title =
      'A long localized title with enough words to exercise a constrained header';
  for (final brightness in Brightness.values) {
    for (final host in ['card', 'sheet', 'info', 'popup', 'search']) {
      testWidgets('$host title preserves layout and actions in $brightness', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        var confirmed = false;
        final Widget child = switch (host) {
          'card' => const SizedBox(
            height: 100,
            child: KurumiSettingsCardTitle(
              title: title,
              trailing: Icon(Icons.info),
            ),
          ),
          'sheet' => KurumiBottomSheetHeader(
            title: title,
            closeTooltip: 'Close',
            confirmTooltip: 'Confirm',
            onClose: () {},
            onConfirm: () => confirmed = true,
          ),
          'info' => KurumiInfoContainer(
            title: title,
            contentBuilder: (_) => const Text('Body stays readable'),
          ),
          'popup' => const KurumiContextMenuDivider(title: title),
          _ => KurumiOptionSearchableSheet<String>(
            title: title,
            searchHint: 'Search',
            items: const ['Result'],
            onFilter: (_) => ['Result'],
            itemBuilder: (_, item) => Text(item),
          ),
        };
        final semantics = tester.ensureSemantics();

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(brightness: brightness),
            builder: (context, child) => KurumiTheme(
              data: KurumiThemeData.fromMaterial(Theme.of(context)),
              child: MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: const TextScaler.linear(2),
                  viewInsets: const EdgeInsets.only(bottom: 220),
                ),
                child: child!,
              ),
            ),
            home: host == 'search'
                ? child
                : Scaffold(
                    body: Align(alignment: Alignment.topCenter, child: child),
                  ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(
          find.text(host == 'card' ? title.toUpperCase() : title),
          findsOneWidget,
        );
        if (host == 'sheet') {
          expect(find.byTooltip('Close').hitTestable(), findsOneWidget);
          await tester.tap(find.byTooltip('Confirm'));
          expect(confirmed, isTrue);
        }
        if (host == 'info') {
          expect(find.text('Body stays readable'), findsOneWidget);
        }
        if (host == 'search') {
          await tester.enterText(find.byType(TextField), 'res');
          await tester.pumpAndSettle();
          expect(find.text('Result').hitTestable(), findsOneWidget);
        }
        final fitters = find.byType(KurumiFittedText);
        expect(fitters, host == 'popup' ? findsNothing : findsOneWidget);
        for (final fitter in fitters.evaluate()) {
          final rendered = find.descendant(
            of: find.byWidget(fitter.widget),
            matching: find.byType(Text),
          );
          expect(
            tester.widget<Text>(rendered).style!.fontSize,
            greaterThanOrEqualTo(12),
          );
        }
        expect(tester.takeException(), isNull);
        semantics.dispose();
      });
    }
  }
}
