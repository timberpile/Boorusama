import 'package:foundation/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:boorusama/core/backups/sources/bookmark_backup_data.dart';
import 'package:boorusama/core/backups/sources/bookmark_backup_importer.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_group.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_group_repository.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_repository.dart';
import 'package:boorusama/core/posts/post/types.dart';

class MockBookmarkRepository extends Mock implements BookmarkRepository {}

class MockBookmarkGroupRepository extends Mock
    implements BookmarkGroupRepository {}

void main() {
  late MockBookmarkRepository bookmarkRepository;
  late MockBookmarkGroupRepository groupRepository;
  late List<Bookmark> storedBookmarks;
  late List<BookmarkGroup> storedGroups;
  late Map<int, Set<int>> memberships;

  ImageUrlResolver resolver(int? _) =>
      const DefaultImageUrlResolver();

  setUp(() {
    bookmarkRepository = MockBookmarkRepository();
    groupRepository = MockBookmarkGroupRepository();
    storedBookmarks = [
      Bookmark.empty.copyWith(
        id: 10,
        originalUrl: 'https://example.com/existing.jpg',
      ),
    ];
    storedGroups = [const BookmarkGroup(id: 7, name: 'Favorites')];
    memberships = {};

    when(
      () => bookmarkRepository.getAllBookmarks(
        imageUrlResolver: any(named: 'imageUrlResolver'),
      ),
    ).thenAnswer((_) => TaskEither.right(storedBookmarks));
    when(() => bookmarkRepository.addBookmarkWithBookmarks(any())).thenAnswer(
      (invocation) async {
        final imported = invocation.positionalArguments.first as List<Bookmark>;
        var nextId = 100;
        storedBookmarks.addAll(
          imported.map((bookmark) => bookmark.copyWith(id: nextId++)),
        );
      },
    );
    when(
      () => groupRepository.getGroups(),
    ).thenAnswer((_) async => storedGroups);
    when(() => groupRepository.createGroup(any())).thenAnswer((
      invocation,
    ) async {
      final group = BookmarkGroup(
        id: storedGroups.length + 20,
        name: invocation.positionalArguments.first as String,
      );
      storedGroups = [...storedGroups, group];
      return group;
    });
    when(
      () => groupRepository.addBookmarkToGroup(
        bookmarkId: any(named: 'bookmarkId'),
        groupId: any(named: 'groupId'),
      ),
    ).thenAnswer((invocation) async {
      final bookmarkId = invocation.namedArguments[#bookmarkId] as int;
      final groupId = invocation.namedArguments[#groupId] as int;
      memberships.putIfAbsent(bookmarkId, () => {}).add(groupId);
    });
  });

  test('adds missing bookmarks and restores groups across local IDs', () async {
    final importedExisting = storedBookmarks.single.copyWith(
      id: 1,
      sourceUrl: 'different metadata is ignored',
    );
    final importedNew = Bookmark.empty.copyWith(
      id: 2,
      originalUrl: 'https://example.com/new.jpg',
    );
    final data = BookmarkBackupData(
      bookmarks: [importedExisting, importedNew],
      groups: [
        const BookmarkGroupBackup(name: 'favorites', bookmarkIds: [1, 2]),
        const BookmarkGroupBackup(name: 'Missing', bookmarkIds: [999]),
      ],
    );

    await importBookmarkBackup(
      data: data,
      bookmarkRepository: bookmarkRepository,
      bookmarkGroupRepository: groupRepository,
      imageUrlResolver: resolver,
    );

    expect(storedBookmarks, hasLength(2));
    expect(storedBookmarks.first.id, 10);
    expect(
      storedBookmarks.first.sourceUrl,
      isNot('different metadata is ignored'),
    );
    expect(storedGroups, [
      const BookmarkGroup(id: 7, name: 'Favorites'),
      const BookmarkGroup(id: 21, name: 'Missing'),
    ]);
    expect(memberships, {
      10: {7},
      100: {7},
    });
    verifyNever(() => groupRepository.createGroup('favorites'));
    verify(() => groupRepository.createGroup('Missing')).called(1);
  });

  test(
    'reuses existing groups and makes repeated imports idempotent',
    () async {
      final bookmark = Bookmark.empty.copyWith(
        id: 1,
        originalUrl: 'https://example.com/image.jpg',
      );
      final data = BookmarkBackupData(
        bookmarks: [bookmark],
        groups: [
          const BookmarkGroupBackup(name: 'New Group', bookmarkIds: [1]),
        ],
      );

      await importBookmarkBackup(
        data: data,
        bookmarkRepository: bookmarkRepository,
        bookmarkGroupRepository: groupRepository,
        imageUrlResolver: resolver,
      );
      await importBookmarkBackup(
        data: data,
        bookmarkRepository: bookmarkRepository,
        bookmarkGroupRepository: groupRepository,
        imageUrlResolver: resolver,
      );

      expect(storedBookmarks, hasLength(2));
      expect(storedGroups.map((group) => group.name), [
        'Favorites',
        'New Group',
      ]);
      expect(memberships, {
        100: {21},
      });
      verify(() => groupRepository.createGroup('New Group')).called(1);
    },
  );

  test('reports total and already-existing bookmark counts', () async {
    final importedExisting = storedBookmarks.single.copyWith(id: 1);
    final importedNew = Bookmark.empty.copyWith(
      id: 2,
      originalUrl: 'https://example.com/new-counted.jpg',
    );

    final result = await importBookmarkBackup(
      data: BookmarkBackupData(
        bookmarks: [importedExisting, importedNew],
        groups: const [],
      ),
      bookmarkRepository: bookmarkRepository,
      bookmarkGroupRepository: groupRepository,
      imageUrlResolver: resolver,
    );

    expect(result.totalCount, 2);
    expect(result.alreadyExistedCount, 1);
  });

  test(
    'reports zero existing bookmarks when every imported bookmark is new',
    () async {
      final result = await importBookmarkBackup(
        data: BookmarkBackupData(
          bookmarks: [
            Bookmark.empty.copyWith(
              id: 1,
              originalUrl: 'https://example.com/new-one.jpg',
            ),
            Bookmark.empty.copyWith(
              id: 2,
              originalUrl: 'https://example.com/new-two.jpg',
            ),
          ],
          groups: const [],
        ),
        bookmarkRepository: bookmarkRepository,
        bookmarkGroupRepository: groupRepository,
        imageUrlResolver: resolver,
      );

      expect(result.totalCount, 2);
      expect(result.alreadyExistedCount, 0);
    },
  );

  test(
    'reports all imported bookmarks as existing when none are added',
    () async {
      final result = await importBookmarkBackup(
        data: BookmarkBackupData(
          bookmarks: [storedBookmarks.single.copyWith(id: 1)],
          groups: const [],
        ),
        bookmarkRepository: bookmarkRepository,
        bookmarkGroupRepository: groupRepository,
        imageUrlResolver: resolver,
      );

      expect(result.totalCount, 1);
      expect(result.alreadyExistedCount, 1);
      verifyNever(() => bookmarkRepository.addBookmarkWithBookmarks(any()));
    },
  );
}
