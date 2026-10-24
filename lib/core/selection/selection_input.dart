import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';
import 'package:selection_mode/selection_mode.dart';

import '../navigation/destination_activity.dart';
import 'ordered_selection_controller.dart';

bool get selectionModifierPressed =>
    HardwareKeyboard.instance.isShiftPressed || selectionAdditivePressed;

bool get selectionAdditivePressed => switch (defaultTargetPlatform) {
  TargetPlatform.macOS => HardwareKeyboard.instance.isMetaPressed,
  _ => HardwareKeyboard.instance.isControlPressed,
};

/// Called by the item's own tap handler, before navigation/custom gestures.
bool handleSelectionTap(BuildContext context, int index) {
  final controller = SelectionMode.maybeOf(context);
  if (controller == null ||
      (!controller.isActive && !selectionModifierPressed)) {
    return false;
  }
  if (controller is OrderedSelectionController) {
    controller.click(
      index,
      range: HardwareKeyboard.instance.isShiftPressed,
      additive: selectionAdditivePressed,
    );
  } else {
    if (!controller.isActive) controller.enable();
    controller.toggleItem(index);
  }
  return true;
}

class SelectionInput extends StatelessWidget {
  const SelectionInput({
    required this.controller,
    required this.itemCount,
    required this.child,
    super.key,
  });
  final SelectionModeController controller;
  final int itemCount;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final active = NavigationActivity.of(context);
    if (!active && controller is OrderedSelectionController) {
      (controller as OrderedSelectionController).synchronizeDuringBuild(
        (controller as OrderedSelectionController).cancelDrag,
      );
    }
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => KurumiBackHandler(
        enabled: active && controller.isActive,
        onBack: () {
          if (controller is OrderedSelectionController &&
              controller.isDragInProgress) {
            (controller as OrderedSelectionController).cancelDrag();
          } else {
            controller.disable();
          }
        },
        child: Focus(
          canRequestFocus: false,
          skipTraversal: true,
          onKeyEvent: (_, event) {
            if (!active ||
                !(ModalRoute.of(context)?.isCurrent ?? true) ||
                event is! KeyDownEvent ||
                event.logicalKey != LogicalKeyboardKey.keyA ||
                !selectionAdditivePressed) {
              return KeyEventResult.ignored;
            }
            final focused = FocusManager.instance.primaryFocus?.context;
            if (focused?.widget is EditableText ||
                focused?.findAncestorWidgetOfExactType<EditableText>() !=
                    null) {
              return KeyEventResult.ignored;
            }
            if (!controller.isActive) controller.enable();
            controller.selectAll(List.generate(itemCount, (i) => i));
            return KeyEventResult.handled;
          },
          child: child,
        ),
      ),
    );
  }
}
