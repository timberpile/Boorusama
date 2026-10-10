import 'package:boorusama/core/bookmarks/src/widgets/bookmark_appbar.dart';
import 'package:flutter/material.dart';
import 'package:kurumi/kurumi.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final scale in [1.0, 2.0]) {
    for (final title in [
      'Cats',
      'Two line title',
      'Many words for a longer bookmark group title',
      'Unbreakable' * 30,
      'Lesezeichen 日本語 مجموعة الإشارات المرجعية',
    ]) {
      testWidgets('fits "$title" inside the toolbar at ${scale}x', (
        tester,
      ) async {
        await tester.binding.setSurfaceSize(const Size(320, 600));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(scale)),
              child: Scaffold(
                appBar: PreferredSize(
                  preferredSize: const Size.fromHeight(kToolbarHeight),
                  child: BookmarkAppBar(title: title),
                ),
              ),
            ),
          ),
        );
        final finder = find.text(title);
        final text = tester.widget<Text>(finder);
        final paragraph = tester.renderObject<RenderParagraph>(finder);
        expect(text.style!.fontSize, inInclusiveRange(12, 22));
        expect(text.textScaler!.scale(12), 12 * scale);
        expect(tester.getSize(find.byType(AppBar)).height, kToolbarHeight);
        expect(paragraph.size.height, lessThanOrEqualTo(kToolbarHeight));
        if (title == 'Cats') {
          expect(text.style!.fontSize, 22);
          expect(paragraph.didExceedMaxLines, isFalse);
        }
        if (paragraph.didExceedMaxLines) expect(text.style!.fontSize, 12);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('shrinks only enough for the largest wrapped fit', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 190,
              height: 38,
              child: DefaultTextStyle(
                style: TextStyle(fontSize: 22, height: 1),
                child: KurumiFittedText(Text('Two line title')),
              ),
            ),
          ),
        ),
      ),
    );
    final text = tester.widget<Text>(find.text('Two line title'));
    expect(text.style!.fontSize, inExclusiveRange(12, 22));
    final larger = TextPainter(
      text: TextSpan(
        text: text.data,
        style: text.style!.copyWith(fontSize: text.style!.fontSize! + 0.01),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 190);
    expect(larger.height, greaterThan(38));
    larger.dispose();
    expect(
      tester
          .renderObject<RenderParagraph>(find.text('Two line title'))
          .didExceedMaxLines,
      isFalse,
    );
  });

  testWidgets('reserves space for back navigation and toolbar actions', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AppBar(
            leading: BackButton(onPressed: () {}),
            title: const SizedBox(
              height: 56,
              child: KurumiFittedText(Text('A longer bookmark title')),
            ),
            actions: [
              IconButton(onPressed: () {}, icon: const Icon(Icons.more_vert)),
            ],
          ),
        ),
      ),
    );
    final titleRect = tester.getRect(find.text('A longer bookmark title'));
    expect(
      titleRect.left,
      greaterThanOrEqualTo(tester.getRect(find.byType(BackButton)).right),
    );
    expect(
      titleRect.right,
      lessThanOrEqualTo(tester.getRect(find.byIcon(Icons.more_vert)).left),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('uses multiple lines at the largest fitting size', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 190,
              height: 56,
              child: DefaultTextStyle(
                style: TextStyle(fontSize: 22, height: 1),
                child: KurumiFittedText(Text('Two line title')),
              ),
            ),
          ),
        ),
      ),
    );
    final text = tester.widget<Text>(find.text('Two line title'));
    expect(text.style!.fontSize, 22);
    final paragraph = tester.renderObject<RenderParagraph>(
      find.text('Two line title'),
    );
    expect(paragraph.size.height, greaterThan(22));
    expect(paragraph.didExceedMaxLines, isFalse);
  });
}
