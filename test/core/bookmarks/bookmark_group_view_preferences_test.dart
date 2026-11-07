import 'dart:async';
import 'dart:convert';

import 'package:boorusama/core/bookmarks/src/providers/bookmark_group_view_preferences.dart';
import 'package:boorusama/core/cache/misc_data_store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:test/test.dart';

const groupA = 'abcdefab-cdef-4abc-8def-abcdefabcdef';
const groupB = '20000000-0000-4000-8000-000000000002';
const groupC = '30000000-0000-4000-8000-000000000003';
const groupD = '40000000-0000-4000-8000-000000000004';
const storageKey = 'bookmarkGroupViewModes';

class _Store implements MiscDataStore {
  final values = <String, String>{};
  int writes = 0;
  bool failNext = false;
  Completer<void>? started;
  Completer<void>? release;

  @override
  String? get(String key) => values[key];

  @override
  Future<void> put(String key, String value) async {
    writes++;
    if (started case final signal? when !signal.isCompleted) {
      signal.complete();
    }
    if (release case final gate?) await gate.future;
    if (failNext) {
      failNext = false;
      throw StateError('write failed');
    }
    values[key] = value;
  }
}

void main() {
  group('BookmarkGroupViewPreferences', () {
    test('defaults to Structure and exposes an immutable map', () {
      final store = _Store();
      final container = ProviderContainer(
        overrides: [miscDataStoreProvider.overrideWithValue(store)],
      );
      addTearDown(container.dispose);
      final preferences = container.read(
        bookmarkGroupViewPreferencesProvider.notifier,
      );

      expect(preferences.modeFor(groupA), BookmarkGroupViewMode.structure);
      expect(container.read(bookmarkGroupViewPreferencesProvider), isEmpty);
      expect(
        () => container.read(bookmarkGroupViewPreferencesProvider)[groupA] =
            BookmarkGroupViewMode.allBookmarks,
        throwsUnsupportedError,
      );
    });

    test(
      'round-trips per UUID values through a new provider container',
      () async {
        final store = _Store();
        final first = ProviderContainer(
          overrides: [miscDataStoreProvider.overrideWithValue(store)],
        );
        final preferences = first.read(
          bookmarkGroupViewPreferencesProvider.notifier,
        );
        await preferences.setMode(groupA, BookmarkGroupViewMode.allBookmarks);
        await preferences.setMode(groupB, BookmarkGroupViewMode.structure);
        first.dispose();

        final reopened = ProviderContainer(
          overrides: [miscDataStoreProvider.overrideWithValue(store)],
        );
        addTearDown(reopened.dispose);
        final reopenedPreferences = reopened.read(
          bookmarkGroupViewPreferencesProvider.notifier,
        );
        expect(
          reopenedPreferences.modeFor(groupA),
          BookmarkGroupViewMode.allBookmarks,
        );
        expect(
          reopenedPreferences.modeFor(groupB),
          BookmarkGroupViewMode.structure,
        );
      },
    );

    test('normalizes UUID casing and rejects invalid identities', () async {
      final store = _Store();
      final container = ProviderContainer(
        overrides: [miscDataStoreProvider.overrideWithValue(store)],
      );
      addTearDown(container.dispose);
      final preferences = container.read(
        bookmarkGroupViewPreferencesProvider.notifier,
      );

      await preferences.setMode(
        groupA.toUpperCase(),
        BookmarkGroupViewMode.allBookmarks,
      );
      expect(preferences.modeFor(groupA), BookmarkGroupViewMode.allBookmarks);
      await expectLater(
        preferences.setMode('not-a-uuid', BookmarkGroupViewMode.structure),
        throwsArgumentError,
      );
      expect(jsonDecode(store.values[storageKey]!), {groupA: 'allBookmarks'});
    });

    test('keeps state unchanged after persistence failure', () async {
      final store = _Store()..failNext = true;
      final container = ProviderContainer(
        overrides: [miscDataStoreProvider.overrideWithValue(store)],
      );
      addTearDown(container.dispose);
      final preferences = container.read(
        bookmarkGroupViewPreferencesProvider.notifier,
      );

      await expectLater(
        preferences.setMode(groupA, BookmarkGroupViewMode.allBookmarks),
        throwsStateError,
      );
      expect(preferences.modeFor(groupA), BookmarkGroupViewMode.structure);
      expect(container.read(bookmarkGroupViewPreferencesProvider), isEmpty);

      await preferences.setMode(groupA, BookmarkGroupViewMode.allBookmarks);
      expect(preferences.modeFor(groupA), BookmarkGroupViewMode.allBookmarks);
    });

    test('serializes concurrent updates without losing either UUID', () async {
      final store = _Store()
        ..started = Completer<void>()
        ..release = Completer<void>();
      final container = ProviderContainer(
        overrides: [miscDataStoreProvider.overrideWithValue(store)],
      );
      addTearDown(container.dispose);
      final preferences = container.read(
        bookmarkGroupViewPreferencesProvider.notifier,
      );

      final first = preferences.setMode(
        groupA,
        BookmarkGroupViewMode.allBookmarks,
      );
      await store.started!.future;
      final second = preferences.setMode(
        groupB,
        BookmarkGroupViewMode.allBookmarks,
      );
      store.release!.complete();
      await Future.wait([first, second]);

      expect(preferences.modeFor(groupA), BookmarkGroupViewMode.allBookmarks);
      expect(preferences.modeFor(groupB), BookmarkGroupViewMode.allBookmarks);
      expect(jsonDecode(store.values[storageKey]!), {
        groupA: 'allBookmarks',
        groupB: 'allBookmarks',
      });
    });

    test(
      'does not update disposed provider state after an in-flight write',
      () async {
        final store = _Store()
          ..started = Completer<void>()
          ..release = Completer<void>();
        final container = ProviderContainer(
          overrides: [miscDataStoreProvider.overrideWithValue(store)],
        );
        final preferences = container.read(
          bookmarkGroupViewPreferencesProvider.notifier,
        );

        final write = preferences.setMode(
          groupA,
          BookmarkGroupViewMode.allBookmarks,
        );
        await store.started!.future;
        container.dispose();
        store.release!.complete();
        await write;

        expect(jsonDecode(store.values[storageKey]!), {groupA: 'allBookmarks'});
      },
    );

    test('forgets only the requested UUID and avoids no-op writes', () async {
      final store = _Store();
      final container = ProviderContainer(
        overrides: [miscDataStoreProvider.overrideWithValue(store)],
      );
      addTearDown(container.dispose);
      final preferences = container.read(
        bookmarkGroupViewPreferencesProvider.notifier,
      );

      await preferences.setMode(groupA, BookmarkGroupViewMode.structure);
      expect(store.writes, 0);
      await preferences.forgetGroup(groupA);
      expect(store.writes, 0);
      await preferences.setMode(groupA, BookmarkGroupViewMode.allBookmarks);
      await preferences.setMode(groupB, BookmarkGroupViewMode.allBookmarks);
      final writesBeforeNoOp = store.writes;
      await preferences.setMode(groupA, BookmarkGroupViewMode.allBookmarks);
      expect(store.writes, writesBeforeNoOp);

      await preferences.forgetGroup(groupA);
      expect(preferences.modeFor(groupA), BookmarkGroupViewMode.structure);
      expect(preferences.modeFor(groupB), BookmarkGroupViewMode.allBookmarks);
      expect(jsonDecode(store.values[storageKey]!), {groupB: 'allBookmarks'});
    });

    test(
      'batch forget and retain preserve remaining group preferences',
      () async {
        final store = _Store();
        final container = ProviderContainer(
          overrides: [miscDataStoreProvider.overrideWithValue(store)],
        );
        addTearDown(container.dispose);
        final preferences = container.read(
          bookmarkGroupViewPreferencesProvider.notifier,
        );
        await preferences.setMode(groupA, BookmarkGroupViewMode.allBookmarks);
        await preferences.setMode(groupB, BookmarkGroupViewMode.allBookmarks);
        await preferences.setMode(groupC, BookmarkGroupViewMode.allBookmarks);

        final writesBeforeBatchForget = store.writes;
        await preferences.forgetGroups({groupA, groupB});
        expect(store.writes, writesBeforeBatchForget + 1);
        expect(container.read(bookmarkGroupViewPreferencesProvider), {
          groupC: BookmarkGroupViewMode.allBookmarks,
        });

        await preferences.setMode(groupD, BookmarkGroupViewMode.allBookmarks);
        final writesBeforePrune = store.writes;
        await preferences.retainGroups({groupC});
        expect(store.writes, writesBeforePrune + 1);
        expect(container.read(bookmarkGroupViewPreferencesProvider), {
          groupC: BookmarkGroupViewMode.allBookmarks,
        });
        expect(jsonDecode(store.values[storageKey]!), {groupC: 'allBookmarks'});
      },
    );

    test('failed batch writes leave the published map unchanged', () async {
      final store = _Store();
      final container = ProviderContainer(
        overrides: [miscDataStoreProvider.overrideWithValue(store)],
      );
      addTearDown(container.dispose);
      final preferences = container.read(
        bookmarkGroupViewPreferencesProvider.notifier,
      );
      await preferences.setMode(groupA, BookmarkGroupViewMode.allBookmarks);
      await preferences.setMode(groupB, BookmarkGroupViewMode.allBookmarks);
      final original = container.read(bookmarkGroupViewPreferencesProvider);
      final originalJson = store.values[storageKey];

      store.failNext = true;
      await expectLater(
        preferences.forgetGroups({groupA, groupB}),
        throwsStateError,
      );
      expect(container.read(bookmarkGroupViewPreferencesProvider), original);
      expect(store.values[storageKey], originalJson);

      store.failNext = true;
      await expectLater(
        preferences.restoreMissing({
          groupC: BookmarkGroupViewMode.structure,
        }),
        throwsStateError,
      );
      expect(container.read(bookmarkGroupViewPreferencesProvider), original);
      expect(store.values[storageKey], originalJson);

      store.failNext = true;
      await expectLater(preferences.retainGroups({groupA}), throwsStateError);
      expect(container.read(bookmarkGroupViewPreferencesProvider), original);
      expect(store.values[storageKey], originalJson);
    });

    test('restoreMissing fills only absent IDs in one write', () async {
      final store = _Store();
      final container = ProviderContainer(
        overrides: [miscDataStoreProvider.overrideWithValue(store)],
      );
      addTearDown(container.dispose);
      final preferences = container.read(
        bookmarkGroupViewPreferencesProvider.notifier,
      );
      await preferences.setMode(groupA, BookmarkGroupViewMode.allBookmarks);
      final writesBeforeRestore = store.writes;

      await preferences.restoreMissing({
        groupA: BookmarkGroupViewMode.structure,
        groupB: BookmarkGroupViewMode.structure,
        groupC: BookmarkGroupViewMode.allBookmarks,
      });

      expect(store.writes, writesBeforeRestore + 1);
      expect(preferences.modeFor(groupA), BookmarkGroupViewMode.allBookmarks);
      expect(preferences.modeFor(groupB), BookmarkGroupViewMode.structure);
      expect(preferences.modeFor(groupC), BookmarkGroupViewMode.allBookmarks);
      expect(container.read(bookmarkGroupViewPreferencesProvider).keys, {
        groupA,
        groupB,
        groupC,
      });
      final writesAfterRestore = store.writes;
      await preferences.restoreMissing({
        groupA: BookmarkGroupViewMode.structure,
        groupB: BookmarkGroupViewMode.allBookmarks,
      });
      expect(store.writes, writesAfterRestore);
      expect(preferences.modeFor(groupA), BookmarkGroupViewMode.allBookmarks);
      expect(preferences.modeFor(groupB), BookmarkGroupViewMode.structure);
    });

    test('queued mode changes retain the result of a batch restore', () async {
      final store = _Store()
        ..started = Completer<void>()
        ..release = Completer<void>();
      final container = ProviderContainer(
        overrides: [miscDataStoreProvider.overrideWithValue(store)],
      );
      addTearDown(container.dispose);
      final preferences = container.read(
        bookmarkGroupViewPreferencesProvider.notifier,
      );

      final restore = preferences.restoreMissing({
        groupA: BookmarkGroupViewMode.allBookmarks,
      });
      await store.started!.future;
      final modeChange = preferences.setMode(
        groupB,
        BookmarkGroupViewMode.allBookmarks,
      );
      store.release!.complete();
      await Future.wait([restore, modeChange]);

      expect(preferences.modeFor(groupA), BookmarkGroupViewMode.allBookmarks);
      expect(preferences.modeFor(groupB), BookmarkGroupViewMode.allBookmarks);
      expect(jsonDecode(store.values[storageKey]!), {
        groupA: 'allBookmarks',
        groupB: 'allBookmarks',
      });
    });

    test('batch helpers avoid writes when they make no changes', () async {
      final store = _Store();
      final container = ProviderContainer(
        overrides: [miscDataStoreProvider.overrideWithValue(store)],
      );
      addTearDown(container.dispose);
      final preferences = container.read(
        bookmarkGroupViewPreferencesProvider.notifier,
      );
      await preferences.setMode(groupA, BookmarkGroupViewMode.allBookmarks);
      final writes = store.writes;

      await preferences.forgetGroups({});
      await preferences.forgetGroups({groupB});
      await preferences.retainGroups({groupA, groupB});
      await preferences.restoreMissing({
        groupA: BookmarkGroupViewMode.structure,
      });

      expect(store.writes, writes);
      expect(container.read(bookmarkGroupViewPreferencesProvider), {
        groupA: BookmarkGroupViewMode.allBookmarks,
      });
    });

    test('ignores malformed JSON and invalid or unknown entries safely', () {
      final store = _Store()..values[storageKey] = '{broken';
      final malformed = ProviderContainer(
        overrides: [miscDataStoreProvider.overrideWithValue(store)],
      );
      addTearDown(malformed.dispose);
      expect(
        malformed
            .read(bookmarkGroupViewPreferencesProvider.notifier)
            .modeFor(groupA),
        BookmarkGroupViewMode.structure,
      );

      store.values[storageKey] = jsonEncode({
        groupA: 'unknownMode',
        'invalid-id': 'allBookmarks',
        groupB.toUpperCase(): 'allBookmarks',
        'not-a-string': 12,
      });
      final defensive = ProviderContainer(
        overrides: [miscDataStoreProvider.overrideWithValue(store)],
      );
      addTearDown(defensive.dispose);
      final preferences = defensive.read(
        bookmarkGroupViewPreferencesProvider.notifier,
      );
      expect(preferences.modeFor(groupA), BookmarkGroupViewMode.structure);
      expect(preferences.modeFor(groupB), BookmarkGroupViewMode.allBookmarks);
      expect(
        defensive.read(bookmarkGroupViewPreferencesProvider).keys,
        {groupB},
      );
    });
  });
}
