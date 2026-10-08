import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foundation/foundation.dart';
import 'package:hive_ce/hive.dart';

import 'package:boorusama/core/backups/export_import/import/import_flow_notifier.dart';
import 'package:boorusama/core/backups/sources/providers.dart';
import 'package:boorusama/core/backups/types.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/bookmark_group_hive_object.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/bookmark_group_repository_hive.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/bookmark_hive_object.dart';
import 'package:boorusama/core/bookmarks/src/data/hive/repository.dart';
import 'package:boorusama/core/bookmarks/src/data/providers.dart';
import 'package:boorusama/core/bookmarks/src/providers/bookmark_provider.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_repository.dart';
import 'package:boorusama/core/hive/hive_adapters.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/settings/providers.dart';
import 'package:boorusama/core/settings/src/types/settings.dart';
import 'package:boorusama/foundation/filesystem.dart';
import 'package:boorusama/foundation/info/package_info.dart';

final _sourceProvider = Provider<PackageTransactionSource>(
  (ref) => PackageTransactionSource(
    source: ref.read(bookmarksBackupSourceProvider),
    incomingPath: null,
    fs: const IoFileSystem(),
    ref: ref,
    credentialsIncluded: false,
  ),
);

void main() {
  const groupId = '550e8400-e29b-41d4-a716-446655440000';
  late Directory tempDirectory;
  late Box<BookmarkHiveObject> bookmarkBox;
  late Box<BookmarkGroupHiveObject> groupBox;
  late BookmarkHiveRepository bookmarkRepository;
  late BookmarkGroupRepositoryHive groupRepository;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp(
      'import_bookmark_refresh_',
    );
    Hive.init(tempDirectory.path);
    if (!Hive.isAdapterRegistered(4)) {
      Hive.registerAdapter(BookmarkHiveObjectAdapter());
    }
    if (!Hive.isAdapterRegistered(5)) {
      Hive.registerAdapter(BookmarkGroupHiveObjectAdapter());
    }
    bookmarkBox = await Hive.openBox<BookmarkHiveObject>('bookmarks_test');
    groupBox = await Hive.openBox<BookmarkGroupHiveObject>('groups_test');
    bookmarkRepository = BookmarkHiveRepository(bookmarkBox);
    groupRepository = BookmarkGroupRepositoryHive(groupBox);
  });

  tearDown(() async {
    await bookmarkBox.close();
    await groupBox.close();
    await tempDirectory.delete(recursive: true);
  });

  ProviderContainer createContainer() {
    final container = ProviderContainer(
      overrides: [
        bookmarkRepoProvider.overrideWith((ref) => bookmarkRepository),
        bookmarkGroupRepoProvider.overrideWith((ref) => groupRepository),
        bookmarkUrlResolverProvider.overrideWith(
          (ref, booruId) => const DefaultImageUrlResolver(),
        ),
        appVersionProvider.overrideWith((ref) => null),
        settingsNotifierProvider.overrideWith(
          () => _TestSettingsNotifier(Settings.defaultSettings),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test(
    'invalid group references fail preparation without changing local data',
    () async {
      final saved = (await bookmarkRepository.addBookmarkWithBookmarks([
        _bookmark(1),
      ])).single;
      await groupRepository.createGroup('Local', id: groupId);
      await groupRepository.addBookmarks(groupId, {saved.id});
      final container = createContainer();
      final source = container.read(bookmarksBackupSourceProvider);
      final encoded = source.converter.encode(
        payload: const [],
        extraFields: {
          'groups': [
            {
              'id': groupId,
              'name': 'Imported',
              'bookmarkIds': [999],
            },
          ],
        },
      );

      await expectLater(
        source.validateEncodedImport(encoded),
        throwsA(isA<InvalidBackupFormatException>()),
      );
      expect(
        await bookmarkRepository.getAllBookmarksOrThrow(
          imageUrlResolver: (_) => const DefaultImageUrlResolver(),
        ),
        [saved],
      );
      expect((await groupRepository.getGroup(groupId))?.name, 'Local');
      expect((await groupRepository.getGroup(groupId))?.bookmarkIds, {
        saved.id,
      });
    },
  );

  test(
    'a newly imported group is visible when import completion is shown',
    () async {
      final container = createContainer();
      await container.read(bookmarkProvider.future);
      final saved = await bookmarkRepository.addBookmarkWithBookmarks([
        _bookmark(1),
        _bookmark(2),
      ]);
      await groupRepository.createGroup('Shared', id: groupId);
      await groupRepository.replaceMemberships(groupId, {
        for (final bookmark in saved) bookmark.id,
      });

      await container.read(_sourceProvider).restart();

      final library = container.read(bookmarkProvider).requireValue;
      expect(library.groups.single.name, 'Shared');
      expect(library.groups.single.bookmarkIds, {
        for (final bookmark in saved) bookmark.id,
      });
      expect(library.items, hasLength(2));
    },
  );

  test(
    'an updated group shows its third bookmark before import completes',
    () async {
      final firstTwo = await bookmarkRepository.addBookmarkWithBookmarks([
        _bookmark(1),
        _bookmark(2),
      ]);
      await groupRepository.createGroup('Shared', id: groupId);
      await groupRepository.replaceMemberships(groupId, {
        for (final bookmark in firstTwo) bookmark.id,
      });
      final container = createContainer();
      expect(
        (await container.read(bookmarkProvider.future)).items,
        hasLength(2),
      );
      final third = (await bookmarkRepository.addBookmarkWithBookmarks([
        _bookmark(3),
      ])).single;
      await groupRepository.replaceMemberships(groupId, {
        for (final bookmark in firstTwo) bookmark.id,
        third.id,
      });

      await container.read(_sourceProvider).restart();

      final library = container.read(bookmarkProvider).requireValue;
      expect(library.groups.single.bookmarkIds, hasLength(3));
      expect(library.items, hasLength(3));
    },
  );

  test(
    'a failed bookmark refresh does not report a committed import as failed',
    () async {
      bookmarkRepository = _FailingSecondReadBookmarkRepository(bookmarkBox);
      final container = createContainer();
      await container.read(bookmarkProvider.future);

      final source = container.read(_sourceProvider);
      await source.restart();

      expect(source.bookmarkRefreshFailed, true);
    },
  );
}

Bookmark _bookmark(int id) => Bookmark.empty.copyWith(
  originalUrl: 'https://example.com/post/$id',
  sourceUrl: 'https://example.com',
  postId: () => id,
);

class _TestSettingsNotifier extends SettingsNotifier {
  _TestSettingsNotifier(super.initialSettings);
}

class _FailingSecondReadBookmarkRepository extends BookmarkHiveRepository {
  _FailingSecondReadBookmarkRepository(super._box);

  var _readCount = 0;

  @override
  BookmarksOrError getAllBookmarks({
    required ImageUrlResolver Function(int? booruId) imageUrlResolver,
  }) {
    _readCount++;
    if (_readCount == 2) {
      return TaskEither.left(BookmarkGetError.unknown);
    }
    return super.getAllBookmarks(imageUrlResolver: imageUrlResolver);
  }
}
