import 'dart:async';
import 'dart:io';

import 'package:boorusama/foundation/app_update/src/github_apk_artifact.dart';
import 'package:boorusama/foundation/app_update/src/github_apk_downloader.dart';
import 'package:boorusama/foundation/app_update/src/providers.dart';
import 'package:boorusama/foundation/app_update/src/types/update_status.dart';
import 'package:boorusama/foundation/app_update/src/widgets/app_update_dialog.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';

const _channel = MethodChannel('com.timberpile.boorusama/github_apk_install');
const _primary = ValueKey('github-update-primary');

void main() {
  setUpAll(() => ensureI18nInitialized('en-US'));
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
  });

  for (final allowed in [true, false]) {
    testWidgets(
      'a background download waits for foreground before permission or installation, allowed=$allowed',
      (tester) async {
        final calls = <String>[];
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(_channel, (call) async {
              calls.add(call.method);
              return switch (call.method) {
                'supportedAbis' => ['arm64-v8a'],
                'canInstall' => allowed,
                _ => null,
              };
            });
        final downloader = _Downloader();
        await _open(tester, downloader);
        await _start(tester);
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        downloader.result.complete(File('/private/cache/update.apk'));
        await tester.pump();
        expect(calls, ['supportedAbis']);
        expect(downloader.calls, 1);

        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pumpAndSettle();
        expect(calls, [
          'supportedAbis',
          'canInstall',
          allowed ? 'install' : 'openInstallSettings',
        ]);
        expect(downloader.calls, 1);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'a permission lookup completed in background is rechecked on resume',
    (
      tester,
    ) async {
      final permission = Completer<bool>();
      final calls = <String>[];
      var lookups = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_channel, (call) async {
            calls.add(call.method);
            return switch (call.method) {
              'supportedAbis' => ['arm64-v8a'],
              'canInstall' => ++lookups == 1 ? await permission.future : true,
              _ => null,
            };
          });
      final downloader = _Downloader()
        ..result.complete(File('/private/cache/update.apk'));
      await _open(tester, downloader);
      await _start(tester);
      expect(calls, ['supportedAbis', 'canInstall']);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      permission.complete(true);
      await tester.pump();
      expect(calls, ['supportedAbis', 'canInstall']);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(calls, ['supportedAbis', 'canInstall', 'canInstall', 'install']);
      expect(downloader.calls, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'a delayed settings return cannot install after foreground was lost again',
    (
      tester,
    ) async {
      final settingsReturn = Completer<void>();
      final calls = <String>[];
      var permission = false;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_channel, (call) async {
            calls.add(call.method);
            switch (call.method) {
              case 'supportedAbis':
                return ['arm64-v8a'];
              case 'canInstall':
                return permission;
              case 'openInstallSettings':
                await settingsReturn.future;
                return null;
              default:
                return null;
            }
          });
      final downloader = _Downloader()
        ..result.complete(File('/private/cache/update.apk'));
      await _open(tester, downloader);
      await _start(tester);
      expect(calls, ['supportedAbis', 'canInstall', 'openInstallSettings']);
      permission = true;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      settingsReturn.complete();
      await tester.pump();
      expect(calls, ['supportedAbis', 'canInstall', 'openInstallSettings']);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(calls, [
        'supportedAbis',
        'canInstall',
        'openInstallSettings',
        'canInstall',
        'install',
      ]);
      expect(downloader.calls, 1);
      expect(tester.takeException(), isNull);
    },
  );
}

Future<void> _open(WidgetTester tester, _Downloader downloader) async {
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  addTearDown(() {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  });
  final status = UpdateAvailable(
    currentVersion: '4.4.0',
    storeVersion: '4.5.0',
    releaseNotes: 'Changes',
    storeUrl: 'https://github.com/timberpile/Boorusama/releases/tag/v4.5.0',
    githubBuildNumber: 200,
    githubApks: [
      GitHubApkArtifact(
        fileName: 'update.apk',
        architecture: 'arm64',
        size: 10,
        sha256: 'unused',
        downloadUrl: Uri.parse('https://example.com/update.apk'),
      ),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        githubAndroidInstallationSupportedProvider.overrideWithValue(true),
        githubApkDownloaderProvider.overrideWithValue(downloader),
      ],
      child: BooruLocalization(
        child: MaterialApp(
          builder: (context, child) => KurumiTheme(
            data: KurumiThemeData.fromMaterial(Theme.of(context)),
            child: child!,
          ),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => AppUpdateDialog(status: status),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}

Future<void> _start(WidgetTester tester) async {
  await tester.ensureVisible(find.byKey(_primary));
  await tester.tap(find.byKey(_primary));
  await tester.pumpAndSettle();
}

class _Downloader extends GitHubApkDownloader {
  final result = Completer<File>();
  var calls = 0;

  @override
  Future<File> download(
    GitHubApkArtifact artifact, {
    required CancelToken cancelToken,
    void Function(int, int)? onProgress,
  }) {
    calls++;
    onProgress?.call(5, 10);
    return result.future;
  }
}
