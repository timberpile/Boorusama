import 'dart:io';

import 'package:boorusama/boorus/registry.dart';
import 'package:boorusama/core/analytics/providers.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/boorus/engine/providers.dart';
import 'package:boorusama/core/configs/config/src/data/booru_config_repository_hive.dart';
import 'package:boorusama/core/configs/config/data.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/configs/manage/providers.dart';
import 'package:boorusama/core/hive/hive_adapters.dart';
import 'package:boorusama/core/posts/details/providers.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/posts/rating/types.dart';
import 'package:boorusama/core/posts/sources/types.dart';
import 'package:boorusama/core/search/subscriptions/providers.dart';
import 'package:boorusama/core/search/subscriptions/types.dart';
import 'package:boorusama/core/settings/providers.dart';
import 'package:boorusama/core/settings/src/data/setting_repository_hive.dart';
import 'package:boorusama/core/settings/types.dart';
import 'package:boorusama/foundation/loggers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

void main() {
  for (final type in [BooruType.philomena, BooruType.gelbooruV2]) {
    for (final useMedia in [false, true]) {
      test(
        '${type.name} profile deletion preserves other data after media use $useMedia',
        () async {
          final fixture = await _Fixture.create(type);
          addTearDown(fixture.dispose);
          if (useMedia) {
            final subscription = fixture.container.listen(
              mediaUrlResolverProvider(fixture.owned.auth),
              (_, _) {},
              fireImmediately: true,
            );
            addTearDown(subscription.close);
            expect(fixture.resolve(), endsWith('/sample'));
          }
          BooruConfig? deleted;
          final failures = <String>[];
          await fixture.container
              .read(booruConfigProvider.notifier)
              .delete(
                fixture.owned,
                onSuccess: (profile) => deleted = profile,
                onFailure: failures.add,
              );
          expect(deleted?.id, fixture.owned.id);
          expect(failures, isEmpty);
          expect(
            (await fixture.profiles.getAll()).map((profile) => profile.id),
            [fixture.original.id],
          );
          expect(
            fixture.container
                .read(booruConfigProvider)
                .map((profile) => profile.id),
            [fixture.original.id],
          );
          expect(
            fixture.container.read(currentBooruConfigProvider).id,
            fixture.original.id,
          );
          expect(
            (await fixture.searches.getAll()).map((search) => search.profileId),
            [fixture.original.id],
          );
          final loaded = (await fixture.settings.load().run()).getOrElse(
            (_) => throw StateError('settings load failed'),
          );
          expect(loaded.booruConfigIdOrderList, [fixture.original.id]);
          expect(loaded.currentBooruConfigId, fixture.original.id);
        },
      );
    }
    test(
      '${type.name} media reacts to global and own profile quality without following selected profile',
      () async {
        final fixture = await _Fixture.create(type, currentOwned: false);
        addTearDown(fixture.dispose);
        final subscription = fixture.container.listen(
          mediaUrlResolverProvider(fixture.owned.auth),
          (_, _) {},
          fireImmediately: true,
        );
        addTearDown(subscription.close);
        expect(fixture.resolve(), endsWith('/sample'));
        final initialResolver = fixture.container.read(
          mediaUrlResolverProvider(fixture.owned.auth),
        );
        await fixture.container
            .read(settingsNotifierProvider.notifier)
            .updateWith(
              (settings) => settings.copyWith(
                viewer: settings.viewer.copyWith(
                  postQuality: PostQuality.medium,
                ),
              ),
            );
        await fixture.container.pump();
        expect(fixture.resolve(), endsWith('/sample'));
        expect(
          fixture.container.read(postQualityProvider(fixture.owned.auth)),
          PostQuality.medium,
        );
        final globalResolver = fixture.container.read(
          mediaUrlResolverProvider(fixture.owned.auth),
        );
        expect(globalResolver, isNot(same(initialResolver)));
        await fixture.setOwnQuality(PostQuality.high, enabled: true);
        await fixture.container.pump();
        expect(fixture.resolve(), endsWith('/sample'));
        expect(
          fixture.container.read(postQualityProvider(fixture.owned.auth)),
          PostQuality.high,
        );
        expect(
          fixture.container.read(mediaUrlResolverProvider(fixture.owned.auth)),
          isNot(same(globalResolver)),
        );
        await fixture.setOwnQuality(PostQuality.medium, enabled: true);
        await fixture.container.pump();
        expect(fixture.resolve(), endsWith('/sample'));
        await fixture.setOwnQuality(PostQuality.medium, enabled: false);
        await fixture.container.pump();
        expect(fixture.resolve(), endsWith('/sample'));
        expect(
          fixture.container.read(postQualityProvider(fixture.owned.auth)),
          PostQuality.medium,
        );
        final stored = (await fixture.profiles.getAll()).singleWhere(
          (profile) => profile.id == fixture.owned.id,
        );
        expect(stored.viewerConfigs?.enable, isFalse);
        expect(
          fixture.container.read(currentBooruConfigProvider).id,
          fixture.original.id,
        );
        final originalResolver = fixture.container.read(
          mediaUrlResolverProvider(fixture.original.auth),
        );
        expect(
          originalResolver.resolveMediaUrl(
            _post(fixture.original),
            fixture.original.viewer,
          ),
          endsWith('/thumb'),
        );
      },
    );
  }
  for (final scenario in [
    (type: BooruType.danbooru, original: '/sample', low: '/thumb'),
    (type: BooruType.e621, original: '/sample', low: '/sample'),
    (type: BooruType.hydrus, original: '/sample', low: '/sample'),
  ]) {
    test(
      '${scenario.type.name} keeps its media policy reactive and permits profile removal',
      () async {
        final fixture = await _Fixture.create(scenario.type);
        addTearDown(fixture.dispose);
        final subscription = fixture.container.listen(
          mediaUrlResolverProvider(fixture.owned.auth),
          (_, _) {},
          fireImmediately: true,
        );
        addTearDown(subscription.close);
        expect(fixture.resolve(), endsWith('/sample'));
        await fixture.container
            .read(settingsNotifierProvider.notifier)
            .updateWith(
              (settings) => settings.copyWith(
                viewer: settings.viewer.copyWith(
                  postQuality: PostQuality.high,
                ),
              ),
            );
        await fixture.container.pump();
        expect(fixture.resolve(), endsWith(scenario.original));
        await fixture.setOwnQuality(PostQuality.medium, enabled: true);
        await fixture.container.pump();
        expect(fixture.resolve(), endsWith(scenario.low));
        BooruConfig? deleted;
        await fixture.container
            .read(booruConfigProvider.notifier)
            .delete(fixture.owned, onSuccess: (profile) => deleted = profile);
        expect(deleted?.id, fixture.owned.id);
        expect((await fixture.profiles.getAll()).map((profile) => profile.id), [
          fixture.original.id,
        ]);
        expect(
          (await fixture.searches.getAll()).map((search) => search.profileId),
          [fixture.original.id],
        );
      },
    );
  }
}

class _Fixture {
  _Fixture(
    this.directory,
    this.profileBox,
    this.settingsBox,
    this.profiles,
    this.settings,
    this.container,
    this.original,
    this.owned,
    this.searches,
  );

  static Future<_Fixture> create(
    BooruType type, {
    bool currentOwned = true,
  }) async {
    final directory = await Directory.systemTemp.createTemp(
      'quality-profile-graph-',
    );
    Hive.init(directory.path);
    if (!Hive.isAdapterRegistered(6)) {
      Hive.registerAdapter(SearchSubscriptionHiveObjectAdapter());
    }
    if (!Hive.isAdapterRegistered(7)) {
      Hive.registerAdapter(SearchPostPreviewHiveObjectAdapter());
    }
    if (!Hive.isAdapterRegistered(8)) {
      Hive.registerAdapter(RecentSearchPostHiveObjectAdapter());
    }
    final profileBox = await Hive.openBox<String>('quality_profile_graph');
    final settingsBox = await Hive.openBox<String>('quality_settings_graph');
    final profiles = HiveBooruConfigRepository(box: profileBox);
    final settings = SettingsRepositoryHive(Future.value(settingsBox));
    final original = _profile(BooruType.danbooru, 1).copyWith(
      viewerConfigs: () => ViewerConfigs(
        enable: true,
        settings: Settings.defaultSettings.viewer.copyWith(
          postQuality: PostQuality.medium,
        ),
      ),
    );
    final owned = _profile(type, 2);
    await profiles.addAll([original, owned]);
    final current = currentOwned ? owned : original;
    final initial = Settings.defaultSettings.copyWith(
      currentBooruConfigId: current.id,
      booruConfigIdOrders: [original.id, owned.id].join(' '),
    );
    await settings.save(initial);
    final registry = createBooruRegistry();
    final db = BooruDb(
      boorus: {
        for (final engineType in [BooruType.danbooru, type])
          engineType: registry.parseFromConfig(engineType.yamlName),
      },
    );
    final container = ProviderContainer(
      overrides: [
        booruEngineRegistryProvider.overrideWith(
          (ref) =>
              ref.watch(booruInitEngineProvider((db: db, registry: registry))),
        ),
        booruConfigRepoProvider.overrideWithValue(profiles),
        booruConfigProvider.overrideWith(
          () => BooruConfigNotifier(initialConfigs: [original, owned]),
        ),
        settingsRepoProvider.overrideWithValue(settings),
        settingsNotifierProvider.overrideWith(() => SettingsNotifier(initial)),
        initialSettingsBooruConfigProvider.overrideWithValue(current),
        loggerProvider.overrideWithValue(
          ConsoleLogger(options: const ConsoleLoggerOptions.defaults()),
        ),
        analyticsProvider.overrideWith((_) => Future.value()),
      ],
    );
    final searches = await container.read(
      searchSubscriptionRepositoryProvider.future,
    );
    await searches.create(
      profileId: original.id,
      query: 'original',
      name: null,
    );
    await searches.create(profileId: owned.id, query: 'owned', name: null);
    await container.read(searchSubscriptionsProvider.future);
    return _Fixture(
      directory,
      profileBox,
      settingsBox,
      profiles,
      settings,
      container,
      original,
      owned,
      searches,
    );
  }

  final Directory directory;
  final Box<String> profileBox;
  final Box<String> settingsBox;
  final HiveBooruConfigRepository profiles;
  final SettingsRepositoryHive settings;
  final ProviderContainer container;
  final BooruConfig original;
  BooruConfig owned;
  final SearchSubscriptionRepository searches;

  String resolve() => container
      .read(mediaUrlResolverProvider(owned.auth))
      .resolveMediaUrl(_post(owned), owned.viewer);

  Future<void> setOwnQuality(
    PostQuality quality, {
    required bool enabled,
  }) async {
    final updated = owned.copyWith(
      viewerConfigs: () => ViewerConfigs(
        enable: enabled,
        settings: Settings.defaultSettings.viewer.copyWith(
          postQuality: quality,
        ),
      ),
    );
    final failures = <String>[];
    await container
        .read(booruConfigProvider.notifier)
        .update(
          oldConfigId: owned.id,
          booruConfigData: updated.toBooruConfigData(),
          onSuccess: (profile) => owned = profile,
          onFailure: failures.add,
        );
    expect(failures, isEmpty);
    expect(owned.viewerConfigs, updated.viewerConfigs);
  }

  Future<void> dispose() async {
    final searchStorage = container.read(
      searchSubscriptionRepositoryProvider.notifier,
    );
    container.dispose();
    await searchStorage.closeFuture;
    await profileBox.close();
    await settingsBox.close();
    await directory.delete(recursive: true);
  }
}

BooruConfig _profile(BooruType type, int seed) => BooruConfig.fromJson({
  ...BooruConfig.defaultConfig(
    booruType: type,
    url: 'https://profile$seed.example',
    customDownloadFileNameFormat: null,
  ).toJson(),
  'id': '00000000-0000-4000-8000-00000000000$seed',
});

Post _post(BooruConfig profile) => Post(
  origin: PostOrigin.fromSource(
    booruType: profile.auth.booruType,
    booruId: profile.booruId,
    source: profile.url,
  ),
  core: PostCoreData(
    id: 1,
    thumbnailImageUrl: '${profile.url}/thumb',
    sampleImageUrl: '${profile.url}/sample',
    originalImageUrl: '${profile.url}/original',
    videoUrl: '',
    videoThumbnailUrl: '',
    width: 200,
    height: 400,
    format: 'png',
    md5: '',
    fileSize: 100,
    duration: 0,
    tags: const {},
    rating: Rating.general,
    hasComment: false,
    isTranslated: false,
    hasParentOrChildren: false,
    source: PostSource.none(),
    score: 0,
  ),
  booruData: const EmptyPostData(typeKey: 'fixture'),
);
