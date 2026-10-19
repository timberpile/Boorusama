import 'package:boorusama/core/configs/manage/providers.dart';
// Flutter imports:
import 'package:material_ui/material_ui.dart';

// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// Project imports:
import 'package:boorusama/boorus/moebooru/favorites/providers.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/configs/config/providers.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/configs/manage/widgets.dart';

void main() {
  testWidgets('isolates equal post IDs between Moebooru profiles', (
    tester,
  ) async {
    final notifiers = <String, Object>{};

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          booruConfigProvider.overrideWith(
            () => BooruConfigNotifier(initialConfigs: _configs),
          ),
        ],
        child: MaterialApp(
          home: Column(
            children: [
              for (final config in _configs)
                CurrentBooruConfigScope(
                  config: config,
                  child: Consumer(
                    builder: (context, ref, _) {
                      notifiers[ref.watchConfigAuth.url] = ref.watch(
                        moebooruFavoritesProvider(1).notifier,
                      );
                      return const SizedBox();
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(notifiers.keys, {_configs.first.url, _configs.last.url});
    expect(
      notifiers[_configs.first.url],
      isNot(same(notifiers[_configs.last.url])),
    );
  });
}

final _configs = [
  BooruConfig.fromJson({
    ...BooruConfig.defaultConfig(
      booruType: BooruType.moebooru,
      url: 'https://first.example',
      customDownloadFileNameFormat: null,
    ).toJson(),
    'id': '00000000-0000-4000-8000-000000000001',
  }),
  BooruConfig.fromJson({
    ...BooruConfig.defaultConfig(
      booruType: BooruType.moebooru,
      url: 'https://second.example',
      customDownloadFileNameFormat: null,
    ).toJson(),
    'id': '00000000-0000-4000-8000-000000000002',
  }),
];
