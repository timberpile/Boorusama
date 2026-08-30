// Package imports:
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';

class MultiSelectButton extends StatelessWidget {
  const MultiSelectButton({
    required this.icon,
    required this.name,
    required this.onPressed,
    super.key,
  });

  factory MultiSelectButton.shrink() => const _ShrinkButton();

  final Widget icon;
  final String name;
  final void Function()? onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Kurumi.themeOf(context).colorScheme;
    final iconTheme = IconTheme.of(context);

    return Semantics(
      label: name,
      button: true,
      enabled: onPressed != null,
      onTap: onPressed,
      excludeSemantics: true,
      child: InkWell(
        hoverColor: Kurumi.themeOf(context).hoverColor.withValues(alpha: 0.1),
        customBorder: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        onTap: onPressed,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 4),
            Theme(
              data: ThemeData(
                iconTheme: iconTheme.copyWith(
                  color: onPressed != null
                      ? colorScheme.onSurface
                      : colorScheme.hintColor,
                ),
              ),
              child: icon,
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(
                left: 4,
                right: 4,
                bottom: 4,
              ),
              child: Text(
                name,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  letterSpacing: 0.5,
                  color: onPressed != null ? null : colorScheme.hintColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShrinkButton extends MultiSelectButton {
  const _ShrinkButton()
    : super(
        icon: const SizedBox.shrink(),
        name: '',
        onPressed: null,
      );

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

/// A multi-selection action with a standard popup menu.
class MultiSelectPopupButton extends StatelessWidget {
  const MultiSelectPopupButton({
    required this.icon,
    required this.name,
    required this.menuBuilder,
    super.key,
    this.enabled = true,
  });

  final Widget icon;
  final String name;
  final WidgetBuilder menuBuilder;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return KurumiPopupMenuButton(
      enabled: enabled,
      semanticLabel: name,
      items: [Builder(builder: menuBuilder)],
      child: MultiSelectButton(
        icon: icon,
        name: name,
        onPressed: enabled ? () {} : null,
      ),
    );
  }
}
