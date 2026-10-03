// Package imports:
import 'package:equatable/equatable.dart';

// Project imports:
import '../../../posts/post/types.dart';

sealed class BookmarkUniqueId extends Equatable {
  const BookmarkUniqueId();

  factory BookmarkUniqueId.fromPost(Post post, [int? _]) =>
      switch (post.booruData) {
        LegacyPostData() || UnknownPostData() => LegacyBookmarkIdentity(
          booruId: post.origin.booruType.id,
          url: post.originalImageUrl,
        ),
        _ => BookmarkIdentity.fromPost(post),
      };
}

final class BookmarkIdentity extends BookmarkUniqueId {
  BookmarkIdentity({
    required this.booruType,
    required String site,
    required this.postId,
  }) : site = normalizePostSourceHost(site);

  factory BookmarkIdentity.fromPost(Post post) =>
      BookmarkIdentity(
        booruType: post.origin.booruType.name,
        site: post.origin.sourceHost,
        postId: post.id,
      );

  factory BookmarkIdentity.fromJson(Map<String, dynamic> json) {
    final booruType = json['booruType'];
    final site = json['site'];
    final postId = json['postId'];
    if (booruType is! String ||
        booruType.isEmpty ||
        site is! String ||
        site.isEmpty ||
        postId is! int) {
      throw const FormatException('Invalid bookmark identity');
    }
    return BookmarkIdentity(
      booruType: booruType,
      site: site,
      postId: postId,
    );
  }

  final String booruType;
  final String site;
  final int postId;

  Map<String, Object> toJson() => {
    'booruType': booruType,
    'site': site,
    'postId': postId,
  };

  @override
  List<Object> get props => [booruType, site, postId];
}

final class LegacyBookmarkIdentity extends BookmarkUniqueId {
  const LegacyBookmarkIdentity({required this.booruId, required this.url});

  final int booruId;
  final String url;

  @override
  List<Object> get props => [booruId, url];
}
