import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../blacklists/providers.dart';
import '../../boorus/booru/types.dart';
import '../../configs/config/types.dart';
import '../../configs/manage/providers.dart';
import '../filter/types.dart';
import '../post/providers.dart';
import '../post/types.dart';
import '../rating/types.dart';
import '../sources/types.dart';
import 'src/data/source_post_lookup.dart';
import 'data.dart';
import 'types.dart';

// These engines' registered post repositories use their JSON APIs. Other
// engines (including separate HTML implementations) are deliberately excluded.
bool supportsExactPostLookup(BooruConfig config) =>
    switch (config.auth.booruType) {
      BooruType.danbooru || BooruType.gelbooru => true,
      BooruType.gelbooruV2 =>
        postOriginFromConfig(config).sourceHost == 'rule34.xxx',
      _ => false,
    };

final exactPostLookupProvider = FutureProvider.autoDispose
    .family<ExactPostLookup, BooruConfig>((ref, target) async {
      final repository = ref.watch(originAwarePostRepoProvider(target));
      final blacklist = await ref.watch(
        blacklistTagsProvider(target.filter).future,
      );
      return ExactPostLookup(
        repository: repository,
        targetOrigin: postOriginFromConfig(target),
        apiMode: supportsExactPostLookup(target),
        isVisible: (post) => isExactLookupPostVisible(post, target, blacklist),
      );
    });

final sourcePostLookupProvider = FutureProvider.autoDispose
    .family<SourcePostLookup, BooruConfig>((ref, target) async {
      final repository = ref.watch(originAwarePostRepoProvider(target));
      final blacklist = await ref.watch(
        blacklistTagsProvider(target.filter).future,
      );
      return SourcePostLookup(
        repository: repository,
        targetOrigin: postOriginFromConfig(target),
        isVisible: (post) => isExactLookupPostVisible(post, target, blacklist),
      );
    });

bool isExactLookupPostVisible(
  Post post,
  BooruConfig target,
  Set<String> blacklist,
) {
  final filter = target.search.filter;
  if (post.isFlash ||
      (filter.deletedItemBehavior.isHidden &&
          (post.status?.matches('deleted') ?? false)) ||
      (filter.bannedPostVisibility.isHidden &&
          (post.status?.matches('banned') ?? false))) {
    return false;
  }
  final visibleRating = switch (filter.ratingFilter) {
    BooruConfigRatingFilter.none => true,
    BooruConfigRatingFilter.hideNSFW => post.rating == Rating.general,
    BooruConfigRatingFilter.hideExplicit =>
      target.auth.booruType == BooruType.danbooru
          ? post.rating == Rating.general || post.rating == Rating.sensitive
          : post.rating != Rating.explicit && post.rating != Rating.unknown,
    BooruConfigRatingFilter.custom =>
      !(filter.granularRatingFilters?.ratings.contains(post.rating) ?? false),
  };
  return visibleRating && filterTags([post], blacklist).isNotEmpty;
}

/// One results page owns this session and shares its bounded metadata refresh
/// across all target profiles.
class CrossProfileLookupSession {
  CrossProfileLookupSession({
    required this.source,
    required this.refreshSource,
    required this.lookup,
    this.sourceLookup,
  });

  final Post source;
  final Future<Post?> Function() refreshSource;
  final Future<ExactPostLookup> Function(BooruConfig) lookup;
  final Future<SourcePostLookup> Function(BooruConfig)? sourceLookup;
  Future<Post?>? _refresh;
  final _methods = <String, PostLookupMatchKind>{};
  final _matched = <String>{};

  Future<PostLookupResult> find(
    BooruConfig target, {
    int page = 1,
    required PostLookupCancellation cancellation,
  }) async {
    if (cancellation.isCancelled) return const PostLookupCancelled();
    if (!supportsExactPostLookup(target)) {
      return const PostLookupUnavailable(
        PostLookupUnavailableReason.unsupported,
      );
    }
    try {
      var resolved = source;
      if (ExactPostLookup.normalizeMd5(source.md5) == null) {
        try {
          resolved =
              await (_refresh ??= Future<Post?>.sync(refreshSource)
                  .timeout(const Duration(seconds: 15))) ??
              source;
        } catch (_) {
          // A refresh failure must not prevent using a source reference already
          // present on the post. With no reference, preserve the actual failure.
          if (lookupSourceUrl(source.source.url) == null) rethrow;
        }
      }
      if (cancellation.isCancelled) return const PostLookupCancelled();
      if (page == 1) {
        _methods.remove(target.id);
        _matched.remove(target.id);
      }
      final sourceReference = lookupSourceUrl(resolved.source.url) != null
          ? resolved
          : source;
      final methods = [
        if (ExactPostLookup.normalizeMd5(resolved.md5) != null)
          PostLookupMatchKind.exactFile,
        if (sourceLookup != null &&
            target.auth.booruType == BooruType.danbooru &&
            pixivArtworkId(sourceReference.source.url) != null)
          PostLookupMatchKind.pixivSource,
        if (sourceLookup != null &&
            supportsSourceUrlLookup(target.auth.booruType) &&
            lookupSourceUrl(sourceReference.source.url) != null)
          PostLookupMatchKind.sourceUrl,
      ];
      if (methods.isEmpty) {
        return const PostLookupUnavailable(
          PostLookupUnavailableReason.missingHash,
        );
      }
      var currentPage = page;
      var index = methods.indexOf(_methods[target.id] ?? methods.first);
      if (index < 0) index = 0;
      PostLookupResult? last;
      for (; index < methods.length; index++) {
        if (cancellation.isCancelled) return const PostLookupCancelled();
        final method = methods[index];
        _methods[target.id] = method;
        final result = method == PostLookupMatchKind.exactFile
            ? await (await lookup(target))
                  .find(resolved, page: currentPage, cancellation: cancellation)
            : await (await sourceLookup!(target)).find(
                sourceReference,
                kind: method,
                page: currentPage,
                cancellation: cancellation,
              );
        if (result is! PostLookupPage) return result;
        last = result;
        if (result.posts.isNotEmpty) _matched.add(target.id);
        if (result.hasMore || _matched.contains(target.id)) return result;
        // Only a completed empty search advances to the next matching method.
        currentPage = 1;
      }
      return last!;
    } catch (error) {
      return cancellation.isCancelled
          ? const PostLookupCancelled()
          : PostLookupFailed(error);
    }
  }
}

final crossProfileLookupSessionProvider = Provider.autoDispose
    .family<CrossProfileLookupSession, Post>((ref, source) {
      return CrossProfileLookupSession(
        source: source,
        refreshSource: () async {
          final profiles = ref.read(booruConfigProvider);
          // An explicit originating account must not fall back to another
          // account on the same host after removal or configuration changes.
          final candidates = source.origin.profileIdHint == null
              ? profiles
              : profiles.where((p) => p.id == source.origin.profileIdHint);
          final resolution = const PostOriginResolver().resolve(
            source.origin,
            candidates,
          );
          if (resolution is! ResolvedPostOrigin || source.sitePostId == null) {
            return null;
          }
          final config = resolution.config;
          final response = await ref
              .read(originAwarePostRepoProvider(config))
              .getPost(
                PostId.from(source.sitePostId!),
                options: PostFetchOptions.raw,
              )
              .run();
          return response.fold((error) => throw error, (post) {
            if (post == null) return null;
            if (post.origin != postOriginFromConfig(config) ||
                post.sitePostId != source.sitePostId) {
              throw StateError('Source metadata identity mismatch');
            }
            return post;
          });
        },
        sourceLookup: (target) async {
          if (!ref.read(booruConfigProvider).contains(target)) {
            throw StateError('Target profile changed');
          }
          return ref.read(sourcePostLookupProvider(target).future);
        },
        lookup: (target) async {
          if (!ref.read(booruConfigProvider).contains(target)) {
            throw StateError('Target profile changed');
          }
          return ref.read(exactPostLookupProvider(target).future);
        },
      );
    });

/// Bounds fan-out without coupling request scheduling to result presentation.
class CrossProfileLookupQueue {
  CrossProfileLookupQueue({this.concurrency = 3})
    : assert(concurrency > 0, 'Concurrency must be positive');
  final int concurrency;
  var _running = 0;
  final _waiting = <Completer<void>>[];

  Future<PostLookupResult> run(
    Future<PostLookupResult> Function() action,
  ) async {
    if (_running >= concurrency) {
      final ready = Completer<void>();
      _waiting.add(ready);
      await ready.future;
    } else {
      _running++;
    }
    try {
      return await action();
    } finally {
      if (_waiting.isEmpty) {
        _running--;
      } else {
        _waiting.removeAt(0).complete();
      }
    }
  }
}
