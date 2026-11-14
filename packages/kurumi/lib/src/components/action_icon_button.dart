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
    // Material 2 constrains the entire icon slot to an iconSize square. Reserve
    // space for both glyphs; KurumiDropdownIcon keeps the main glyph at its
    // requested size rather than inheriting this larger composite slot size.
    final slotSize = showDropdown ? iconSize + _dropdownChevronSize : iconSize;
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
          iconSize: slotSize,
          icon: showDropdown
              ? KurumiDropdownIcon(icon: icon, iconSize: iconSize)
              : icon,
        ),
      ),
    );
  }
}

/// Keeps both glyphs within layout bounds instead of painting outside a 24 dp
/// icon or superimposing a tiny arrow. Row supplies the trailing RTL placement.
class KurumiDropdownIcon extends StatelessWidget {
  const KurumiDropdownIcon({
    required this.icon,
    this.iconSize = 24,
    super.key,
  });

  final Widget icon;
  final double iconSize;

  @override
  Widget build(BuildContext context) => IconTheme.merge(
    data: IconThemeData(size: iconSize),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox.square(dimension: iconSize, child: Center(child: icon)),
        const ExcludeSemantics(
          child: Icon(Icons.expand_more, size: _dropdownChevronSize),
        ),
      ],
    ),
  );
}
