import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:boorusama/core/selection/checkbox_range_selection.dart';

void main() {
  testWidgets(
    'checkbox range reverses without replacing choices outside the visible folder',
    (tester) async {
      var selected = <int>{0, 99};
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => CheckboxRangeSelection<int>(
                entries: [0, 1, 2, 3, 4, 5],
                selected: selected,
                onChanged: (value) => setState(() => selected = value),
                child: ListView(
                  children: [
                    for (var i = 0; i < 6; i++)
                      CheckboxRangeItem(
                        value: i,
                        child: CheckboxListTile(
                          title: Text('Item $i'),
                          value: selected.contains(i),
                          onChanged: (value) => setState(() {
                            if (value!) {
                              selected.add(i);
                            } else {
                              selected.remove(i);
                            }
                          }),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Item 1')),
      );
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 10));
      await gesture.moveTo(tester.getCenter(find.text('Item 4')));
      await tester.pump();
      expect(selected, {0, 1, 2, 3, 4, 99});
      await gesture.moveTo(tester.getCenter(find.text('Item 2')));
      await tester.pump();
      expect(selected, {0, 1, 2, 99});
      await gesture.up();
      await tester.pump();
      await tester.tap(find.text('Item 2'));
      await tester.pump();
      expect(selected, {0, 1, 99});
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'a completed checkbox drag leaves platform Back with its dialog',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => AlertDialog(
                    content: CheckboxRangeSelection<int>(
                      entries: const [0],
                      selected: const {},
                      onChanged: (_) {},
                      child: const CheckboxRangeItem(
                        value: 0,
                        child: Text('Choice'),
                      ),
                    ),
                  ),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.longPress(find.text('Choice'));
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
    },
  );
}
