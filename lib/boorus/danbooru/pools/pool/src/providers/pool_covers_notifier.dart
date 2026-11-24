import 'dart:async';

import '../../../../../../core/content/content_access.dart';
import '../../../../../../core/content/content_access_provider.dart';
import '../../../../../../core/content/content_media_access.dart';

import 'package:booru_clients/danbooru.dart';

import '../../../../../../core/blacklists/providers.dart';
import '../../../../client_provider.dart';
import '../types/safebooru_pool_availability.dart';

// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Project imports:
import '../../../../../../core/configs/config/types.dart';
import '../../../../../../core/configs/manage/providers.dart';
import '../../../../../../core/posts/post/types.dart';
import '../../../../posts/post/providers.dart';
import '../../types.dart';
import '../types/pool_cover.dart';

/// Reader identity is part of cover evidence even for identical credentials.
class PoolCoverSearch extends BooruConfigSearch {
  PoolCoverSearch(this.reader, this.access)
    : super(auth: reader.auth, filter: reader.search.filter);
  final BooruConfig reader;
  final ContentAccessKey? access;
  @override
  List<Object?> get props => [...super.props, reader.id, access];
}

BooruConfigSearch poolCoverSearch(T Function<T>(ProviderListenable<T>) watch) {
  final reader = watch(currentReadOnlyBooruConfigProvider);
  if (!isDonmaiSafebooru(reader.url)) return reader.search;
  final key =
      reader.anonymousReadScope?.key ??
      watch(currentContentAccessKeyProvider) ??
      watch(contentProfileAccessProvider(reader.id))?.key;
  return PoolCoverSearch(reader, key);
}

final danbooruPoolCoversProvider =
    NotifierProvider.family<
      PoolCoversNotifier,
      Map<int, PoolCover?>,
      BooruConfigSearch
    >(
      PoolCoversNotifier.new,
      dependencies: [
        contentAccessContextProvider,
        danbooruPostRepoProvider,
        booruConfigProvider,
        blacklistTagsProvider,
        danbooruClientProvider,
      ],
    );

final danbooruPoolCoverProvider = Provider.autoDispose
    .family<PoolCover?, PoolId>(
      (ref, id) {
        final config = poolCoverSearch(ref.watch);
        final covers = ref.watch(danbooruPoolCoversProvider(config));

        return covers[id];
      },
      dependencies: [
        currentReadOnlyBooruConfigProvider,
        currentContentAccessKeyProvider,
        contentProfileAccessProvider,
        danbooruPoolCoversProvider,
      ],
    );

class PoolCoversNotifier
    extends FamilyNotifier<Map<PoolId, PoolCover?>, BooruConfigSearch> {
  final _inFlight = <PoolId, Future<void>>{};
  final _lastCandidates = <PoolId, ({int postId, Object revision})>{};
  Object? _generation;
  final _assessments = <int, (DanbooruPool, PoolAssessment)>{};
  final _facts = <int, PostDto>{};
  late PostRepository<Post> _postRepo;
  BooruConfig? _reader;

  @override
  Map<PoolId, PoolCover?> build(BooruConfigSearch arg) {
    final generation = _generation = Object();
    _inFlight.clear();
    _lastCandidates.clear();
    _assessments.clear();
    _facts.clear();
    if (isDonmaiSafebooru(arg.auth.url)) {
      _reader = switch (arg) {
        PoolCoverSearch(:final access?) =>
          ref.watch(contentAccessContextProvider(access))?.config,
        PoolCoverSearch() => null,
        _ =>
          ref
              .watch(booruConfigProvider)
              .where((p) => p.search == arg)
              .singleOrNull,
      };
      if (_reader case final reader?) {
        if (reader.anonymousReadScope != null) {
          ref.watch(globalBlacklistedTagsProvider);
        } else {
          ref.watch(blacklistTagsProvider(reader.filter));
        }
      }
    }
    _postRepo = ref.watch(
      danbooruPostRepoProvider(
        BooruConfigSearch(auth: arg.auth, filter: arg.filter),
      ),
    );
    ref.onDispose(() {
      if (identical(_generation, generation)) _generation = null;
    });
    return {};
  }

  Future<void> load(List<DanbooruPool>? pools) async {
    if (pools == null) return;
    if (isDonmaiSafebooru(arg.auth.url)) {
      await _loadSafebooru(pools);
      return;
    }
    final candidates = {
      for (final pool in pools)
        if (pool.postIds?.isNotEmpty ?? false) pool.id: pool,
    };
    final invalidated = <PoolId>{};
    for (final pool in candidates.values) {
      final postId = pool.postIds!.last;
      if (_lastCandidates[pool.id]?.postId == postId) continue;
      _lastCandidates[pool.id] = (postId: postId, revision: Object());
      unawaited(_inFlight.remove(pool.id));
      if (state.containsKey(pool.id)) invalidated.add(pool.id);
    }
    if (invalidated.isNotEmpty) {
      state = {
        for (final entry in state.entries)
          if (!invalidated.contains(entry.key)) entry.key: entry.value,
      };
    }
    final waiting = <Future<void>>{
      for (final id in candidates.keys) ?_inFlight[id],
    };
    final toFetch = [
      for (final pool in candidates.values)
        if (!state.containsKey(pool.id) && !_inFlight.containsKey(pool.id))
          pool,
    ];
    if (toFetch.isNotEmpty) {
      final generation = _generation;
      final pending = _fetch({
        for (final pool in toFetch) pool.id: _lastCandidates[pool.id]!,
      }, generation);
      for (final pool in toFetch) {
        _inFlight[pool.id] = pending;
      }
      waiting.add(pending);
      try {
        await pending;
      } finally {
        if (identical(_generation, generation)) {
          _inFlight.removeWhere((_, value) => identical(value, pending));
        }
      }
    }
    await Future.wait(waiting);
  }

  PoolAssessment? assessment(DanbooruPool pool) {
    final saved = _assessments[pool.id];
    return saved?.$1 == pool ? saved?.$2 : null;
  }

  Future<void> _loadSafebooru(List<DanbooruPool> pools) async {
    // A raw page contains at most 20 rows. No per-Pool requests or retries.
    final generation = _generation;
    final reader = _reader;
    if (reader == null || generation == null) return;
    final wanted = pools.take(20).toList();
    final waiting = {for (final pool in wanted) ?_inFlight[pool.id]};
    final pending = wanted
        .where(
          (pool) => assessment(pool) == null && !_inFlight.containsKey(pool.id),
        )
        .toList();
    if (pending.isNotEmpty) {
      final work = () async {
        final ids = {
          for (final pool in pending) ...poolAvailabilityCandidates(pool),
        }.take(60).toSet();
        try {
          final missing = ids.where((id) => !_facts.containsKey(id)).toSet();
          final rows = await ref
              .read(danbooruClientProvider(arg.auth))
              .getPostsByIds(missing);
          if (!identical(_generation, generation)) return;
          for (final row in rows) {
            if (ids.contains(row.id)) _facts[row.id!] = row;
          }
        } catch (_) {
          if (!identical(_generation, generation)) return;
          // Failure retains verified facts and allows a normal reload retry.
          return;
        }
        if (!identical(_generation, generation)) return;
        final blacklist = reader.anonymousReadScope != null
            ? ref
                  .read(globalBlacklistedTagsProvider)
                  .asData
                  ?.value
                  .map((row) => row.name)
                  .toSet()
            : ref.read(blacklistTagsProvider(reader.filter)).asData?.value;
        final next = {...state};
        for (final pool in pending) {
          final value = assessSafebooruPool(pool, _facts, arg, blacklist);
          _assessments[pool.id] = (pool, value);
          next[pool.id] = value.covers.firstOrNull ?? PoolCover.empty(pool.id);
        }
        state = next;
      }();
      for (final pool in pending) {
        _inFlight[pool.id] = work;
      }
      waiting.add(work);
      try {
        await work;
      } finally {
        if (identical(_generation, generation)) {
          _inFlight.removeWhere((_, value) => identical(value, work));
        }
      }
    }
    await Future.wait(waiting);
  }

  Future<void> _fetch(
    Map<PoolId, ({int postId, Object revision})> candidates,
    Object? generation,
  ) async {
    final ids = candidates.values.map((item) => item.postId).toSet().toList();
    final result = await _postRepo.getPostsFromIds(ids).run();
    if (!identical(_generation, generation) || generation == null) return;
    result.fold(
      // A failed lookup leaves a candidate retryable on ordinary listing reload.
      (_) {},
      (result) {
        final posts = {for (final post in result.posts) post.id: post};
        final resolved = {
          for (final entry in candidates.entries)
            if (_lastCandidates[entry.key] == entry.value)
              entry.key: switch (posts[entry.value.postId]) {
                final post? => PoolCover.fromPost(post),
                _ => PoolCover.empty(entry.value.postId),
              },
        };
        if (resolved.isNotEmpty) state = {...state, ...resolved};
      },
    );
  }
}
