import 'dart:io';

import 'package:boorusama/core/analytics/providers.dart';
import 'package:boorusama/core/debug/src/logging/app_logger.dart';
import 'package:boorusama/core/backups/export_import/models/export_selection.dart';
import 'package:boorusama/core/backups/export_import/package/export_package_reader.dart';
import 'package:boorusama/core/backups/export_import/package/export_package_writer.dart';
import 'package:boorusama/core/backups/export_import/sources/export_import_source.dart';
import 'package:boorusama/core/backups/export_import/sources/legacy_json_source_adapter.dart';
import 'package:boorusama/core/backups/sources/settings_source.dart';
import 'package:boorusama/core/settings/src/data/providers.dart';
import 'package:boorusama/core/settings/src/providers/settings_notifier.dart';
import 'package:boorusama/core/settings/src/types/settings.dart';
import 'package:boorusama/core/settings/src/types/settings_repository.dart';
import 'package:boorusama/core/settings/src/types/viewer_toolbar_layout.dart';
import 'package:boorusama/foundation/filesystem.dart';
import 'package:boorusama/foundation/info/package_info.dart';
import 'package:boorusama/foundation/loggers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _source = Provider(SettingsBackupSource.new);

class _Store implements SettingsRepository {
  Settings saved = Settings.defaultSettings;

  @override
  Future<bool> save(Settings settings) async {
    saved = settings;
    return true;
  }

  @override
  SettingsOrError load() => throw UnimplementedError();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'toolbar layout survives a settings bsexport and persisted import',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'toolbar_backup_',
      );
      addTearDown(() => directory.delete(recursive: true));
      final store = _Store();
      final layout = ViewerToolbarLayout(
        toolbar: const [
          ViewerToolbarAction.upvote,
          ViewerToolbarAction.bookmark,
        ],
        more: const [ViewerToolbarAction.share, ViewerToolbarAction.download],
      );
      final container = ProviderContainer(
        overrides: [
          appVersionProvider.overrideWithValue(null),
          appFileSystemProvider.overrideWithValue(const IoFileSystem()),
          settingsRepoProvider.overrideWithValue(store),
          settingsNotifierProvider.overrideWith(
            () => SettingsNotifier(
              Settings.defaultSettings.copyWith(
                viewerToolbarLayout: () => layout,
              ),
            ),
          ),
          loggerProvider.overrideWithValue(AppLogger()),
          analyticsProvider.overrideWith((ref) => Future.value()),
        ],
      );
      addTearDown(container.dispose);
      final source = container.read(_source);
      final snapshot = await LegacyJsonSourceAdapter(source: source).capture(
        const ExportSourceRequest(
          selection: ExportNodeSelection.leaf('settings'),
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
      await container
          .read(settingsNotifierProvider.notifier)
          .replaceSettings(
            Settings.defaultSettings,
          );
      final preparation = await source.capabilities.file!.prepareImport(
        staged.pathFor('sources/settings/data.json'),
        null,
      );
      await preparation.executeImport();
      expect(store.saved.viewerToolbarLayout, layout);
      expect(
        container.read(settingsNotifierProvider).viewerToolbarLayout,
        layout,
      );
    },
  );
}
