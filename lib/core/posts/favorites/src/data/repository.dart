// Project imports:
import '../../../post/types.dart';
import '../types/types.dart';

class EmptyFavoriteRepository extends FavoriteRepository<Post> {
  @override
  bool canFavorite() => false;

  @override
  Future<AddFavoriteStatus> addToFavorites(int postId) async =>
      AddFavoriteStatus.failure;

  @override
  Future<bool> removeFromFavorites(int postId) async => false;
}

class FavoriteRepositoryBuilder<T extends Post> extends FavoriteRepository<T> {
  FavoriteRepositoryBuilder({
    required this.add,
    required this.remove,
    this.isFavorited,
    required bool Function() canFavorite,
    this.needsWebsiteLogin = false,
    this.filter,
  }) : _canFavorite = canFavorite;

  final Future<AddFavoriteStatus> Function(int postId) add;
  final Future<bool> Function(int postId) remove;
  final bool? Function(T post)? isFavorited;
  final bool Function() _canFavorite;
  final Future<List<int>?> Function(List<int> postIds)? filter;

  @override
  final bool needsWebsiteLogin;

  @override
  bool canFavorite() => _canFavorite();

  @override
  Future<AddFavoriteStatus> addToFavorites(int postId) {
    return add(postId);
  }

  @override
  Future<bool> removeFromFavorites(int postId) {
    return remove(postId);
  }

  @override
  bool? isPostFavorited(T post) => isFavorited?.call(post);

  @override
  bool get supportsFavoriteLookup => filter != null;

  @override
  Future<List<int>?> filterFavoritedPosts(List<int> postIds) async =>
      filter?.call(postIds);
}
