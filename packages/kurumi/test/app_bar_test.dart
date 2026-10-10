import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurumi/kurumi.dart';

void main() {
  for (final sliver in [false, true]) {
    testWidgets(
      'prefers a slightly smaller single-line ${sliver ? 'sliver' : 'normal'} title',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(268, 600));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final title = const Text('aaaaa aaaa', style: TextStyle(height: 1));
        await tester.pumpWidget(
          MaterialApp(
            home: sliver
                ? Scaffold(
                    body: CustomScrollView(
                      slivers: [
                        KurumiSliverAppBar(
                          leading: BackButton(onPressed: () {}),
                          title: title,
                        ),
                      ],
                    ),
                  )
                : Scaffold(
                    appBar: KurumiAppBar(
                      leading: BackButton(onPressed: () {}),
                      title: title,
                    ),
                  ),
          ),
        );
        final text = tester.widget<Text>(find.text('aaaaa aaaa'));
        expect(text.style!.fontSize, closeTo(18, .02));
        expect(tester.getSize(find.text('aaaaa aaaa')).height, lessThan(22));
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final sliver in [false, true]) {
    for (final scale in [1.0, 1.5, 2.0]) {
      for (final title in [
        'Cats',
        'Many words for a longer page title that should use the available toolbar',
        'Unbreakable' * 30,
        'Lesezeichen 日本語 مجموعة الإشارات المرجعية',
      ]) {
        testWidgets(
          'fits $title in ${sliver ? 'sliver' : 'normal'} toolbar at ${scale}x',
          (tester) async {
            await tester.binding.setSurfaceSize(const Size(320, 600));
            addTearDown(() => tester.binding.setSurfaceSize(null));
            var backTaps = 0;
            var actionTaps = 0;
            final leading = BackButton(onPressed: () => backTaps++);
            final actions = [
              IconButton(
                onPressed: () => actionTaps++,
                icon: const Icon(Icons.more_vert),
              ),
            ];
            await tester.pumpWidget(
              MaterialApp(
                home: MediaQuery(
                  data: MediaQueryData(
                    size: const Size(320, 600),
                    padding: const EdgeInsets.only(top: 24),
                    viewPadding: const EdgeInsets.only(top: 24),
                    viewInsets: const EdgeInsets.only(bottom: 200),
                    textScaler: TextScaler.linear(scale),
                  ),
                  child: sliver
                      ? Scaffold(
                          body: CustomScrollView(
                            slivers: [
                              KurumiSliverAppBar(
                                title: Text(title),
                                leading: leading,
                                actions: actions,
                                pinned: true,
                              ),
                              const SliverToBoxAdapter(
                                child: SizedBox(
                                  height: 40,
                                  key: ValueKey('content'),
                                ),
                              ),
                            ],
                          ),
                        )
                      : Scaffold(
                          appBar: KurumiAppBar(
                            title: Text(title),
                            leading: leading,
                            actions: actions,
                          ),
                          body: const SizedBox(
                            height: 40,
                            key: ValueKey('content'),
                          ),
                        ),
                ),
              ),
            );
            final text = tester.widget<Text>(find.text(title));
            final paragraph = tester.renderObject<RenderParagraph>(
              find.text(title),
            );
            expect(text.style!.fontSize, inInclusiveRange(12, 22));
            expect(text.textScaler!.scale(12), 12 * scale);
            final rect = tester.getRect(find.text(title));
            expect(rect.top, greaterThanOrEqualTo(24));
            expect(rect.bottom, lessThanOrEqualTo(80));
            expect(
              rect.left,
              greaterThanOrEqualTo(
                tester.getRect(find.byType(BackButton)).right,
              ),
            );
            expect(
              rect.right,
              lessThanOrEqualTo(
                tester
                    .getRect(find.widgetWithIcon(IconButton, Icons.more_vert))
                    .left,
              ),
            );
            expect(
              tester.getTopLeft(find.byKey(const ValueKey('content'))).dy,
              80,
            );
            if (title == 'Cats') {
              expect(text.style!.fontSize, 22);
              expect(paragraph.didExceedMaxLines, isFalse);
            }
            if (paragraph.didExceedMaxLines) {
              expect(text.style!.fontSize, 12);
              expect(text.overflow, TextOverflow.ellipsis);
            }
            await tester.tap(find.byType(BackButton));
            await tester.tap(find.byIcon(Icons.more_vert));
            expect(backTaps, 1);
            expect(actionTaps, 1);
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }

  for (final explicit in [false, true]) {
    testWidgets(
      'preserves ${explicit ? 'explicit' : 'themed'} toolbar height and bottom',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(appBarTheme: const AppBarTheme(toolbarHeight: 72)),
            home: Scaffold(
              appBar: KurumiAppBar(
                toolbarHeight: explicit ? 88 : null,
                title: const Text(
                  'A long page title that uses the taller toolbar',
                ),
                bottom: const PreferredSize(
                  preferredSize: Size.fromHeight(20),
                  child: SizedBox(height: 20),
                ),
              ),
              body: const SizedBox(key: ValueKey('content')),
            ),
          ),
        );
        final height = explicit ? 88.0 : 72.0;
        expect(
          tester.getTopLeft(find.byKey(const ValueKey('content'))).dy,
          height + 20,
        );
        expect(
          tester
              .getRect(
                find.text('A long page title that uses the taller toolbar'),
              )
              .bottom,
          lessThanOrEqualTo(height),
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('keeps short centered titles centered', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: KurumiAppBar(
            centerTitle: true,
            leading: BackButton(onPressed: () {}),
            title: const Text('Cats'),
            actions: [
              IconButton(onPressed: () {}, icon: const Icon(Icons.more_vert)),
            ],
          ),
        ),
      ),
    );
    expect(
      tester.getCenter(find.text('Cats')).dx,
      tester.getSize(find.byType(Scaffold)).width / 2,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'fits changing compound titles without shrinking their controls',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final title = ValueNotifier('Cats');
      addTearDown(title.dispose);
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: Scaffold(
              appBar: KurumiAppBar(
                title: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: ValueListenableBuilder<String>(
                        valueListenable: title,
                        builder: (context, value, child) =>
                            KurumiFittedText(Text(value)),
                      ),
                    ),
                    IconButton(
                      onPressed: () => taps++,
                      icon: const Icon(Icons.info),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      final controlSize = tester.getSize(find.byType(IconButton));
      title.value = 'Many words in a changed selection title that needs to fit';
      await tester.pump();
      final text = tester.widget<Text>(find.text(title.value));
      expect(text.style!.fontSize, inInclusiveRange(12, 22));
      expect(text.textScaler!.scale(12), 24);
      expect(
        tester
            .getRect(find.text(title.value))
            .overlaps(tester.getRect(find.byType(IconButton))),
        isFalse,
      );
      expect(tester.getSize(find.byType(IconButton)), controlSize);
      await tester.tap(find.byType(IconButton));
      expect(taps, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('keeps toolbar text fields editable with an open keyboard', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            viewInsets: EdgeInsets.only(bottom: 250),
            textScaler: TextScaler.linear(2),
          ),
          child: Scaffold(appBar: KurumiAppBar(title: TextField())),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), 'cats');
    expect(find.text('cats'), findsOneWidget);
    expect(tester.getSize(find.byType(AppBar)).height, 56);
    expect(tester.takeException(), isNull);
  });
  testWidgets('preserves styled RTL titles and their semantics', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final semantics = tester.ensureSemantics();
    try {
      const title = 'مجموعة الإشارات المرجعية الطويلة 日本語';
      await tester.pumpWidget(
        MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(2)),
              child: Scaffold(
                appBar: KurumiAppBar(
                  leading: BackButton(onPressed: () {}),
                  title: const Text(
                    title,
                    style: TextStyle(
                      fontSize: 26,
                      color: Colors.blue,
                      fontWeight: FontWeight.bold,
                    ),
                    locale: Locale('ar'),
                    semanticsLabel: 'Full accessible page title',
                  ),
                  actions: [
                    IconButton(
                      onPressed: () {},
                      icon: const Icon(Icons.more_vert),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      final text = tester.widget<Text>(find.text(title));
      expect(text.style!.fontSize, inInclusiveRange(12, 26));
      expect(text.style!.color, Colors.blue);
      expect(text.style!.fontWeight, FontWeight.bold);
      expect(text.locale, const Locale('ar'));
      expect(text.textScaler!.scale(12), 24);
      expect(
        find.bySemanticsLabel('Full accessible page title'),
        findsOneWidget,
      );
      final rect = tester.getRect(find.text(title));
      expect(
        rect.right,
        lessThanOrEqualTo(tester.getRect(find.byType(BackButton)).left),
      );
      expect(
        rect.left,
        greaterThanOrEqualTo(
          tester
              .getRect(find.widgetWithIcon(IconButton, Icons.more_vert))
              .right,
        ),
      );
      expect(rect.bottom, lessThanOrEqualTo(56));
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets(
    'keeps a custom sliver title inside the collapsed toolbar above its bottom',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final controller = ScrollController();
      addTearDown(controller.dispose);
      const title = 'A very long page title in a collapsing scrollable toolbar';
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              padding: EdgeInsets.only(top: 24),
              textScaler: TextScaler.linear(2),
            ),
            child: Scaffold(
              body: CustomScrollView(
                controller: controller,
                slivers: [
                  const KurumiSliverAppBar(
                    pinned: true,
                    toolbarHeight: 72,
                    expandedHeight: 160,
                    title: Text(title),
                    bottom: PreferredSize(
                      preferredSize: Size.fromHeight(20),
                      child: SizedBox(height: 20),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 1000)),
                ],
              ),
            ),
          ),
        ),
      );
      controller.jumpTo(300);
      await tester.pumpAndSettle();
      final rect = tester.getRect(find.text(title));
      expect(rect.top, greaterThanOrEqualTo(24));
      expect(rect.bottom, lessThanOrEqualTo(96));
      final header = tester.renderObject<RenderSliver>(
        find.byType(SliverAppBar),
      );
      expect(header.geometry!.paintExtent, 116);
      expect(tester.takeException(), isNull);
    },
  );
}
