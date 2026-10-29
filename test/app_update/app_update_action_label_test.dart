import 'package:boorusama/foundation/app_update/src/github_apk_artifact.dart';
import 'package:boorusama/foundation/app_update/src/providers.dart';
import 'package:boorusama/foundation/app_update/src/types/update_status.dart';
import 'package:boorusama/foundation/app_update/src/widgets/app_update_dialog.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';

void main() {
  setUpAll(() => ensureI18nInitialized('en-US'));

  for (final github in [true, false]) {
    testWidgets(
      '${github ? 'GitHub' : 'store'} updates describe their actual primary action',
      (tester) async {
        final status = UpdateAvailable(
          currentVersion: '4.4.0',
          storeVersion: '4.5.0',
          releaseNotes: 'Changes',
          storeUrl: github
              ? 'https://github.com/timberpile/Boorusama/releases/tag/v4.5.0'
              : 'https://play.google.com/store/apps/details?id=com.timberpile.boorusama',
          githubBuildNumber: github ? 200 : null,
          githubApks: github
              ? [
                  GitHubApkArtifact(
                    fileName: 'update.apk',
                    architecture: 'arm64',
                    size: 10,
                    sha256: 'unused',
                    downloadUrl: Uri.parse('https://example.com/update.apk'),
                  ),
                ]
              : const [],
        );
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              githubAndroidInstallationSupportedProvider.overrideWithValue(
                github,
              ),
            ],
            child: BooruLocalization(
              child: MaterialApp(
                builder: (context, child) => KurumiTheme(
                  data: KurumiThemeData.fromMaterial(Theme.of(context)),
                  child: child!,
                ),
                home: AppUpdateDialog(status: status),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.text('Download and install'),
          github ? findsOneWidget : findsNothing,
        );
        expect(find.text('Update'), github ? findsNothing : findsOneWidget);
        expect(find.text('Install update'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
