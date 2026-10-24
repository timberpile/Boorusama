import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';

import '../core/configs/config/types.dart';
import 'anime-pictures/tops/widgets.dart';
import 'danbooru/artists/search/widgets.dart';
import 'danbooru/blacklist/widgets.dart';
import 'danbooru/favgroups/listing/widgets.dart';
import 'danbooru/forums/topics/widgets.dart';
import 'danbooru/pools/listing/widgets.dart';
import 'danbooru/posts/explores/widgets.dart';
import 'danbooru/saved_searches/feed/widgets.dart';
import 'danbooru/users/details/widgets.dart';
import 'e621/popular/widgets.dart';
import 'eshuushuu/configs/extra_data.dart';
import 'eshuushuu/users/widgets.dart';
import 'moebooru/popular/widgets.dart';
import 'pixiv/explore/widgets.dart';
import 'shimmie2/extensions/page.dart';
import 'szurubooru/pools/widgets.dart';

/// This optional fork registry leaves the upstream BooruBuilder API intact.
Widget buildEngineNavigationPage(
  BuildContext context,
  BooruConfig config,
  String toolId,
) => switch (toolId) {
  'danbooru.explore' => const DanbooruExplorePage(),
  'danbooru.pools' => const DanbooruPoolPage(),
  'danbooru.forum' => const DanbooruForumPage(),
  'danbooru.artists' => const DanbooruArtistSearchPage(),
  'danbooru.profile' => const DanbooruProfilePage(),
  'danbooru.favorite-groups' => const FavoriteGroupsPage(),
  'danbooru.saved-searches' => const SavedSearchFeedPage(),
  'danbooru.blacklist' => const DanbooruBlacklistedTagsPage(),
  'moebooru.popular' => _toolHost(
    context.t.explore.popular,
    const MoebooruPopularPage(),
  ),
  'moebooru.hot' => _toolHost(
    context.t.explore.hot,
    const MoebooruPopularRecentPage(),
  ),
  'e621.popular' => _toolHost(
    context.t.explore.popular,
    const E621PopularPage(),
  ),
  'anime-pictures.top' => _toolHost(
    context.t.explore.top,
    const AnimePicturesTopPage(),
  ),
  'eshuushuu.profile' => switch (EshuushuuExtraData.fromPassHash(
    config.passHash,
  ).userId) {
    final id? => EshuushuuUserDetailsPage(userId: id, username: config.login),
    _ => _toolHost(
      context.t.navigation.profiles,
      Text(context.t.navigation.unavailable_profile),
    ),
  },
  'pixiv.explore' => const PixivExplorePage(),
  'shimmie2.extensions' => const Shimmie2ExtensionsPage(),
  'szurubooru.pools' => const SzurubooruPoolPage(),
  _ => _toolHost(
    context.t.navigation.menu,
    Text(context.t.navigation.unavailable_profile),
  ),
};

Widget _toolHost(String title, Widget child) => Scaffold(
  appBar: KurumiAppBar(title: Text(title)),
  body: child,
);
