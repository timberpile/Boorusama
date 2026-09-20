// Package imports:
import 'package:clock/clock.dart';
import 'package:foundation/foundation.dart';

// Project imports:
import '../../../../configs/config/types.dart';
import '../../../../errors/types.dart';
import '../../../../posts/post/types.dart';
import '../refresh/chronological_search_scanner.dart';
import '../refresh/search_refresh_query_adapter.dart';
import '../types/search_post_preview.dart';
import '../types/search_following_feed.dart';
import '../types/search_refresh.dart';
import '../types/search_subscription.dart';
import '../types/search_subscription_repository.dart';

typedef SearchPostRepositoryResolver =
    PostRepository<Post> Function(BooruConfigSearch config);
typedef SearchRefreshQueryAdapterResolver =
    SearchRefreshQueryAdapter Function(BooruConfigAuth config);

class SearchRefreshService {
  SearchRefreshService({
    required this.repository,
    required this.resolvePostRepository,
    required this.resolveQueryAdapter,
    required this.scanner,
    Clock clock = const Clock(),
  }) : _clock = clock;

  final SearchSubscriptionRepository repository;
  final SearchPostRepositoryResolver resolvePostRepository;
  final SearchRefreshQueryAdapterResolver resolveQueryAdapter;
  final ChronologicalSearchScanner scanner;
  final Clock _clock;

  Future<SearchRefreshOutcome> refresh(
    SearchSubscription subscription,
    BooruConfig config,
  ) async {
    final startedAt = _clock.now().toUtc();
    final checkpoint = subscription.lastSuccessfulCheckAt;
    final baseline = checkpoint == null;
    SearchScanResult scan;
    try {
      final plan = resolveQueryAdapter(config.auth).plan(
        subscription.query,
        after: null,
      );
      switch (plan) {
        case UnsupportedSearchRefreshQueryPlan():
          scan = const FailedSearchScan(SearchRefreshErrorKind.unsupported);
        case SupportedSearchRefreshQueryPlan(:final query):
          final posts = resolvePostRepository(config.search);
          Future<Either<SearchRefreshErrorKind, PostResult<Post>>> fetchPage(
            int page,
            int limit,
          ) async {
            return (await posts
                    .getPosts(
                      query,
                      page,
                      limit: limit,
                      options: const PostFetchOptions(
                        cascadeRequest: false,
                        chronological: true,
                      ),
                    )
                    .run())
                .mapLeft(_mapError);
          }
          scan = await scanner.scanSnapshot(fetchPage: fetchPage);
      }
    } catch (error) {
      scan = FailedSearchScan(_mapError(error));
    }

    switch (scan) {
      case FailedSearchScan(:final kind):
        return _fail(subscription, startedAt, kind);
      case LoadedSearchSnapshot(:final posts):
        final previews = <SearchPostPreview>[];
        for (final post in posts) {
          switch (post.createdAt) {
            case null:
              return _fail(
                subscription,
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
            subscriptionId: subscription.id,
            feedPosts: posts.map(CachedFeedPost.fromPost).toList(),
            expectedCreatedAt: subscription.createdAt,
            expectedCheckpoint: checkpoint,
            startedAt: startedAt,
            identityRetentionBoundary: startedAt.subtract(
              const Duration(minutes: 5),
            ),
            baseline: baseline,
            discoveredPosts: previews,
          ),
        );
        if (committed == null) return const SearchRefreshDiscarded();
        final knownIds = subscription.recentPostIdentities
            .map((post) => post.postId)
            .toSet();
        return SearchRefreshSucceeded(
          subscription: committed,
          detectedNewPosts:
              !baseline &&
              previews.any(
                (post) =>
                    post.postCreatedAt!.isAfter(checkpoint) &&
                    knownIds.add(post.postId),
              ),
          baseline: baseline,
        );
    }
  }

  Future<SearchRefreshOutcome> _fail(
    SearchSubscription subscription,
    DateTime startedAt,
    SearchRefreshErrorKind kind,
  ) async {
    final saved = await repository.recordRefreshFailure(
      subscription.id,
      expectedCreatedAt: subscription.createdAt,
      attemptedAt: startedAt,
      kind: kind,
    );
    return saved == null
        ? const SearchRefreshDiscarded()
        : SearchRefreshFailed(kind);
  }

  SearchRefreshErrorKind _mapError(Object error) => switch (error) {
    AppError(type: AppErrorType.loadDataFromServerFailed) =>
      SearchRefreshErrorKind.parsing,
    AppError() => SearchRefreshErrorKind.network,
    ServerError(httpStatusCode: 401 || 403) =>
      SearchRefreshErrorKind.authentication,
    ServerError(httpStatusCode: 400 || 422) => SearchRefreshErrorKind.query,
    ServerError(httpStatusCode: 410) => SearchRefreshErrorKind.pagination,
    ServerError(httpStatusCode: 429) => SearchRefreshErrorKind.network,
    ServerError(:final httpStatusCode)
        when httpStatusCode != null && httpStatusCode >= 500 =>
      SearchRefreshErrorKind.network,
    UnknownError(:final error) => _mapError(error),
    FormatException() || TypeError() => SearchRefreshErrorKind.parsing,
    _ => SearchRefreshErrorKind.other,
  };
}
