// Package imports:
import 'package:hive_ce/hive.dart';

// Project imports:
import '../blacklists/src/data/hive/tag_hive_object.dart';
import '../bookmarks/src/data/hive/bookmark_hive_object.dart';
import '../bookmarks/src/data/hive/bookmark_group_hive_object.dart';
import '../search/subscriptions/src/data/hive/recent_search_post_hive_object.dart';
import '../search/subscriptions/src/data/hive/search_post_preview_hive_object.dart';
import '../tags/favorites/src/data/favorite_tag_hive_object.dart';

export 'search_subscription_hive_adapter.dart';

@GenerateAdapters([
  AdapterSpec<FavoriteTagHiveObject>(),
  AdapterSpec<BlacklistedTagHiveObject>(),
  AdapterSpec<BookmarkHiveObject>(),
  AdapterSpec<BookmarkGroupHiveObject>(),
  AdapterSpec<SearchPostPreviewHiveObject>(),
  AdapterSpec<RecentSearchPostHiveObject>(),
])
part 'hive_adapters.g.dart';
