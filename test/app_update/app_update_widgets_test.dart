import 'dart:async';
import 'dart:io';

import 'package:boorusama/core/settings/src/pages/updates_settings_page.dart';
import 'package:boorusama/core/settings/src/providers/settings_provider.dart';
import 'package:boorusama/core/settings/src/types/settings.dart';
import 'package:boorusama/foundation/app_update/src/github_apk_artifact.dart';
import 'package:boorusama/foundation/app_update/src/github_apk_downloader.dart';
import 'package:boorusama/foundation/app_update/src/providers.dart';
import 'package:boorusama/foundation/app_update/src/types/update_status.dart';
import 'package:boorusama/foundation/app_update/src/update_check_coordinator.dart';
import 'package:boorusama/foundation/app_update/src/widgets/app_update_dialog.dart';
import 'package:boorusama/foundation/app_update/src/widgets/app_update_lifecycle_listener.dart';
import 'package:dio/dio.dart';
import 'package:kurumi/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';

const _channel = MethodChannel('com.timberpile.boorusama/github_apk_install');
const _releaseUrl =
    'https://github.com/timberpile/Boorusama/releases/tag/v4.5.0';

UpdateAvailable _status({
  bool play = false,
  String notes = 'Changes',
}) => UpdateAvailable(
  currentVersion: '4.4.0',
  storeVersion: '4.5.0',
  releaseNotes: notes,
  storeUrl: play
      ? 'https://play.google.com/store/apps/details?id=com.timberpile.boorusama'
      : _releaseUrl,
  githubBuildNumber: play ? null : 200,
  githubApks: play
      ? const []
      : [
          GitHubApkArtifact(
            fileName: 'update.apk',
            architecture: 'arm64',
            size: 10,
            sha256: 'unused',
            downloadUrl: Uri.parse(_releaseUrl),
          ),
        ],
);

Widget _wrap(
  Widget child, {
  List<Override> overrides = const [],
  double scale = 1,
  bool canInstall = false,
}) => ProviderScope(
  overrides: [
    githubAndroidInstallationSupportedProvider.overrideWithValue(canInstall),
    ...overrides,
  ],
  child: BooruLocalization(
    child: MaterialApp(
      builder: (context, child) => KurumiTheme(
        data: KurumiThemeData.fromMaterial(Theme.of(context)),
        child: MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
      ),
      home: child,
    ),
  ),
);

void main() {
  setUpAll(() => ensureI18nInitialized('en-US'));
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null),
  );

  Future<void> tap(WidgetTester tester, String text) async {
    if (find.text(text).evaluate().isEmpty) {
      await tester.scrollUntilVisible(find.text(text), 150);
    }
    await tester.ensureVisible(find.text(text));
    await tester.tap(find.text(text));
    await tester.pumpAndSettle();
  }

  testWidgets('Play dialog keeps Later and Update without a GitHub link', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(AppUpdateDialog(status: _status(play: true))),
    );
    expect(find.text('Later'), findsOneWidget);
    expect(find.text('Update'), findsOneWidget);
    expect(find.text('Open GitHub'), findsNothing);
    expect(find.text('Download update'), findsNothing);
  });

  testWidgets(
    'narrow dialog scrolls long notes and actions with large text and keyboard',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      tester.view.viewInsets = const FakeViewPadding(bottom: 220);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _wrap(
          AppUpdateDialog(
            status: _status(
              notes: List.filled(20, 'A release note.').join('\n\n'),
            ),
          ),
          scale: 2,
        ),
      );
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Update'));
      await tester.pumpAndSettle();
      expect(find.text('Update').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'download requires an explicit tap and guides permission before installing',
    (tester) async {
      final calls = <String>[];
      var permission = false;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_channel, (call) async {
            calls.add(call.method);
            if (call.method == 'install') {
              expect((call.arguments as Map)['buildNumber'], 2200);
              expect((call.arguments as Map)['version'], '4.5.0');
            }
            return switch (call.method) {
              'supportedAbis' => ['arm64-v8a'],
              'canInstall' => permission,
              'openInstallSettings' => null,
              'install' => null,
              _ => throw StateError(call.method),
            };
          });
      final downloader = _Downloader();
      await tester.pumpWidget(
        _wrap(
          AppUpdateDialog(status: _status()),
          canInstall: true,
          overrides: [
            githubApkDownloaderProvider.overrideWithValue(downloader),
          ],
        ),
      );
      expect(calls, isEmpty);
      expect(downloader.calls, 0);
      await tap(tester, 'Download update');
      expect(downloader.calls, 1);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      downloader.result.complete(
        File('/private/cache/github-updates/update.apk'),
      );
      await tester.pumpAndSettle();
      await tap(tester, 'Install update');
      expect(calls, ['supportedAbis', 'canInstall']);
      expect(find.text('Allow installs'), findsOneWidget);
      await tap(tester, 'Allow installs');
      expect(calls.last, 'openInstallSettings');
      permission = true;
      await tap(tester, 'Install update');
      expect(calls.sublist(calls.length - 2), ['canInstall', 'install']);
    },
  );

  testWidgets(
    'closing during ABI lookup cancels without downloading or setState after dispose',
    (tester) async {
      final abis = Completer<List<String>>();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_channel, (_) => abis.future);
      final downloader = _Downloader();
      await tester.pumpWidget(
        _wrap(
          AppUpdateDialog(status: _status()),
          canInstall: true,
          overrides: [
            githubApkDownloaderProvider.overrideWithValue(downloader),
          ],
        ),
      );
      await tester.tap(find.text('Download update'));
      await tester.pump();
      await tester.pumpWidget(const SizedBox());
      abis.complete(['arm64-v8a']);
      await tester.pump();
      expect(downloader.calls, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('closing during permission lookup never launches the installer', (
    tester,
  ) async {
    final permission = Completer<bool>();
    final calls = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
          calls.add(call.method);
          return switch (call.method) {
            'supportedAbis' => ['arm64-v8a'],
            'canInstall' => await permission.future,
            _ => null,
          };
        });
    final downloader = _Downloader()
      ..result.complete(File('/private/cache/update.apk'));
    await tester.pumpWidget(
      _wrap(
        AppUpdateDialog(status: _status()),
        canInstall: true,
        overrides: [githubApkDownloaderProvider.overrideWithValue(downloader)],
      ),
    );
    await tap(tester, 'Download update');
    await tap(tester, 'Install update');
    expect(calls, ['supportedAbis', 'canInstall']);
    await tester.pumpWidget(const SizedBox());
    permission.complete(true);
    await tester.pump();
    expect(calls, ['supportedAbis', 'canInstall']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('incompatible ABI keeps browser fallback without downloading', (
    tester,
  ) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (_) async => ['x86_64']);
    final downloader = _Downloader();
    await tester.pumpWidget(
      _wrap(
        AppUpdateDialog(status: _status()),
        canInstall: true,
        overrides: [githubApkDownloaderProvider.overrideWithValue(downloader)],
      ),
    );
    await tap(tester, 'Download update');
    expect(downloader.calls, 0);
    expect(
      find.text('No compatible APK is available for this device.'),
      findsOneWidget,
    );
    expect(find.text('Open GitHub'), findsOneWidget);
  });

  testWidgets(
    'manual error survives refresh and a foreground success replaces it',
    (tester) async {
      final automaticChecks = StateProvider((ref) => false);
      String? cache;
      var now = DateTime.utc(2026, 10, 15);
      var checks = 0;
      final coordinator = UpdateCheckCoordinator(
        checkForUpdate: () async {
          checks++;
          return checks == 1
              ? const UpdateError('Offline')
              : const UpdateNotAvailable();
        },
        load: () => cache,
        save: (value) async {
          cache = value;
        },
        clock: () => now,
      );
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _wrap(
          const AppUpdateLifecycleListener(child: UpdatesSettingsPage()),
          scale: 2,
          overrides: [
            updateChecksSupportedProvider.overrideWithValue(true),
            settingsProvider.overrideWithValue(
              Settings.defaultSettings.copyWith(automaticUpdateChecks: false),
            ),
            appUpdateCoordinatorProvider.overrideWithValue(coordinator),
            shouldCheckForUpdateProvider.overrideWith(
              (ref) => ref.watch(automaticChecks),
            ),
          ],
        ),
      );
      await tap(tester, 'Check now');
      await tester.scrollUntilVisible(
        find.text('Could not check for updates'),
        -150,
      );
      expect(find.text('Could not check for updates'), findsOneWidget);
      expect(checks, 1);
      now = now.add(const Duration(hours: 24));
      final container = ProviderScope.containerOf(
        tester.element(find.byType(UpdatesSettingsPage)),
      );
      container.read(automaticChecks.notifier).state = true;
      await tester.pumpAndSettle();
      expect(find.text("You're up to date"), findsOneWidget);
      expect(checks, 2);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'foreground checks run initially and resume only after 24 hours',
    (tester) async {
      var now = DateTime.utc(2026, 10, 15);
      var checks = 0;
      final coordinator = UpdateCheckCoordinator(
        checkForUpdate: () async {
          checks++;
          return const UpdateNotAvailable();
        },
        load: () => null,
        save: (_) async {},
        clock: () => now,
      );
      await tester.pumpWidget(
        _wrap(
          const AppUpdateLifecycleListener(child: SizedBox()),
          overrides: [
            updateChecksSupportedProvider.overrideWithValue(true),
            shouldCheckForUpdateProvider.overrideWithValue(true),
            appUpdateCoordinatorProvider.overrideWithValue(coordinator),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(checks, 1);
      now = now.add(const Duration(hours: 23));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(checks, 1);
      now = now.add(const Duration(hours: 1));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(checks, 2);
    },
  );
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
