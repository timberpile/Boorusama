import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';

import '../configs/config/types.dart';
import '../configs/manage/providers.dart';

import 'package:kurumi/cupertino.dart';
import 'package:kurumi/material.dart' show MaterialPage;

import '../routers/widgets/dialog_page.dart';
import '../settings/src/routes/settings_adaptive_page.dart';
import 'destination_id.dart';
import 'destination_activity.dart';
import 'destination_profile_scope.dart';

/// Reuses public page factories and untouched extras. There is no fabricated
/// GoRouterState and no per-engine copy of a feature page implementation.
List<RouteBase> destinationChildRoutes(
  DestinationId destination,
  List<GoRoute> templates,
) => [
  for (final (path, template) in flattenNavigationRoutes(templates))
    if (template.builder != null || template.pageBuilder != null)
      GoRoute(
        path: path,
        name: template.name == null
            ? null
            : '${destination.toStorageKey()}:${template.name}',
        builder: template.builder == null
            ? null
            : (context, state) => _source(
                destination,
                state,
                template.builder!(context, state),
              ),
        pageBuilder: template.pageBuilder == null
            ? null
            : (context, state) => _scopePage(
                template.pageBuilder!(context, state),
                (child) => _source(destination, state, child),
              ),
        onExit: template.onExit,
      ),
];

Iterable<(String, GoRoute)> flattenNavigationRoutes(
  List<GoRoute> templates, [
  String parent = '',
]) sync* {
  for (final template in templates) {
    final path = '$parent${template.path.replaceFirst(RegExp('^/'), '')}';
    yield (path, template);
    yield* flattenNavigationRoutes(
      template.routes.whereType<GoRoute>().toList(),
      '$path/',
    );
  }
}

Widget _source(DestinationId destination, GoRouterState state, Widget child) {
  final owner = state.uri.queryParameters['_profile'];
  // Full searches own a changeable source for their entire lifetime. An outer
  // lease for the launch profile would revoke a search after it switched owners.
  if (state.name?.endsWith(':/search') ?? false) {
    return DestinationPageActivity(child: child);
  }
  return DestinationPageActivity(
    child: owner == null || owner == destination.profileId
        ? child
        : _PageSourceLease(
            key: ValueKey(owner),
            profileId: owner,
            child: child,
          ),
  );
}

Page<dynamic> _scopePage(Page<dynamic> page, Widget Function(Widget) wrap) =>
    switch (page) {
      final CupertinoPage<dynamic> p => CupertinoPage<dynamic>(
        key: p.key,
        name: p.name,
        arguments: p.arguments,
        restorationId: p.restorationId,
        child: wrap(p.child),
        title: p.title,
        maintainState: p.maintainState,
        fullscreenDialog: p.fullscreenDialog,
        allowSnapshotting: p.allowSnapshotting,
        canPop: p.canPop,
        onPopInvoked: p.onPopInvoked,
      ),
      final MaterialPage<dynamic> p => MaterialPage<dynamic>(
        key: p.key,
        name: p.name,
        arguments: p.arguments,
        restorationId: p.restorationId,
        child: wrap(p.child),
        maintainState: p.maintainState,
        fullscreenDialog: p.fullscreenDialog,
        allowSnapshotting: p.allowSnapshotting,
        canPop: p.canPop,
        onPopInvoked: p.onPopInvoked,
      ),
      final CustomTransitionPage<dynamic> p => CustomTransitionPage<dynamic>(
        key: p.key,
        name: p.name,
        arguments: p.arguments,
        restorationId: p.restorationId,
        child: wrap(p.child),
        transitionsBuilder: p.transitionsBuilder,
        transitionDuration: p.transitionDuration,
        reverseTransitionDuration: p.reverseTransitionDuration,
        maintainState: p.maintainState,
        fullscreenDialog: p.fullscreenDialog,
        opaque: p.opaque,
        barrierDismissible: p.barrierDismissible,
        barrierColor: p.barrierColor,
        barrierLabel: p.barrierLabel,
      ),
      final DialogPage<dynamic> p => DialogPage<dynamic>(
        key: p.key,
        name: p.name,
        arguments: p.arguments,
        restorationId: p.restorationId,
        builder: (context) => wrap(p.builder(context)),
        anchorPoint: p.anchorPoint,
        barrierColor: p.barrierColor,
        barrierDismissible: p.barrierDismissible,
        barrierLabel: p.barrierLabel,
        useSafeArea: p.useSafeArea,
        themes: p.themes,
        animationStyle: p.animationStyle,
      ),
      final SettingsAdaptivePage<dynamic> p => SettingsAdaptivePage<dynamic>(
        key: p.key,
        name: p.name,
        arguments: p.arguments,
        restorationId: p.restorationId,
        child: wrap(p.child),
        animate: p.animate,
        title: p.title,
        maintainState: p.maintainState,
      ),
      _ => throw UnsupportedError(
        'Unregistered navigation page factory: ${page.runtimeType}',
      ),
    };

/// A child of a global destination must not silently inherit replacement
/// credentials while its immutable route payload still describes the old source.
class _PageSourceLease extends ConsumerStatefulWidget {
  const _PageSourceLease({
    required this.profileId,
    required this.child,
    super.key,
  });
  final String profileId;
  final Widget child;
  @override
  ConsumerState<_PageSourceLease> createState() => _PageSourceLeaseState();
}

class _PageSourceLeaseState extends ConsumerState<_PageSourceLease> {
  BooruConfigAuth? _auth;
  var _revoked = false;
  @override
  Widget build(BuildContext context) {
    final current = ref
        .watch(booruConfigProvider)
        .where((c) => c.id == widget.profileId)
        .firstOrNull;
    _auth ??= current?.auth;
    _revoked = _revoked || current == null || current.auth != _auth;
    if (_revoked) {
      return Center(child: Text(context.t.navigation.unavailable_profile));
    }
    return DestinationProfileScope(
      profileId: widget.profileId,
      child: widget.child,
    );
  }
}
