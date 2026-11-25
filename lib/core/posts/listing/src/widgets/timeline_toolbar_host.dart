import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kurumi/material.dart';

import '../../../../configs/config/providers.dart';
import '../../../../configs/manage/widgets.dart';
import '../../../../content/content_media_access.dart';

/// The attached header owns this presentation slot; the grid retains its state.
class TimelineToolbarHost extends ChangeNotifier {
  Object? _owner;
  Widget? _toolbar;
  var _disposed = false;

  Widget? get toolbar => _toolbar;

  void attach(Object owner, Widget toolbar) {
    if (_disposed) return;
    _owner = owner;
    _toolbar = toolbar;
    notifyListeners();
  }

  void release(Object owner) {
    if (_disposed || !identical(owner, _owner)) return;
    clear();
  }

  void clear() {
    if (_disposed || _toolbar == null) return;
    _owner = null;
    _toolbar = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

class TimelineToolbarHostScope extends InheritedWidget {
  const TimelineToolbarHostScope({
    required this.host,
    required super.child,
    super.key,
  });

  final TimelineToolbarHost? host;

  static TimelineToolbarHost? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<TimelineToolbarHostScope>()
      ?.host;

  @override
  bool updateShouldNotify(TimelineToolbarHostScope oldWidget) =>
      host != oldWidget.host;
}

/// Replaces a grid's floating sliver when the header hosts its Toolbar.
class HostedTimelineToolbar extends ConsumerStatefulWidget {
  const HostedTimelineToolbar({
    required this.host,
    required this.child,
    super.key,
  });

  final TimelineToolbarHost host;
  final Widget child;

  @override
  ConsumerState<HostedTimelineToolbar> createState() =>
      _HostedTimelineToolbarState();
}

class _HostedTimelineToolbarState extends ConsumerState<HostedTimelineToolbar> {
  var _scheduled = false;
  var _active = true;

  @override
  Widget build(BuildContext context) {
    // Copy the profile values, not a descendant ProviderContainer whose lifetime
    // can end before the route removes its old toolbar after a query change.
    final config = ref.watchConfig;
    final accessKey = ref.watch(currentContentAccessKeyProvider);
    final requireAccess = ref.watch(contentAccessRequiredProvider);
    final bookmarkId = ref.watch(currentContentBookmarkIdProvider);
    final presentation = InheritedTheme.captureAll(
      context,
      CurrentBooruConfigScope(
        config: config,
        unavailable: const SizedBox.shrink(),
        accessKey: accessKey,
        requireAccess: requireAccess,
        bookmarkId: bookmarkId,
        child: widget.child,
      ),
    );
    _presentation = presentation;
    if (!_scheduled) {
      _scheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scheduled = false;
        if (!mounted || !_active) return;
        widget.host.attach(
          this,
          Builder(
            builder: (_) =>
                mounted && _active ? _presentation : const SizedBox.shrink(),
          ),
        );
      });
    }
    return const SliverToBoxAdapter(child: SizedBox.shrink());
  }

  late Widget _presentation;

  @override
  void activate() {
    super.activate();
    _active = true;
  }

  @override
  void deactivate() {
    _active = false;
    final host = widget.host;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_active) host.release(this);
    });
    super.deactivate();
  }
}
