import 'package:go_router/go_router.dart';
import 'package:boorusama/core/home/types.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/configs/manage/providers.dart';
import 'package:boorusama/core/navigation/app_navigation.dart';
import 'package:boorusama/core/navigation/destination_id.dart';
import 'package:boorusama/core/navigation/navigation_catalog.dart';
import 'package:boorusama/core/navigation/navigation_catalog_provider.dart';
import 'package:boorusama/core/navigation/navigation_controller.dart';
import 'package:boorusama/core/navigation/navigation_preferences.dart';
import 'package:boorusama/core/navigation/production_navigation_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _config = BooruConfig.fromJson({
  ...BooruConfig.defaultConfig(
    booruType: BooruType.gelbooru,
    url: 'https://gelbooru.com',
    customDownloadFileNameFormat: null,
  ).toJson(),
  'id': '00000000-0000-4000-8000-000000000001',
});

class _Controller extends NavigationController {
  @override
  NavigationPreferences build() =>
      NavigationPreferences(lastBrowseProfileId: _config.id);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('all real page factories register in one router with unique names', () {
    final provider = Provider(
      (ref) => createProductionNavigationRouter(ref, AppNavigation()),
    );
    final container = ProviderContainer(
      overrides: [
        customHomeViewKeyProvider.overrideWithValue(null),
        navigationControllerProvider.overrideWith(_Controller.new),
        navigationProfilesProvider.overrideWithValue([_config]),
        booruConfigProvider.overrideWith(
          () => BooruConfigNotifier(initialConfigs: [_config]),
        ),
        navigationCatalogProvider.overrideWithValue(
          NavigationCatalog(
            profileSections: [],
            globalEntries: [],
            eligibleFavoritesProfileIds: [_config.id],
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    final router = container.read(provider);
    expect(router.namedLocation('/search'), '/search');
    for (final link in [
      'boorusama://post/open?v=1&engine=danbooru&site=https%3A%2F%2Fsite.test&key=id%3A42',
      'boorusama://search/open?v=1&engine=danbooru&site=https%3A%2F%2Fsite.test&mode=raw&q=cat',
    ]) {
      final match = router.configuration.findMatch(Uri.parse(link));
      expect(match.isError, isFalse);
      final route = match.matches.last.route as GoRoute;
      expect(route.redirect, isNull);
      expect(route.builder, isNotNull);
    }
    expect(router.namedLocation('/bookmarks/group'), '/bookmarks/group');
    final browse = DestinationId.browse(_config.id);
    expect(
      router.namedLocation('${browse.toStorageKey()}:/search'),
      '${browse.location}/search',
    );
    expect(
      router.configuration
          .findMatch(Uri.parse('${browse.location}/bookmarks/group'))
          .isError,
      isFalse,
    );
    expect(
      router.configuration
          .findMatch(
            Uri.parse('${DestinationId.favorites(_config.id).location}/search'),
          )
          .isError,
      isFalse,
    );
  });
}
