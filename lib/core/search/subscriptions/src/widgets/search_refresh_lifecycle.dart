import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/search_refresh_coordinator.dart';

class SearchRefreshLifecycle extends ConsumerStatefulWidget {
  const SearchRefreshLifecycle({required this.child, super.key});
  final Widget child;
  @override
  ConsumerState<SearchRefreshLifecycle> createState() =>
      _SearchRefreshLifecycleState();
}

class _SearchRefreshLifecycleState extends ConsumerState<SearchRefreshLifecycle>
    with WidgetsBindingObserver {
  late final SearchRefreshCoordinator _coordinator;

  @override
  void initState() {
    super.initState();
    _coordinator = ref.read(searchRefreshCoordinatorProvider.notifier);
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _coordinator.setForeground(
          WidgetsBinding.instance.lifecycleState == null ||
              WidgetsBinding.instance.lifecycleState ==
                  AppLifecycleState.resumed,
        );
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) =>
      _coordinator.setForeground(state == AppLifecycleState.resumed);
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _coordinator.setForeground(false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
