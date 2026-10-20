// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kurumi/material.dart';

// Project imports:
import '../providers.dart';

/// Starts a foreground check and refreshes it only when the cooldown expires.
class AppUpdateLifecycleListener extends ConsumerStatefulWidget {
  const AppUpdateLifecycleListener({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<AppUpdateLifecycleListener> createState() =>
      _AppUpdateLifecycleListenerState();
}

class _AppUpdateLifecycleListenerState
    extends ConsumerState<AppUpdateLifecycleListener>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    if (!ref.read(shouldCheckForUpdateProvider)) return;
    if (ref.read(appUpdateCoordinatorProvider).isCheckDue) {
      ref.invalidate(appUpdateStatusProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(appUpdateStatusProvider);
    return widget.child;
  }
}
