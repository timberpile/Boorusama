import 'package:boorusama/core/posts/listing/src/widgets/timeline_option_selector.dart';
import 'package:boorusama/core/posts/listing/src/widgets/timeline_toolbar.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets(
      'composable controls remain reachable at 320 dp, 2x, keyboard, $brightness',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        var value = 'Public';
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(brightness: brightness),
            builder: (context, child) => KurumiTheme(
              data: KurumiThemeData.fromMaterial(Theme.of(context)),
              child: MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: const TextScaler.linear(2),
                  viewInsets: const EdgeInsets.only(bottom: 240),
                ),
                child: child!,
              ),
            ),
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) => Align(
                  alignment: Alignment.topLeft,
                  child: TimelineToolbar(
                    trailing: IconButton(
                      key: const ValueKey('overflow'),
                      onPressed: () {},
                      icon: const Icon(Icons.more_vert),
                    ),
                    children: [
                      TimelineOptionSelector<String>(
                        label: value,
                        options: const ['Public', 'Private'],
                        value: value,
                        optionLabel: (value) => value,
                        onSelected: (next) => setState(() => value = next),
                      ),
                      const SizedBox(width: 24),
                      const Text('Page-owned count'),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        final overflow = tester.getRect(find.byKey(const ValueKey('overflow')));
        await tester.tap(find.byType(TimelineOptionSelector<String>));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Private'));
        await tester.pumpAndSettle();
        expect(value, 'Private');
        expect(find.text('Private'), findsOneWidget);
        await tester.drag(
          find.byKey(const ValueKey('timeline-toolbar-content')),
          const Offset(-300, 0),
        );
        await tester.pumpAndSettle();
        expect(
          tester.getRect(find.byKey(const ValueKey('overflow'))),
          overflow,
        );
        expect(
          find.byKey(const ValueKey('overflow')).hitTestable(),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}
