import 'dart:typed_data';
import 'package:cache_manager/cache_manager.dart';
import 'package:boorusama/core/images/providers.dart';
import 'package:boorusama/foundation/filesystem.dart';
import 'dart:io';

import 'package:boorusama/core/analytics/providers.dart';
import 'package:boorusama/core/cache/cache_notifier.dart';
import 'package:boorusama/core/settings/providers.dart';
import 'package:boorusama/core/settings/src/data/setting_repository_hive.dart';
import 'package:boorusama/core/settings/src/pages/data_and_storage_page.dart';
import 'package:boorusama/core/settings/types.dart';
import 'package:boorusama/foundation/loggers.dart';
import 'package:boorusama/foundation/utils/file_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';

void main() {
  setUpAll(() => ensureI18nInitialized('en-US'));
  testWidgets(
    'image and video limit dialogs save independently and restore their visible values',
    (tester) async {
      await tester.runAsync(() async {
        Future<T> real<T>(Future<T> Function() body) => body();
        await tester.binding.setSurfaceSize(const Size(800, 1200));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        late Directory directory;
        late Box box;
        await real(() async {
          directory = await Directory.systemTemp.createTemp('cache-limit-ui-');
          Hive.init(directory.path);
          box = await Hive.openBox('cache_limit_settings');
        });
        addTearDown(
          () => tester.runAsync(() async {
            await box.close();
            await directory.delete(recursive: true);
          }),
        );
        final repository = SettingsRepositoryHive(Future.value(box));
        Widget page(Settings initial) => BooruLocalization(
          child: ProviderScope(
            overrides: [
              settingsNotifierProvider.overrideWith(
                () => SettingsNotifier(initial),
              ),
              settingsRepoProvider.overrideWithValue(repository),
              appFileSystemProvider.overrideWithValue(
                _CacheTestFileSystem(directory.path),
              ),
              loggerProvider.overrideWithValue(
                ConsoleLogger(options: const ConsoleLoggerOptions.defaults()),
              ),
              analyticsProvider.overrideWith((ref) => Future.value()),
              appCacheSizeProvider.overrideWith(
                (ref) => Future.value(DirectorySizeInfo.zero),
              ),
              imageCacheSizeProvider.overrideWith(
                (ref) => Future.value(DirectorySizeInfo.zero),
              ),
              videoCacheSizeProvider.overrideWith(
                (ref) => Future.value(DirectorySizeInfo.zero),
              ),
              tagCacheSizeProvider.overrideWith((ref) => Future.value(0)),
              persistentCacheSizeProvider.overrideWith(
                (ref) => Future.value(0),
              ),
              diskSpaceInfoProvider.overrideWith(
                (ref) => Future.value(DiskSpaceInfo.zero),
              ),
            ],
            child: MaterialApp(
              builder: (context, child) => KurumiTheme(
                data: KurumiThemeData.fromMaterial(
                  Theme.of(context).copyWith(platform: TargetPlatform.iOS),
                ),
                child: child!,
              ),
              home: const DataAndStoragePage(),
            ),
          ),
        );
        await tester.pumpWidget(page(Settings.defaultSettings));
        await tester.pumpAndSettle();
        expect(find.text('Image cache limit'), findsOneWidget);
        expect(find.text('Bookmark images'), findsNothing);
        final container = ProviderScope.containerOf(
          tester.element(find.byType(DataAndStoragePage)),
        );
        final manager =
            container.read(defaultImageCacheManagerProvider)
                as ManagedImageCacheManager;
        final domain = manager.cacheDomain;
        await real(
          () => manager.saveFile('live-limit', Uint8List.fromList([1, 2, 3])),
        );

        Future<void> select(String title, String value) async {
          final tile = find.ancestor(
            of: find.text(title),
            matching: find.byWidgetPredicate((w) => w is KurumiSettingsTile),
          );
          final dropdown = find.descendant(
            of: tile,
            matching: find.byWidgetPredicate(
              (w) => w is KurumiOptionDropDownButton,
            ),
          );
          await tester.ensureVisible(dropdown);
          await tester.pumpAndSettle();
          await tester.tap(dropdown);
          await tester.pumpAndSettle();
          final choice = find.text(value).last;
          await tester.ensureVisible(choice);
          await tester.pumpAndSettle();
          expect(choice.hitTestable(), findsOneWidget);
          await tester.tap(choice);
          await tester.pumpAndSettle();
          await real(
            () => Future<void>.delayed(const Duration(milliseconds: 20)),
          );
          await tester.pumpAndSettle();
        }

        await select('Image cache limit', '500 MB');
        await select('Video cache limit', '2 GB');
        await select('Image cache limit', 'Custom...');
        expect(find.text('10 GB'), findsOneWidget);
        await tester.tap(find.byIcon(Icons.add));
        await tester.pumpAndSettle();
        expect(find.text('20 GB'), findsOneWidget);
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        var reopened = Settings.fromJson(
          (await repository.load().run())
              .getOrElse((_) => throw StateError('settings failed'))
              .toJson(),
        );
        expect(reopened.toJson()['imageCacheMaxSize'], '500MB');
        expect(reopened.toJson()['videoCacheMaxSize'], '2GB');
        await select('Image cache limit', 'Disabled');
        await select('Image cache limit', 'Custom...');
        expect(find.text('50 GB'), findsOneWidget);
        await container
            .read(settingsNotifierProvider.notifier)
            .updateWith(
              (latest) =>
                  latest.copyWith(blacklistedTags: 'kept while dialog open'),
            );
        await tester.tap(find.byIcon(Icons.remove));
        await tester.pumpAndSettle();
        expect(find.text('40 GB'), findsOneWidget);
        await tester.tap(find.text('OK'));
        await real(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pumpAndSettle();
        await select('Image cache limit', 'Disabled');
        await real(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        reopened = (await repository.load().run()).getOrElse(
          (_) => throw StateError('settings failed'),
        );
        expect(
          identical(container.read(defaultImageCacheManagerProvider), manager),
          isTrue,
        );
        expect(identical(manager.cacheDomain, domain), isTrue);
        await real(() async {
          expect((await manager.getStats()).retainedBytes, 0);
          expect(await manager.getCachedFileBytes('live-limit'), isNull);
        });
        expect(reopened.toJson()['imageCacheMaxSize'], '0B');
        expect(reopened.toJson()['videoCacheMaxSize'], '2GB');
        expect(reopened.blacklistedTags, 'kept while dialog open');
        await tester.pumpWidget(const SizedBox());
        await tester.pumpWidget(page(reopened));
        await tester.pumpAndSettle();
        expect(find.text('Disabled'), findsOneWidget);
        expect(find.text('2 GB'), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
        await manager.dispose();
      });
    },
  );
}

class _CacheTestFileSystem extends IoFileSystem {
  const _CacheTestFileSystem(this.root);
  final String root;
  @override
  Future<String?> getTemporaryPath() async => root;
}
