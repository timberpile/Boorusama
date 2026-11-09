import 'package:boorusama/core/posts/details/src/widgets/native_metadata_selection.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurumi/material.dart';

void main() {
  testWidgets(
    'metadata selection preserves control arrows, editable caret and metadata copy',
    (tester) async {
      final first = FocusNode();
      final second = FocusNode();
      final field = FocusNode();
      final text = TextEditingController(text: 'editable');
      addTearDown(() {
        first.dispose();
        second.dispose();
        field.dispose();
        text.dispose();
      });
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NativeMetadataSelectionScope(
              child: Column(
                children: [
                  const NativeMetadataText('Native metadata words'),
                  Row(
                    children: [
                      TextButton(
                        focusNode: first,
                        onPressed: () {},
                        child: const Text('First'),
                      ),
                      TextButton(
                        focusNode: second,
                        onPressed: () {},
                        child: const Text('Second'),
                      ),
                    ],
                  ),
                  TextField(focusNode: field, controller: text),
                ],
              ),
            ),
          ),
        ),
      );
      first.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(second.hasPrimaryFocus, isTrue);

      field.requestFocus();
      text.selection = const TextSelection.collapsed(offset: 0);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(field.hasPrimaryFocus, isTrue);
      expect(text.selection.baseOffset, 1);

      final selection = tester.widget<SelectionArea>(
        find.byType(SelectionArea),
      );
      expect(selection.focusNode!.skipTraversal, isTrue);
      selection.focusNode!.requestFocus();
      await tester.pump();
      tester
          .state<SelectableRegionState>(find.byType(SelectableRegion))
          .selectAll(SelectionChangedCause.keyboard);
      await tester.pump();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();
      expect(copied, 'Native metadata words');
      expect(selection.focusNode!.hasPrimaryFocus, isTrue);
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
  );
}
