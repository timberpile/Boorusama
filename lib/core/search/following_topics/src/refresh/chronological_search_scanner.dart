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

final class LoadedSearchSnapshot extends SearchScanResult {
  const LoadedSearchSnapshot(this.posts, {this.truncated = false});

  final List<Post> posts;
  final bool truncated;

  @override
  List<Object?> get props => [posts, truncated];
}

final class FailedSearchScan extends SearchScanResult {
  const FailedSearchScan(this.kind);

  final SearchRefreshErrorKind kind;

  @override
  List<Object?> get props => [kind];
}

class ChronologicalSearchScanner {
  ChronologicalSearchScanner({this.pageSize = 50})
    : assert(pageSize > 0, 'pageSize must be positive');

  final int pageSize;

  Future<SearchScanResult> scanSnapshot({
    required SearchRefreshPageFetcher fetchPage,
    int? requestLimit,
    int maxPages = 1,
  }) async {
    final limit = requestLimit ?? pageSize;
    if (limit < 1 || maxPages < 1) {
      throw ArgumentError(
        'Snapshot request limit and page count must be positive',
      );
    }
    final posts = <Post>[];
    final seenIds = <int>{};
    var truncated = false;
    for (var pageNumber = 1; pageNumber <= maxPages; pageNumber++) {
      final result = await fetchPage(pageNumber, limit);
      SearchRefreshErrorKind? failure;
      final page = result.fold<PostResult<Post>?>(
        (error) {
          failure = error;
          return null;
        },
        (value) => value,
      );
      if (failure case final error?) return FailedSearchScan(error);
      final chunk = page!;
      for (final post in chunk.posts.take(limit)) {
        if (post.createdAt == null) {
          return const FailedSearchScan(SearchRefreshErrorKind.unsupported);
        }
        if (seenIds.add(post.id)) posts.add(post);
      }
      // An unknown continuation on a full final page means the count is a
      // lower bound; never claim that the complete delta was enumerated.
      final mayContinue =
          chunk.posts.length >= limit &&
          chunk.hasMore != false &&
          (chunk.maxPage == null || pageNumber < chunk.maxPage!);
      if (pageNumber == maxPages && mayContinue) truncated = true;
      if (!mayContinue) break;
    }
    return LoadedSearchSnapshot(
      List.unmodifiable(posts),
      truncated: truncated,
    );
  }
}
