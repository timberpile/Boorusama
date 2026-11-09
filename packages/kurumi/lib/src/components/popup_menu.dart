import 'dart:math';

import 'package:anchor_ui/anchor_ui.dart';
import 'package:flutter/material.dart';

import '../theme/theme.dart';
import 'anchor.dart';

class KurumiPopupMenuButton extends StatefulWidget {
  const KurumiPopupMenuButton({
    required this.items,
    super.key,
    this.iconColor,
    this.iconBackgroundColor,
    this.maxWidth,
    this.semanticLabel,
    this.icon,
    this.iconPadding = const EdgeInsets.all(6),
    this.child,
    this.enabled = true,
  });

  final List<Widget> items;
  final Color? iconColor;
  final double? maxWidth;
  final Color? iconBackgroundColor;
  final String? semanticLabel;
  final Widget? icon;
  final EdgeInsetsGeometry iconPadding;
  final Widget? child;
  final bool enabled;

  @override
  State<KurumiPopupMenuButton> createState() => _KurumiPopupMenuButtonState();
}

class _KurumiPopupMenuButtonState extends State<KurumiPopupMenuButton> {
  final _controller = AnchorController();
  Rect _openerBounds = Rect.zero;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final menuFeedback = KurumiTheme.maybeBehaviorOf(context)?.menuFeedback;

    void toggleMenu() {
      if (!widget.enabled) return;
      if (!_controller.isShowing) {
        final reference = context.findRenderObject();
        if (reference is RenderBox && reference.hasSize) {
          _openerBounds = reference.localToGlobal(Offset.zero) & reference.size;
        }
      }
      menuFeedback?.call();
      _controller.toggle();
    }

    final button =
        widget.child ??
        Material(
          color: widget.iconBackgroundColor ?? Colors.transparent,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: widget.enabled ? toggleMenu : null,
            child: Padding(
              padding: widget.iconPadding,
              child:
                  widget.icon ??
                  Icon(
                    Icons.more_vert,
                    color: widget.iconColor,
                    semanticLabel: widget.semanticLabel,
                  ),
            ),
          ),
        );

    return KurumiAnchor(
      controller: _controller,
      overlayBuilder: (overlayContext) {
        final media = MediaQuery.of(overlayContext);
        final safeTop = media.padding.top + 12;
        final safeBottom =
            media.size.height -
            max(media.padding.bottom, media.viewInsets.bottom) -
            12;
        // The anchor may flip above its opener. Bound the scroll viewport to
        // the larger side so either placement can remain fully on screen.
        final availableHeight = max(
          0.0,
          max(
            _openerBounds.top - safeTop - 4,
            safeBottom - _openerBounds.bottom - 4,
          ),
        );
        return Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 8,
          ),
          constraints: BoxConstraints(
            maxWidth: min(media.size.width, widget.maxWidth ?? 200),
            maxHeight: availableHeight,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: widget.items,
            ),
          ),
        );
      },
      child: Semantics(
        button: true,
        enabled: widget.enabled,
        label: widget.semanticLabel,
        onTap: widget.enabled ? toggleMenu : null,
        excludeSemantics: widget.child != null,
        child: widget.child != null
            ? Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: widget.enabled ? toggleMenu : null,
                  child: IgnorePointer(child: button),
                ),
              )
            : button,
      ),
    );
  }
}

class KurumiPopupMenuItem extends StatelessWidget {
  const KurumiPopupMenuItem({
    required this.title,
    required this.onTap,
    super.key,
    this.icon,
    this.trailing,
    this.hideOnTap = true,
    this.minHeight = 0,
  });

  final double minHeight;
  final Widget title;
  final Widget? icon;
  final Widget? trailing;
  final bool hideOnTap;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final controller = AnchorData.maybeOf(context)?.controller;

    void handleTap() {
      if (hideOnTap) controller?.hide();
      onTap?.call();
    }

    return Semantics(
      button: true,
      enabled: onTap != null,
      onTap: onTap == null ? null : handleTap,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap == null ? null : handleTap,
          borderRadius: BorderRadius.circular(8),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: minHeight),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 8,
              ),
              child: Row(
                children: [
                  if (icon case final icon?)
                    Theme(
                      data: Theme.of(context).copyWith(
                        iconTheme: IconThemeData(
                          color: onTap == null
                              ? Theme.of(context).disabledColor
                              : colorScheme.onSurfaceVariant,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: icon,
                      ),
                    ),
                  Flexible(child: title),
                  if (trailing case final trailing?) ...[
                    const SizedBox(width: 8),
                    trailing,
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
