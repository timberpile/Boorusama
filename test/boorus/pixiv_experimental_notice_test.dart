import 'package:boorusama/boorus/pixiv/configs/experimental_notice.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:material_ui/material_ui.dart';

const _description =
    'Pixiv support is limited and may change. '
    'Not all website features are available.';

void main() {
  setUpAll(() async {
    await ensureI18nInitialized('en-US');
  });

  testWidgets('untranslated locale uses the English experimental notice', (
    tester,
  ) async {
    await tester.runAsync(() => ensureI18nInitialized('de-DE'));
    try {
      await tester.pumpWidget(const _TestApp());
      expect(find.text('Experimental'), findsOneWidget);
      expect(find.text(_description), findsOneWidget);
      expect(tester.takeException(), isNull);
    } finally {
      await tester.runAsync(() => ensureI18nInitialized('en-US'));
    }
  });

  testWidgets(
    'explains experimental status without an acknowledgement action',
    (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      try {
        await tester.pumpWidget(const _TestApp());

        expect(find.text('Experimental'), findsOneWidget);
        expect(find.text(_description), findsOneWidget);
        expect(find.byType(TextButton), findsNothing);
        expect(find.byType(Checkbox), findsNothing);
        expect(
          tester
              .getSemantics(find.text('Experimental'))
              .getSemanticsData()
              .label,
          contains('Experimental'),
        );
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
      }
    },
  );

  for (final brightness in Brightness.values) {
    for (final width in [240.0, 320.0]) {
      testWidgets(
        'wraps at $width pixels with enlarged text and keyboard in $brightness',
        (tester) async {
          tester.view.physicalSize = Size(width, 640);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          await tester.pumpWidget(
            _TestApp(
              brightness: brightness,
              textScaler: const TextScaler.linear(2),
              keyboardInset: 280,
            ),
          );
          await tester.ensureVisible(find.text(_description));
          await tester.pump();

          expect(find.text('Experimental'), findsOneWidget);
          expect(find.text(_description), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}

class _TestApp extends StatelessWidget {
  const _TestApp({
    this.brightness = Brightness.light,
    this.textScaler = TextScaler.noScaling,
    this.keyboardInset = 0,
  });

  final Brightness brightness;
  final TextScaler textScaler;
  final double keyboardInset;

  @override
  Widget build(BuildContext context) {
    return BooruLocalization(
      child: MaterialApp(
        theme: ThemeData(brightness: brightness),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: textScaler,
            viewInsets: EdgeInsets.only(bottom: keyboardInset),
          ),
          child: KurumiTheme(
            data: KurumiThemeData.fromMaterial(Theme.of(context)),
            child: child!,
          ),
        ),
        home: const Scaffold(
          body: SingleChildScrollView(
            padding: EdgeInsets.all(12),
            child: PixivExperimentalNotice(),
          ),
        ),
      ),
    );
  }
}
