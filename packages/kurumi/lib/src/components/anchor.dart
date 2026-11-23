import 'dart:async';
import 'dart:math' as math;

import 'package:anchor_ui/anchor_ui.dart';
import 'package:material_ui/material_ui.dart';

import '../foundation/platform.dart';
import '../theme/theme.dart';
import 'back_handler.dart';

class KurumiAnchor extends StatefulWidget {
  const KurumiAnchor({
    required this.controller,
    required this.overlayBuilder,
    required this.child,
    super.key,
    this.placement = Placement.bottom,
    this.viewPadding,
    this.backgroundColor,
    this.onShow,
    this.onHide,
    this.onBack,
    this.spacing,
    this.backdropColor,
    this.reduceAnimation,
    this.constrainToViewport = false,
  });

  final AnchorController controller;
  final WidgetBuilder overlayBuilder;
  final Widget child;
  final Placement placement;
  final EdgeInsets? viewPadding;
  final Color? backgroundColor;
  final VoidCallback? onShow;
  final VoidCallback? onHide;

  /// Optional nested navigation owned by the visible popup.
  final VoidCallback? onBack;
  final double? spacing;
  final Color? backdropColor;
  final bool? reduceAnimation;

  /// Opt in when the overlay content can scroll within the available viewport.
  final bool constrainToViewport;

  @override
  State<KurumiAnchor> createState() => _KurumiAnchorState();
}

class _KurumiAnchorState extends State<KurumiAnchor>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;
  final _overlayScope = FocusScopeNode(debugLabel: 'KurumiAnchorOverlay');
  FocusNode? _opener;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _overlayScope.dispose();
    super.dispose();
  }

  void _handleShowRequested(VoidCallback showOverlay) {
    _opener = FocusManager.instance.primaryFocus;
    showOverlay();
    _animationController.forward();
    // Autofocus, like a selected option's, applies in a microtask after the
    // overlay's first frame; only without it does the first item take focus.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => scheduleMicrotask(() {
        if (!mounted || !widget.controller.isShowing) return;
        if (_overlayScope.focusedChild != null) return;
        _overlayScope.traversalDescendants.firstOrNull?.requestFocus();
      }),
    );
  }

  void _handleHideRequested(VoidCallback hideOverlay) {
    final opener = _opener;
    _opener = null;
    // Only when the menu still holds focus, so a route opened from a menu
    // item keeps it.
    if (_overlayScope.hasFocus && opener?.context != null) {
      opener?.requestFocus();
    }
    _animationController.reverse().then((_) {
      if (mounted) {
        hideOverlay();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = kurumiIsDesktopPlatform();

    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, child) => KurumiBackHandler(
        enabled: widget.controller.isShowing,
        onBack: widget.onBack ?? widget.controller.hide,
        child: child!,
      ),
      child: RawAnchor(
        controller: widget.controller,
        placement: widget.placement,
        middlewares: [
          OffsetMiddleware(mainAxis: OffsetValue.value(widget.spacing ?? 4)),
          const FlipMiddleware(),
          const ShiftMiddleware(),
          if (widget.constrainToViewport) const _ViewportFitMiddleware(),
        ],
        viewPadding:
            widget.viewPadding ??
            (isDesktop ? const EdgeInsets.all(4) : const EdgeInsets.all(12)),
        onShowRequested: _handleShowRequested,
        onHideRequested: _handleHideRequested,
        backdropBuilder: (context) => FadeTransition(
          opacity: _animationController,
          child: GestureDetector(
            onTap: () => widget.controller.hide(),
            child: Container(
              color:
                  widget.backdropColor ??
                  (isDesktop ? Colors.transparent : Colors.black45),
            ),
          ),
        ),
        onShow: widget.onShow,
        onHide: widget.onHide,
        overlayBuilder: (context) => FocusScope(
          node: _overlayScope,
          onFocusChange: (hasFocus) {
            if (!hasFocus && widget.controller.isShowing) {
              widget.controller.hide();
            }
          },
          child: NotificationListener<ScrollNotification>(
            // A popup owns its scrolling; the page behind it must not react.
            onNotification: (_) => true,
            child: Builder(builder: _buildOverlay),
          ),
        ),
        child: widget.child,
      ),
    );
  }

  Widget _buildOverlay(BuildContext context) {
    final isDesktop = kurumiIsDesktopPlatform();
    final shouldReduceAnimation =
        widget.reduceAnimation ??
        KurumiTheme.maybeBehaviorOf(context)?.reduceMotion ??
        false;

    return switch ((isDesktop, shouldReduceAnimation)) {
      (true, _) || (_, true) => _OverlayContainer(
        backgroundColor: widget.backgroundColor,
        builder: widget.overlayBuilder,
      ),
      _ => _AnimatedOverlay(
        controller: _animationController,
        child: _OverlayContainer(
          backgroundColor: widget.backgroundColor,
          builder: widget.overlayBuilder,
        ),
      ),
    };
  }
}

/// Flip/Shift alone cannot keep a tall vertical popup inside both vertical
/// boundaries: Shift only adjusts the cross axis. Bound scrollable content and
/// clamp the measured overlay after normal anchor placement has been chosen.
class _ViewportFitMiddleware implements PositioningMiddleware<Object?> {
  const _ViewportFitMiddleware();

  @override
  (PositionState, Object?) run(PositionState state) {
    final config = state.config;
    final points = state.anchorPoints;
    final width = math.max(
      0.0,
      config.viewportSize.width - config.padding.horizontal,
    );
    final height = math.max(
      0.0,
      config.viewportSize.height - config.padding.vertical,
    );
    final overlayWidth = math.min(config.overlayWidth ?? 0, width);
    final overlayHeight = math.min(config.overlayHeight ?? 0, height);
    final left =
        config.childPosition.dx +
        config.childSize.width * (1 + points.childAnchor.x) / 2 -
        overlayWidth * (1 + points.overlayAnchor.x) / 2 +
        points.offset.dx;
    final top =
        config.childPosition.dy +
        config.childSize.height * (1 + points.childAnchor.y) / 2 -
        overlayHeight * (1 + points.overlayAnchor.y) / 2 +
        points.offset.dy;
    final dx =
        left.clamp(
          config.padding.left,
          config.padding.left + width - overlayWidth,
        ) -
        left;
    final dy =
        top.clamp(
          config.padding.top,
          config.padding.top + height - overlayHeight,
        ) -
        top;
    return (
      state.copyWith(
        anchorPoints: points.copyWith(offset: points.offset + Offset(dx, dy)),
      ),
      // SizeData makes RawAnchor measure its opener during an overlay build.
      // The opener may be in a newly rebuilt transform while a menu dismisses.
      // Scrollable popup content owns its constraints without that callback.
      null,
    );
  }
}

class _OverlayContainer extends StatelessWidget {
  const _OverlayContainer({
    required this.backgroundColor,
    required this.builder,
  });

  final Color? backgroundColor;
  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context) {
    final isDesktop = kurumiIsDesktopPlatform();
    final colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color:
            backgroundColor ??
            (isDesktop
                ? colorScheme.surfaceContainerHighest
                : colorScheme.surface),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: colorScheme.outlineVariant,
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: builder(context),
    );
  }
}

class _AnimatedOverlay extends StatelessWidget {
  const _AnimatedOverlay({
    required this.controller,
    required this.child,
  });

  final AnimationController controller;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final animation = CurvedAnimation(
      parent: controller,
      curve: Curves.easeOutCubic,
    );

    return FadeTransition(
      opacity: animation,
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.8, end: 1).animate(animation),
        alignment: switch (AnchorData.of(context).geometry.direction) {
          AxisDirection.up => Alignment.bottomCenter,
          AxisDirection.down => Alignment.topCenter,
          AxisDirection.left => Alignment.centerRight,
          AxisDirection.right => Alignment.centerLeft,
        },
        child: child,
      ),
    );
  }
}
