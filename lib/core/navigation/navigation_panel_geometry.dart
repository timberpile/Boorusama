import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:kurumi/material.dart';

import '../widgets/viewport_bottom_insets.dart';
import 'destination_id.dart';

/// Rendered geometry, shared by the bar, route-owned footer and overlay insets.
@immutable
class NavigationPanelGeometry extends ViewportBottomInsets {
  NavigationPanelGeometry({
    required this.navigationExtent,
    required this.footerExtent,
    required this.hiddenFraction,
    required this.systemMediaQuery,
  }) : super(
         visible: math.max(
           systemMediaQuery.padding.bottom,
           (navigationExtent + footerExtent) * (1 - hiddenFraction),
         ),
         endClearance: navigationExtent + footerExtent,
       );
  final double navigationExtent;
  final double footerExtent;
  final double hiddenFraction;
  final MediaQueryData systemMediaQuery;
  double get totalExtent => navigationExtent + footerExtent;
  double get displacement => totalExtent * hiddenFraction;
  bool get navigationVisible => displacement < navigationExtent;
  bool get footerVisible => footerExtent > 0 && hiddenFraction < 1;

  @override
  bool operator ==(Object other) =>
      other is NavigationPanelGeometry &&
      navigationExtent == other.navigationExtent &&
      footerExtent == other.footerExtent &&
      hiddenFraction == other.hiddenFraction &&
      systemMediaQuery == other.systemMediaQuery;
  @override
  int get hashCode => Object.hash(
    navigationExtent,
    footerExtent,
    hiddenFraction,
    systemMediaQuery,
  );
}

final navigationFooterExtentsProvider =
    NotifierProvider<
      NavigationFooterExtents,
      Map<Object, ({DestinationId destination, double extent})>
    >(NavigationFooterExtents.new);

/// Transient layout leases, never persisted and never containing route widgets.
class NavigationFooterExtents
    extends
        Notifier<Map<Object, ({DestinationId destination, double extent})>> {
  var _disposed = false;
  @override
  Map<Object, ({DestinationId destination, double extent})> build() {
    ref.onDispose(() => _disposed = true);
    return const {};
  }

  void update(Object owner, DestinationId? destination, double extent) {
    if (_disposed) return;
    if (destination == null || extent <= 0) {
      if (state.containsKey(owner)) state = {...state}..remove(owner);
    } else {
      final entry = (destination: destination, extent: extent);
      if (state[owner] != entry) state = {...state, owner: entry};
    }
  }
}

class NavigationPanelScope extends InheritedWidget {
  const NavigationPanelScope({
    required this.motion,
    required this.footerTarget,
    required super.child,
    super.key,
  });
  final ValueListenable<NavigationPanelGeometry> motion;
  final double footerTarget;

  static NavigationPanelScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<NavigationPanelScope>();
  @override
  bool updateShouldNotify(NavigationPanelScope oldWidget) =>
      motion != oldWidget.motion || footerTarget != oldWidget.footerTarget;
}
