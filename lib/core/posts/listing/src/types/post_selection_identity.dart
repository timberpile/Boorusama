import '../../../../bookmarks/src/types/bookmark_identity.dart';
import '../../../post/types.dart';

/// Unknown identities are unique per row and survive only a proven append.
class PostSelectionIdentity {
  List<Post> _posts = const [];
  List<Object> _keys = const [];

  List<Object> resolve(List<Post> posts) {
    final append =
        posts.length >= _posts.length &&
        List.generate(
          _posts.length,
          (i) => identical(posts[i], _posts[i]),
        ).every((same) => same);
    final occurrences = <Object, int>{};
    final keys = <Object>[];
    for (var i = 0; i < posts.length; i++) {
      final identity = BookmarkIdentity.tryFromPost(posts[i]);
      final key =
          identity ?? (append && i < _keys.length ? _keys[i] : Object());
      final occurrence = occurrences.update(
        key,
        (n) => n + 1,
        ifAbsent: () => 0,
      );
      keys.add(identity == null ? key : (identity, occurrence));
    }
    _posts = List.of(posts);
    _keys = keys;
    return keys;
  }
}
