// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kurumi/material.dart';

// Project imports:
import '../../../../core/configs/config/providers.dart';
import '../../users/creator/providers.dart';
import 'post_creator_preloadable.dart';

class DanbooruCreatorPreloader extends ConsumerStatefulWidget {
  const DanbooruCreatorPreloader({
    required this.preloadable,
    required this.child,
    super.key,
  });

  final PostCreatorsPreloadable preloadable;
  final Widget child;

  @override
  ConsumerState<ConsumerStatefulWidget> createState() =>
      _DanbooruCreatorPreloaderState();
}

class _DanbooruCreatorPreloaderState
    extends ConsumerState<DanbooruCreatorPreloader> {
  @override
  void initState() {
    super.initState();
    _loadCreators();
  }

  @override
  void didUpdateWidget(covariant DanbooruCreatorPreloader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.preloadable != widget.preloadable) _loadCreators();
  }

  void _loadCreators() {
    ref
        .read(danbooruCreatorsProvider(ref.readConfigAuth).notifier)
        .load(widget.preloadable.userIds);
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
