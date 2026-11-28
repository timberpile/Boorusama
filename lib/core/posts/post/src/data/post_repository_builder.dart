// Package imports:
import 'package:foundation/foundation.dart';

// Project imports:
import '../../../../http/client/types.dart';
import '../../../../search/queries/types.dart';
import '../../../../search/selected_tags/types.dart';
import '../../../../settings/types.dart';
import '../types/post.dart';
import '../types/post_repository.dart';

class PostRepositoryBuilder<T extends Post>
    implements PostRepository<T>, ForegroundPostConsumer<T> {
  PostRepositoryBuilder({
    required this.fetch,
    required this.fetchSingle,
    required this.getSettings,
    required this.tagComposer,
    this.fetchFromController,
    this.onConsumePreparedPosts,
  });

  final Future<void> Function(List<T>)? onConsumePreparedPosts;
  @override
  Future<void> consumePreparedPosts(List<T> posts) async {
    await onConsumePreparedPosts?.call(posts);
  }

  final PostFutureFetcher<T> fetch;
  final PostSingleFutureFetcher<T> fetchSingle;
  final PostFutureControllerFetcher<T>? fetchFromController;
  final Future<ImageListingSettings> Function() getSettings;
  @override
  final TagQueryComposer tagComposer;

  @override
  PostsOrError<T> getPosts(
    String tags,
    int page, {
    int? limit,
    PostFetchOptions? options,
  }) => TaskEither.Do(($) async {
    final lim = limit ?? (await getSettings()).postsPerPage;

    final newTags = tags.isEmpty ? <String>[] : tags.split(' ');

    final tags2 = tagComposer.compose(newTags);

    return $(
      tryFetchRemoteData(
        fetcher: () => _withPageSize(
          fetch(tags2, page, limit: lim, options: options),
          lim,
        ),
      ),
    );
  });

  @override
  PostsOrError<T> getPostsFromController(
    SearchTagSet controller,
    int page, {
    int? limit,
    PostFetchOptions? options,
  }) => fetchFromController != null
      ? TaskEither.Do(($) async {
          final lim = limit ?? (await getSettings()).postsPerPage;

          return $(
            tryFetchRemoteData(
              fetcher: () => _withPageSize(
                fetchFromController!(
                  controller,
                  page,
                  limit: lim,
                  options: options,
                ),
                lim,
              ),
            ),
          );
        })
      : TaskEither.Do(($) async {
          final lim = limit ?? (await getSettings()).postsPerPage;

          final tags = controller.rawTags;
          final composedTags = tagComposer.compose(tags);

          return $(
            tryFetchRemoteData(
              fetcher: () => _withPageSize(
                fetch(composedTags, page, limit: lim, options: options),
                lim,
              ),
            ),
          );
        });

  Future<PostResult<T>> _withPageSize(
    Future<PostResult<T>> fetch,
    int requested,
  ) async {
    final result = await fetch;
    return result.total == null || result.pageSize != null
        ? result
        : result.copyWith(pageSize: () => requested);
  }

  @override
  PostOrError<T> getPost(
    PostId id, {
    PostFetchOptions? options,
  }) => TaskEither.Do(($) {
    return $(
      tryFetchRemoteData(
        fetcher: () => fetchSingle(
          id,
          options: options,
        ),
      ),
    );
  });
}
