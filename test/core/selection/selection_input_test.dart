import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:selection_mode/selection_mode.dart';
import 'package:boorusama/core/navigation/destination_activity.dart';
import 'package:boorusama/core/selection/ordered_selection_controller.dart';
import 'package:boorusama/core/selection/ordered_selection_canvas.dart';
import 'package:boorusama/core/selection/selection_input.dart';

void main() {
  testWidgets(
    'edge auto-scroll uses the canvas below a header and reaches lazy loaded rows',
    (tester) async {
      final controller = OrderedSelectionController<int>()
        ..setEntries(List.generate(40, (i) => i));
      final scroll = ScrollController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                const SizedBox(height: 200),
                SizedBox(
                  height: 250,
                  child: SelectionMode(
                    controller: controller,
                    scrollController: scroll,
                    options: const SelectionOptions(
                      behavior: SelectionBehavior.manual,
                      dragSelection: DragSelectionOptions(),
                    ),
                    child: OrderedSelectionCanvas(
                      controller: controller,
                      child: ListView.builder(
                        controller: scroll,
                        itemCount: 40,
                        itemExtent: 50,
                        itemBuilder: (context, i) => SelectableBuilder(
                          index: i,
                          builder: (_, selected) =>
                              SizedBox.expand(child: Text('Row $i')),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      controller.enable(initialSelected: [0]);
      await tester.pump();
      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Row 1')),
      );
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 10));
      await gesture.moveTo(const Offset(200, 325));
      await tester.pump(const Duration(milliseconds: 160));
      expect(
        scroll.offset,
        0,
        reason: 'the middle of the canvas is outside both scroll edges',
      );
      await gesture.moveTo(const Offset(200, 445));
      for (var frame = 0; frame < 80 && scroll.offset < 100; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(scroll.offset, greaterThanOrEqualTo(100));
      expect(controller.selectedKeys, contains(5));
      await gesture.up();
      await tester.pump();
      final stoppedAt = scroll.offset;
      await tester.pump(const Duration(milliseconds: 160));
      expect(scroll.offset, stoppedAt);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
      scroll.dispose();
    },
  );

  testWidgets(
    'shortcuts respect editable focus, modal Escape and inactive destination ownership',
    (tester) async {
      final controller = OrderedSelectionController<int>()
        ..setEntries([0, 1, 2]);
      final text = TextEditingController(text: 'search query');
      final active = ValueNotifier(true);
      final focus = FocusNode();
      await tester.pumpWidget(
        MaterialApp(
          home: ValueListenableBuilder(
            valueListenable: active,
            builder: (_, enabled, _) => NavigationActivity(
              active: enabled,
              child: SelectionMode(
                controller: controller,
                options: const SelectionOptions(
                  behavior: SelectionBehavior.manual,
                ),
                child: SelectionInput(
                  controller: controller,
                  itemCount: 3,
                  child: Scaffold(
                    body: Column(
                      children: [
                        TextField(controller: text),
                        Focus(
                          focusNode: focus,
                          child: const Text('Collection'),
                        ),
                        Builder(
                          builder: (context) => TextButton(
                            onPressed: () => showDialog<void>(
                              context: context,
                              builder: (_) =>
                                  const AlertDialog(content: Text('Modal')),
                            ),
                            child: const Text('Dialog'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      controller.enable(initialSelected: [1]);
      await tester.pump();
      await tester.tap(find.byType(TextField));
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      expect(controller.selection, {1});
      expect(
        text.selection,
        const TextSelection(baseOffset: 0, extentOffset: 12),
      );
      await tester.tap(find.text('Dialog'));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('Modal'), findsNothing);
      expect(controller.selection, {1});
      active.value = false;
      await tester.pump();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      expect(controller.selection, {1});
      active.value = true;
      await tester.pump();
      focus.requestFocus();
      await tester.pump();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();
      expect(controller.selection, {0, 1, 2});
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(controller.isActive, isFalse);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
      text.dispose();
      focus.dispose();
      active.dispose();
    },
  );
}
