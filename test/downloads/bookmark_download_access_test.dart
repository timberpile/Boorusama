import 'package:boorusama/core/posts/post/providers.dart';

import 'dart:async';

import 'package:boorusama/core/app_scope.dart';
import 'package:boorusama/core/blacklists/providers.dart';
import 'package:boorusama/core/bookmarks/providers.dart';
import 'package:boorusama/core/bookmarks/types.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/configs/manage/providers.dart';
import 'package:boorusama/core/ddos/handler/providers.dart';
import 'package:boorusama/core/downloads/urls/providers.dart';
import 'package:boorusama/core/downloads/urls/types.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/widgets/reboot.dart';
import 'package:boorusama/foundation/permissions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../application/support/fake_booru_backend.dart';
import '../support/boorusama_test_runtime.dart';

class _Profiles extends BooruConfigNotifier {
  _Profiles(List<BooruConfig> initial) : super(initialConfigs: initial);
  void replace(List<BooruConfig> configs) => state = configs;
}

class _PendingPermission extends DeviceStoragePermissionNotifier {
  _PendingPermission(this.entered, this.result);
  final Completer<void> entered;
  final Completer<DeviceStoragePermissionState> result;
  @override
  Future<DeviceStoragePermissionState> build() {
    entered.complete();
    return result.future;
  }
}

class _PendingExtractor implements DownloadFileUrlExtractor {
  final entered = Completer<void>();
  final result = Completer<DownloadUrlData?>();
  @override
  Future<DownloadUrlData?> getDownloadFileUrl({
    required Post post,
    required String quality,
  }) {
    entered.complete();
    return result.future;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final change in ['delete', 'credentials', 'policy']) {
    test('pending permission stops native scheduling after $change', () async {
      final backend = FakeBooruBackend();
      final downloads = MemoryDownloadService();
      final runtime = backend.createRuntime(
        configs: [backend.config],
        downloadService: downloads,
      );
      final initial = runtime.initialState;
      final profiles = _Profiles([backend.config]);
      final entered = Completer<void>();
      final permission = Completer<DeviceStoragePermissionState>();
      var tags = <String>{};
      final container = ProviderContainer(
        overrides: [
          ...buildBoorusamaOverrides(
            runtime,
            RebootData(
              config: initial.initialConfig,
              configs: initial.configs,
              settings: initial.settings,
            ),
          ),
          booruConfigProvider.overrideWith(() => profiles),
          blacklistTagsProvider.overrideWith((_, _) async => tags),
          deviceStoragePermissionProvider.overrideWith(
            () => _PendingPermission(entered, permission),
          ),
          bypassDdosHeadersProvider.overrideWith(
            (_, _) => Future.value(<String, String>{}),
          ),
        ],
      );
      addTearDown(container.dispose);
      await container.read(bookmarkProvider.future);
      final post = TestPost(
        id: 42,
        origin: postOriginFromConfig(backend.config),
        originalImageUrl: '${backend.config.url}/original.jpg',
      );
      final bookmark = PostBookmark.fromSnapshot(
        id: 42,
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
        snapshot: const StoredPostCodec().encode(
          post,
          dataCodec: const EmptyPostDataCodec('test'),
        ),
        post: post,
        postId: 42,
      );
      final operation = container
          .read(bookmarkProvider.notifier)
          .downloadBookmarks(backend.config.auth, backend.config.download, [
            bookmark,
          ]);
      await entered.future;
      if (change == 'delete') {
        profiles.replace([]);
      } else if (change == 'credentials') {
        profiles.replace([backend.config.copyWith(apiKey: 'changed')]);
      } else {
        tags = {'revoked'};
        container.invalidate(blacklistTagsProvider(backend.config.filter));
        await container.read(
          blacklistTagsProvider(backend.config.filter).future,
        );
      }
      permission.complete(
        const DeviceStoragePermissionState(
          storagePermission: PermissionStatus.granted,
          isNotificationRead: true,
        ),
      );
      await operation;
      expect(downloads.requests, isEmpty);
    });
  }
  test(
    'pending extractor stops scheduling after credential revocation',
    () async {
      final backend = FakeBooruBackend();
      final downloads = MemoryDownloadService();
      final runtime = backend.createRuntime(
        configs: [backend.config],
        downloadService: downloads,
      );
      final initial = runtime.initialState;
      final profiles = _Profiles([backend.config]);
      final extractor = _PendingExtractor();
      final container = ProviderContainer(
        overrides: [
          ...buildBoorusamaOverrides(
            runtime,
            RebootData(
              config: initial.initialConfig,
              configs: initial.configs,
              settings: initial.settings,
            ),
          ),
          booruConfigProvider.overrideWith(() => profiles),
          blacklistTagsProvider.overrideWith((_, _) async => <String>{}),
          downloadFileUrlExtractorProvider.overrideWith((_, _) => extractor),
          bypassDdosHeadersProvider.overrideWith(
            (_, _) => Future.value(<String, String>{}),
          ),
        ],
      );
      addTearDown(container.dispose);
      await container.read(bookmarkProvider.future);
      final post = TestPost(
        id: 42,
        origin: postOriginFromConfig(backend.config),
        originalImageUrl: '${backend.config.url}/original.jpg',
      );
      final bookmark = PostBookmark.fromSnapshot(
        id: 42,
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
        snapshot: const StoredPostCodec().encode(
          post,
          dataCodec: const EmptyPostDataCodec('test'),
        ),
        post: post,
        postId: 42,
      );
      final operation = container
          .read(bookmarkProvider.notifier)
          .downloadBookmarks(backend.config.auth, backend.config.download, [
            bookmark,
          ]);
      await extractor.entered.future;
      profiles.replace([backend.config.copyWith(apiKey: 'revoked')]);
      extractor.result.complete(
        const DownloadUrlData.urlOnly('https://headless.booru.test/file.jpg'),
      );
      await operation;
      expect(downloads.requests, isEmpty);
    },
  );
}
