import 'dart:math' as math;

// Package imports:
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';

class MultiSelectButton extends StatelessWidget {
  const MultiSelectButton({
    required this.icon,
    required this.name,
    required this.onPressed,
    this.menuOnly = false,
    this.primary = false,
    this.wrapLabel = false,
    super.key,
  });

  factory MultiSelectButton.shrink() => const _ShrinkButton();

  final Widget icon;
  final String name;
  final void Function()? onPressed;
  final bool menuOnly;
  final bool primary;
  final bool wrapLabel;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Kurumi.themeOf(context).colorScheme;
    final iconTheme = IconTheme.of(context);

    return Tooltip(
      message: name,
      excludeFromSemantics: true,
      child: Semantics(
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
              if (wrapLabel)
                _WrappedButtonLabel(
                  name: name,
                  enabled: onPressed != null,
                )
              else ...[
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
            ],
          ),
        ),
      ),
    );
  }
}

/// Reuses the single-line label and spacing budget to keep the icon and hit
/// target fixed. Only the caption scales down when its words need more room.
class _WrappedButtonLabel extends StatelessWidget {
  const _WrappedButtonLabel({required this.name, required this.enabled});

  final String name;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: 10,
      letterSpacing: 0.5,
      color: enabled ? null : Kurumi.themeOf(context).colorScheme.hintColor,
    );
    final painter = TextPainter(
      text: TextSpan(
        text: name,
        style: DefaultTextStyle.of(context).style.merge(style),
      ),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 2,
    );
    painter.layout();
    final lineHeight = painter.preferredLineHeight;
    final wordWidth = painter.minIntrinsicWidth;
    painter.dispose();

    return SizedBox(
      height: lineHeight + 8,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: LayoutBuilder(
          builder: (context, constraints) => FittedBox(
            fit: BoxFit.scaleDown,
            child: SizedBox(
              width: constraints.hasBoundedWidth
                  ? math.max(constraints.maxWidth, wordWidth)
                  : null,
              child: Text(
                name,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: style.copyWith(height: 1),
              ),
            ),
          ),
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

class MultiSelectPopupButton extends StatelessWidget {
  const MultiSelectPopupButton({
    required this.icon,
    required this.name,
    required this.enabled,
    required this.items,
    this.wrapLabel = false,
    super.key,
  });

  final Widget icon;
  final String name;
  final bool enabled;
  final List<Widget> items;
  final bool wrapLabel;

  @override
  Widget build(BuildContext context) => KurumiPopupMenuButton(
    items: items,
    enabled: enabled,
    semanticLabel: name,
    child: MultiSelectButton(
      icon: icon,
      name: name,
      wrapLabel: wrapLabel,
      onPressed: enabled ? () {} : null,
    ),
  );
}
