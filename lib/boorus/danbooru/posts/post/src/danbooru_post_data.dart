// Package imports:
import 'package:equatable/equatable.dart';

// Project imports:
import '../../../../../core/posts/post/types.dart';
import 'danbooru_post.dart';

final class DanbooruPostData extends Equatable implements BooruPostData {
  const DanbooruPostData({
    required this.lastCommentAt,
    required this.upScore,
    required this.downScore,
    required this.favCount,
    required this.approverId,
    required this.generalTags,
    required this.metaTags,
    required this.hasChildren,
    required this.hasLarge,
    required this.pixelHash,
  });

  factory DanbooruPostData.fromPost(DanbooruPost post) => DanbooruPostData(
    lastCommentAt: post.lastCommentAt,
    upScore: post.upScore,
    downScore: post.downScore,
    favCount: post.favCount,
    approverId: post.approverId,
    generalTags: post.generalTags,
    metaTags: post.metaTags,
    hasChildren: post.hasChildren,
    hasLarge: post.hasLarge,
    pixelHash: post.pixelHash,
  );

  final DateTime? lastCommentAt;
  final int upScore;
  final int downScore;
  final int favCount;
  final int? approverId;
  final Set<String> generalTags;
  final Set<String> metaTags;
  final bool hasChildren;
  final bool hasLarge;
  final String pixelHash;

  @override
  String get typeKey => 'danbooru';

  @override
  int get schemaVersion => 1;

  @override
  List<Object?> get props => [
    lastCommentAt,
    upScore,
    downScore,
    favCount,
    approverId,
    generalTags,
    metaTags,
    hasChildren,
    hasLarge,
    pixelHash,
  ];
}
