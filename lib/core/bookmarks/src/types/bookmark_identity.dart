// Package imports:
import 'package:equatable/equatable.dart';

// Project imports:
import '../../../boorus/booru/types.dart';
import '../../../posts/post/types.dart';

sealed class BookmarkUniqueId extends Equatable {
  const BookmarkUniqueId();

  factory BookmarkUniqueId.fromPost(Post post, [int? _]) =>
      BookmarkIdentity.tryFromPost(post) ?? const UnbookmarkablePostIdentity();
}

final class BookmarkIdentity extends BookmarkUniqueId {
  BookmarkIdentity({
    required String site,
    required this.postKey,
  }) : site = normalizePostSourceHost(site) {
    if (this.site.isEmpty || postKey.isEmpty) {
      throw const FormatException('Invalid bookmark identity');
    }
  }

  factory BookmarkIdentity.fromPost(Post post) =>
      BookmarkIdentity.tryFromPost(post) ??
      (throw const FormatException('Post has no stable bookmark identity'));

  static BookmarkIdentity? tryFromPost(Post post) {
    final site = post.origin.sourceHost;
    final key = switch ((post.origin.booruType, post.booruData)) {
      (_, final StableBookmarkPostKeyData data) => data.stableBookmarkPostKey,
      (BooruType.sankaku || BooruType.pixiv, _) => null,
      (_, _) when post.id > 0 => 'id:${post.id}',
      _ => null,
    };
    if (site.isEmpty || key == null || key.isEmpty) return null;
    return BookmarkIdentity(site: site, postKey: key);
  }

  factory BookmarkIdentity.fromJson(Map<String, dynamic> json) {
    final site = json['site'];
    final postKey = json['postKey'];
    if (site is! String ||
        site.isEmpty ||
        postKey is! String ||
        postKey.isEmpty) {
      throw const FormatException('Invalid bookmark identity');
    }
    return BookmarkIdentity(site: site, postKey: postKey);
  }

  final String site;
  final String postKey;

  Map<String, Object> toJson() => {
    'site': site,
    'postKey': postKey,
  };

  @override
  List<Object> get props => [site, postKey];
}

final class UnbookmarkablePostIdentity extends BookmarkUniqueId {
  const UnbookmarkablePostIdentity();

  @override
  List<Object> get props => const [];
}
