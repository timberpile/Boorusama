// Public toast helpers cannot override native keyboard movement per call.
// Keep the scope adapter here so full-viewport feedback is displaced once.
import 'package:oktoast/src/core/toast.dart' show ToastTheme;

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

class KurumiRemoveLeftPaddingOnLargeScreen extends StatelessWidget {
  const KurumiRemoveLeftPaddingOnLargeScreen({
    required this.child,
    required this.isLargeScreen,
    super.key,
  });

  final Widget child;
  final bool isLargeScreen;

  @override
  Widget build(BuildContext context) {
    return MediaQuery.removePadding(
      context: context,
      removeLeft: isLargeScreen,
      child: child,
    );
  }
}

/// Live bottom obstruction for overlays hosted by the enclosed Navigator.
/// Pages may retain a different, stable padding while app chrome animates.
class KurumiOverlayInsetsScope extends StatelessWidget {
  const KurumiOverlayInsetsScope({
    required this.bottomPadding,
    required this.bottomViewPadding,
    required this.child,
    this.bottomPaddingListenable,
    this.bottomObstructionListenable,
    super.key,
  });

  final Widget child;
  final double bottomPadding;
  final double bottomViewPadding;

  /// Lets an overlay hosted outside this inherited scope follow its obstruction.
  /// Keyboard displacement remains the responsibility of the overlay host.
  final ValueListenable<double>? bottomPaddingListenable;

  /// Full viewport obstruction, including the keyboard. Scoped toasts use this
  /// instead of OKToast's separate native-window displacement.
  final ValueListenable<double>? bottomObstructionListenable;

  static KurumiOverlayInsetsScope? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<_KurumiOverlayInsetsData>()
      ?.data;

  @override
  Widget build(BuildContext context) {
    final theme = ToastTheme.of(context);
    return _KurumiOverlayInsetsData(
      data: this,
      child: bottomObstructionListenable == null
          ? child
          : ToastTheme(
              textStyle: theme.textStyle,
              textDirection: theme.textDirection,
              handleTouch: theme.handleTouch,
              radius: theme.radius,
              position: theme.position,
              backgroundColor: theme.backgroundColor,
              dismissOtherOnShow: theme.dismissOtherOnShow,
              movingOnWindowChange: false,
              animationBuilder: theme.animationBuilder,
              animationDuration: theme.animationDuration,
              animationCurve: theme.animationCurve,
              duration: theme.duration,
              textPadding: theme.textPadding,
              textAlign: theme.textAlign,
              textMaxLines: theme.textMaxLines,
              textOverflow: theme.textOverflow,
              child: child,
            ),
    );
  }
}

class _KurumiOverlayInsetsData extends InheritedWidget {
  const _KurumiOverlayInsetsData({required this.data, required super.child});
  final KurumiOverlayInsetsScope data;
  @override
  bool updateShouldNotify(_KurumiOverlayInsetsData oldWidget) =>
      data.bottomPadding != oldWidget.data.bottomPadding ||
      data.bottomViewPadding != oldWidget.data.bottomViewPadding ||
      data.bottomPaddingListenable != oldWidget.data.bottomPaddingListenable ||
      data.bottomObstructionListenable !=
          oldWidget.data.bottomObstructionListenable;
}

/// Apply at a route's overlay boundary, before constructing its content.
/// A root-Navigator overlay outside the scope retains its normal MediaQuery.
class KurumiOverlayMediaQuery extends StatelessWidget {
  const KurumiOverlayMediaQuery({required this.builder, super.key});

  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context) {
    final insets = KurumiOverlayInsetsScope.maybeOf(context);
    if (insets == null) return Builder(builder: builder);
    final data = MediaQuery.of(context);
    return MediaQuery(
      data: data.copyWith(
        padding: data.padding.copyWith(bottom: insets.bottomPadding),
        viewPadding: data.viewPadding.copyWith(
          bottom: insets.bottomViewPadding,
        ),
      ),
      child: Builder(builder: builder),
    );
  }
}
