import 'dart:async';

import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/configs/config/src/data/booru_config_converter.dart';
import 'package:boorusama/core/configs/manage/providers.dart';
import 'package:boorusama/core/navigation/navigation_catalog_provider.dart';
import 'package:boorusama/core/settings/src/providers/settings_notifier.dart';
import 'package:boorusama/core/settings/src/types/settings.dart';
import 'package:flutter_test/flutter_test.dart';

import 'booru_config_notifier_test.dart' as fixtures;

void main() {
  for (final failOrdering in [false, true]) {
    test(
      'a persisted duplicate is visible before ordering ${failOrdering ? 'fails' : 'finishes'}',
      () async {
        final settings = _GatedSettings();
        final repository = fixtures.InMemoryBooruConfigRepository();
        final original = (await repository.add(
          BooruConfig.empty.toBooruConfigData().copyWith(
            name: 'Original',
            url: 'https://example.com',
          ),
        ))!;
        final container = fixtures.createBooruConfigContainer(
          settingsRepository: settings,
          booruConfigRepository: repository,
        );
        final notifier = container.read(booruConfigProvider.notifier);
        await notifier.fetch();
        await container
            .read(settingsNotifierProvider.notifier)
            .updateWith(
              (value) => value.copyWith(booruConfigIdOrders: original.id),
            );
        settings.hold = true;
        final visible = container.listen(navigationProfilesProvider, (_, _) {});
        addTearDown(visible.close);
        final failures = <String>[];
        final pending = notifier.duplicate(
          config: original,
          onFailure: failures.add,
        );
        await settings.started.future;
        final persisted = await repository.getAll();
        final duplicate = persisted.singleWhere(
          (item) => item.id != original.id,
        );
        expect(
          container.read(navigationProfilesProvider).map((item) => item.id),
          [original.id, duplicate.id],
        );
        expect(duplicate.name, 'Original copy');
        expect(duplicate.url, original.url);
        expect(isCanonicalProfileId(duplicate.id), isTrue);
        if (failOrdering) {
          settings.release.completeError(StateError('Preference write failed'));
        } else {
          settings.release.complete(true);
        }
        await pending;
        expect(failures, failOrdering ? hasLength(1) : isEmpty);
        expect(container.read(booruConfigProvider), persisted);
        await notifier.fetch();
        expect(
          container.read(navigationProfilesProvider).map((item) => item.id),
          [original.id, duplicate.id],
        );
      },
    );
  }

  test(
    'a failed profile write reports failure without publishing a phantom',
    () async {
      final repository = _FailingProfiles();
      final container = fixtures.createBooruConfigContainer(
        settingsRepository: fixtures.InMemorySettingsRepository(),
        booruConfigRepository: repository,
      );
      final failures = <String>[];
      await container
          .read(booruConfigProvider.notifier)
          .duplicate(
            config: BooruConfig.empty,
            onFailure: failures.add,
          );
      expect(failures, hasLength(1));
      expect(container.read(booruConfigProvider), isEmpty);
      expect(await repository.getAll(), isEmpty);
    },
  );
}

class _GatedSettings extends fixtures.InMemorySettingsRepository {
  final started = Completer<void>();
  final release = Completer<bool>();
  var hold = false;

  @override
  Future<bool> save(Settings settings) async {
    if (hold) {
      started.complete();
      if (!await release.future) return false;
    }
    return super.save(settings);
  }
}

class _FailingProfiles extends fixtures.InMemoryBooruConfigRepository {
  @override
  Future<BooruConfig?> add(BooruConfigData data) async => null;
}
