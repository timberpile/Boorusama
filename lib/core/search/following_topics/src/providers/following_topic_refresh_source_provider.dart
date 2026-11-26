import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../boorus/engine/providers.dart';
import '../../../../configs/config/types.dart';
import '../refresh/gallery_topic_refresh_source.dart';
import '../refresh/search_refresh_query_adapter.dart';

final followingTopicGalleryRefreshSourceProvider =
    Provider.family<GalleryTopicRefreshSource?, BooruConfigAuth>(
      (ref, auth) =>
          ref.watch(booruRepoProvider(auth))?.galleryTopicRefreshSource(auth),
    );

final followingTopicQueryTrackingSupportedProvider =
    Provider.family<bool Function(String), BooruConfigAuth>((ref, auth) {
      if (ref.watch(followingTopicGalleryRefreshSourceProvider(auth)) != null) {
        return (query) => query.trim().isNotEmpty;
      }
      final adapter = ref
          .watch(booruRepoProvider(auth))
          ?.searchRefreshQueryAdapter(auth);
      return (query) => supportsSearchRefreshQuery(adapter, query);
    });
