import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/content/anonymous_read_scope.dart';
import 'package:boorusama/core/content/anonymous_source_policy.dart';
import 'package:boorusama/core/content/content_access.dart';
import 'package:boorusama/core/downloads/downloader/src/providers/download_notifier.dart';
import 'package:boorusama/core/downloads/downloader/src/types/download.dart';
import 'package:boorusama/core/downloads/downloader/src/types/observer.dart';
import 'package:boorusama/core/downloads/urls/types.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/settings/types.dart';
import 'package:boorusama/foundation/loggers.dart';
import 'package:boorusama/foundation/permissions.dart';
import 'package:boorusama/foundation/platform.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes/test_post.dart';

void main() {
  test(
    'public single and bulk downloads stop before permission or work',
    () async {
      var permissionReads = 0;
      final extractor = _Extractor();
      final downloader = _Downloader();
      final observer = _Observer();
      var multiCheckCalls = 0;
      final params = _params(
        auth: _publicAuth(),
        extractor: extractor,
        downloader: downloader,
        observer: observer,
        canDownloadMultipleFiles: () {
          multiCheckCalls++;
          return false;
        },
      );
      final container = ProviderContainer(
        overrides: [
          deviceStoragePermissionProvider.overrideWith(
            () => _PermissionNotifier(() => permissionReads++),
          ),
          appPlatformProvider.overrideWithValue(AppPlatform.android),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(
        downloadNotifierProvider(params).notifier,
      );
      expect(await notifier.download(TestPost(id: 71)), isNull);
      await notifier.bulkDownload([TestPost(id: 71)]);

      expect(permissionReads, 0);
      expect(extractor.calls, 0);
      expect(downloader.calls, 0);
      expect(multiCheckCalls, 0);
      expect(observer.singleStarts, 0);
      expect(observer.bulkStarts, 0);
    },
  );

  test(
    'configured profile downloads retain the existing permission path',
    () async {
      var permissionReads = 0;
      final extractor = _Extractor(onRead: () => throw StateError('stop here'));
      final params = _params(
        auth: _privateAuth(),
        extractor: extractor,
        downloader: _Downloader(),
        observer: _Observer(),
        canDownloadMultipleFiles: () => true,
      );
      final container = ProviderContainer(
        overrides: [
          deviceStoragePermissionProvider.overrideWith(
            () => _PermissionNotifier(() => permissionReads++),
          ),
          appPlatformProvider.overrideWithValue(AppPlatform.android),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(
        downloadNotifierProvider(params).notifier,
      );
      await expectLater(
        notifier.download(TestPost(id: 72)),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'stop here',
          ),
        ),
      );

      expect(permissionReads, 1);
      expect(extractor.calls, 1);
    },
  );
}

DownloadNotifierParams _params({
  required BooruConfigAuth auth,
  required _Extractor extractor,
  required _Downloader downloader,
  required _Observer observer,
  required bool Function() canDownloadMultipleFiles,
}) => (
  auth: auth,
  download: BooruConfig.empty.download,
  profileIconUrl: null,
  downloadFileUrlExtractor: extractor,
  filenameBuilder: null,
  observer: observer,
  canDownloadMultipleFiles: canDownloadMultipleFiles,
  headers: const {},
  settings: Settings.defaultSettings,
  downloader: downloader,
  logger: _Logger(),
);

BooruConfigAuth _publicAuth() {
  final source = const AnonymousSourcePolicy().resolve(
    BooruType.danbooru,
    Uri.parse('https://safebooru.donmai.us'),
  )!;
  final scope = AnonymousReadScope(
    source: source,
    key: ContentAccessKey(
      engine: source.engine,
      siteNamespace: source.site.host,
      authEpoch: 1,
      policyEpoch: 1,
    ),
    current: () => true,
    createDio: () =>
        throw StateError('Download guard must not create a client'),
  );
  return BooruConfigAuth(
    booruId: source.engine.id,
    booruIdHint: source.engine.id,
    url: source.site.toString(),
    apiKey: null,
    login: null,
    passHash: null,
    proxySettings: null,
    networkSettings: null,
    anonymousReadScope: scope,
  );
}

BooruConfigAuth _privateAuth() => BooruConfigAuth(
  booruId: BooruType.danbooru.id,
  booruIdHint: BooruType.danbooru.id,
  url: 'https://danbooru.example',
  apiKey: 'configured-secret',
  login: 'configured-account',
  passHash: null,
  proxySettings: null,
  networkSettings: null,
);

class _PermissionNotifier extends DeviceStoragePermissionNotifier {
  _PermissionNotifier(this.onBuild);

  final void Function() onBuild;

  @override
  Future<DeviceStoragePermissionState> build() async {
    onBuild();
    return const DeviceStoragePermissionState(
      storagePermission: PermissionStatus.granted,
      isNotificationRead: true,
    );
  }
}

class _Extractor implements DownloadFileUrlExtractor {
  _Extractor({this.onRead});

  final void Function()? onRead;
  var calls = 0;

  @override
  Future<DownloadUrlData?> getDownloadFileUrl({
    required Post post,
    required String quality,
  }) async {
    calls++;
    onRead?.call();
    return null;
  }
}

class _Downloader implements DownloadService {
  var calls = 0;

  @override
  Future<DownloadResult> download(DownloadOptions options) {
    calls++;
    return Future.error(StateError('Unexpected download'));
  }

  @override
  Future<bool> cancelAll(String group) async => false;
  @override
  Future<void> pauseAll(String group) async {}
  @override
  Future<void> resumeAll(String group) async {}
}

class _Observer implements DownloadObserver {
  var singleStarts = 0;
  var bulkStarts = 0;

  @override
  void onSingleDownloadStart() => singleStarts++;
  @override
  void onBulkDownloadStart({required int total}) => bulkStarts++;
}

class _Logger implements Logger {
  @override
  String getDebugName() => 'public-download-test';
  @override
  void debug(String serviceName, String message, {String? sensitiveMessage}) {}
  @override
  void error(String serviceName, String message, {String? sensitiveMessage}) {}
  @override
  void info(String serviceName, String message, {String? sensitiveMessage}) {}
  @override
  void verbose(
    String serviceName,
    String message, {
    String? sensitiveMessage,
  }) {}
  @override
  void warn(String serviceName, String message, {String? sensitiveMessage}) {}
}
