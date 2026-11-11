import 'dart:async';

import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:kurumi/material.dart';

import '../../../../navigation/destination_activity.dart';
import '../../../listing/providers.dart';
import '../../../listing/types.dart';
import '../../../post/types.dart';

/// Page eviction retains only an offset and the extent of the previous visit.
/// Reloads cannot crawl beyond that visit, and user scrolling cancels restore.
class PoolGalleryCheckpoint extends StatefulWidget {
  const PoolGalleryCheckpoint({
    required this.identity,
    required this.controller,
    required this.scrollController,
    required this.perPage,
    required this.child,
    super.key,
  });

  final Object identity;
  final PostGridController<Post> controller;
  final ScrollController scrollController;
  final int perPage;
  final Widget child;

  @override
  State<PoolGalleryCheckpoint> createState() => _PoolGalleryCheckpointState();
}

class _PoolGalleryCheckpointState extends State<PoolGalleryCheckpoint> {
  PageStorageBucket? _storage;
  var _read = false;
  var _active = false;
  var _restoring = false;
  var _scheduled = false;
  var _fetchPending = false;
  var _offset = 0.0;
  var _page = 1;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
    widget.scrollController.addListener(_scrolled);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _active = NavigationActivity.of(context);
    _storage = PageStorage.maybeOf(context);
    if (!_read) {
      _read = true;
      final saved = _storage?.readState(context, identifier: widget.identity);
      if (saved case (final double offset, final int page, final int perPage)
          when page > 0 && perPage > 0) {
        _offset = perPage == widget.perPage ? offset : 0;
        _page = ((page - 1) * perPage ~/ widget.perPage) + 1;
        _restoring =
            _offset > 0 ||
            (widget.controller.pageMode == PageMode.paginated && _page > 1);
      }
    }
    _changed();
  }

  void _save() {
    if (!_active ||
        _restoring ||
        widget.scrollController.positions.length != 1) {
      return;
    }
    _storage?.writeState(
      context,
      (widget.scrollController.offset, widget.controller.page, widget.perPage),
      identifier: widget.identity,
    );
  }

  void _scrolled() => _save();

  void _changed() {
    if (!_restoring) {
      _save();
      return;
    }
    if (_scheduled) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (mounted) _restore();
    });
  }

  void _restore() {
    final controller = widget.controller;
    if (!_active ||
        !_restoring ||
        _fetchPending ||
        controller.loadingMore ||
        controller.refreshing ||
        controller.errors.value != null ||
        widget.scrollController.positions.length != 1) {
      return;
    }
    final position = widget.scrollController.position;
    if (!position.hasContentDimensions) return;
    if (controller.pageMode == PageMode.paginated) {
      final last = controller.maxPage.value;
      final target = last == null ? _page : _page.clamp(1, last < 1 ? 1 : last);
      if (controller.page != target) {
        _fetchPending = true;
        unawaited(_fetchPreviousPage(target));
        return;
      }
    }
    if (controller.pageMode != PageMode.paginated &&
        _offset > position.maxScrollExtent &&
        controller.page < _page &&
        controller.hasMore) {
      _fetchPending = true;
      unawaited(_fetchPreviousPage());
      return;
    }
    // Missing or newly restricted members may shorten the previous viewport.
    position.jumpTo(
      _offset.clamp(position.minScrollExtent, position.maxScrollExtent),
    );
    _restoring = false;
    _save();
  }

  Future<void> _fetchPreviousPage([int? page]) async {
    try {
      if (page != null) {
        await widget.controller.jumpToPage(page);
      } else {
        await widget.controller.fetchMore();
      }
    } catch (_) {
      // The grid owns request errors and its explicit Retry action.
    } finally {
      _fetchPending = false;
      if (mounted) _changed();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    widget.scrollController.removeListener(_scrolled);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      NotificationListener<UserScrollNotification>(
        onNotification: (notification) {
          if (notification.direction != ScrollDirection.idle) {
            _restoring = false;
            _save();
          }
          return false;
        },
        child: widget.child,
      );
}
