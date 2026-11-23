import 'dart:io';
import 'dart:typed_data';

import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/content/content_access.dart';
import 'package:boorusama/core/content/content_media_access.dart';
import 'package:cache_manager/cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _url = 'https://cdn.donmai.us/sample/offline-fixture.jpg';
const _profileId = '11111111-1111-4111-8111-111111111111';

ContentAccessKey _access(int generation) => ContentAccessKey(
  engine: BooruType.danbooru,
  siteNamespace: 'danbooru.donmai.us',
  profileId: _profileId,
  authEpoch: generation,
  policyEpoch: generation + 1,
);

void main() {
  test('saved media reuses URL cache files across disk reopen', () async {
    final root = await Directory.systemTemp.createTemp('bookmark-url-cache-');
    final managers = <DefaultImageCacheManager>[];
    final containers = <ProviderContainer>[];
    DefaultImageCacheManager open() {
      final manager = DefaultImageCacheManager(
        cacheRootPathProvider: () => root.path,
        cacheDirName: 'images',
      );
      managers.add(manager);
      return manager;
    }

    ImageCacheManager forAccess(DefaultImageCacheManager manager, int epoch) {
      final container = ProviderContainer();
      containers.add(container);
      return container.read(
        contentMediaCacheManagerProvider((
          manager: manager,
          access: _access(epoch),
        )),
      );
    }

    try {
      final original = open();
      final key = original.generateCacheKey(_url);
      final bytes = Uint8List.fromList([1, 4, 9, 16]);
      await original.saveFile(key, bytes);

      final first = forAccess(original, 1);
      expect(first, same(original));
      expect(first.generateCacheKey(_url), key);
      expect(await first.getCachedFileBytes(key), bytes);
      expect(first, isA<ManagedImageCacheManager>());
      final customKey = original.generateCacheKey(_url, customKey: 'variant');
      expect(first.generateCacheKey(_url, customKey: 'variant'), customKey);
      expect(
        first.generateCacheKey(_url.replaceFirst('/sample/', '/thumbnail/')),
        isNot(key),
      );
      expect(
        await first.getCachedFileBytes(
          first.generateCacheKey(_url.replaceFirst('/sample/', '/thumbnail/')),
        ),
        isNull,
      );

      // Disposing a page/provider must not dispose the shared cache or erase it.
      containers.removeLast().dispose();
      expect(await original.getCachedFileBytes(key), bytes);
      final second = forAccess(original, 200);
      expect(second.generateCacheKey(_url), key);
      expect(await second.getCachedFileBytes(key), bytes);
      containers.removeLast().dispose();
      await original.dispose();
      managers.remove(original);

      final reopened = open();
      final afterRestart = forAccess(reopened, 1);
      expect(afterRestart.generateCacheKey(_url), key);
      expect(await afterRestart.getCachedFileBytes(key), bytes);
      final lease = await (afterRestart as ManagedImageCacheManager)
          .acquireFile(key);
      expect(lease, isNotNull);
      try {
        expect(await File(lease!.path).readAsBytes(), bytes);
      } finally {
        await lease?.release();
      }
    } finally {
      for (final container in containers) {
        container.dispose();
      }
      for (final manager in managers) {
        await manager.dispose();
      }
      await root.delete(recursive: true);
    }
  });
}
