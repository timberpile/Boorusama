// Dart imports:
import 'dart:convert';
import 'dart:io';

// Flutter imports:
import 'package:flutter_test/flutter_test.dart';

// Package imports:
import 'package:archive/archive_io.dart';

// Project imports:
import 'package:boorusama/core/backups/export_import/package/export_package_reader.dart';
import 'package:boorusama/foundation/filesystem.dart';

void main() {
  const mimeType = 'application/vnd.boorusama.export';
  const uti = 'com.timberpile.boorusama.export';

  test('Android opens and receives only the custom export MIME type', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    final exportFilters =
        RegExp(
              '<intent-filter>(.*?)</intent-filter>',
              dotAll: true,
            )
            .allMatches(manifest)
            .map((match) => match.group(1)!)
            .where(
              (filter) => filter.contains(mimeType),
            );

    expect(exportFilters, hasLength(2));
    expect(
      exportFilters.any(
        (filter) => filter.contains('android.intent.action.VIEW'),
      ),
      isTrue,
    );
    expect(
      exportFilters.any(
        (filter) => filter.contains('android.intent.action.SEND'),
      ),
      isTrue,
    );
    expect(manifest, isNot(contains('application/octet-stream')));
  });

  for (final plistPath in [
    'ios/Runner/Info.plist',
    'macos/Runner/Info.plist',
  ]) {
    test('$plistPath declares the export document type', () {
      final plist = File(plistPath).readAsStringSync();

      expect(plist, contains('<key>UTExportedTypeDeclarations</key>'));
      expect(plist, contains('<key>CFBundleDocumentTypes</key>'));
      expect(plist, contains('<string>$uti</string>'));
      expect(plist, contains('<string>$mimeType</string>'));
      expect(plist, contains('<string>bsexport</string>'));
      expect(plist, contains('<string>public.content</string>'));
      expect(plist, contains('<string>public.data</string>'));
    });
  }

  test(
    'package validation does not depend on the filename extension',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'bsexport_extension_fallback_',
      );
      addTearDown(() => directory.delete(recursive: true));
      final path = '${directory.path}/shared-file.bin';
      final manifest = utf8.encode(
        jsonEncode({
          'formatVersion': 1,
          'createdAt': '2026-10-01T00:00:00.000Z',
          'appVersion': '1.2.3',
          'sources': <Object?>[],
        }),
      );
      final encoder = ZipFileEncoder()..create(path);
      encoder.addArchiveFile(
        ArchiveFile('manifest.json', manifest.length, manifest),
      );
      await encoder.close();

      final staged = await const ExportPackageReader(
        fs: IoFileSystem(),
      ).stage(path);
      addTearDown(staged.dispose);

      expect(staged.manifest.formatVersion, 1);
    },
  );
}
