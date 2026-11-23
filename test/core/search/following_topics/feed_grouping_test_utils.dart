import 'dart:async';

import 'package:boorusama/boorus/danbooru/posts/post/src/danbooru_post_data.dart';
import 'package:boorusama/core/bookmarks/src/types/pool_bookmark.dart';
import 'package:boorusama/core/bookmarks/src/types/pool_bookmark_capability.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/posts/rating/types.dart';
import 'package:boorusama/core/posts/sources/types.dart';
import 'package:boorusama/core/search/following_topics/src/types/feed_series_membership.dart';
import 'package:boorusama/core/search/following_topics/types.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'following_topic_test_utils.dart';

final feedGroupingConfig = BooruConfig.fromJson({
  ...testProfile.toJson(),
  'url': 'https://danbooru.donmai.us',
  'booruId': BooruType.danbooru.id,
  'booruIdHint': BooruType.danbooru.id,
});
final otherGroupingConfig = BooruConfig.fromJson({
  ...feedGroupingConfig.toJson(),
  'id': otherTestProfile.id,
  'login': 'other',
});

Post feedGroupingPost(
  int id, {
  int? parent,
  BooruConfig? config,
  Set<String> tags = const {'cat'},
}) {
  final owner = config ?? feedGroupingConfig;
  return Post(
    origin: PostOrigin.fromSource(
      booruType: owner.auth.booruType,
      booruId: owner.booruId,
      source: owner.url,
      profileIdHint: owner.id,
    ),
    core: PostCoreData(
      id: id,
      createdAt: checkedAt.add(Duration(seconds: id)),
      thumbnailImageUrl: 'https://example.com/$id-thumb.jpg',
      sampleImageUrl: 'https://example.com/$id.jpg',
      originalImageUrl: 'https://example.com/$id.jpg',
      videoUrl: '',
      videoThumbnailUrl: '',
      width: 100,
      height: 160,
      format: 'jpg',
      md5: '$id',
      fileSize: 1,
      duration: 0,
      tags: tags,
      rating: Rating.general,
      hasComment: false,
      isTranslated: false,
      hasParentOrChildren: parent != null,
      parentId: parent,
      source: PostSource.none(),
      score: id,
    ),
    booruData: const DanbooruPostData(
      lastCommentAt: null,
      upScore: 0,
      downScore: 0,
      favCount: 0,
      approverId: null,
      generalTags: {},
      metaTags: {},
      hasChildren: false,
      hasLarge: false,
      pixelHash: '',
    ),
  );
}

FeedSeriesMembership feedMembership(
  FollowingTopic source,
  Post post,
  List<int> series,
) => FeedSeriesMembership(
  origin: post.origin,
  postId: post.id,
  sourceId: source.id,
  sourceRevision: source.runtimeRevision,
  series: [
    for (final id in series)
      FeedSeriesSummary(id: id, title: 'Series $id', total: 20),
  ],
);

class FeedSeriesCapability implements PoolBookmarkCapability {
  FutureOr<Map<int, List<RemoteBookmarkPool>>> Function(List<Post>)? respond;
  final calls = <(String, List<int>)>[];
  @override
  Future<Map<int, List<RemoteBookmarkPool>>> getBookmarkSeries(
    BooruConfig config,
    List<Post> posts,
  ) async {
    calls.add((config.id, posts.map((post) => post.id).toList()));
    return respond?.call(posts) ?? {for (final post in posts) post.id: []};
  }

  @override
  Future<RemoteBookmarkPool?> getBookmarkPool(
    BooruConfig config,
    int id,
  ) async => null;
  @override
  Future<void> openBookmarkPool(
    WidgetRef ref,
    BooruConfig config,
    int id,
  ) async {}
}

RemoteBookmarkPool feedPool(int id) => RemoteBookmarkPool(
  id: id,
  title: 'Series $id',
  category: BookmarkedPoolCategory.series,
  total: 20,
);
