import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../bookmarks/src/types/bookmark_tag_index.dart';
import '../../../../configs/config/types.dart';
import '../../../../configs/manage/providers.dart';
import '../../../../posts/post/types.dart';
import '../types/cached_topic_feed_filter.dart';

final cachedFeedTagIndexProvider = Provider.autoDispose
    .family<
      BookmarkTagIndex,
      (List<StoredPostSnapshot>, CachedTopicFeedFilter)
    >((
      ref,
      request,
    ) {
      final (snapshots, filter) = request;
      final configs = ref.watch(booruConfigProvider);
      return cachedTopicFeedTagIndex(
        filter.matchingSnapshots(snapshots),
        siteUrl: (snapshot) => switch (const PostOriginResolver().resolve(
          PostOrigin.fromSnapshot(snapshot.origin),
          configs,
        )) {
          ResolvedPostOrigin(:final config) => config.auth.url,
          _ => snapshot.origin.sourceHost,
        },
      );
    });
