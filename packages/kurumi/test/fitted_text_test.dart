import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurumi/kurumi.dart';

class _OffsetTextScaler extends TextScaler {
  const _OffsetTextScaler();
  @override
  double scale(double fontSize) => fontSize + 10;
  @override
  double get textScaleFactor => 1.5;
}

void main() {
  Future<Text> render(
    WidgetTester tester, {
    String title = 'aaaaa aaaa',
    required double width,
    double height = 56,
    TextScaler scaler = TextScaler.noScaling,
    double gain = 1.5,
    bool rich = false,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: width,
              height: height,
              child: DefaultTextStyle(
                style: const TextStyle(fontSize: 22, height: 1),
                child: KurumiFittedText(
                  rich
                      ? Text.rich(
                          TextSpan(children: [TextSpan(text: title)]),
                          semanticsLabel: 'Complete original title',
                        )
                      : Text(title),
                  textScaler: scaler,
                  minimumWrappingFontSizeGain: gain,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    return tester.widget<Text>(
      find.descendant(
        of: find.byType(KurumiFittedText),
        matching: find.byType(Text),
      ),
    );
  }

  int lineCount(WidgetTester tester) {
    final paragraph = tester.renderObject<RenderParagraph>(
      find.descendant(
        of: find.byType(KurumiFittedText),
        matching: find.byType(RichText),
      ),
    );
    return paragraph
        .getBoxesForSelection(
          TextSelection(
            baseOffset: 0,
            extentOffset: paragraph.text.toPlainText().length,
          ),
        )
        .map((box) => box.top)
        .toSet()
        .length;
  }

  for (final oneLineSize in [20.5, 18.0, 14.7, 14.0, 12.0]) {
    testWidgets('50 percent boundary with one line at $oneLineSize', (
      tester,
    ) async {
      final text = await render(tester, width: oneLineSize * 10);
      final wrap = 22 >= oneLineSize * 1.5;
      expect(text.style!.fontSize, closeTo(wrap ? 22 : oneLineSize, .02));
      expect(lineCount(tester), wrap ? 2 : 1);
      expect(text.overflow, TextOverflow.visible);
    });
  }
  testWidgets('inclusive gain boundary uses actual Flutter measurements', (
    tester,
  ) async {
    final single = await render(tester, width: 180, gain: 2);
    final exactGain = 22 / single.style!.fontSize!;
    final equal = await render(tester, width: 180, gain: exactGain);
    expect(equal.style!.fontSize, 22);
    expect(lineCount(tester), 2);
    final below = await render(tester, width: 180, gain: exactGain + .0001);
    expect(below.style!.fontSize, single.style!.fontSize);
    expect(lineCount(tester), 1);
  });

  testWidgets('three lines can beat selected one even when two do not', (
    tester,
  ) async {
    final intermediate = await render(
      tester,
      title: 'aaa bbbbbbbbbb ccc',
      width: 220,
      height: 44,
      gain: 1,
    );
    expect(intermediate.style!.fontSize, inExclusiveRange(15, 18));
    expect(lineCount(tester), 2);
    final text = await render(
      tester,
      title: 'aaa bbbbbbbbbb ccc',
      width: 220,
      height: 90,
    );
    expect(text.style!.fontSize, closeTo(22, .02));
    expect(lineCount(tester), 3);
  });
  testWidgets('does not impose a three-line cap', (tester) async {
    final text = await render(tester, title: 'a a a a', width: 40, height: 120);
    expect(text.style!.fontSize, 22);
    expect(lineCount(tester), 4);
    expect(text.overflow, TextOverflow.visible);
  });
  testWidgets(
    'does not truncate when only a wrapped layout fits at the floor',
    (tester) async {
      final text = await render(tester, title: 'aaaaa aaaa aaaa', width: 100);
      expect(text.style!.fontSize, greaterThanOrEqualTo(12));
      expect(lineCount(tester), greaterThan(1));
      expect(text.maxLines, isNull);
      expect(text.overflow, TextOverflow.visible);
    },
  );
  testWidgets('compares rendered sizes under nonlinear scaling', (
    tester,
  ) async {
    final text = await render(
      tester,
      width: 240,
      height: 120,
      scaler: const _OffsetTextScaler(),
    );
    expect(text.style!.fontSize, closeTo(14, .02));
    expect(lineCount(tester), 1);
    expect(text.textScaler, isA<_OffsetTextScaler>());
  });
  for (final scale in [1.0, 1.5, 2.0]) {
    testWidgets('keeps fewer lines and original scaler at ${scale}x', (
      tester,
    ) async {
      final text = await render(
        tester,
        width: 18 * 10 * scale,
        height: 56 * scale,
        scaler: TextScaler.linear(scale),
      );
      expect(text.style!.fontSize, closeTo(18, .02));
      expect(lineCount(tester), 1);
      expect(text.textScaler!.scale(18), 18 * scale);
    });
  }
  testWidgets('fallback uses every visible line and preserves rich semantics', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      final text = await render(
        tester,
        title: 'aaaaa ' * 30,
        width: 100,
        height: 56,
        rich: true,
      );
      expect(text.style!.fontSize, 12);
      expect(text.maxLines, 4);
      expect(text.overflow, TextOverflow.ellipsis);
      expect(find.bySemanticsLabel('Complete original title'), findsOneWidget);
    } finally {
      semantics.dispose();
    }
  });
  testWidgets('extreme scaling respects minimum and ellipsizes', (
    tester,
  ) async {
    final title = 'unbreakable' * 30;
    final text = await render(
      tester,
      title: title,
      width: 100,
      height: 56,
      scaler: const TextScaler.linear(4),
    );
    expect(text.style!.fontSize, 12);
    expect(text.maxLines, 1);
    expect(text.textScaler!.scale(12), 48);
    expect(text.data, title);
  });
  testWidgets('card default still selects largest wrapped text', (
    tester,
  ) async {
    final text = await render(tester, width: 180, gain: 1);
    expect(text.style!.fontSize, 22);
    expect(lineCount(tester), 2);
  });
}
