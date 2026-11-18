import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';

import '../widgets/viewport_bottom_insets.dart';
import 'destination_activity.dart';
import 'destination_profile_scope.dart';
import 'destination_router.dart';
import 'navigation_chrome_controller.dart';
import 'navigation_panel_geometry.dart';

/// Keeps feature state in its route; navigation only leases its measured height.
class NavigationAttachedFooter extends ConsumerStatefulWidget {
  const NavigationAttachedFooter({required this.child, this.footer, super.key});
  final Widget child;
  final Widget? footer;
  @override
  ConsumerState<NavigationAttachedFooter> createState() =>
      _NavigationAttachedFooterState();
}

class _NavigationAttachedFooterState
    extends ConsumerState<NavigationAttachedFooter> {
  NavigationFooterExtents? _leases;
  Widget? _retiringFooter;
  double _height = 0;
  var _scheduled = false;
  var _owns = false;
  var _bottomBar = false;
  var _retireScheduled = false;
  DestinationScope? _destination;
  final _pinnedInsets = ValueNotifier(
    const ViewportBottomInsets(visible: 0, endClearance: 0),
  );

  void _sync() {
    if (_scheduled) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (mounted) {
        _leases?.update(
          this,
          _owns && _bottomBar ? _destination?.id : null,
          widget.footer != null ? _height : 0,
        );
      }
    });
  }

  void _measure(Size size) {
    if (!mounted || widget.footer == null || _height == size.height) return;
    _height = size.height;
    _sync();
    setState(() {});
  }

  @override
  void didUpdateWidget(NavigationAttachedFooter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.footer != null && widget.footer == null) {
      _retiringFooter = oldWidget.footer;
    }
    if (widget.footer != null) _retiringFooter = null;
    _sync();
  }

  @override
  void dispose() {
    _pinnedInsets.dispose();
    final leases = _leases;
    // The inherited host may still be building when a retained route is removed.
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => leases?.update(this, null, 0),
      );
    } else {
      leases?.update(this, null, 0);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final panel = NavigationPanelScope.maybeOf(context);
    _bottomBar = panel != null && panel.motion.value.navigationExtent > 0;
    _destination = DestinationScope.maybeOf(context);
    _leases = ref.read(navigationFooterExtentsProvider.notifier);
    final observer = ref.watch(currentDestinationRouteObserverProvider);
    final route = ModalRoute.of(context);
    Widget layout() {
      _owns = _destination?.active ?? true;
      if (observer is DestinationRouteObserver && route != null) {
        final index = observer.routes.indexOf(route);
        _owns =
            _owns &&
            index >= 0 &&
            observer.routes
                .skip(index + 1)
                .every((r) => r is PopupRoute || isPostViewerRoute(r));
      }
      _sync();
      if (panel == null) {
        return Column(
          children: [
            Expanded(child: widget.child),
            if (widget.footer case final footer?)
              SafeArea(top: false, child: footer),
          ],
        );
      }
      final motion = panel.motion;
      final system = motion.value.systemMediaQuery;
      final media = MediaQuery.of(context);
      final footer = widget.footer ?? (_bottomBar ? _retiringFooter : null);
      if (!_bottomBar) {
        final obstruction =
            (widget.footer != null ? _height : 0) + system.padding.bottom;
        if (_pinnedInsets.value.visible != obstruction) {
          _pinnedInsets.value = ViewportBottomInsets(
            visible: obstruction,
            endClearance: obstruction,
          );
        }
      }
      final chrome = ref.watch(
        navigationChromeProvider.select(
          (s) => (
            selected: s.selectionActive,
            viewer: s.viewerOpen,
            menu: s.menuOpen,
          ),
        ),
      );
      return MediaQuery(
        // Only this full-height viewport opts out of synthetic shell padding.
        data: media.copyWith(
          padding: media.padding.copyWith(bottom: system.padding.bottom),
          viewPadding: media.viewPadding.copyWith(
            bottom: system.viewPadding.bottom,
          ),
        ),
        child: ViewportBottomInsetsScope(
          insets: _bottomBar ? motion : _pinnedInsets,
          child: Stack(
            fit: StackFit.expand,
            children: [
              widget.child,
              if (footer != null && _owns)
                ValueListenableBuilder<NavigationPanelGeometry>(
                  valueListenable: motion,
                  child: KurumiMeasureSize(
                    onChange: _measure,
                    child: Material(
                      color: Theme.of(context).colorScheme.surfaceContainer,
                      child: footer,
                    ),
                  ),
                  builder: (context, geometry, child) {
                    if (widget.footer == null &&
                        geometry.footerExtent <= .001 &&
                        !_retireScheduled) {
                      _retireScheduled = true;
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        _retireScheduled = false;
                        if (mounted && widget.footer == null) {
                          setState(() {
                            _retiringFooter = null;
                            _height = 0;
                          });
                        }
                      });
                    }
                    final enabled =
                        widget.footer != null &&
                        (!_bottomBar || geometry.footerVisible) &&
                        geometry.systemMediaQuery.viewInsets.bottom == 0 &&
                        !chrome.selected &&
                        !chrome.viewer &&
                        !chrome.menu &&
                        NavigationActivity.of(context);
                    return Positioned(
                      left: 0,
                      right: 0,
                      bottom: _bottomBar
                          ? geometry.navigationExtent
                          : system.padding.bottom,
                      child: IgnorePointer(
                        ignoring: !enabled,
                        child: ExcludeFocus(
                          excluding: !enabled,
                          child: ExcludeSemantics(
                            excluding: !enabled,
                            child: Transform.translate(
                              key: const ValueKey(
                                'attached-footer-translation',
                              ),
                              offset: Offset(
                                0,
                                _bottomBar ? geometry.displacement : 0,
                              ),
                              child: ClipRect(
                                child: Align(
                                  alignment: Alignment.bottomCenter,
                                  heightFactor: !_bottomBar
                                      ? 1
                                      : _height > 0
                                      ? (geometry.footerExtent / _height).clamp(
                                          0,
                                          1,
                                        )
                                      : 0,
                                  child: child,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      );
    }

    return observer is DestinationRouteObserver
        ? ListenableBuilder(
            listenable: observer.topRoute,
            builder: (_, _) => layout(),
          )
        : layout();
  }
}
