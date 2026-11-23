import 'package:boorusama/boorus/navigation_capabilities.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/navigation/destination_definition.dart';
import 'package:boorusama/core/navigation/navigation_catalog.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';

void main() {
  ProfileNavigationCapabilities capabilities(
    BooruType type, {
    bool login = false,
    bool? canFavorite,
    int? userId,
  }) {
    final config = BooruConfig.defaultConfig(
      booruType: type,
      url: 'https://example.invalid',
      customDownloadFileNameFormat: null,
    );
    return describeEngineNavigation(
      config: config,
      loginDetails: DefaultBooruLoginDetails(
        login: login ? 'fixture' : null,
        apiKey: login ? 'fixture' : null,
        url: config.url,
      ),
      hasFavoritesBuilder: true,
      knownUserId: userId,
      knownShimmieFavorites: canFavorite,
    );
  }

  testWidgets(
    'Pixiv navigation uses Following independently of its page title',
    (tester) async {
      final following = capabilities(BooruType.pixiv).tools
          .singleWhere((tool) => tool.toolId == 'pixiv.following-artists');
      await tester.pumpWidget(
        BooruLocalization(
          child: MaterialApp(
            home: Builder(
              builder: (context) => Text(following.label(context)),
            ),
          ),
        ),
      );
      expect(find.text('Following'), findsOneWidget);
      expect(find.text('Following Artists'), findsNothing);
      expect(find.text('Pixiv Following'), findsNothing);
    },
  );

  test('all engines with secondary menus have an explicit inventory', () {
    final expected = {
      BooruType.danbooru: [
        'danbooru.explore',
        'danbooru.pools',
        'danbooru.forum',
        'danbooru.artists',
        'danbooru.profile',
        'danbooru.favorite-groups',
        'danbooru.saved-searches',
        'danbooru.blacklist',
      ],
      BooruType.moebooru: ['moebooru.popular', 'moebooru.hot'],
      BooruType.e621: ['e621.popular'],
      BooruType.animePictures: ['anime-pictures.top'],
      BooruType.eshuushuu: ['eshuushuu.profile'],
      BooruType.shimmie2: ['shimmie2.extensions'],
      BooruType.szurubooru: ['szurubooru.pools'],
      BooruType.pixiv: ['pixiv.explore', 'pixiv.following-artists'],
    };
    for (final entry in expected.entries) {
      expect(
        capabilities(entry.key).tools.map((e) => e.toolId),
        entry.value,
        reason: entry.key.name,
      );
    }
    for (final type in [
      BooruType.gelbooru,
      BooruType.gelbooruV1,
      BooruType.gelbooruV2,
      BooruType.hydrus,
      BooruType.sankaku,
      BooruType.zerochan,
      BooruType.philomena,
      BooruType.hybooru,
      BooruType.nozomi,
    ]) {
      expect(capabilities(type).tools, isEmpty, reason: type.name);
    }
  });
  test('Danbooru guest retains public tools and omits all account tools', () {
    final result = buildNavigationCatalog(
      profilesInStoredOrder: [capabilities(BooruType.danbooru)],
      globalDefinitions: [],
    );
    expect(result.profileSections.single.rows.map((e) => e.toolId), [
      'danbooru.explore',
      'danbooru.pools',
      'danbooru.forum',
      'danbooru.artists',
    ]);
    expect(result.eligibleFavoritesProfileIds, isEmpty);
  });
  test(
    'account metadata is supplied without eagerly discovering other users',
    () {
      final unknown = capabilities(BooruType.danbooru, login: true);
      expect(
        unknown.tools
            .singleWhere((e) => e.toolId == 'danbooru.profile')
            .availability,
        NavigationAvailability.waitingForAccountMetadata,
      );
      expect(
        capabilities(
          BooruType.danbooru,
          login: true,
          userId: 7,
        ).tools.singleWhere((e) => e.toolId == 'danbooru.profile').availability,
        NavigationAvailability.available,
      );
      expect(
        capabilities(BooruType.shimmie2, login: true).favorites,
        NavigationAvailability.waitingForAccountMetadata,
      );
      expect(
        capabilities(
          BooruType.shimmie2,
          login: true,
          canFavorite: true,
        ).favorites,
        NavigationAvailability.available,
      );
      expect(
        capabilities(BooruType.shimmie2, canFavorite: true).favorites,
        NavigationAvailability.requiresAccount,
      );
    },
  );
  test('Pixiv guest keeps Explore but does not expose account following', () {
    final result = buildNavigationCatalog(
      profilesInStoredOrder: [capabilities(BooruType.pixiv)],
      globalDefinitions: [],
    );
    expect(result.profileSections.single.rows.map((row) => row.toolId), [
      'pixiv.explore',
    ]);
    expect(result.eligibleFavoritesProfileIds, isEmpty);
  });
  test('Favorites-only Gelbooru never emits a profile heading', () {
    final result = buildNavigationCatalog(
      profilesInStoredOrder: [capabilities(BooruType.gelbooru, login: true)],
      globalDefinitions: [],
    );
    expect(result.profileSections, isEmpty);
    expect(result.eligibleFavoritesProfileIds, hasLength(1));
  });
}
