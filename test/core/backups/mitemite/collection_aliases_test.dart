import 'dart:async';
import 'dart:convert';

import 'package:boorusama/core/backups/mitemite/collection_aliases.dart';
import 'package:boorusama/core/backups/mitemite/protocol.dart';
import 'package:boorusama/core/cache/misc_data_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final group = SyncCollectionId(
    publisher: '11111111-1111-4111-8111-111111111111',
    kind: 'bookmarks',
    source: '22222222-2222-4222-8222-222222222222',
  );
  final folder = SyncCollectionId(
    publisher: group.publisher,
    kind: 'following_topics',
    source: group.source,
  );
  final foreign = SyncCollectionId(
    publisher: '33333333-3333-4333-8333-333333333333',
    kind: 'bookmarks',
    source: group.source,
  );

  test(
    'normalize, edit and clear without unrelated private preference writes',
    () async {
      final preferences = _Store()..values['mitemite.v1.identity'] = 'keep';
      final aliases = SyncCollectionAliases(preferences);
      expect(aliases.values, isEmpty);
      await aliases.set(group, '  My Group  ');
      expect(aliases.values[group], 'My Group');
      expect(SyncCollectionAliases(preferences).values[group], 'My Group');
      final writes = preferences.writes;
      await aliases.set(group, 'My Group');
      expect(preferences.writes, writes);
      await aliases.set(group, 'Edited');
      await aliases.set(group, ' \n ');
      expect(aliases.values, isEmpty);
      expect(SyncCollectionAliases(preferences).values, isEmpty);
      expect(preferences.values.keys, {
        'mitemite.v1.identity',
        SyncCollectionAliases.key,
      });
      expect(preferences.values['mitemite.v1.identity'], 'keep');
    },
  );

  test(
    'source identity separates publishers and collection kinds over restart',
    () async {
      final preferences = _Store();
      var aliases = SyncCollectionAliases(preferences);
      await aliases.set(group, 'Group');
      await aliases.set(folder, 'Folder');
      await aliases.set(foreign, 'Other device');
      aliases = SyncCollectionAliases(preferences);
      expect(aliases.values, {
        group: 'Group',
        folder: 'Folder',
        foreign: 'Other device',
      });
      await aliases.retain('bookmarks', {foreign});
      expect(aliases.values, {folder: 'Folder', foreign: 'Other device'});
      await aliases.forget(foreign.publisher);
      expect(aliases.values, {folder: 'Folder'});
      await aliases.set(folder, null);
      expect(aliases.values, isEmpty);
    },
  );

  test('cached failed writes retain confirmed labels and clear reasserts durable state', () async {
    final preferences = _Store();
    final aliases = SyncCollectionAliases(preferences);
    preferences.fail = true;
    await expectLater(aliases.set(group, 'Unconfirmed'), throwsStateError);
    expect(aliases.values, isEmpty);
    // Even though clearing equals the confirmed display state, it must replace
    // the failed cached preference before an unrelated later durability barrier.
    await aliases.set(group, null);
    expect(preferences.writes, 2);
    expect(SyncCollectionAliases(preferences).values, isEmpty);
  });

  test(
    'serialized edits preserve aliases for independent identities',
    () async {
      final preferences = _Store();
      final aliases = SyncCollectionAliases(preferences);
      final entered = Completer<void>();
      final release = Completer<void>();
      preferences.hold = () {
        entered.complete();
        return release.future;
      };
      final first = aliases.set(group, 'First');
      await entered.future;
      final second = aliases.set(folder, 'Second');
      expect(aliases.values, isEmpty);
      release.complete();
      await Future.wait([first, second]);
      expect(SyncCollectionAliases(preferences).values, {
        group: 'First',
        folder: 'Second',
      });
    },
  );

  test('reject malformed metadata and oversized labels without changing saved values', () async {
    final preferences = _Store();
    final aliases = SyncCollectionAliases(preferences);
    await aliases.set(group, 'Keep');
    final saved = preferences.values[SyncCollectionAliases.key];
    await expectLater(aliases.set(group, 'x' * 161), throwsFormatException);
    expect(preferences.values[SyncCollectionAliases.key], saved);
    preferences.values[SyncCollectionAliases.key] = jsonEncode({
      'version': 1,
      'aliases': {'../invalid': 'value'},
    });
    expect(
      () => SyncCollectionAliases(preferences).values,
      throwsFormatException,
    );
  });
}

final class _Store implements MiscDataStore {
  final values = <String, String>{};
  var writes = 0;
  var fail = false;
  Future<void> Function()? hold;
  @override
  String? get(String key) => values[key];
  @override
  Future<void> put(String key, String value) async {
    writes++;
    values[key] = value;
    final pending = hold;
    hold = null;
    if (pending != null) await pending();
    if (fail) {
      fail = false;
      throw StateError('failed cached write');
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
