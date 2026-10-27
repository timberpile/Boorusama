import 'dart:math' as math;

// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kurumi/material.dart';

// Project imports:
import '../settings/providers.dart';
import 'adaptive_button_row.dart';
import 'multi_select_button.dart';

class MultiSelectionActionBar extends ConsumerWidget {
  const MultiSelectionActionBar({
    required this.children,
    this.height,
    super.key,
  });

  final List<Widget> children;
  final double? height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reduceAnimation = ref.watch(
      settingsProvider.select((value) => value.reduceAnimations),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final inline = children
              .where(
                (button) => button is! MultiSelectButton || !button.menuOnly,
              )
              .length;
          // Size for all inline actions, reserving overflow within the five slots.
          final slots = math.max(
            1,
            math.min(5, inline + (children.length > inline ? 1 : 0)),
          );
          final width = constraints.hasBoundedWidth
              ? math.min(86.0, math.max(1.0, constraints.maxWidth / slots - 4))
              : 86.0;
          return AdaptiveButtonRow.menu(
            maxVisibleButtons: 5,
            padding: EdgeInsets.zero,
            reduceAnimation: reduceAnimation,
            buttons: children
                .map(
                  (button) => switch (button) {
                    MultiSelectButton() => ButtonData(
                      widget: button,
                      title: button.name,
                      icon: button.icon,
                      onTap: button.onPressed,
                      enabled: button.onPressed != null,
                      required: button.primary,
                      placement: button.menuOnly
                          ? ButtonPlacement.menuOnly
                          : ButtonPlacement.flexible,
                    ),
                    MultiSelectPopupButton() => ButtonData(
                      widget: button,
                      title: button.name,
                      icon: button.icon,
                      required: true,
                    ),
                    _ => ButtonData(
                      widget: button,
                      title: 'Button',
                      onTap: () {},
                    ),
                  },
                )
                .toList(),
            spacing: 4,
            buttonWidth: width,
          );
        },
      ),
    );
  }
}
