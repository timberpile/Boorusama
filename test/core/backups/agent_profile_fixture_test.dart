import 'dart:convert';
import 'dart:io';

import 'package:boorusama/core/backups/export_import/clipboard/export_clipboard_service.dart';
import 'package:boorusama/core/backups/export_import/import/import_plan.dart';
import 'package:boorusama/core/backups/export_import/import/profile_import_projection.dart';
import 'package:boorusama/core/backups/export_import/models/import_action.dart';
import 'package:boorusama/core/backups/export_import/package/export_package_reader.dart';
import 'package:boorusama/core/backups/export_import/sources/profile_export_sanitizer.dart';
import 'package:boorusama/core/backups/sources/providers.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/foundation/filesystem.dart';
import 'package:boorusama/foundation/info/package_info.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'the anonymous clipboard fixture imports stable credential-free profiles',
    () async {
      final root = Directory.systemTemp.createTempSync('agent_profiles_');
      addTearDown(() => root.deleteSync(recursive: true));
      final fs = _FileSystem(root.path);
      final text = await File(
        'test/fixtures/agent_profiles/anonymous-profiles-v1.clipboard.txt',
      ).readAsString();
      final clipboard = ExportClipboardService(
        fs: fs,
        clipboard: _Clipboard(text),
      );
      expect(await clipboard.detect(), isTrue);
      final input = await clipboard.importToTemporaryFile();
      addTearDown(input.dispose);
      final package = await ExportPackageReader(fs: fs).stage(input.path);
      addTearDown(package.dispose);
      expect(package.manifest.containsCredentials, isFalse);
      final source = package.manifest.sources.single;
      expect(source.id, 'profiles');
      expect(source.recommendedAction, ImportAction.replace);
      final sourcePath = package.pathFor(source.parts.single.path);
      final encoded = await fs.readString(sourcePath);
      expect(
        encoded,
        await File(
          'test/fixtures/agent_profiles/anonymous-profiles-v1.json',
        ).readAsString(),
      );
      final rows =
          (jsonDecode(encoded) as Map<String, dynamic>)['data'] as List;
      for (final row in rows.cast<Map<String, dynamic>>()) {
        expect(row.keys.toSet(), {
          'id',
          'booruId',
          'booruIdHint',
          'name',
          'url',
        });
        expect(isCanonicalProfileId(row['id'] as String), isTrue);
      }
      final container = ProviderContainer(
        overrides: [
          appFileSystemProvider.overrideWithValue(fs),
          appVersionProvider.overrideWith((ref) => null),
        ],
      );
      addTearDown(container.dispose);
      final preparation = await container
          .read(booruConfigsBackupSourceProvider)
          .capabilities
          .file!
          .prepareImport(sourcePath, null);
      final profiles = preparation.preparedData! as List<BooruConfig>;
      expect(profiles, hasLength(4));
      expect(profiles.map((p) => p.auth.booruType.id), [20, 23, 24, 25]);
      expect(profiles.any(profileContainsCredentials), isFalse);
      expect(profiles.every((p) => p.optionWarnings.isEmpty), isTrue);
      for (var setup = 0; setup < 2; setup++) {
        final result = const ProfileImportProjector().project(
          imported: profiles,
          local: [],
          resolution: ResolvedImportSource(
            id: 'profiles',
            action: ImportAction.replace,
            items: const [],
          ),
          credentialsIncluded: false,
        );
        expect(result.profiles, profiles);
        expect(result.profiles.map((p) => p.id), [
          for (var i = 1; i <= 4; i++)
            'a0000000-0000-4000-8000-${i.toString().padLeft(12, '0')}',
        ]);
      }
    },
  );
}

class _FileSystem extends IoFileSystem {
  _FileSystem(this.root);
  final String root;
  @override
  Future<String?> getTemporaryPath() async => root;
}

class _Clipboard implements ExportClipboardPort {
  _Clipboard(this.text);
  final String text;
  @override
  Future<bool> containsExport() async =>
      text.startsWith(kExportClipboardPrefix);
  @override
  Future<String?> read() async => text;
  @override
  Future<void> write(String value) async => throw UnsupportedError('Read only');
}
