// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kurumi/material.dart';

// Project imports:
import '../../../../configs/config/types.dart';
import '../../../../notes/note/providers.dart';
import '../../../details_pageview/widgets.dart';
import '../../../post/types.dart';
import 'post_details_page_view_scope.dart';

class CurrentPostDetailsNotes extends ConsumerStatefulWidget {
  const CurrentPostDetailsNotes({
    required this.post,
    required this.viewerConfig,
    required this.authConfig,
    required this.enabled,
    required this.child,
    super.key,
  });

  final Post post;
  final BooruConfigViewer viewerConfig;
  final BooruConfigAuth authConfig;
  final bool enabled;
  final Widget child;

  @override
  ConsumerState<CurrentPostDetailsNotes> createState() =>
      _CurrentPostDetailsNotesState();
}

class _CurrentPostDetailsNotesState
    extends ConsumerState<CurrentPostDetailsNotes> {
  @override
  void initState() {
    super.initState();
    _scheduleLoad();
  }

  @override
  void didUpdateWidget(covariant CurrentPostDetailsNotes oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enabled &&
        (!widget.enabled || oldWidget.authConfig != widget.authConfig)) {
      ref.invalidate(notesProvider(oldWidget.authConfig));
    }
    if (widget.enabled &&
        (!oldWidget.enabled ||
            oldWidget.post != widget.post ||
            oldWidget.authConfig != widget.authConfig ||
            oldWidget.viewerConfig != widget.viewerConfig)) {
      _scheduleLoad();
    }
  }

  void _scheduleLoad() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!mounted || !widget.enabled || !widget.viewerConfig.autoFetchNotes) {
      return;
    }
    ref.read(notesProvider(widget.authConfig).notifier).load(widget.post);
  });

  @override
  Widget build(BuildContext context) => PopScope(
    onPopInvokedWithResult: (didPop, result) {
      if (didPop && widget.enabled) {
        ref.invalidate(notesProvider(widget.authConfig));
      }
    },
    child: widget.child,
  );
}

class PostDetailsNotes<T extends Post> extends ConsumerStatefulWidget {
  const PostDetailsNotes({
    required this.child,
    required this.viewerConfig,
    required this.authConfig,
    required this.posts,
    super.key,
  });

  final BooruConfigViewer viewerConfig;
  final BooruConfigAuth authConfig;
  final List<T> posts;
  final Widget child;

  @override
  ConsumerState<PostDetailsNotes<T>> createState() =>
      _PostDetailsNotesState<T>();
}

class _PostDetailsNotesState<T extends Post>
    extends ConsumerState<PostDetailsNotes<T>> {
  PostDetailsPageViewController? _pageViewController;

  PostDetailsPageViewController get _controller {
    return _pageViewController ??= PostDetailsPageViewScope.of(context);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_pageViewController == null) {
      final controller = _controller;

      WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
        if (widget.viewerConfig.autoFetchNotes) {
          ref
              .read(notesProvider(widget.authConfig).notifier)
              .load(widget.posts[controller.initialPage]);
        }
      });

      controller.currentPage.addListener(_onPageChanged);
    }
  }

  void _onPageChanged() {
    if (!mounted) return;
    final post = widget.posts[_controller.page];

    if (widget.viewerConfig.autoFetchNotes) {
      ref.read(notesProvider(widget.authConfig).notifier).load(post);
    }
  }

  @override
  void dispose() {
    _controller.currentPage.removeListener(_onPageChanged);

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          ref.invalidate(notesProvider(widget.authConfig));
        }
      },
      child: widget.child,
    );
  }
}
