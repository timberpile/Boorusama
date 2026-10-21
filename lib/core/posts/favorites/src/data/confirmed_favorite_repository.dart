import '../../../post/types.dart';
import '../types/favorite_interruption.dart';
import '../types/types.dart';

typedef FavoriteProjection = Future<void> Function();

/// Projects only acknowledged mutations. The local projection must not turn a
/// successful server action into a failure (which could cause a duplicate retry),
/// or prevent a server action when optional local preferences are unavailable.
class ConfirmedFavoriteRepository<T extends Post>
    extends FavoriteRepository<T> {
  ConfirmedFavoriteRepository({
    required this.delegate,
    required this.prepareProjection,
    required this.onProjectionError,
  });

  final FavoriteRepository<T> delegate;
  final Future<FavoriteProjection?> Function(int postId, bool favorited)
  prepareProjection;
  final void Function(Object error) onProjectionError;

  @override
  bool canFavorite() => delegate.canFavorite();

  @override
  bool isPostFavorited(T post) => delegate.isPostFavorited(post);

  @override
  Future<List<int>> filterFavoritedPosts(List<int> postIds) =>
      delegate.filterFavoritedPosts(postIds);

  Future<_PreparedProjection> _prepare(int postId, bool favorited) async {
    try {
      return _PreparedProjection(await prepareProjection(postId, favorited));
    } catch (error) {
      return _PreparedProjection(null, error);
    }
  }

  Future<void> _apply(_PreparedProjection prepared) async {
    try {
      if (prepared.error case final error?) throw error;
      await prepared.apply?.call();
    } catch (error) {
      // Feedback is a separate channel. Even a disposed UI/provider must not
      // hide the already acknowledged result of the server request.
      try {
        onProjectionError(error);
      } catch (_) {}
    }
  }

  @override
  Future<AddFavoriteStatus> addToFavorites(int postId) async {
    final prepared = await _prepare(postId, true);
    final AddFavoriteStatus result;
    try {
      result = await delegate.addToFavorites(postId);
    } on FavoriteCompletedWithInterruption {
      await _apply(prepared);
      rethrow;
    }
    if (result == AddFavoriteStatus.success ||
        result == AddFavoriteStatus.alreadyExists) {
      await _apply(prepared);
    }
    return result;
  }

  @override
  Future<bool> removeFromFavorites(int postId) async {
    final prepared = await _prepare(postId, false);
    final bool result;
    try {
      result = await delegate.removeFromFavorites(postId);
    } on FavoriteCompletedWithInterruption {
      await _apply(prepared);
      rethrow;
    }
    if (result) await _apply(prepared);
    return result;
  }
}

class _PreparedProjection {
  const _PreparedProjection(this.apply, [this.error]);

  final FavoriteProjection? apply;
  final Object? error;
}
