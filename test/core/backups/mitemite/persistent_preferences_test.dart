import 'package:boorusama/core/backups/mitemite/collection_aliases.dart';
import 'package:boorusama/core/backups/mitemite/protocol.dart';

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:boorusama/core/backups/mitemite/private_preferences.dart';
import 'package:boorusama/core/cache/hive_misc_data_store.dart';
import 'package:boorusama/core/cache/misc_data_store.dart';
import 'package:boorusama/foundation/filesystem.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:path/path.dart' as p;

void main() {
  test(
    'only confirmed identical writes skip durability, never reopening',
    () async {
      final fixture = await _Fixture.open();
      try {
        await fixture.legacy.put(
          PrivateSyncPreferences.identityKey,
          'original',
        );
        final fs = _Barriers();
        final store = fixture.store(fs: fs);
        await store.synchronize();
        await store.put('mitemite.v1.counter', '2');
        final barriers = fs.files.length;
        await store.put('mitemite.v1.counter', '2');
        await store.synchronize();
        expect(fs.files.length, barriers);
        await fixture.reopen();
        final reopened = fixture.store(fs: fs, boxWasPresent: true);
        await reopened.synchronize();
        expect(fs.files.length, greaterThan(barriers));
      } finally {
        await fixture.close();
      }
    },
  );

  test('sync authority survives loss of the ordinary app cache', () async {
    final root = await Directory.systemTemp.createTemp('sync_private_');
    final cache = Directory(p.join(root.path, 'cache'));
    final private = Directory(p.join(root.path, 'private'));
    await cache.create();
    await private.create();
    try {
      var legacy = await Hive.openBox<String>('misc_data_v1', path: cache.path);
      var stable = await Hive.openBox<String>('state_v1', path: private.path);
      await legacy.put('mitemite.v1.identity', 'original-test-identity');
      await legacy.put('mitemite.v1.publisher.peer', 'observed-sequence-21');
      await legacy.put('ordinary-cache', 'disposable');
      final store = await _open(legacy, stable);
      expect(store.get('mitemite.v1.identity'), 'original-test-identity');
      final collection = SyncCollectionId(
        publisher: '11111111-1111-4111-8111-111111111111',
        kind: 'bookmarks',
        source: '22222222-2222-4222-8222-222222222222',
      );
      await SyncCollectionAliases(store).set(collection, 'My durable alias');
      await Hive.close();
      await cache.delete(recursive: true);
      await cache.create();
      legacy = await Hive.openBox<String>('misc_data_v1', path: cache.path);
      stable = await Hive.openBox<String>('state_v1', path: private.path);
      final reopened = await _open(legacy, stable, boxWasPresent: true);
      expect(reopened.get('mitemite.v1.identity'), 'original-test-identity');
      expect(
        reopened.get('mitemite.v1.publisher.peer'),
        'observed-sequence-21',
      );
      expect(reopened.get('ordinary-cache'), isNull);
      expect(
        SyncCollectionAliases(reopened).values[collection],
        'My durable alias',
      );
    } finally {
      await Hive.close();
      await root.delete(recursive: true);
    }
  });

  test(
    'migrates the complete prefix once and delegates ordinary cache writes',
    () async {
      final fixture = await _Fixture.open();
      try {
        final values = {
          'mitemite.v1.identity': 'identity-bytes',
          'mitemite.v1.settings': 'opaque-tree-uri',
          'mitemite.v1.publisher.peer': 'high-water-21',
          'mitemite.v1.local_events': 'outbox-and-permission-receipts',
          'mitemite.v1.outgoing.self.counter': 'reservation-45',
        };
        await fixture.legacy.putAll({...values, 'other-cache': 'keep'});
        final store = fixture.store();
        await store.synchronize();
        final snapshot = jsonDecode(
          fixture.stable.get(PrivateSyncPreferences.snapshotKey)!,
        );
        expect(snapshot['values'], values);
        expect(fixture.stable.keys, [PrivateSyncPreferences.snapshotKey]);
        await store.put('other-cache', 'updated');
        expect(fixture.legacy.get('other-cache'), 'updated');
        expect(fixture.stable.get('other-cache'), isNull);
        for (final entry in values.entries) {
          expect(store.get(entry.key), entry.value);
        }
      } finally {
        await fixture.close();
      }
    },
  );

  test(
    'durable authority wins over stale legacy cache across reopening',
    () async {
      final fixture = await _Fixture.open();
      try {
        await fixture.legacy.put('mitemite.v1.identity', 'original');
        await fixture.legacy.put('mitemite.v1.publisher.peer', '21');
        final store = fixture.store();
        await store.synchronize();
        await store.put('mitemite.v1.publisher.peer', '22');
        await fixture.legacy.put(
          'mitemite.v1.identity',
          'stale-replacement',
        );
        await fixture.legacy.put('mitemite.v1.publisher.peer', '0');
        await fixture.reopen();
        final reopened = fixture.store(boxWasPresent: true);
        await reopened.synchronize();
        expect(reopened.get('mitemite.v1.identity'), 'original');
        expect(reopened.get('mitemite.v1.publisher.peer'), '22');
        expect(
          fixture.legacy.get('mitemite.v1.identity'),
          'stale-replacement',
        );
      } finally {
        await fixture.close();
      }
    },
  );

  test('failed migration barrier cannot reserve a new counter and retries the whole baseline', () async {
    final fixture = await _Fixture.open();
    try {
      await fixture.legacy.put('mitemite.v1.identity', 'original');
      await fixture.legacy.put('mitemite.v1.publisher.peer', '21');
      final fs = _Barriers()..fail = true;
      final store = fixture.store(fs: fs);
      await expectLater(
        store.put('mitemite.v1.counter', '2'),
        throwsStateError,
      );
      expect(fixture.stable.get('mitemite.v1.counter'), isNull);
      final snapshot = jsonDecode(
        fixture.stable.get(PrivateSyncPreferences.snapshotKey)!,
      );
      expect(snapshot['values'], {
        'mitemite.v1.identity': 'original',
        'mitemite.v1.publisher.peer': '21',
      });
      fs.fail = false;
      await store.synchronize();
      await store.put('mitemite.v1.counter', '2');
      expect(store.get('mitemite.v1.identity'), 'original');
      expect(store.get('mitemite.v1.publisher.peer'), '21');
      expect(store.get('mitemite.v1.counter'), '2');
      expect(fs.files.every((path) => path == fixture.stable.path), isTrue);
    } finally {
      await fixture.close();
    }
  });

  test(
    'migration waits for newly created private directory ancestry durability',
    () async {
      final fixture = await _Fixture.open();
      try {
        await fixture.legacy.put(
          PrivateSyncPreferences.identityKey,
          'original',
        );
        final fs = _Barriers()
          ..failDirectory = p.dirname(p.dirname(fixture.stable.path!));
        final store = fixture.store(fs: fs);
        await expectLater(
          store.put('mitemite.v1.counter', '22'),
          throwsStateError,
        );
        expect(fixture.stable.get('mitemite.v1.counter'), isNull);
        fs.failDirectory = null;
        await store.synchronize();
        expect(
          fs.directories,
          containsAll([
            p.dirname(fixture.stable.path!),
            p.dirname(p.dirname(fixture.stable.path!)),
            p.dirname(p.dirname(p.dirname(fixture.stable.path!))),
          ]),
        );
        await store.put('mitemite.v1.counter', '22');
        expect(store.get('mitemite.v1.counter'), '22');
      } finally {
        await fixture.close();
      }
    },
  );

  test('failed cached overlay write reestablishes durability before retry succeeds', () async {
    final fixture = await _Fixture.open();
    try {
      await fixture.legacy.put(PrivateSyncPreferences.identityKey, 'original');
      final fs = _Barriers();
      final store = fixture.store(fs: fs);
      await store.synchronize();
      fs.fail = true;
      await expectLater(
        store.put('mitemite.v1.counter', '2'),
        throwsStateError,
      );
      expect(store.get('mitemite.v1.counter'), '2');
      await expectLater(store.synchronize(), throwsStateError);
      fs.fail = false;
      final before = fs.files.length;
      await store.put('mitemite.v1.counter', '2');
      expect(fs.files.length, greaterThan(before));
      await fixture.reopen();
      final reopened = fixture.store(boxWasPresent: true);
      await reopened.synchronize();
      expect(reopened.get('mitemite.v1.counter'), '2');
    } finally {
      await fixture.close();
    }
  });

  test(
    'private writes serialize while unrelated cache preferences stay usable',
    () async {
      final fixture = await _Fixture.open();
      try {
        await fixture.legacy.put(
          PrivateSyncPreferences.identityKey,
          'original',
        );
        final fs = _BlockingBarrier();
        final store = fixture.store(fs: fs);
        await store.synchronize();
        fs.blockNext = true;
        final first = store.put('mitemite.v1.counter.a', '1');
        await fs.entered.future;
        final second = store.put('mitemite.v1.counter.b', '2');
        await store.put('ordinary-cache', 'independent');
        expect(fixture.stable.get('mitemite.v1.counter.b'), isNull);
        expect(store.get('ordinary-cache'), 'independent');
        fs.release.complete();
        await Future.wait([first, second]);
        expect(store.get('mitemite.v1.counter.a'), '1');
        expect(store.get('mitemite.v1.counter.b'), '2');
      } finally {
        await fixture.close();
      }
    },
  );

  for (final invalid in [
    '{',
    '{"version":2,"values":{}}',
    '{"version":1,"values":{"other-cache":"wrong"}}',
  ]) {
    test(
      'invalid durable state never falls back to a legacy identity: $invalid',
      () async {
        final fixture = await _Fixture.open();
        try {
          await fixture.legacy.put('mitemite.v1.identity', 'legacy-key');
          await fixture.legacy.put('ordinary-cache', 'available');
          await fixture.stable.put(PrivateSyncPreferences.snapshotKey, invalid);
          final store = fixture.store(boxWasPresent: true);
          expect(store.get('mitemite.v1.identity'), isNull);
          expect(store.get('ordinary-cache'), 'available');
          await expectLater(store.synchronize(), throwsFormatException);
          await expectLater(
            store.put('mitemite.v1.identity', 'replacement'),
            throwsFormatException,
          );
          expect(
            fixture.stable.get(PrivateSyncPreferences.snapshotKey),
            invalid,
          );
        } finally {
          await fixture.close();
        }
      },
    );
  }

  test('incomplete existing authority fails closed, while a fresh empty store is valid', () async {
    final fixture = await _Fixture.open();
    try {
      final incomplete = fixture.store(boxWasPresent: true);
      await expectLater(incomplete.synchronize(), throwsFormatException);
      final fresh = fixture.store();
      await fresh.synchronize();
      await fresh.put('mitemite.v1.identity', 'new-first-identity');
      await fixture.reopen();
      final reopened = fixture.store(boxWasPresent: true);
      await reopened.synchronize();
      expect(reopened.get('mitemite.v1.identity'), 'new-first-identity');
    } finally {
      await fixture.close();
    }
  });

  for (final state in ['legacy', 'snapshot', 'overlay']) {
    test(
      'partial $state authority cannot silently generate a replacement identity',
      () async {
        final fixture = await _Fixture.open();
        try {
          if (state == 'legacy') {
            await fixture.legacy.put(
              'mitemite.v1.settings',
              'configured-tree',
            );
          } else {
            await fixture.stable.put(
              PrivateSyncPreferences.snapshotKey,
              jsonEncode({
                'version': 1,
                'values': state == 'snapshot'
                    ? {'mitemite.v1.settings': 'configured-tree'}
                    : <String, String>{},
              }),
            );
            if (state == 'overlay') {
              await fixture.stable.put('mitemite.v1.publisher.peer', '21');
            }
          }
          final store = fixture.store(boxWasPresent: state != 'legacy');
          expect(store.get(PrivateSyncPreferences.identityKey), isNull);
          await expectLater(store.synchronize(), throwsFormatException);
          await expectLater(
            store.put(PrivateSyncPreferences.identityKey, 'replacement'),
            throwsFormatException,
          );
        } finally {
          await fixture.close();
        }
      },
    );
  }

  test(
    'an existing empty private file never reimports stale legacy authority',
    () async {
      final fixture = await _Fixture.open();
      try {
        await fixture.legacy.put(
          PrivateSyncPreferences.identityKey,
          'stale-cached-key',
        );
        await fixture.legacy.put(
          'mitemite.v1.publisher.peer',
          'old-sequence',
        );
        final store = fixture.store(boxWasPresent: true);
        expect(store.get(PrivateSyncPreferences.identityKey), isNull);
        await expectLater(store.synchronize(), throwsFormatException);
        expect(fixture.stable.isEmpty, isTrue);
        expect(
          fixture.legacy.get(PrivateSyncPreferences.identityKey),
          'stale-cached-key',
        );
      } finally {
        await fixture.close();
      }
    },
  );

  test(
    'an orphaned overlay cannot be completed from stale legacy data',
    () async {
      final fixture = await _Fixture.open();
      try {
        await fixture.legacy.put('mitemite.v1.identity', 'legacy');
        await fixture.stable.put('mitemite.v1.counter', '21');
        final store = fixture.store(boxWasPresent: true);
        expect(store.get('mitemite.v1.identity'), isNull);
        await expectLater(store.synchronize(), throwsFormatException);
      } finally {
        await fixture.close();
      }
    },
  );
}

Future<MiscDataStore> _open(
  Box<String> legacy,
  Box<String> stable, {
  bool boxWasPresent = false,
}) async {
  final store = PrivateSyncPreferences(
    legacy: HiveMiscDataStore(legacy),
    box: stable,
    fs: const IoFileSystem(),
    boxWasPresent: boxWasPresent,
  );
  await store.synchronize();
  return store;
}

class _Fixture {
  _Fixture(this.root, this.legacy, this.stable);
  final Directory root;
  Box<String> legacy;
  Box<String> stable;
  static Future<_Fixture> open() async {
    final root = await Directory.systemTemp.createTemp('sync_private_cases_');
    await Directory(p.join(root.path, 'cache')).create();
    await Directory(p.join(root.path, 'private')).create();
    return _Fixture(
      root,
      await Hive.openBox<String>('legacy', path: p.join(root.path, 'cache')),
      await Hive.openBox<String>('stable', path: p.join(root.path, 'private')),
    );
  }

  PrivateSyncPreferences store({
    AppFileSystem fs = const IoFileSystem(),
    bool boxWasPresent = false,
  }) => PrivateSyncPreferences(
    legacy: HiveMiscDataStore(legacy),
    box: stable,
    fs: fs,
    boxWasPresent: boxWasPresent,
  );
  Future<void> reopen() async {
    await Hive.close();
    legacy = await Hive.openBox<String>(
      'legacy',
      path: p.join(root.path, 'cache'),
    );
    stable = await Hive.openBox<String>(
      'stable',
      path: p.join(root.path, 'private'),
    );
  }

  Future<void> close() async {
    await Hive.close();
    await root.delete(recursive: true);
  }
}

class _Barriers extends IoFileSystem {
  var fail = false;
  String? failDirectory;
  final directories = <String>[];
  final files = <String>[];
  @override
  Future<void> syncDirectory(String path) async {
    directories.add(path);
    if (path == failDirectory) {
      throw StateError('Injected private parent barrier failure');
    }
    await super.syncDirectory(path);
  }

  @override
  Future<void> syncFile(String path) async {
    files.add(path);
    if (fail) throw StateError('Injected private storage barrier failure');
    await super.syncFile(path);
  }
}

class _BlockingBarrier extends IoFileSystem {
  var blockNext = false;
  final entered = Completer<void>();
  final release = Completer<void>();
  @override
  Future<void> syncFile(String path) async {
    if (blockNext) {
      blockNext = false;
      entered.complete();
      await release.future;
    }
    await super.syncFile(path);
  }
}
