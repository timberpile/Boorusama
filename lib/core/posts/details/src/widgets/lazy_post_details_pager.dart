import 'dart:async';

import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';

class LazyPostDetailsSource {
  const LazyPostDetailsSource({
    required this.changes,
    required this.postIds,
    required this.hasMore,
    required this.fetchMore,
  });

  final Listenable changes;
  final List<int> Function() postIds;
  final bool Function() hasMore;
  final Future<void> Function() fetchMore;
}

class LazyPostDetailsPager extends StatefulWidget {
  const LazyPostDetailsPager({
    required this.source,
    required this.initialIndex,
    required this.itemBuilder,
    this.axis = Axis.horizontal,
    this.onPageChanged,
    super.key,
  });

  final LazyPostDetailsSource source;
  final int initialIndex;
  final Widget Function(BuildContext context, int postId) itemBuilder;
  final Axis axis;
  final ValueChanged<int>? onPageChanged;

  @override
  State<LazyPostDetailsPager> createState() => _LazyPostDetailsPagerState();
}

class _LazyPostDetailsPagerState extends State<LazyPostDetailsPager> {
  late final PageController _controller;
  late final List<int> _ids;
  late final Set<int> _knownIds;
  var _loadingMore = false;
  var _loadFailed = false;

  @override
  void initState() {
    super.initState();
    _ids = List.of(widget.source.postIds());
    _knownIds = _ids.toSet();
    _controller = PageController(initialPage: widget.initialIndex);
    widget.source.changes.addListener(_appendPosts);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadNearEnd(widget.initialIndex);
    });
  }

  @override
  void dispose() {
    widget.source.changes.removeListener(_appendPosts);
    _controller.dispose();
    super.dispose();
  }

  void _appendPosts() {
    final added = [
      for (final id in widget.source.postIds())
        if (_knownIds.add(id)) id,
    ];
    if (added.isNotEmpty) setState(() => _ids.addAll(added));
  }

  void _loadNearEnd(int index) {
    if (_loadingMore ||
        _loadFailed ||
        !widget.source.hasMore() ||
        index < _ids.length - 2) {
      return;
    }
    setState(() => _loadingMore = true);
    unawaited(_fetchMore());
  }

  Future<void> _fetchMore() async {
    try {
      await widget.source.fetchMore();
    } catch (_) {
      if (mounted) setState(() => _loadFailed = true);
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  void _retry() {
    setState(() => _loadFailed = false);
    final index = _controller.hasClients
        ? _controller.page?.round() ?? widget.initialIndex
        : widget.initialIndex;
    _loadNearEnd(index);
  }

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      PageView.builder(
        controller: _controller,
        scrollDirection: widget.axis,
        itemCount: _ids.length,
        onPageChanged: (index) {
          widget.onPageChanged?.call(index);
          _loadNearEnd(index);
        },
        itemBuilder: (context, index) => KeyedSubtree(
          key: ValueKey(_ids[index]),
          child: widget.itemBuilder(context, _ids[index]),
        ),
      ),
      if (_loadingMore)
        const Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: LinearProgressIndicator(),
        ),
      if (_loadFailed)
        Positioned(
          left: 0,
          right: 0,
          bottom: 16,
          child: Center(
            child: FilledButton(
              onPressed: _retry,
              child: Text(context.t.generic.action.retry),
            ),
          ),
        ),
    ],
  );
}
