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
  const LoadedSearchSnapshot(this.posts);

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
  ChronologicalSearchScanner({this.pageSize = 50})
    : assert(pageSize > 0, 'pageSize must be positive');

  final int pageSize;

  Future<SearchScanResult> scanSnapshot({
    required SearchRefreshPageFetcher fetchPage,
  }) async {
    final result = await fetchPage(1, pageSize);
    return result.fold(
      FailedSearchScan.new,
      (page) {
        final posts = <Post>[];
        final seenIds = <int>{};
        DateTime? previousCreatedAt;
        for (final post in page.posts.take(pageSize)) {
          switch (post.createdAt) {
            case null:
              return const FailedSearchScan(SearchRefreshErrorKind.unsupported);
            case final DateTime createdAt:
              final uploadedAt = createdAt.toUtc();
              if (previousCreatedAt != null &&
                  uploadedAt.isAfter(previousCreatedAt)) {
                return const FailedSearchScan(
                  SearchRefreshErrorKind.unsupported,
                );
              }
              previousCreatedAt = uploadedAt;
              if (seenIds.add(post.id)) posts.add(post);
          }
        }
        return LoadedSearchSnapshot(List.unmodifiable(posts));
      },
    );
  }
}
