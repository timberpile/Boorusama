import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:boorusama/core/bookmarks/src/providers/bookmark_provider.dart';
import 'package:boorusama/core/bookmarks/types.dart';
import 'package:boorusama/core/bookmarks/server_favorites.dart';
import 'package:boorusama/core/cache/misc_data_store.dart';
import 'package:boorusama/foundation/data_mutation_coordinator.dart';

class _Store implements MiscDataStore {
  String? value;
  bool fail = false;
  int writes = 0;

  @override
  String? get(String key) => value;

  @override
  Future<void> put(String key, String value) async {
    if (fail) throw StateError('storage unavailable');
    writes++;
    this.value = value;
  }
}

class _Library extends BookmarkLibraryNotifier {
  bool fail = false;
  int reads = 0;
  int admissions = 0;

  @override
  Future<T> runWithLibrary<T>(Future<T> Function() operation) =>
      ref.read(dataMutationCoordinatorProvider).runExclusive(() async {
        admissions++;
        if (fail) throw StateError('library unavailable');
        return operation();
      });

  final snapshot = BookmarkLibraryState(
    bookmarks: const [],
    groups: [
      BookmarkGroup(id: 'empty', name: 'Empty', bookmarkIds: {}),
      BookmarkGroup(id: 'populated', name: 'Populated', bookmarkIds: {1}),
    ],
  );

  @override
  Future<BookmarkLibraryState> build() async => snapshot;

  @override
  Future<BookmarkLibraryState> snapshotForExport() async {
    reads++;
    if (fail) throw StateError('library unavailable');
    return snapshot;
  }
}

void main() {
  late _Store store;
  late _Library library;
  late ProviderContainer container;

  setUp(() {
    store = _Store();
    library = _Library();
    container = ProviderContainer(
      overrides: [
        miscDataStoreProvider.overrideWithValue(store),
        bookmarkLibraryProvider.overrideWith(() => library),
      ],
    );
  });

  tearDown(() => container.dispose());

  test(
    'initial state is disabled and reading it never loads bookmarks',
    () async {
      final settings = await container.read(
        serverFavoriteSettingsProvider.future,
      );
      expect(settings.resolve('profile'), isNull);
      expect(library.reads, 0);
      expect(store.writes, 0);
    },
  );

  test(
    'global assignment persists separately and survives provider recreation',
    () async {
      await container
          .read(serverFavoriteSettingsProvider.notifier)
          .setGlobal('empty');
      expect(store.writes, 1);
      final other = ProviderContainer(
        overrides: [
          miscDataStoreProvider.overrideWithValue(store),
        ],
      );
      addTearDown(other.dispose);
      expect(
        (await other.read(serverFavoriteSettingsProvider.future)).globalGroupId,
        'empty',
      );
    },
  );

  test('failed persistence keeps the previous resolved target', () async {
    final notifier = container.read(serverFavoriteSettingsProvider.notifier);
    await notifier.setGlobal('empty');
    store.fail = true;
    await expectLater(notifier.setGlobal(null), throwsStateError);
    expect(
      (await container.read(serverFavoriteSettingsProvider.future))
          .resolve('profile'),
      'empty',
    );
  });

  test(
    'populated first bindings preserve contents without confirmation',
    () async {
      final before = library.snapshot;
      await container
          .read(serverFavoriteSettingsProvider.notifier)
          .setGlobal('populated');
      expect(store.writes, 1);
      expect(library.snapshot, same(before));
      expect(library.snapshot.groupsById['populated']!.bookmarkIds, {1});
      expect(
        (await container.read(serverFavoriteSettingsProvider.future))
            .globalGroupId,
        'populated',
      );
    },
  );

  test('a missing destination still fails before saving settings', () async {
    await expectLater(
      container
          .read(serverFavoriteSettingsProvider.notifier)
          .setGlobal('deleted'),
      throwsA(
        isA<ServerFavoriteException>().having(
          (error) => error.problem,
          'problem',
          ServerFavoriteProblem.targetMissing,
        ),
      ),
    );
    expect(store.writes, 0);
    expect(
      (await container.read(serverFavoriteSettingsProvider.future))
          .globalGroupId,
      isNull,
    );
  });

  test(
    'disabling remains possible while the bookmark library is unavailable',
    () async {
      final notifier = container.read(serverFavoriteSettingsProvider.notifier);
      await notifier.setGlobal('empty');
      final reads = library.reads;
      final admissions = library.admissions;
      library.fail = true;
      await notifier.setGlobal(null);
      expect(library.reads, reads);
      expect(
        library.admissions,
        admissions,
        reason:
            'Disabling must not request admission to an unavailable library.',
      );
      expect(
        (await container.read(serverFavoriteSettingsProvider.future))
            .resolve('profile'),
        isNull,
      );
    },
  );

  test(
    'binding fails before writes when library admission is unavailable',
    () async {
      await container.read(serverFavoriteSettingsProvider.future);
      library.fail = true;
      await expectLater(
        container
            .read(serverFavoriteSettingsProvider.notifier)
            .setGlobal('empty'),
        throwsStateError,
      );
      expect(library.admissions, 1);
      expect(library.reads, 0);
      expect(store.writes, 0);
      expect(
        (await container.read(serverFavoriteSettingsProvider.future))
            .globalGroupId,
        isNull,
      );
    },
  );

  test(
    'corrupt settings fail closed without overwriting the stored value',
    () async {
      store.value = '{broken';
      await expectLater(
        container.read(serverFavoriteSettingsProvider.future),
        throwsFormatException,
      );
      expect(store.value, '{broken');
      expect(store.writes, 0);
    },
  );
}
