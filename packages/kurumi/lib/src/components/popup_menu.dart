import 'dart:math';

import 'package:anchor_ui/anchor_ui.dart';
import 'package:flutter/material.dart';

import '../foundation/platform.dart';
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
    this.tooltip,
    this.icon,
    this.iconPadding = const EdgeInsets.all(6),
    this.child,
    this.enabled = true,
    this.focusNode,
  });

  final List<Widget> items;
  final Color? iconColor;
  final double? maxWidth;
  final Color? iconBackgroundColor;
  final String? semanticLabel;
  final String? tooltip;
  final Widget? icon;
  final EdgeInsetsGeometry iconPadding;
  final Widget? child;
  final bool enabled;
  final FocusNode? focusNode;

  @override
  State<KurumiPopupMenuButton> createState() => _KurumiPopupMenuButtonState();
}

class _KurumiPopupMenuButtonState extends State<KurumiPopupMenuButton> {
  final _controller = AnchorController();

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
      menuFeedback?.call();
      _controller.toggle();
    }

    final button =
        widget.child ??
        Material(
          color: widget.iconBackgroundColor ?? Colors.transparent,
          shape: const CircleBorder(),
          child: InkWell(
            focusNode: widget.focusNode,
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

    final trigger = Semantics(
      button: true,
      enabled: widget.enabled,
      label: widget.semanticLabel,
      onTap: widget.enabled ? toggleMenu : null,
      excludeSemantics: widget.child != null,
      child: widget.child != null
          ? Material(
              color: Colors.transparent,
              child: InkWell(
                focusNode: widget.focusNode,
                onTap: widget.enabled ? toggleMenu : null,
                child: IgnorePointer(child: button),
              ),
            )
          : button,
    );

    return KurumiAnchor(
      controller: _controller,
      constrainToViewport: true,
      overlayBuilder: (context) {
        final media = MediaQuery.of(context);
        final margin = kurumiIsDesktopPlatform() ? 4.0 : 12.0;
        final bottom = max(media.padding.bottom, media.viewInsets.bottom);
        return Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 8,
          ),
          constraints: BoxConstraints(
            maxWidth: min(
              max(
                0.0,
                media.size.width - media.padding.horizontal - margin * 2,
              ),
              widget.maxWidth ?? 200,
            ),
            maxHeight: max(
              0.0,
              media.size.height - media.padding.top - bottom - margin * 2,
            ),
          ),
          child: SingleChildScrollView(
            primary: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: widget.items,
            ),
          ),
        );
      },
      // Keep the tooltip below the anchor's OverlayPortal. An outer tooltip
      // can detach the popup's semantics traversal subtree on mobile.
      child: switch (widget.tooltip) {
        final message? => Tooltip(
          message: message,
          excludeFromSemantics: true,
          child: trigger,
        ),
        null => trigger,
      },
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
  });

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
    );
  }
}
