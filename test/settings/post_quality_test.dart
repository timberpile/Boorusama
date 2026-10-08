import 'dart:async';
import 'package:boorusama/core/settings/providers.dart';
import 'package:boorusama/core/settings/src/types/settings_repository.dart';
import 'package:boorusama/core/analytics/providers.dart';
import 'package:boorusama/foundation/loggers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:convert';
import 'dart:io';

import 'package:boorusama/core/images/image_quality.dart';
import 'package:boorusama/core/backups/utils/json_handler.dart';
import 'package:boorusama/core/backups/types/types.dart';
import 'package:boorusama/core/settings/src/data/setting_repository_hive.dart';
import 'package:boorusama/core/settings/types.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

void main() {
  test(
    'queued quality edits preserve a pending refresh choice in persisted Hive state',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'post-quality-queue-',
      );
      Hive.init(directory.path);
      final box = await Hive.openBox<String>('settings');
      final repository = _DelayedRepository(
        SettingsRepositoryHive(Future.value(box)),
      );
      final container = ProviderContainer(
        overrides: [
          settingsRepoProvider.overrideWithValue(repository),
          settingsNotifierProvider.overrideWith(
            () => SettingsNotifier(Settings.defaultSettings),
          ),
          loggerProvider.overrideWithValue(
            ConsoleLogger(options: const ConsoleLoggerOptions.defaults()),
          ),
          analyticsProvider.overrideWith((ref) => Future.value()),
        ],
      );
      try {
        final notifier = container.read(settingsNotifierProvider.notifier);
        final first = notifier.updateWith(
          (current) => current.copyWith(
            searchRefresh: current.searchRefresh.copyWith(enabled: false),
          ),
        );
        await repository.entered.future;
        final post = notifier.updateWith(
          (current) => current.copyWith(
            viewer: current.viewer.copyWith(postQuality: PostQuality.medium),
          ),
        );
        final thumbnail = notifier.updateWith(
          (current) => current.copyWith(
            listing: current.listing.copyWith(imageQuality: ImageQuality.low),
          ),
        );
        repository.release.complete();
        expect(
          await Future.wait([first, post, thumbnail]),
          everyElement(isTrue),
        );
        final loaded = (await repository.load().run()).getOrElse(
          (error) => throw StateError('load failed'),
        );
        expect(loaded.searchRefresh.enabled, isFalse);
        expect(loaded.viewer.postQuality, PostQuality.medium);
        expect(loaded.listing.imageQuality, ImageQuality.low);
      } finally {
        container.dispose();
        await box.close();
        await directory.delete(recursive: true);
      }
    },
  );

  test('fresh and legacy settings separate thumbnail and post defaults', () {
    expect(
      Settings.defaultSettings.listing.imageQuality,
      ImageQuality.automatic,
    );
    expect(Settings.defaultSettings.viewer.toJson()['postQuality'], 4);
    for (final old in ImageQuality.values) {
      final json = Settings.defaultSettings.toJson()
        ..remove('postQuality')
        ..['imageQuality'] = 1
        ..['imageQualityInFullView'] = old.toData();
      final migrated = Settings.fromJson(json);
      expect(migrated.listing.imageQuality, ImageQuality.low);
      expect(migrated.viewer.toJson()['postQuality'], 4);
      expect(migrated.imageQualityInFullView, old);
    }
  });

  for (final quality in PostQuality.values) {
    test(
      'deliberate $quality survives persistence and unrelated viewer edits',
      () async {
        final directory = await Directory.systemTemp.createTemp(
          'post-quality-',
        );
        Hive.init(directory.path);
        final box = await Hive.openBox<String>('settings');
        try {
          final repository = SettingsRepositoryHive(Future.value(box));
          final settings = Settings.defaultSettings.copyWith(
            viewer: ImageViewerSettings.fromJson({
              ...Settings.defaultSettings.viewer.toJson(),
              'postQuality': quality.toData(),
            }),
            listing: Settings.defaultSettings.listing.copyWith(
              imageQuality: ImageQuality.low,
            ),
          );
          await repository.save(settings);
          final loaded = (await repository.load().run()).getOrElse(
            (_) => throw StateError('load failed'),
          );
          expect(loaded.viewer.toJson()['postQuality'], quality.toData());
          expect(loaded.listing.imageQuality, ImageQuality.low);
          final edited = loaded.viewer.copyWith(loadOriginalOnZoom: false);
          expect(edited.toJson()['postQuality'], quality.toData());
          final profile = ViewerConfigs(settings: edited, enable: true);
          expect(
            ViewerConfigs.fromJsonString(
              profile.toJsonString(),
            ).settings.toJson()['postQuality'],
            quality.toData(),
          );
        } finally {
          await box.close();
          await directory.delete(recursive: true);
        }
      },
    );
  }

  test('backup parsing keeps independent quality and legacy migration', () {
    final handler = SingleHandler<Settings>(
      parser: Settings.fromJson,
      encoder: (settings) => settings.toJson(),
    );
    for (final quality in [null, 0, 1, 2, 3, 4]) {
      final json = Settings.defaultSettings.toJson()..remove('postQuality');
      if (quality != null) json['postQuality'] = quality;
      final imported = handler.parse(ExportDataPayload.legacy(data: [json]));
      expect(
        imported.viewer.toJson()['postQuality'],
        quality == null || quality >= 3 ? 4 : 2,
      );
      expect(
        handler.parse(ExportDataPayload.legacy(data: handler.encode(imported))),
        imported,
      );
    }
  });

  test(
    'missing or invalid quality defaults High and old Automatic migrates Medium',
    () {
      for (final value in [null, 'bad', 999, {}, false]) {
        expect(
          ImageViewerSettings.fromJson({
            'postQuality': value,
          }).toJson()['postQuality'],
          4,
        );
      }
      expect(
        ImageViewerSettings.fromJson(const {
          'postQuality': 'automatic',
        }).toJson()['postQuality'],
        2,
      );
      final legacyProfile = jsonEncode({
        'enable': true,
        'settings': {'imageQualityInFullView': 1},
      });
      expect(
        ViewerConfigs.fromJsonString(
          legacyProfile,
        ).settings.toJson()['postQuality'],
        4,
      );
    },
  );
}

class _DelayedRepository implements SettingsRepository {
  _DelayedRepository(this.delegate);
  final SettingsRepositoryHive delegate;
  final entered = Completer<void>();
  final release = Completer<void>();
  @override
  SettingsOrError load() => delegate.load();
  @override
  Future<bool> save(Settings settings) async {
    if (!entered.isCompleted) {
      entered.complete();
      await release.future;
    }
    return delegate.save(settings);
  }
}
