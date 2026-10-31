import '../../../../../../core/posts/post/providers.dart';
import '../../../../../../core/posts/listing/providers.dart';

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';
import 'package:kurumi/kurumi.dart';
import 'package:selection_mode/selection_mode.dart';

import '../../../../../../core/bookmarks/src/providers/pool_bookmark_provider.dart';
import '../../../../../../core/bookmarks/src/types/pool_bookmark.dart';
import '../../../../../../core/bookmarks/src/types/pool_bookmark_capability.dart';
import '../../../../../../core/configs/config/types.dart';
import '../../../../../../core/configs/manage/providers.dart';
import '../../../../../../core/posts/listing/src/types/neighboring_series.dart';
import '../../../../../../core/posts/listing/widgets.dart';
import '../../../../../../core/posts/pools/pool_grid_item.dart';
import '../../../../../../core/posts/post/types.dart';
import '../../../../../../core/search/following_topics/src/widgets/feed_post_thumbnail.dart';

bool _matchesSource(BooruConfig config, Post post) =>
    post.origin.sourceHost == postOriginFromConfig(config).sourceHost &&
    post.origin.booruType == config.auth.booruType &&
    (post.origin.profileIdHint == null ||
        post.origin.profileIdHint == config.id);

/// Per-search, source/account-scoped metadata. No member snapshots are stored.
class SearchSeriesIndex extends ChangeNotifier {
  final _metadata = <(BooruConfig, int), List<RemoteBookmarkPool>>{};
  final _pending = <(BooruConfig, int), Future<void>>{};
  var _disposed = false;

  List<RemoteBookmarkPool> pools(BooruConfig config, Post post) =>
      _matchesSource(config, post)
      ? _metadata[(config, post.id)] ?? const []
      : const [];

  Future<void> load(
    BooruConfig config,
    List<Post> posts,
    PoolBookmarkCapability capability,
  ) async {
    if (_disposed) return;
    final eligible = posts
        .take(PoolBookmarkCapability.membershipBudget)
        .where((p) => _matchesSource(config, p))
        .toList();
    final keys = eligible.map((p) => (config, p.id)).toSet();
    final missing = keys
        .where(
          (key) => !_metadata.containsKey(key) && !_pending.containsKey(key),
        )
        .toSet();
    if (missing.isNotEmpty) {
      final ids = missing.map((key) => key.$2).toSet();
      final future = () async {
        try {
          final result = await capability
              .getBookmarkSeries(
                config,
                eligible.where((p) => ids.contains(p.id)).toList(),
              )
              .timeout(const Duration(seconds: 10));
          if (_disposed) return;
          for (final key in missing) {
            _metadata[key] = (result[key.$2] ?? const [])
                .where(
                  (pool) =>
                      pool.id > 0 &&
                      pool.category == BookmarkedPoolCategory.series,
                )
                .toList();
          }
          while (_metadata.length > 512) {
            _metadata.remove(_metadata.keys.first);
          }
        } catch (_) {
          // Unavailable metadata leaves the actual posts visible and retryable.
        } finally {
          for (final key in missing) {
            unawaited(_pending.remove(key));
          }
          if (!_disposed) notifyListeners();
        }
      }();
      for (final key in missing) {
        _pending[key] = future;
      }
    }
    await Future.wait({
      for (final key in keys)
        if (_pending[key] case final future?) future,
    });
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

bool isExplicitSeriesSearch(String query) => RegExp(
  r'(^|\s)(?:pool|series):\S+',
  caseSensitive: false,
).hasMatch(query);

class SearchSeriesGrid extends ConsumerStatefulWidget {
  const SearchSeriesGrid({
    required this.controller,
    required this.config,
    required this.query,
    required this.itemBuilder,
    required this.index,
    super.key,
  });
  final PostGridController<Post> controller;
  final BooruConfig config;
  final String query;
  final IndexedWidgetBuilder itemBuilder;
  final SearchSeriesIndex index;
  @override
  ConsumerState<SearchSeriesGrid> createState() => _SearchSeriesGridState();
}

class _SearchSeriesGridState extends ConsumerState<SearchSeriesGrid> {
  List<Post> _posts = const [];
  List<NeighboringSeriesEntry<Post>> _display = const [];
  var _frozenUntil = 0;
  final _admitted = <int>{};
  final _displayPools = <(int, int), RemoteBookmarkPool>{};

  List<NeighboringSeriesEntry<Post>> _project(
    List<Post> posts, {
    bool enabled = true,
  }) => groupNeighboringSeries(
    posts,
    enabled: enabled,
    scopeKey: (p) => _matchesSource(widget.config, p)
        ? (p.origin, widget.config.id, widget.config.auth)
        : null,
    seriesIds: (p) =>
        widget.index.pools(widget.config, p).map((pool) => pool.id),
  );

  @override
  void didUpdateWidget(covariant SearchSeriesGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.config != oldWidget.config ||
        widget.query != oldWidget.query ||
        widget.controller != oldWidget.controller) {
      _posts = const [];
      _display = const [];
      _frozenUntil = 0;
      _admitted.clear();
      _displayPools.clear();
    }
  }

  void _admit(int start) {
    final window = start ~/ (PoolBookmarkCapability.membershipBudget ~/ 2);
    if (!_admitted.add(window)) return;
    final config = widget.config;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          widget.config != config ||
          isExplicitSeriesSearch(widget.query))
        return;
      final capability = ref.read(poolBookmarkCapabilityProvider(config));
      if (capability != null)
        unawaited(
          widget.index.load(
            config,
            _posts
                .skip(window * (PoolBookmarkCapability.membershipBudget ~/ 2))
                .toList(),
            capability,
          ),
        );
    });
  }

  @override
  Widget build(BuildContext context) {
    final selection = SelectionMode.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge([
        widget.index,
        selection,
        widget.controller.itemsNotifier,
      ]),
      builder: (_, _) {
        final posts = widget.controller.items.toList();
        final samePrefix =
            _posts.length <= posts.length &&
            _posts.indexed.every((entry) => entry.$2 == posts[entry.$1]);
        if (!samePrefix) {
          _frozenUntil = 0;
          _admitted.clear();
          _display = const [];
          _displayPools.clear();
        }
        _posts = posts;
        final prefix = _display
            .where((e) => e.firstIndex < _frozenUntil)
            .toList();
        final start = prefix.isEmpty
            ? 0
            : prefix.last.firstIndex + prefix.last.posts.length;
        // Re-project only the unseen suffix. The raw controller never changes.
        _display = [
          ...prefix,
          for (final entry in _project(posts.sublist(start)))
            NeighboringSeriesEntry.offset(entry, start),
        ];
        for (final entry in _display) {
          if (entry.seriesId case final id?) {
            final pool = widget.index
                .pools(widget.config, entry.posts.first)
                .where((pool) => pool.id == id)
                .firstOrNull;
            if (pool != null) _displayPools[(entry.firstIndex, id)] = pool;
          }
        }
        final display =
            selection.isActive || isExplicitSeriesSearch(widget.query)
            ? _project(posts, enabled: false)
            : _display;
        return PostGridSliver<Post>(
          postController: widget.controller,
          displayItemCount: display.length,
          itemBuilder: (context, i) {
            final entry = display[i];
            if (!selection.isActive && !isExplicitSeriesSearch(widget.query)) {
              _frozenUntil =
                  (_frozenUntil < entry.firstIndex + entry.posts.length)
                  ? entry.firstIndex + entry.posts.length
                  : _frozenUntil;
              _admit(entry.firstIndex + entry.posts.length);
            }
            if (entry.seriesId == null)
              return widget.itemBuilder(context, entry.firstIndex);
            final pool = _displayPools[(entry.firstIndex, entry.seriesId!)];
            if (pool == null)
              return widget.itemBuilder(context, entry.firstIndex);
            return KeyedSubtree(
              key: ValueKey((
                'series',
                widget.config.auth,
                pool.id,
                entry.posts.first.id,
              )),
              child: GestureDetector(
                onLongPress: () =>
                    selection.enable(initialSelected: [entry.firstIndex]),
                child: AspectRatio(
                  aspectRatio: .6,
                  child: PoolGridItem(
                    name: pool.title,
                    total: pool.total,
                    category: context.t.pool.category.series,
                    image: FeedPostThumbnail(
                      post: entry.posts.first,
                      config: widget.config.auth,
                    ),
                    onTap: () async {
                      final config = widget.config;
                      final capability = ref.read(
                        poolBookmarkCapabilityProvider(config),
                      );
                      try {
                        if (capability == null ||
                            !ref.read(booruConfigProvider).contains(config)) {
                          throw StateError('Series profile unavailable');
                        }
                        await capability.openBookmarkPool(ref, config, pool.id);
                      } catch (_) {
                        if (context.mounted)
                          Kurumi.showErrorToast(
                            context,
                            context.t.bookmark.pool_unavailable,
                          );
                      }
                    },
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
