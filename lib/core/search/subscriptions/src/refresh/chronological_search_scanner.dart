// Package imports:
import 'package:equatable/equatable.dart';
import 'package:foundation/foundation.dart';

// Project imports:
import '../../../../posts/post/types.dart';
import '../types/search_refresh.dart';

typedef SearchRefreshPageFetcher =
    Future<Either<SearchRefreshErrorKind, PostResult<Post>>> Function(
      int page,
      int limit,
    );

sealed class SearchScanResult extends Equatable {
  const SearchScanResult();
}

final class CompletedSearchScan extends SearchScanResult {
  const CompletedSearchScan(this.posts);

  final List<Post> posts;

  @override
  List<Object?> get props => [posts];
}

final class FailedSearchScan extends SearchScanResult {
  const FailedSearchScan(this.kind);

  final SearchRefreshErrorKind kind;

  @override
  List<Object?> get props => [kind];
}

class ChronologicalSearchScanner {
  ChronologicalSearchScanner({
    this.pageSize = 50,
    this.overlap = const Duration(minutes: 5),
  }) : assert(pageSize > 0, 'pageSize must be positive'),
       assert(!overlap.isNegative, 'overlap must not be negative');

  final int pageSize;
  final Duration overlap;

  Future<SearchScanResult> scanBaseline({
    required String query,
    required SearchRefreshPageFetcher fetchPage,
  }) async {
    final result = await fetchPage(1, pageSize);
    return result.fold(
      FailedSearchScan.new,
      (page) {
        final validation = _validatePage(page.posts);
        return switch (validation.error) {
          final SearchRefreshErrorKind kind => FailedSearchScan(kind),
          null => CompletedSearchScan(_uniquePosts(page.posts)),
        };
      },
    );
  }

  Future<SearchScanResult> scanForNewPosts({
    required String query,
    required DateTime checkpoint,
    required SearchRefreshPageFetcher fetchPage,
  }) async {
    final normalizedCheckpoint = checkpoint.toUtc();
    final overlapBoundary = normalizedCheckpoint.subtract(overlap);
    final posts = <Post>[];
    final seenIds = <int>{};
    DateTime? previousCreatedAt;

    for (var pageNumber = 1; ; pageNumber++) {
      final fetched = await fetchPage(pageNumber, pageSize);
      final result = fetched.fold<SearchScanResult?>(
        (kind) => FailedSearchScan(kind),
        (page) {
          final validation = _validatePage(
            page.posts,
            previousCreatedAt: previousCreatedAt,
          );
          final error = validation.error;
          if (error != null) return FailedSearchScan(error);

          previousCreatedAt = validation.lastCreatedAt;
          for (final post in page.posts) {
            switch (post.createdAt) {
              case final DateTime createdAt
                  when createdAt.toUtc().isAfter(normalizedCheckpoint):
                if (seenIds.add(post.id)) {
                  posts.add(post);
                }
              case null:
                return const FailedSearchScan(
                  SearchRefreshErrorKind.unsupported,
                );
            }
          }

          final oldestCreatedAt = validation.oldestCreatedAt;
          final reachedOverlapBoundary =
              oldestCreatedAt != null &&
              !oldestCreatedAt.isAfter(overlapBoundary);
          final reachedMaxPage = switch (page.maxPage) {
            final int maxPage => pageNumber >= maxPage,
            null => false,
          };
          final isShortPage = page.posts.length < pageSize;

          return switch (reachedOverlapBoundary ||
              reachedMaxPage ||
              isShortPage) {
            true => CompletedSearchScan(posts),
            false => null,
          };
        },
      );

      if (result != null) return result;
    }
  }

  _PageValidation _validatePage(
    List<Post> posts, {
    DateTime? previousCreatedAt,
  }) {
    var lastCreatedAt = previousCreatedAt;

    for (final post in posts) {
      final createdAt = post.createdAt;
      if (createdAt == null) {
        return const _PageValidation.unsupported();
      }

      final normalizedCreatedAt = createdAt.toUtc();
      if (lastCreatedAt != null && normalizedCreatedAt.isAfter(lastCreatedAt)) {
        return const _PageValidation.unsupported();
      }
      lastCreatedAt = normalizedCreatedAt;
    }

    return _PageValidation(
      lastCreatedAt: lastCreatedAt,
      oldestCreatedAt: posts.isEmpty ? null : lastCreatedAt,
    );
  }

  List<Post> _uniquePosts(List<Post> posts) {
    final seenIds = <int>{};
    return posts.where((post) => seenIds.add(post.id)).toList();
  }
}

class _PageValidation {
  const _PageValidation({
    required this.lastCreatedAt,
    required this.oldestCreatedAt,
  }) : error = null;

  const _PageValidation.unsupported()
    : error = SearchRefreshErrorKind.unsupported,
      lastCreatedAt = null,
      oldestCreatedAt = null;

  final SearchRefreshErrorKind? error;
  final DateTime? lastCreatedAt;
  final DateTime? oldestCreatedAt;
}
