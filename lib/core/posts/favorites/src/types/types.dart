// Project imports:
import '../../../post/types.dart';

enum AddFavoriteStatus {
  success,
  failure,
  alreadyExists;

  bool get confirmed => this == success || this == alreadyExists;
}

enum FavoriteActionFailure implements Exception {
  unconfirmed,
  websiteLoginRequired,
  websiteSessionRejected,
}

abstract class FavoriteRepository<T extends Post> {
  bool get needsWebsiteLogin => false;
  bool canFavorite();
  Future<AddFavoriteStatus> addToFavorites(int postId);
  Future<bool> removeFromFavorites(int postId);
  bool isPostFavorited(T post);
  Future<List<int>> filterFavoritedPosts(List<int> postIds) async {
    return [];
  }
}
