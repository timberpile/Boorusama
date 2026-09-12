// Dart imports:
import 'dart:convert';

// Package imports:
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:package_info_plus/package_info_plus.dart';

// Project imports:
import 'package:boorusama/foundation/app_update/providers.dart';
import 'package:boorusama/foundation/app_update/src/types/update_status.dart';

void main() {
  group('GitHubReleaseUpdateChecker', () {
    test('returns UpdateAvailable for a newer Timberpile prerelease', () async {
      final checker = GitHubReleaseUpdateChecker(
        packageInfo: _packageInfo(version: '4.5.0-timberpile.1'),
        manifestUrl: 'https://example.com/boorusama-update.json',
        client: MockClient(
          (_) async => Response(
            jsonEncode({
              'schemaVersion': 1,
              'version': '4.5.0-timberpile.2',
              'releaseUrl':
                  'https://github.com/timberpile/Boorusama/releases/tag/v4.5.0-timberpile.2',
              'notes': 'Changes',
            }),
            200,
          ),
        ),
      );

      final status = await checker.checkForUpdate();

      expect(status, isA<UpdateAvailable>());
      expect(
        kGitHubUpdateManifestUrl,
        'https://github.com/timberpile/Boorusama/releases/latest/download/boorusama-update.json',
      );
    });

    test('returns UpdateAvailable when manifest version is newer', () async {
      final checker = GitHubReleaseUpdateChecker(
        packageInfo: _packageInfo(version: '4.4.0'),
        manifestUrl: 'https://example.com/boorusama-update.json',
        client: MockClient(
          (_) async => Response(
            jsonEncode({
              'schemaVersion': 1,
              'version': '4.5.0',
              'releaseUrl':
                  'https://github.com/timberpile/Boorusama/releases/tag/v4.5.0',
              'notes': 'Changes',
            }),
            200,
          ),
        ),
      );

      final status = await checker.checkForUpdate();

      expect(status, isA<UpdateAvailable>());
      final update = status as UpdateAvailable;
      expect(update.currentVersion, '4.4.0');
      expect(update.storeVersion, '4.5.0');
      expect(update.releaseNotes, 'Changes');
      expect(
        update.storeUrl,
        'https://github.com/timberpile/Boorusama/releases/tag/v4.5.0',
      );
    });

    test(
      'returns UpdateNotAvailable when manifest version is current',
      () async {
        final checker = GitHubReleaseUpdateChecker(
          packageInfo: _packageInfo(version: '4.5.0'),
          manifestUrl: 'https://example.com/boorusama-update.json',
          client: MockClient(
            (_) async => Response(
              jsonEncode({
                'schemaVersion': 1,
                'version': '4.5.0',
                'releaseUrl':
                    'https://github.com/timberpile/Boorusama/releases/tag/v4.5.0',
                'notes': 'Changes',
              }),
              200,
            ),
          ),
        );

        final status = await checker.checkForUpdate();

        expect(status, isA<UpdateNotAvailable>());
      },
    );

    test('returns UpdateError for invalid manifest JSON', () async {
      final checker = GitHubReleaseUpdateChecker(
        packageInfo: _packageInfo(version: '4.4.0'),
        manifestUrl: 'https://example.com/boorusama-update.json',
        client: MockClient(
          (_) async => Response('[]', 200),
        ),
      );

      final status = await checker.checkForUpdate();

      expect(status, isA<UpdateError>());
    });

    test('returns UpdateError for non-success responses', () async {
      final checker = GitHubReleaseUpdateChecker(
        packageInfo: _packageInfo(version: '4.4.0'),
        manifestUrl: 'https://example.com/boorusama-update.json',
        client: MockClient(
          (_) async => Response('Not found', 404),
        ),
      );

      final status = await checker.checkForUpdate();

      expect(status, isA<UpdateError>());
    });
  });
}

PackageInfo _packageInfo({
  required String version,
}) {
  return PackageInfo(
    appName: 'Boorusama',
    packageName: 'com.timberpile.boorusama',
    version: version,
    buildNumber: '1',
  );
}
