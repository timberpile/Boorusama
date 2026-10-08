import 'dart:convert';
import 'dart:io';

import 'package:boorusama/core/backups/auto/repo_android.dart';
import 'package:boorusama/core/backups/auto/types.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const repository = AutoBackupRepositoryAndroid();
  const tree =
      'content://com.android.externalstorage.documents/tree/primary%3APictures';
  final calls = <MethodCall>[];
  Object? response = true;
  PlatformException? failure;

  setUp(() {
    calls.clear();
    response = true;
    failure = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(AutoBackupRepositoryAndroid.channel, (
          call,
        ) async {
          calls.add(call);
          if (failure != null) throw failure!;
          return response;
        });
  });

  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(AutoBackupRepositoryAndroid.channel, null),
  );

  test('legacy paths require approval before any storage operation', () async {
    for (final path in [null, '/storage/emulated/0/Pictures']) {
      await expectLater(
        repository.getBackupDirectoryPath(path),
        throwsA(
          isA<PlatformException>().having(
            (e) => e.code,
            'code',
            'backup_folder_access_required',
          ),
        ),
      );
    }
    expect(calls, isEmpty);
  });

  test('saved tree is reused and revoked access propagates', () async {
    expect(await repository.getBackupDirectoryPath(tree), tree);
    expect(calls.single.method, 'prepare');
    failure = PlatformException(code: 'backup_folder_access_required');
    await expectLater(
      repository.getBackupDirectoryPath(tree),
      throwsA(isA<PlatformException>()),
    );
  });

  test(
    'device folder display decodes names without changing storage URIs',
    () async {
      const nested =
          'content://com.android.externalstorage.documents/tree/primary%3ADocuments%2FMy%20Backups%2F100%2525';
      expect(
        await AutoBackupRepositoryAndroid.directoryDisplayPath(nested),
        'Documents/My Backups/100%25',
      );
      expect(
        await AutoBackupRepositoryAndroid.directoryDisplayPath(tree),
        'Pictures',
      );
      expect(calls, isEmpty);

      expect(await repository.getBackupDirectoryPath(nested), nested);
      expect((calls.single.arguments as Map)['location'], nested);
    },
  );

  test('removable storage display keeps the volume distinct', () async {
    expect(
      await AutoBackupRepositoryAndroid.directoryDisplayPath(
        'content://com.android.externalstorage.documents/tree/ABCD-1234%3APictures%2FBackups',
      ),
      'ABCD-1234/Pictures/Backups',
    );
    expect(calls, isEmpty);
  });

  test('opaque provider IDs use the provider folder name', () async {
    const cloud = 'content://example.documents/tree/opaque%3A123';
    response = 'My cloud backups';
    expect(
      await AutoBackupRepositoryAndroid.directoryDisplayPath(cloud),
      'My cloud backups',
    );
    expect(calls.single.method, 'directoryDisplayName');
    expect((calls.single.arguments as Map)['location'], cloud);
  });

  test('unavailable folder names never fall back to the raw URI', () async {
    const cloud = 'content://example.documents/tree/opaque%3A123';
    for (final name in [null, '', ' ']) {
      response = name;
      expect(
        await AutoBackupRepositoryAndroid.directoryDisplayPath(cloud),
        isNull,
      );
    }
    failure = PlatformException(code: 'backup_folder_access_required');
    expect(
      await AutoBackupRepositoryAndroid.directoryDisplayPath(cloud),
      isNull,
    );
  });

  test('filesystem location display stays unchanged', () async {
    const path = '/storage/emulated/0/Pictures';
    expect(await AutoBackupRepositoryAndroid.directoryDisplayPath(path), path);
    expect(calls, isEmpty);
  });

  test('manifest round trip and write failure use document channel', () async {
    final manifest = AutoBackupManifest(
      backups: [
        AutoBackupEntry(
          fileName: 'backup.bsexport',
          createdAt: DateTime.utc(2026),
          fileSize: 123,
        ),
      ],
    );
    await repository.saveManifest(tree, manifest);
    final arguments = calls.single.arguments as Map;
    response = arguments['content'];
    final loaded = await repository.loadManifest(tree);
    expect(loaded.toJson(), jsonDecode(response! as String));
    failure = PlatformException(code: 'backup_storage_failed');
    await expectLater(
      repository.saveManifest(tree, manifest),
      throwsA(isA<PlatformException>()),
    );
    await expectLater(
      repository.loadManifest(tree),
      throwsA(isA<PlatformException>()),
    );
  });

  test('retention names preserve the encoded tree URI', () async {
    response = ['legacy.zip', 'current.bsexport'];
    expect(await repository.listBackupFiles(tree), [
      'legacy.zip',
      'current.bsexport',
    ]);
    response = true;
    final location = p.join(tree, 'legacy.zip');
    await repository.deleteFile(location);
    expect((calls.last.arguments as Map)['location'], '$tree/legacy.zip');
    expect(calls.last.method, 'delete');
  });
  test(
    'cancelled folder selection returns null without storage operations',
    () async {
      response = null;
      expect(await AutoBackupRepositoryAndroid.pickDirectory(), isNull);
      expect(calls.map((call) => call.method), ['pickDirectory']);
    },
  );

  for (final fail in [false, true]) {
    test(
      'package staging is removed after ${fail ? 'failed' : 'successful'} transfer',
      () async {
        final cache = await Directory.systemTemp.createTemp(
          'android_backup_test_',
        );
        addTearDown(() => cache.delete(recursive: true));
        final stagingRepository = AutoBackupRepositoryAndroid(
          temporaryDirectory: () async => cache,
        );
        String? source;
        final destination = p.join(tree, 'test.bsexport');
        Future<String> create(String path) async {
          source = path;
          await File(path).writeAsString('package');
          if (fail) failure = PlatformException(code: 'backup_storage_failed');
          return path;
        }

        if (fail) {
          await expectLater(
            stagingRepository.writeBackup(destination, create),
            throwsA(isA<PlatformException>()),
          );
        } else {
          expect(
            await stagingRepository.writeBackup(destination, create),
            destination,
          );
        }
        expect((calls.single.arguments as Map)['source'], source);
        expect(await cache.list().toList(), isEmpty);
      },
    );
  }
  test(
    'unreadable or empty manifest fails instead of resetting history',
    () async {
      response = '';
      await expectLater(repository.loadManifest(tree), throwsFormatException);
      expect(calls.map((call) => call.method), ['readManifest']);
    },
  );
}
