import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/configs/config/providers.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/configs/manage/providers.dart';
import 'package:boorusama/core/navigation/navigation_catalog_provider.dart';
import 'package:boorusama/core/settings/providers.dart';
import 'package:boorusama/core/settings/types.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final profiles = [
    for (var i = 1; i <= 3; i++)
      BooruConfig.fromJson({
        ...BooruConfig.defaultConfig(
          booruType: BooruType.danbooru,
          url: 'https://danbooru.donmai.us',
          customDownloadFileNameFormat: null,
        ).toJson(),
        'id': '00000000-0000-4000-8000-00000000000$i',
      }),
  ];
  test(
    'all presentation orders retain known IDs then append missing profiles',
    () async {
      final ids = profiles.map((p) => p.id).toList();
      final settings = Settings.fromJson(
        Settings.defaultSettings
            .copyWith(
              booruConfigIdOrders: '${ids[2]} stale ${ids[0]} ${ids[2]}',
              currentBooruConfigId: ids[1],
            )
            .toJson(),
      );
      for (var restart = 0; restart < 2; restart++) {
        final container = ProviderContainer(
          overrides: [
            booruConfigProvider.overrideWith(
              () => BooruConfigNotifier(initialConfigs: profiles),
            ),
            settingsProvider.overrideWithValue(settings),
          ],
        );
        addTearDown(container.dispose);
        final expected = [profiles[2], profiles[0], profiles[1]];
        expect(container.read(orderedProfileConfigsProvider), expected);
        expect(container.read(navigationProfilesProvider), expected);
        expect(await container.read(orderedConfigsProvider.future), expected);
        expect(container.read(settingsProvider).currentBooruConfigId, ids[1]);
        expect(container.read(booruConfigProvider), profiles);
      }
    },
  );
}
