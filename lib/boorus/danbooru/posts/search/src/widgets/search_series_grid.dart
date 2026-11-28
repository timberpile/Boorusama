import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kurumi/material.dart';

import '../../../../../../core/bookmarks/src/providers/pool_bookmark_provider.dart';
import '../../../../../../core/bookmarks/src/types/pool_bookmark.dart';
import '../../../../../../core/bookmarks/src/types/pool_bookmark_capability.dart';
import '../../../../../../core/configs/config/types.dart';
import '../../../../../../core/posts/listing/providers.dart';
import '../../../../../../core/posts/post/providers.dart';
import '../../../../../../core/posts/listing/src/widgets/grouped_post_grid.dart';
import '../../../../../../core/posts/post/types.dart';

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

  /// Resolve each ordinary page before the grid can freeze cached tiles. One
  /// admission covers the whole supported page (up to 200 IDs) in one metadata
  /// request with a ten-second timeout, independent of the post page size.
  Future<void> loadPage(
    BooruConfig config,
    List<Post> posts,
    PoolBookmarkCapability capability,
  ) async {
    final page = posts.take(PoolBookmarkCapability.membershipBudget).toList();
    await Future.wait([
      for (
        var start = 0;
        start < page.length;
        start += PoolBookmarkCapability.membershipBudget
      )
        load(config, page.skip(start).toList(), capability),
    ]);
  }

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
            if (!result.containsKey(key.$2)) continue;
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
      for (final key in keys) ?_pending[key],
    });
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

bool isExplicitSeriesSearch(String query) => RegExp(
  r'(^|\s)-?(?:pool|series|parent|child|id):\S+',
  caseSensitive: false,
).hasMatch(query);

class SearchSeriesGrid extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) => GroupedPostGrid(
    controller: controller,
    sessionKey: (config, query),
    configForPost: (post) => _matchesSource(config, post) ? config : null,
    seriesForPost: (post) => index.pools(config, post),
    itemBuilder: itemBuilder,
    raw: isExplicitSeriesSearch(query),
    metadataChanges: index,
    onAdmit: (start, posts) {
      final capability = ref.read(poolBookmarkCapabilityProvider(config));
      if (capability != null) {
        unawaited(index.load(config, posts.skip(start).toList(), capability));
      }
    },
  );
}
