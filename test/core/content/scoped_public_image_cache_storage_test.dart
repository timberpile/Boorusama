import 'dart:io';
import 'dart:typed_data';

import 'package:boorusama/core/images/scoped_image_cache_manager.dart';
import 'package:cache_manager/cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'scoped keys persist safely and isolate real disk cache generations',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'scoped-public-image-cache-',
      );
      final managers = <DefaultImageCacheManager>[];
      final scopes = <ScopedImageCacheManager>[];
      final leases = <ImageCacheFileLease>[];

      DefaultImageCacheManager createManager() {
        final manager = DefaultImageCacheManager(
          cacheRootPathProvider: () => root.path,
          cacheDirName: 'images',
        );
        managers.add(manager);
        return manager;
      }

      ScopedImageCacheManager scope(
        ImageCacheManager delegate,
        String namespace,
      ) {
        final manager = ScopedImageCacheManager(
          delegate: delegate,
          namespace: namespace,
          current: () => true,
        );
        scopes.add(manager);
        return manager;
      }

      try {
        final delegate = createManager();
        final publicScope = scope(delegate, 'public:safebooru/nested/path');
        final accountA = scope(delegate, 'profile:account-a');
        final accountB = scope(delegate, 'profile:account-b');
        const url = 'https://safebooru.donmai.us/data/same-image.jpg';
        final publicKey = publicScope.generateCacheKey(url);
        final accountAKey = accountA.generateCacheKey(url);
        final accountBKey = accountB.generateCacheKey(url);
        final customKey = publicScope.generateCacheKey(
          url,
          customKey: r'custom/path\with/separators',
        );
        final legacyKey = delegate.generateCacheKey(url);

        expect(publicKey, matches(RegExp(r'^[a-f0-9]{64}$')));
        expect(customKey, matches(RegExp(r'^[a-f0-9]{64}$')));
        expect({publicKey, accountAKey, accountBKey, legacyKey}, hasLength(4));
        expect(customKey, isNot(publicKey));

        final publicBytes = Uint8List.fromList([10, 11, 12]);
        final accountABytes = Uint8List.fromList([20, 21, 22]);
        final accountBBytes = Uint8List.fromList([30, 31, 32]);
        final legacyBytes = Uint8List.fromList([40, 41, 42]);
        await publicScope.saveFile(publicKey, publicBytes);
        await publicScope.saveFile(customKey, Uint8List.fromList([13]));
        await accountA.saveFile(accountAKey, accountABytes);
        await accountB.saveFile(accountBKey, accountBBytes);
        await delegate.saveFile(legacyKey, legacyBytes);

        expect(await publicScope.getCachedFileBytes(publicKey), publicBytes);
        expect(await publicScope.hasValidCache(publicKey), isTrue);
        expect(await accountA.getCachedFileBytes(accountAKey), accountABytes);
        expect(await accountA.hasValidCache(accountAKey), isTrue);
        expect(await accountB.getCachedFileBytes(accountBKey), accountBBytes);
        expect(await delegate.getCachedFileBytes(legacyKey), legacyBytes);

        final managedPublic = publicScope as ManagedImageCacheManager;
        final readLease = await managedPublic.acquireFile(publicKey);
        expect(readLease, isNotNull);
        expect(readLease!.isRetained, isTrue);
        expect(await File(readLease.path).exists(), isTrue);
        leases.add(readLease);

        final commitKey = publicScope.generateCacheKey(
          'https://safebooru.donmai.us/data/managed-commit.jpg',
        );
        final commitSession = await managedPublic.beginFileWrite(commitKey);
        final committedBytes = Uint8List.fromList([50, 51, 52, 53]);
        await File(commitSession.stagedPath).writeAsBytes(
          committedBytes,
          flush: true,
        );
        final commitLease = await commitSession.commit();
        expect(commitLease.isRetained, isTrue);
        expect(await File(commitLease.path).readAsBytes(), committedBytes);
        leases.add(commitLease);

        await publicScope.clearCache(publicKey);
        expect(await publicScope.getCachedFileBytes(publicKey), isNull);
        expect(await accountA.getCachedFileBytes(accountAKey), accountABytes);
        expect(await accountB.getCachedFileBytes(accountBKey), accountBBytes);
        expect(await delegate.getCachedFileBytes(legacyKey), legacyBytes);

        await Future.wait(leases.map((lease) => lease.release()));
        leases.clear();
        for (final manager in scopes) {
          await manager.dispose();
        }
        scopes.clear();
        await delegate.dispose();

        final reopenedDelegate = createManager();
        final reopenedPublic = scope(
          reopenedDelegate,
          'public:safebooru/nested/path',
        );
        final wrongNamespace = scope(reopenedDelegate, 'public:other-source');
        final reopenedCommitKey = reopenedPublic.generateCacheKey(
          'https://safebooru.donmai.us/data/managed-commit.jpg',
        );
        expect(reopenedCommitKey, commitKey);
        expect(
          await reopenedPublic.getCachedFileBytes(reopenedCommitKey),
          committedBytes,
        );
        expect(await reopenedPublic.hasValidCache(reopenedCommitKey), isTrue);
        expect(
          await wrongNamespace.getCachedFileBytes(reopenedCommitKey),
          isNull,
        );
        expect(await wrongNamespace.hasValidCache(reopenedCommitKey), isFalse);
        expect(await root.exists(), isTrue);
      } finally {
        for (final lease in leases) {
          await lease.release();
        }
        for (final manager in scopes) {
          await manager.dispose();
        }
        for (final manager in managers) {
          await manager.dispose();
        }
        await root.delete(recursive: true);
      }
    },
  );
}
