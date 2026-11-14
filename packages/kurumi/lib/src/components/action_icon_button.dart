import 'package:flutter/material.dart';

const _dropdownChevronSize = 16.0;

/// A normal action with an optional held alternative. The trailing chevron is
/// an affordance, not a second hit target or a persisted selection indicator.
class KurumiActionIconButton extends StatelessWidget {
  const KurumiActionIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.onLongPress,
    this.showDropdown = false,
    this.iconSize = 24,
    super.key,
  });

  final Widget icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final VoidCallback? onLongPress;
  final bool showDropdown;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final hold = onPressed == null ? null : onLongPress;
    return TooltipTheme(
      data: hold == null
          ? TooltipTheme.of(context)
          : TooltipTheme.of(context).copyWith(
              triggerMode: TooltipTriggerMode.manual,
            ),
      child: GestureDetector(
        onLongPress: hold,
        child: IconButton(
          tooltip: tooltip,
          onPressed: onPressed,
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          visualDensity: VisualDensity.standard,
          padding: const EdgeInsets.all(4),
          splashRadius: 24,
          iconSize: iconSize,
          icon: showDropdown
              ? KurumiDropdownIcon(icon: icon, iconSize: iconSize)
              : icon,
        ),
      ),
    );
  }
}

/// Composes the glyphs inside the existing 48 dp button. The icon slot keeps
/// its original size; only the composite paints into the button's inner padding.
class KurumiDropdownIcon extends StatelessWidget {
  const KurumiDropdownIcon({
    required this.icon,
    this.iconSize = 24,
    super.key,
  });

  final Widget icon;
  final double iconSize;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: iconSize,
    child: Stack(
      clipBehavior: Clip.none,
      children: [
        PositionedDirectional(
          start: -6,
          top: 0,
          child: IconTheme.merge(
            data: IconThemeData(size: iconSize),
            child: SizedBox.square(
              dimension: iconSize,
              child: Center(child: icon),
            ),
          ),
        ),
        PositionedDirectional(
          end: -12,
          top: (iconSize - _dropdownChevronSize) / 2,
          child: const ExcludeSemantics(
            child: Icon(Icons.expand_more, size: _dropdownChevronSize),
          ),
        ),
      ],
    ),
  );
}
