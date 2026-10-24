import 'package:boorusama/core/navigation/destination_id.dart';
import 'package:boorusama/core/navigation/destination_definition.dart';
import 'package:boorusama/core/navigation/navigation_catalog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  SiteToolDefinition tool(
    String id, {
    bool favorite = false,
    bool available = true,
  }) => SiteToolDefinition(
    toolId: id,
    label: (_) => id,
    icon: Icons.search,
    availability: available
        ? NavigationAvailability.available
        : NavigationAvailability.requiresAccount,
    isUnifiedFavorites: favorite,
  );
  ProfileNavigationCapabilities profile(
    String id,
    List<SiteToolDefinition> tools,
  ) => ProfileNavigationCapabilities(
    profileId: id,
    caption: 'Same name',
    profileIcon: 'https://example.invalid',
    tools: tools,
    favorites: NavigationAvailability.available,
  );
  NavigationCatalog catalog(List<ProfileNavigationCapabilities> profiles) =>
      buildNavigationCatalog(
        profilesInStoredOrder: profiles,
        globalDefinitions: [
          GlobalNavigationDefinition.sharedFavorites(
            label: (_) => 'Favorites',
            icon: Icons.favorite,
          ),
        ],
      );
  test('favorites-only profiles do not emit empty sections', () {
    final result = catalog([
      profile('gelbooru', [tool('gelbooru.favorites', favorite: true)]),
    ]);
    expect(result.profileSections, isEmpty);
    expect(result.eligibleFavoritesProfileIds, ['gelbooru']);
  });
  test('unavailable tools do not keep a heading alive', () {
    expect(
      catalog([
        profile('guest', [tool('account', available: false)]),
      ]).profileSections,
      isEmpty,
    );
  });
  test('same-site accounts keep distinct targets and stored order', () {
    final result = catalog([
      profile('b', [tool('danbooru.pools')]),
      profile('a', [tool('danbooru.pools')]),
    ]);
    expect(result.profileSections.map((e) => e.profileId), ['b', 'a']);
    expect(
      const DestinationId.tool('b', 'danbooru.pools'),
      isNot(const DestinationId.tool('a', 'danbooru.pools')),
    );
  });
  test(
    'shared favorites occurs once and disappears without eligible profiles',
    () {
      expect(
        catalog([profile('a', []), profile('b', [])]).globalEntries,
        hasLength(1),
      );
      expect(catalog([]).globalEntries, isEmpty);
    },
  );
  test('destination keys round trip opaque identities without collisions', () {
    for (final id in [
      const DestinationId.app(AppDestination.favoriteTags),
      const DestinationId.browse('a/b:"☃'),
      const DestinationId.favorites('a'),
      const DestinationId.tool('a:b', 'c:d'),
    ]) {
      expect(DestinationId.tryParse(id.toStorageKey()), id);
    }
    expect(
      const DestinationId.tool('a:b', 'c'),
      isNot(const DestinationId.tool('a', 'b:c')),
    );
    for (final invalid in [
      'null',
      '{}',
      '[2,"browse","a"]',
      '[1,"browse"]',
      '[1,"app","bogus"]',
      '[1,"browse",3]',
      '[1,"tool","a","x",0]',
    ]) {
      expect(DestinationId.tryParse(invalid), isNull, reason: invalid);
    }
  });
}
