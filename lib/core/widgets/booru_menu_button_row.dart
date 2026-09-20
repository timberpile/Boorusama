// Package imports:
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';

// Project imports:
import 'adaptive_button_row.dart';

class BooruMenuButtonRow extends StatelessWidget {
  const BooruMenuButtonRow({
    required this.buttons,
    this.buttonWidth,
    this.spacing = 8,
    this.overflowIcon,
    this.overflowButtonBuilder,
    this.onOverflow,
    this.maxVisibleButtons,
    this.alignment,
    this.crossAxisAlignment = CrossAxisAlignment.center,
    this.padding,
    this.onOpened,
    this.onClosed,
    this.onMenuTap,
    super.key,
  });

  final List<ButtonData> buttons;
  final double? buttonWidth;
  final double spacing;
  final Widget? overflowIcon;
  final Widget Function(VoidCallback)? overflowButtonBuilder;
  final ValueChanged<int>? onOverflow;
  final int? maxVisibleButtons;
  final MainAxisAlignment? alignment;
  final CrossAxisAlignment crossAxisAlignment;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onOpened;
  final VoidCallback? onClosed;
  final VoidCallback? onMenuTap;

  @override
  Widget build(BuildContext context) {
    final behavior = KurumiTheme.behaviorOf(context);

    return KurumiAdaptiveButtonRow.menu(
      buttons: buttons.cast<KurumiButtonData>(),
      overflowLabel: context.t.generic.action.more,
      buttonWidth: buttonWidth,
      spacing: spacing,
      overflowIcon: overflowIcon,
      onOverflow: onOverflow,
      maxVisibleButtons: maxVisibleButtons,
      alignment: alignment,
      crossAxisAlignment: crossAxisAlignment,
      padding: padding,
      onOpened: () {
        behavior.adaptiveMenuFeedback?.call();
        onOpened?.call();
      },
      onClosed: onClosed,
      onMenuTap: () {
        behavior.adaptiveMenuFeedback?.call();
        onMenuTap?.call();
      },
    );
  }
}
