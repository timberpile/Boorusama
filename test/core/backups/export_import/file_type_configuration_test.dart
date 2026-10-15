// Dart imports:
import 'dart:convert';
import 'dart:io';

// Flutter imports:
import 'package:flutter_test/flutter_test.dart';

// Package imports:
import 'package:archive/archive_io.dart';

// Project imports:
import 'package:boorusama/core/backups/export_import/package/export_package_reader.dart';
import 'package:boorusama/core/backups/utils/backup_file_picker.dart';
import 'package:boorusama/foundation/filesystem.dart';

void main() {
  const mimeType = 'application/vnd.boorusama.export';
  const uti = 'com.timberpile.boorusama.export';

  test('file selection accepts export containers but rejects loose JSON', () {
    const extensions = ['bsexport', 'zip'];

    expect(
      BackupFilePicker.hasAllowedExtension('shared.BSEXPORT', extensions),
      isTrue,
    );
    expect(
      BackupFilePicker.hasAllowedExtension('shared.zip', extensions),
      isTrue,
    );
    expect(
      BackupFilePicker.hasAllowedExtension('bookmarks.json', extensions),
      isFalse,
    );
    expect(
      BackupFilePicker.hasAllowedExtension('bookmarks', extensions),
      isFalse,
    );
  });

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

  test('Android opens exports through a separate app-task receiver', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    final mainActivity = RegExp(
      r'<activity(?=[^>]*android:name="\.MainActivity")[^>]*>.*?</activity>',
      dotAll: true,
    ).firstMatch(manifest)?.group(0);
    final exportReceiver = RegExp(
      r'<activity(?=[^>]*android:name="\.ExportOpenActivity")[^>]*>.*?</activity>',
      dotAll: true,
    ).firstMatch(manifest)?.group(0);

    expect(exportReceiver, isNotNull);
    expect(exportReceiver, contains('android.intent.action.VIEW'));
    expect(exportReceiver, contains('android.intent.action.SEND'));
    expect(exportReceiver, contains(mimeType));
    expect(mainActivity, contains('android:launchMode="singleTop"'));
    expect(mainActivity, contains('android:scheme="boorusama"'));
    expect(mainActivity, isNot(contains(mimeType)));
    expect(mainActivity, isNot(contains('android:taskAffinity=""')));
  });

  test('Android stages each received intent with a bounded private delivery', () {
    final channel = File(
      'android/app/src/main/kotlin/com/timberpile/boorusama/ReceivedExportChannel.kt',
    ).readAsStringSync();

    expect(channel, contains('MAX_EXPORT_BYTES'));
    expect(channel, contains('ReceivedExportStaging.stage('));
    expect(channel, contains('"id" to delivery.id'));
    expect(channel, contains('"path" to delivery.file.absolutePath'));
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
    'Apple runners forward opened exports and expose the custom clipboard type',
    () {
      final ios = File('ios/Runner/AppDelegate.swift').readAsStringSync();
      final macosDelegate = File(
        'macos/Runner/AppDelegate.swift',
      ).readAsStringSync();
      final macosWindow = File(
        'macos/Runner/MainFlutterWindow.swift',
      ).readAsStringSync();

      expect(ios, contains('open url: URL'));
      expect(ios, contains('isExportFileURL'));
      expect(
        ios,
        contains('return super.application(app, open: url, options: options)'),
      );
      expect(ios, contains('ReceivedExportChannel'));
      expect(ios, contains('com.timberpile.boorusama.export'));
      expect(ios, contains('com.timberpile.boorusama/export_clipboard'));
      expect(macosDelegate, contains('openFiles filenames'));
      expect(macosWindow, contains('ReceivedExportChannel'));
      expect(macosWindow, contains('com.timberpile.boorusama.export'));
      expect(
        macosWindow,
        contains('com.timberpile.boorusama/export_clipboard'),
      );
    },
  );

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
