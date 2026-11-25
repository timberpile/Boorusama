import 'dart:io';

import 'package:boorusama/core/backups/export_import/models/export_selection.dart';
import 'package:boorusama/core/backups/export_import/package/export_package_reader.dart';
import 'package:boorusama/core/backups/export_import/package/export_package_writer.dart';
import 'package:boorusama/core/backups/export_import/sources/export_import_source.dart';
import 'package:boorusama/core/backups/export_import/sources/legacy_json_source_adapter.dart';
import 'package:boorusama/core/backups/sources/providers.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/settings/src/types/settings.dart';
import 'package:boorusama/core/settings/src/types/viewer_toolbar_layout.dart';
import 'package:boorusama/foundation/filesystem.dart';
import 'package:boorusama/foundation/info/package_info.dart';
import 'package:flutter_test/flutter_test.dart';

import '../search/following_topics/following_topic_test_utils.dart';

class _Store implements BooruConfigRepository {
  List<BooruConfig> profiles = [];

  @override
  Future<List<BooruConfig>> getAll() async => List.of(profiles);

  @override
  Future<void> clear() async => profiles.clear();

  @override
  Future<List<BooruConfig>> addAll(List<BooruConfig> configs) async {
    profiles.addAll(configs);
    return configs;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'each toolbar layout survives profile bsexport and persisted import',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'toolbar_backup_',
      );
      addTearDown(() => directory.delete(recursive: true));
      final first = ViewerToolbarLayout(
        toolbar: const [
          ViewerToolbarAction.favorite,
          ViewerToolbarAction.bookmark,
        ],
      );
      final second = ViewerToolbarLayout(
        toolbar: const [ViewerToolbarAction.share],
      );
      final firstProfile = testProfile.copyWith(
        name: 'First profile',
        viewerConfigs: () =>
            ViewerConfigs.undefined().copyWith(toolbarLayout: () => first),
      );
      final secondProfile = otherTestProfile.copyWith(
        name: 'Second profile',
        viewerConfigs: () =>
            ViewerConfigs.undefined().copyWith(toolbarLayout: () => second),
      );
      final store = _Store();
      final harness = FollowingTopicHarness(
        profiles: [firstProfile, secondProfile],
        profileRepository: store,
        overrides: [
          appVersionProvider.overrideWithValue(null),
          appFileSystemProvider.overrideWithValue(const IoFileSystem()),
        ],
      );
      addTearDown(harness.dispose);
      final source = harness.container.read(booruConfigsBackupSourceProvider);
      final snapshot = await LegacyJsonSourceAdapter(source: source).capture(
        const ExportSourceRequest(
          selection: ExportNodeSelection.leaf('profiles'),
          includeCredentials: false,
        ),
      );
      final path = await const ExportPackageWriter(fs: IoFileSystem()).write(
        ExportPackageBuild(
          createdAt: DateTime.utc(2026, 10, 29),
          appVersion: '4.8.1',
          sources: [snapshot.toPackageBuild()],
        ),
        '${directory.path}/toolbar.bsexport',
      );
      final staged = await const ExportPackageReader(fs: IoFileSystem())
          .stage(path);
      addTearDown(staged.dispose);
      final preparation = await source.capabilities.file!.prepareImport(
        staged.pathFor('sources/profiles/data.json'),
        null,
      );
      await preparation.executeImport();
      final restored = {
        for (final profile in store.profiles)
          profile.id: profile.viewerConfigs?.toolbarLayout,
      };
      expect(restored, {firstProfile.id: first, secondProfile.id: second});
    },
  );
}
