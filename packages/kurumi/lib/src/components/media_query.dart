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
class KurumiOverlayInsetsScope extends InheritedWidget {
  const KurumiOverlayInsetsScope({
    required this.bottomPadding,
    required this.bottomViewPadding,
    required super.child,
    this.bottomPaddingListenable,
    super.key,
  });

  final double bottomPadding;
  final double bottomViewPadding;

  /// Lets an overlay hosted outside this inherited scope follow its obstruction.
  /// Keyboard displacement remains the responsibility of the overlay host.
  final ValueListenable<double>? bottomPaddingListenable;

  static KurumiOverlayInsetsScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<KurumiOverlayInsetsScope>();

  @override
  bool updateShouldNotify(KurumiOverlayInsetsScope oldWidget) =>
      bottomPadding != oldWidget.bottomPadding ||
      bottomViewPadding != oldWidget.bottomViewPadding ||
      bottomPaddingListenable != oldWidget.bottomPaddingListenable;
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
