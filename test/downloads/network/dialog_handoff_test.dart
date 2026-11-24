import 'dart:async';

import 'package:boorusama/core/app_scope.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/ddos/handler/providers.dart';
import 'package:boorusama/core/downloads/downloader/src/providers/download_network_policy_provider.dart';
import 'package:boorusama/core/downloads/downloader/src/providers/download_notifier.dart';
import 'package:boorusama/core/downloads/downloader/types.dart';
import 'package:boorusama/core/downloads/downloader/src/widgets/download_network_dialog.dart';
import 'package:boorusama/core/downloads/filename/types.dart';
import 'package:boorusama/core/downloads/sidecar/types.dart';
import 'package:boorusama/core/downloads/urls/providers.dart';
import 'package:boorusama/core/navigation/app_navigation.dart';
import 'package:boorusama/core/navigation/destination_activity.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/settings/types.dart';
import 'package:boorusama/foundation/loggers.dart';
import 'package:boorusama/foundation/networking/network_provider.dart';
import 'package:boorusama/foundation/permissions.dart';
import 'package:boorusama/foundation/platform.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';

import '../../application/support/fake_booru_backend.dart';
import '../../support/boorusama_test_runtime.dart';

class _Permission extends DeviceStoragePermissionNotifier {
  @override
  Future<DeviceStoragePermissionState> build() async =>
      const DeviceStoragePermissionState(
        storagePermission: PermissionStatus.granted,
        isNotificationRead: true,
      );
}

class _GuardedDownload extends ConsumerStatefulWidget {
  const _GuardedDownload({
    required this.params,
    required this.post,
    required this.actorCurrent,
    required this.result,
  });
  final DownloadNotifierParams params;
  final Post post;
  final ValueNotifier<bool> actorCurrent;
  final Completer<DownloadTaskInfo?> result;

  @override
  ConsumerState<_GuardedDownload> createState() => _GuardedDownloadState();
}

class _GuardedDownloadState extends ConsumerState<_GuardedDownload> {
  bool _current() =>
      mounted && NavigationActivity.of(context) && widget.actorCurrent.value;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: TextButton(
      key: const ValueKey('guarded-download'),
      onPressed: () {
        unawaited(
          ref
              .read(downloadNotifierProvider(widget.params).notifier)
              .download(widget.post, isCurrent: _current)
              .then(
                widget.result.complete,
                onError: widget.result.completeError,
              ),
        );
      },
      child: const Text('Download'),
    ),
  );
}

void main() {
  for (final outcome in ['approve', 'cancel', 'actor changes while closing']) {
    testWidgets('guarded ASK download: $outcome', (tester) async {
      await ensureI18nInitialized('en-US');
      final backend = FakeBooruBackend();
      final downloads = MemoryDownloadService();
      final settings = Settings.defaultSettings.copyWith(
        downloadNetworkPolicy: DownloadNetworkPolicy.askOnMobileData,
        downloadSidecarFormat: SidecarFormat.off,
      );
      final runtime = backend.createRuntime(
        settings: settings,
        downloadService: downloads,
      );
      final navigation = AppNavigation();
      final coverage = NavigationCoverageObserver();
      final actorCurrent = ValueNotifier(true);
      final result = Completer<DownloadTaskInfo?>();
      final DownloadNotifierParams params = (
        auth: backend.config.auth,
        download: backend.config.download,
        profileIconUrl: null,
        downloadFileUrlExtractor: const UrlInsidePostExtractor(),
        filenameBuilder: fallbackFileNameBuilder,
        observer: null,
        canDownloadMultipleFiles: () => true,
        headers: <String, String>{},
        settings: settings,
        downloader: downloads,
        logger: ConsoleLogger(options: const ConsoleLoggerOptions.defaults()),
      );
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        coverage.dispose();
        actorCurrent.dispose();
      });
      await tester.pumpWidget(
        BoorusamaAppScope(
          runtime: runtime,
          additionalOverrides: [
            appNavigationProvider.overrideWithValue(navigation),
            appPlatformProvider.overrideWithValue(AppPlatform.android),
            deviceStoragePermissionProvider.overrideWith(_Permission.new),
            wifiDownloadConstraintSupportedProvider.overrideWithValue(true),
            currentConnectivityProvider.overrideWith(
              (_) => Future.value([ConnectivityResult.mobile]),
            ),
            bypassDdosHeadersProvider.overrideWith(
              (_, _) => Future.value(<String, String>{}),
            ),
          ],
          child: MaterialApp(
            navigatorKey: navigation.navigatorKey,
            navigatorObservers: [coverage, navigation.routeObserver],
            initialRoute: 'navigation-shell',
            routes: {
              'navigation-shell': (_) => DestinationActivityHost(
                selected: true,
                coverage: coverage,
                child: DestinationPageActivity(
                  child: _GuardedDownload(
                    params: params,
                    post: TestPost(
                      id: 1,
                      originalImageUrl: 'https://media.example.test/1.jpg',
                      sampleImageUrl: 'https://media.example.test/1-sample.jpg',
                    ),
                    actorCurrent: actorCurrent,
                    result: result,
                  ),
                ),
              ),
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      final button = find.byKey(const ValueKey('guarded-download'));
      expect(NavigationActivity.of(tester.element(button)), true);
      await tester.tap(button);
      await tester.pumpAndSettle();
      final dialog = find.byType(DownloadNetworkDialog);
      expect(dialog, findsOneWidget);
      expect(
        NavigationActivity.of(tester.element(button)),
        false,
        reason: 'The real root observer suspends the originating page while ASK is open.',
      );
      final route = ModalRoute.of(tester.element(dialog))!;
      if (outcome == 'actor changes while closing') {
        unawaited(route.popped.then((_) => actorCurrent.value = false));
      }
      final strings = tester.element(dialog).t;
      await tester.tap(
        find.text(
          outcome == 'cancel'
              ? strings.generic.action.cancel
              : strings.download.network_prompt.use_mobile_data,
        ),
      );
      var finished = false;
      DownloadTaskInfo? info;
      Object? failure;
      unawaited(
        result.future.then(
          (value) {
            info = value;
            finished = true;
          },
          onError: (Object error) {
            failure = error;
            finished = true;
          },
        ),
      );
      for (var frame = 0; frame < 80 && !finished; frame++) {
        await tester.pump(const Duration(milliseconds: 20));
        await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      }
      expect(
        finished,
        true,
        reason: 'The owned dialog handoff must complete without waiting for actor validity.',
      );
      expect(failure, isNull);
      await tester.pumpAndSettle();
      if (outcome == 'approve') {
        expect(info, isNotNull);
        expect(downloads.requests, hasLength(1));
        expect(
          downloads.requests.single.networkConstraint,
          DownloadNetworkConstraint.unrestricted,
        );
      } else {
        expect(info, isNull);
        expect(downloads.requests, isEmpty);
      }
      expect(tester.takeException(), isNull);
    });
  }
}
