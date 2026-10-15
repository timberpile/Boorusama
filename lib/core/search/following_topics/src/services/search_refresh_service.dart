// Package imports:
import 'package:clock/clock.dart';
import 'package:foundation/foundation.dart';

// Project imports:
import '../../../../configs/config/types.dart';
import '../../../../errors/types.dart';
import '../../../../http/client/coordination.dart';
import '../../../../posts/post/types.dart';
import '../refresh/chronological_search_scanner.dart';
import '../refresh/search_refresh_query_adapter.dart';
import '../refresh/search_refresh_fetch_policy.dart';
import '../types/search_post_preview.dart';
import '../types/topic_feed.dart';
import '../types/search_refresh.dart';
import '../types/following_topic.dart';
import '../types/following_topic_repository.dart';

typedef SearchPostRepositoryResolver =
    PostRepository<Post> Function(BooruConfig config);
typedef SearchPostDataCodecResolver =
    BooruPostDataCodec? Function(BooruConfig config);
typedef SearchRefreshQueryAdapterResolver =
    SearchRefreshQueryAdapter Function(BooruConfigAuth config);

class SearchRefreshService {
  SearchRefreshService({
    required this.repository,
    required this.resolvePostRepository,
    required this.resolveQueryAdapter,
    required this.scanner,
    this.resolvePostDataCodec,
    Clock clock = const Clock(),
  }) : _clock = clock;

  final FollowingTopicRepository repository;
  final SearchPostRepositoryResolver resolvePostRepository;
  final SearchPostDataCodecResolver? resolvePostDataCodec;
  final SearchRefreshQueryAdapterResolver resolveQueryAdapter;
  final ChronologicalSearchScanner scanner;
  final Clock _clock;

  Future<SearchRefreshOutcome> refresh(
    FollowingTopic topic,
    BooruConfig config, {
    bool Function()? automatic,
    bool requireFullSnapshot = false,
    int snapshotPostLimit = 1000,
  }) async {
    final startedAt = _clock.now().toUtc();
    final checkpoint = topic.lastSuccessfulCheckAt;
    final baseline = checkpoint == null;
    SearchScanResult scan;
    var delta = false;
    List<Post> initialPosts = const [];
    try {
      final plan = resolveQueryAdapter(config.auth).plan(
        topic.query,
        after: null,
      );
      switch (plan) {
        case UnsupportedSearchRefreshQueryPlan():
          scan = const FailedSearchScan(SearchRefreshErrorKind.unsupported);
        case SupportedSearchRefreshQueryPlan(:final query):
          final fetchPlan = planSearchRefreshFetch(
            booruType: config.auth.booruType,
            siteUrl: config.url,
            query: query,
            afterPostId: topic.highestSeenPostId,
            requireFullSnapshot: baseline,
          );
          delta = fetchPlan.delta;
          final posts = resolvePostRepository(config);
          var cursor = topic.highestSeenPostId;
          Future<Either<SearchRefreshErrorKind, PostResult<Post>>> fetchPage(
            int page,
            int limit,
          ) async {
            final request = delta
                ? planSearchRefreshFetch(
                    booruType: config.auth.booruType,
                    siteUrl: config.url,
                    query: query,
                    afterPostId: cursor,
                  )
                : fetchPlan;
            final result =
                (await posts
                        .getPosts(
                          request.query,
                          delta ? 1 : page,
                          limit: limit,
                          options: PostFetchOptions.raw,
                        )
                        .run())
                    .mapLeft((error) {
                      if (error is RateLimitedError ||
                          error is RequestCancelledError) {
                        throw error;
                      }
                      return _mapError(error);
                    });
            if (!delta) return result;
            // Keyset pagination always requests page one above the last ID.
            // Reject a server that ignores the filter/order before advancing
            // the durable checkpoint. Offset pagination can skip deletions.
            return result.flatMap((page) {
              var previous = cursor!;
              for (final post in page.posts) {
                if (post.id <= previous) {
                  return Either.left(SearchRefreshErrorKind.unsupported);
                }
                previous = post.id;
              }
              cursor = previous;
              return Either.right(page);
            });
          }
          scan = await scanner.scanSnapshot(
            fetchPage: fetchPage,
            requestLimit: fetchPlan.limit,
            maxPages: delta
                ? (1000 / fetchPlan.limit).ceil()
                : requireFullSnapshot
                ? (snapshotPostLimit / fetchPlan.limit).ceil()
                : 1,
          );
          if (requireFullSnapshot && delta && scan is LoadedSearchSnapshot) {
            final snapshotPlan = planSearchRefreshFetch(
              booruType: config.auth.booruType,
              siteUrl: config.url,
              query: query,
              requireFullSnapshot: true,
            );
            final snapshot = await scanner.scanSnapshot(
              requestLimit: snapshotPlan.limit,
              maxPages: (snapshotPostLimit / snapshotPlan.limit).ceil(),
              fetchPage: (page, limit) async =>
                  (await posts
                          .getPosts(
                            snapshotPlan.query,
                            page,
                            limit: limit,
                            options: PostFetchOptions.raw,
                          )
                          .run())
                      .mapLeft((error) {
                        if (error is RateLimitedError ||
                            error is RequestCancelledError) {
                          throw error;
                        }
                        return _mapError(error);
                      }),
            );
            switch (snapshot) {
              case LoadedSearchSnapshot(:final posts):
                initialPosts = posts;
              case FailedSearchScan():
                scan = snapshot;
            }
          }
      }
    } catch (error) {
      if (error is RateLimitedError) {
        return SearchRefreshDeferred(error.retryAt);
      }
      if (error is RequestCancelledError ||
          (ApiRequestContext.current().cancelToken?.isCancelled ?? false)) {
        return const SearchRefreshDiscarded();
      }
      scan = FailedSearchScan(_mapError(error));
    }

    if ((ApiRequestContext.current().cancelToken?.isCancelled ?? false) ||
        !(ApiRequestContext.current().canStart?.call() ?? true)) {
      return const SearchRefreshDiscarded();
    }
    switch (scan) {
      case FailedSearchScan(:final kind):
        return _fail(topic, startedAt, kind);
      case LoadedSearchSnapshot(:final posts, :final truncated):
        final previews = <SearchPostPreview>[];
        for (final post in posts) {
          switch (post.createdAt) {
            case null:
              return _fail(
                topic,
                startedAt,
                SearchRefreshErrorKind.unsupported,
              );
            case final createdAt:
              previews.add(
                SearchPostPreview(
                  postId: post.id,
                  postCreatedAt: createdAt.toUtc(),
                  thumbnailUrl: post.thumbnailImageUrl,
                  sampleUrl: post.sampleImageUrl,
                  discoveredAt: startedAt,
                ),
              );
          }
        }
        final committed = await repository.commitRefresh(
          SearchRefreshCommit(
            topicId: topic.id,
            canCommit: _commitGuard(),
            automaticResolver: automatic,
            feedPosts: [
              for (final post in [...initialPosts, ...posts])
                feedPostSnapshotFromPost(
                  post,
                  origin: PostOrigin.fromSource(
                    booruType: config.auth.booruType,
                    booruId: config.booruId,
                    source: config.url,
                    profileIdHint: config.id,
                  ),
                  dataCodec: resolvePostDataCodec?.call(config),
                ),
            ],
            expectedCreatedAt: topic.createdAt,
            expectedRevision: topic.runtimeRevision,
            expectedCheckpoint: checkpoint,
            startedAt: startedAt,
            identityRetentionBoundary: startedAt.subtract(
              const Duration(minutes: 5),
            ),
            baseline: baseline,
            delta: delta,
            truncated: truncated,
            discoveredPosts: previews,
          ),
        );
        if (committed == null) return const SearchRefreshDiscarded();
        return SearchRefreshSucceeded(
          topic: committed,
          detectedNewPosts: switch (topic.highestSeenPostId) {
            final previousId? when !baseline => previews.any(
              (post) => post.postId > previousId,
            ),
            _ => false,
          },
          baseline: baseline,
        );
    }
  }

  Future<SearchRefreshOutcome> _fail(
    FollowingTopic topic,
    DateTime startedAt,
    SearchRefreshErrorKind kind,
  ) async {
    final saved = await repository.recordRefreshFailure(
      topic.id,
      expectedCreatedAt: topic.createdAt,
      expectedRevision: topic.runtimeRevision,
      attemptedAt: startedAt,
      kind: kind,
      canCommit: _commitGuard(),
    );
    return saved == null
        ? const SearchRefreshDiscarded()
        : SearchRefreshFailed(kind);
  }

  bool Function() _commitGuard() {
    final context = ApiRequestContext.current();
    return () =>
        !(context.cancelToken?.isCancelled ?? false) &&
        (context.canStart?.call() ?? true);
  }

  SearchRefreshErrorKind _mapError(Object error) => switch (error) {
    AppError(type: AppErrorType.loadDataFromServerFailed) =>
      SearchRefreshErrorKind.parsing,
    AppError() => SearchRefreshErrorKind.network,
    ServerError(httpStatusCode: 401 || 403) =>
      SearchRefreshErrorKind.authentication,
    ServerError(httpStatusCode: 400) => SearchRefreshErrorKind.query,
    ServerError(httpStatusCode: 422) => SearchRefreshErrorKind.tagLimit,
    ServerError(httpStatusCode: 410) => SearchRefreshErrorKind.pagination,
    ServerError(httpStatusCode: 429) => SearchRefreshErrorKind.rateLimited,
    ServerError(:final httpStatusCode)
        when httpStatusCode != null && httpStatusCode >= 500 =>
      SearchRefreshErrorKind.network,
    UnknownError(:final error) => _mapError(error),
    FormatException() || TypeError() => SearchRefreshErrorKind.parsing,
    _ => SearchRefreshErrorKind.other,
  };
}
