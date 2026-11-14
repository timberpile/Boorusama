import 'package:boorusama/core/backups/folder_sync/android_storage.dart';
import 'package:boorusama/core/backups/folder_sync/storage.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('boorusama/folder_sync');
  const tree = 'content://example.documents/tree/shared%3ASync';
  const owner = '11111111-1111-4111-8111-111111111111';
  final calls = <MethodCall>[];
  Object? response;
  PlatformException? failure;
  final storage = AndroidFolderSyncStorage(tree);
  setUp(() {
    calls.clear();
    failure = null;
    response = true;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          if (failure != null) throw failure!;
          return response;
        });
  });
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null),
  );

  test('requires a selected document tree and preserves opaque IDs', () async {
    for (final location in [
      '/storage/shared',
      'file:///shared',
      'content://x/document/id',
    ]) {
      expect(() => AndroidFolderSyncStorage(location), throwsFormatException);
    }
    response = <String>[];
    expect(await storage.list('devices'), isEmpty);
    expect((calls.single.arguments as Map)['location'], tree);
  });
  test('path and retention validation happens before channel access', () async {
    for (final path in [
      '../other',
      '/devices',
      'devices/../../other',
      'devices\\other',
    ]) {
      await expectLater(storage.list(path), throwsFormatException);
    }
    await expectLater(
      storage.deleteOwnedRevision('devices/$owner/identity.json', owner: owner),
      throwsFormatException,
    );
    await expectLater(
      storage.deleteOwnedRevision(
        'devices/$owner/catalog/1.json',
        owner: '22222222-1111-4111-8111-111111111111',
      ),
      throwsFormatException,
    );
    expect(calls, isEmpty);
  });
  test(
    'bounded reads, ambiguous listings and revoked grants fail closed',
    () async {
      response = Uint8List.fromList([1, 2, 3]);
      await expectLater(
        storage.read('devices/$owner/identity.json', maxBytes: 2),
        throwsFormatException,
      );
      response = ['../other'];
      await expectLater(storage.list('devices'), throwsFormatException);
      response = ['nested/path'];
      await expectLater(storage.list('devices'), throwsFormatException);
      failure = PlatformException(code: 'sync_folder_access_required');
      await expectLater(
        storage.read('devices/$owner/identity.json'),
        throwsA(isA<PlatformException>()),
      );
      expect(
        calls.map((call) => call.method),
        isNot(contains('deleteOwnedRevision')),
      );
    },
  );
  test('immutable-write failures and owned retention are explicit', () async {
    response = false;
    await expectLater(
      storage.writeImmutable('devices/$owner/catalog/1.json', Uint8List(1)),
      throwsStateError,
    );
    response = true;
    await storage.deleteOwnedRevision(
      'devices/$owner/catalog/1.json',
      owner: owner,
    );
    expect(calls.last.method, 'deleteOwnedRevision');
    await expectLater(
      storage.read(
        'devices/$owner/catalog/1.json',
        maxBytes: folderSyncMaxBytes + 1,
      ),
      throwsArgumentError,
    );
  });
}
