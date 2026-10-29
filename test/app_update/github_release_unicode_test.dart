import 'dart:convert';

import 'package:boorusama/foundation/app_update/src/github_release_update_checker.dart';
import 'package:boorusama/foundation/app_update/src/types/update_status.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:package_info_plus/package_info_plus.dart';

void main() {
  const notes = '# Changes 🛠️\n\n- Fixes 🐛\n- 日本語, Grüße, 👩🏽‍💻\n';
  for (final contentType in <String?>[
    null,
    'application/octet-stream',
    'text/plain',
    'application/json',
    'application/json; charset=utf-8',
  ]) {
    test(
      'preserves release note Unicode with content type $contentType',
      () async {
        final response = Response.bytes(
          utf8.encode(
            jsonEncode({
              'version': '2.0.0',
              'releaseUrl':
                  'https://github.com/timberpile/Boorusama/releases/tag/v2.0.0',
              'notes': notes,
            }),
          ),
          200,
          headers: {if (contentType != null) 'content-type': contentType},
        );
        final client = MockClient((_) async => response);
        addTearDown(client.close);
        final result = await _checker(client).checkForUpdate();
        expect(result, isA<UpdateAvailable>());
        expect((result as UpdateAvailable).releaseNotes, notes);
        expect(result.currentVersion, '1.0.0');
        expect(result.storeVersion, '2.0.0');
      },
    );
  }

  test(
    'invalid UTF-8 is reported instead of replacing release-note characters',
    () async {
      final client = MockClient(
        (_) async => Response.bytes([
          ...utf8.encode(
            '{"version":"2.0.0","releaseUrl":"https://example.com","notes":"',
          ),
          0xff,
          ...utf8.encode('"}'),
        ], 200),
      );
      addTearDown(client.close);
      final result = await _checker(client).checkForUpdate();
      expect(result, isA<UpdateError>());
    },
  );
}

GitHubReleaseUpdateChecker _checker(Client client) =>
    GitHubReleaseUpdateChecker(
      packageInfo: PackageInfo(
        appName: 'Boorusama',
        packageName: 'com.example.boorusama',
        version: '1.0.0',
        buildNumber: '1',
      ),
      manifestUrl: 'https://example.com/update.json',
      compareAndroidBuildNumbers: false,
      client: client,
    );
