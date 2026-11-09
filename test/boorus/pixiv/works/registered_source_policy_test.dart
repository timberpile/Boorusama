import 'package:booru_clients/pixiv.dart';
import 'package:boorusama/boorus/pixiv/client_provider.dart';
import 'package:boorusama/boorus/pixiv/works/work_source.dart';
import 'package:boorusama/boorus/registry.dart';
import 'package:boorusama/core/blacklists/src/data/providers.dart';
import 'package:boorusama/core/blacklists/providers.dart';
import 'package:boorusama/core/blacklists/types.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/boorus/engine/providers.dart';
import 'package:boorusama/core/configs/manage/providers.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/content/content_access_provider.dart';
import 'package:boorusama/core/content/groups/group_source_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'work_test_fixtures.dart';

void main() {
  test(
    'registered Pixiv source uses the real registry-backed blacklist',
    () async {
      final config = workAccess().config!;
      final components = createBooruRegistry();
      final db = BooruDb(
        boorus: {BooruType.pixiv: components.parseFromConfig('pixiv')},
      );
      final container = ProviderContainer(
        overrides: [
          booruConfigProvider.overrideWith(
            () => BooruConfigNotifier(initialConfigs: [config]),
          ),
          booruEngineRegistryProvider.overrideWith(
            (ref) => ref.watch(
              booruInitEngineProvider((db: db, registry: components)),
            ),
          ),
          globalBlacklistedTagRepoProvider.overrideWith(
            (ref) async => _Blacklist(),
          ),
          pixivClientProvider.overrideWith(
            (ref, auth) => PixivClient(accessToken: 'fixture'),
          ),
        ],
      );
      addTearDown(container.dispose);
      final hold = container.listen(
        contentProfileAccessProvider(config.id),
        (_, _) {},
      );
      addTearDown(hold.close);
      // Keep the production blacklist/notifier/registry chain intact. Replacing
      // blacklistTagsProvider hides the registration Ref's circular dependency.
      expect(
        await container.read(blacklistTagsProvider(config.filter).future),
        {'blocked'},
      );
      await container.pump();
      final access = container.read(contentProfileAccessProvider(config.id))!;
      final sourceHold = container.listen(
        contentGroupSourceProvider(access.key),
        (_, _) {},
      );
      addTearDown(sourceHold.close);
      final source = container.read(
        contentGroupSourceProvider(access.key),
      ) as PixivWorkSource;
      expect(source.blacklist, {'blocked'});
      expect(source.access, same(access));
    },
  );
}

class _Blacklist implements GlobalBlacklistedTagRepository {
  @override
  Future<List<BlacklistedTag>> getBlacklist() async => [
    BlacklistedTag(
      id: 1,
      name: 'blocked',
      isActive: true,
      createdDate: DateTime.utc(2026),
      updatedDate: DateTime.utc(2026),
    ),
  ];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
