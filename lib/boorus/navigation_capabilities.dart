import 'package:flutter/widgets.dart';
import 'package:i18n/i18n.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../core/boorus/booru/types.dart';
import '../core/configs/config/types.dart';
import '../core/navigation/destination_definition.dart';
import 'eshuushuu/configs/extra_data.dart';

/// Fork-local capability projection. The caller supplies the engine's existing
/// local login rules and already resolved metadata. No provider is watched and
/// no widget, client or repository is constructed while building the catalog.
ProfileNavigationCapabilities describeEngineNavigation({
  required BooruConfig config,
  required BooruLoginDetails loginDetails,
  required bool hasFavoritesBuilder,
  int? knownUserId,
  bool? knownShimmieFavorites,
}) {
  const available = NavigationAvailability.available;
  const requiresAccount = NavigationAvailability.requiresAccount;
  const waiting = NavigationAvailability.waitingForAccountMetadata;
  const unsupported = NavigationAvailability.unsupported;
  final login = loginDetails.hasLogin();
  final account = login ? available : requiresAccount;
  final profile = !login
      ? requiresAccount
      : knownUserId == null
      ? waiting
      : available;
  final eshuushuuAccount =
      login && EshuushuuExtraData.fromPassHash(config.passHash).userId != null
      ? available
      : requiresAccount;
  SiteToolDefinition tool(
    String id,
    LocalizedLabel label,
    IconData icon, [
    NavigationAvailability availability = available,
  ]) => SiteToolDefinition(
    toolId: id,
    label: label,
    icon: icon,
    availability: availability,
  );
  final tools = switch (config.auth.booruType) {
    BooruType.danbooru => [
      tool('danbooru.explore', (c) => c.t.explore.explore, Symbols.explore),
      tool('danbooru.pools', (c) => c.t.pool.pools, Symbols.photo_album),
      tool('danbooru.forum', (c) => c.t.forum.forum, Symbols.forum),
      tool('danbooru.artists', (c) => c.t.artists.title, Symbols.search),
      tool(
        'danbooru.profile',
        (c) => c.t.profile.profile,
        Symbols.account_box,
        profile,
      ),
      tool(
        'danbooru.favorite-groups',
        (c) => c.t.favorite_groups.favorite_groups,
        Symbols.collections,
        account,
      ),
      tool(
        'danbooru.saved-searches',
        (c) => c.t.saved_search.saved_search,
        Symbols.saved_search,
        account,
      ),
      tool(
        'danbooru.blacklist',
        (c) => c.t.blacklisted_tags.blacklisted_tags,
        Symbols.tag,
        account,
      ),
    ],
    BooruType.moebooru => [
      tool('moebooru.popular', (c) => c.t.explore.popular, Symbols.explore),
      tool(
        'moebooru.hot',
        (c) => c.t.explore.hot,
        Symbols.local_fire_department,
      ),
    ],
    BooruType.e621 => [
      tool('e621.popular', (c) => c.t.explore.popular, Symbols.explore),
    ],
    BooruType.animePictures => [
      tool('anime-pictures.top', (c) => c.t.explore.top, Symbols.explore),
    ],
    BooruType.eshuushuu => [
      tool(
        'eshuushuu.profile',
        (c) => c.t.profile.profile,
        Symbols.account_box,
        eshuushuuAccount,
      ),
    ],
    BooruType.shimmie2 => [
      tool(
        'shimmie2.extensions',
        (c) => c.t.shimmie2.extension.title,
        Symbols.extension,
      ),
    ],
    BooruType.szurubooru => [
      tool('szurubooru.pools', (c) => c.t.pool.pools, Symbols.photo_library),
    ],
    BooruType.pixiv => [
      tool(
        'pixiv.explore',
        (c) => c.t.pixiv.explore.title,
        Symbols.leaderboard,
      ),
    ],
    _ => <SiteToolDefinition>[],
  };
  final favorites = !hasFavoritesBuilder
      ? unsupported
      : switch (config.auth.booruType) {
          BooruType.danbooru ||
          BooruType.gelbooru ||
          BooruType.gelbooruV2 ||
          BooruType.moebooru ||
          BooruType.e621 ||
          BooruType.szurubooru => account,
          BooruType.hydrus => available,
          BooruType.sankaku =>
            config.login != null ? available : requiresAccount,
          BooruType.animePictures =>
            config.passHash != null ? available : requiresAccount,
          BooruType.eshuushuu => eshuushuuAccount,
          BooruType.shimmie2 =>
            !login
                ? requiresAccount
                : switch (knownShimmieFavorites) {
                    true => available,
                    false => unsupported,
                    null => waiting,
                  },
          _ => unsupported,
        };
  return ProfileNavigationCapabilities(
    profileId: config.id,
    caption: config.name,
    profileIcon: config.url,
    tools: tools,
    favorites: favorites,
  );
}
