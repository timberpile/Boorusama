// Package imports:
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';

const double _kDefaultSpacing = 8;
const double _kWrapSpacing = 4;

typedef OverflowStrategy = KurumiOverflowStrategy;
typedef ButtonPlacement = KurumiButtonPlacement;

class ButtonData extends KurumiButtonData {
  const ButtonData({
    required super.widget,
    required super.title,
    super.onTap,
    super.enabled,
    super.required = false,
    super.placement = ButtonPlacement.flexible,
  });
}

class SimpleButtonData extends ButtonData {
  SimpleButtonData({
    required IconData icon,
    required super.title,
    required VoidCallback onPressed,
    String? tooltip,
    super.required,
    super.placement,
  }) : super(
         widget: IconButton(
           icon: Icon(icon),
           onPressed: onPressed,
           tooltip: tooltip ?? title,
         ),
         onTap: onPressed,
       );
}

class AdaptiveButtonRow extends StatelessWidget {
  const AdaptiveButtonRow._({
    required this.buttons,
    required this.overflowStrategy,
    this.buttonWidth,
    this.spacing = _kDefaultSpacing,
    this.overflowIcon,
    this.onOverflow,
    this.scrollController,
    this.runSpacing = _kDefaultSpacing,
    this.alignment,
    this.maxVisibleButtons,
    this.padding,
    this.onOpened,
    this.onClosed,
    this.onMenuTap,
    this.reduceAnimation,
    super.key,
  });

  factory AdaptiveButtonRow.menu({
    required List<ButtonData> buttons,
    double? buttonWidth,
    double spacing = _kDefaultSpacing,
    Widget? overflowIcon,
    ValueChanged<int>? onOverflow,
    int? maxVisibleButtons,
    MainAxisAlignment? alignment,
    EdgeInsetsGeometry? padding,
    VoidCallback? onOpened,
    VoidCallback? onClosed,
    VoidCallback? onMenuTap,
    bool? reduceAnimation,
    Key? key,
  }) => AdaptiveButtonRow._(
    buttons: buttons,
    overflowStrategy: OverflowStrategy.menu,
    buttonWidth: buttonWidth,
    spacing: spacing,
    overflowIcon: overflowIcon,
    onOverflow: onOverflow,
    maxVisibleButtons: maxVisibleButtons,
    alignment: alignment,
    padding: padding,
    onOpened: onOpened,
    onClosed: onClosed,
    onMenuTap: onMenuTap,
    reduceAnimation: reduceAnimation,
    key: key,
  );

  factory AdaptiveButtonRow.scrollable({
    required List<ButtonData> buttons,
    double? buttonWidth,
    double spacing = _kDefaultSpacing,
    ScrollController? scrollController,
    int? maxVisibleButtons,
    MainAxisAlignment? alignment,
    EdgeInsetsGeometry? padding,
    bool? reduceAnimation,
    Key? key,
  }) => AdaptiveButtonRow._(
    buttons: buttons,
    overflowStrategy: OverflowStrategy.scrollable,
    buttonWidth: buttonWidth,
    spacing: spacing,
    scrollController: scrollController,
    maxVisibleButtons: maxVisibleButtons,
    alignment: alignment,
    padding: padding,
    reduceAnimation: reduceAnimation,
    key: key,
  );

  factory AdaptiveButtonRow.wrap({
    required List<ButtonData> buttons,
    double? buttonWidth,
    double spacing = _kWrapSpacing,
    double runSpacing = _kWrapSpacing,
    MainAxisAlignment? alignment,
    int? maxVisibleButtons,
    EdgeInsetsGeometry? padding,
    bool? reduceAnimation,
    Key? key,
  }) => AdaptiveButtonRow._(
    buttons: buttons,
    overflowStrategy: OverflowStrategy.wrap,
    buttonWidth: buttonWidth,
    spacing: spacing,
    runSpacing: runSpacing,
    alignment: alignment,
    maxVisibleButtons: maxVisibleButtons,
    padding: padding,
    reduceAnimation: reduceAnimation,
    key: key,
  );

  final List<ButtonData> buttons;
  final OverflowStrategy overflowStrategy;
  final double? buttonWidth;
  final double spacing;
  final int? maxVisibleButtons;
  final MainAxisAlignment? alignment;
  final EdgeInsetsGeometry? padding;
  final bool? reduceAnimation;
  final Widget? overflowIcon;
  final ValueChanged<int>? onOverflow;
  final VoidCallback? onOpened;
  final VoidCallback? onClosed;
  final VoidCallback? onMenuTap;
  final ScrollController? scrollController;
  final double runSpacing;

  @override
  Widget build(BuildContext context) {
    final kurumiButtons = buttons.cast<KurumiButtonData>();

    return switch (overflowStrategy) {
      OverflowStrategy.menu => KurumiAdaptiveButtonRow.menu(
        buttons: kurumiButtons,
        overflowLabel: context.t.generic.action.more,
        buttonWidth: buttonWidth,
        spacing: spacing,
        overflowIcon: overflowIcon,
        onOverflow: onOverflow,
        maxVisibleButtons: maxVisibleButtons,
        alignment: alignment,
        padding: padding,
        onOpened: onOpened,
        onClosed: onClosed,
        onMenuTap: onMenuTap,
        reduceAnimation: reduceAnimation,
      ),
      OverflowStrategy.scrollable => KurumiAdaptiveButtonRow.scrollable(
        buttons: kurumiButtons,
        buttonWidth: buttonWidth,
        spacing: spacing,
        scrollController: scrollController,
        maxVisibleButtons: maxVisibleButtons,
        alignment: alignment,
        padding: padding,
        reduceAnimation: reduceAnimation,
      ),
      OverflowStrategy.wrap => KurumiAdaptiveButtonRow.wrap(
        buttons: kurumiButtons,
        buttonWidth: buttonWidth,
        spacing: spacing,
        runSpacing: runSpacing,
        alignment: alignment,
        maxVisibleButtons: maxVisibleButtons,
        padding: padding,
        reduceAnimation: reduceAnimation,
      ),
    };
  }
}
