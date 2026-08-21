// Package imports:
import 'package:foundation/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

// Project imports:
import 'package:boorusama/core/bookmarks/src/data/providers.dart';
import 'package:boorusama/core/bookmarks/src/providers/bookmark_provider.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_group_repository.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_repository.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/settings/providers.dart';
import 'package:boorusama/core/settings/src/types/settings.dart';

class MockBookmarkRepository extends Mock implements BookmarkRepository {}

class MockBookmarkGroupRepository extends Mock
    implements BookmarkGroupRepository {}

void main() {
  late MockBookmarkRepository bookmarkRepository;
  late MockBookmarkGroupRepository groupRepository;
  late Bookmark bookmark;
  late List<Bookmark> storedBookmarks;
  late Map<int, Set<int>> membershipsByBookmark;

  setUp(() {
    bookmarkRepository = MockBookmarkRepository();
    groupRepository = MockBookmarkGroupRepository();
    bookmark = Bookmark.empty.copyWith(id: 1);
    storedBookmarks = [bookmark];
    membershipsByBookmark = {};

    when(
      () => bookmarkRepository.getAllBookmarks(
        imageUrlResolver: any(named: 'imageUrlResolver'),
      ),
    ).thenAnswer((_) => TaskEither.right(storedBookmarks));
    when(() => bookmarkRepository.removeBookmarks(any())).thenAnswer((
      invocation,
    ) async {
      final bookmarks =
          invocation.positionalArguments.first as Iterable<Bookmark>;
      storedBookmarks.removeWhere(bookmarks.contains);
    });
    when(
      () => groupRepository.pruneStaleMemberships(
        bookmarkIds: any(named: 'bookmarkIds'),
      ),
    ).thenAnswer((_) async {});
    when(() => groupRepository.getMembershipsByBookmark()).thenAnswer(
      (_) async => {
        for (final entry in membershipsByBookmark.entries)
          entry.key: {...entry.value},
      },
    );
    when(
      () => groupRepository.addBookmarkToGroup(
        bookmarkId: any(named: 'bookmarkId'),
        groupId: any(named: 'groupId'),
      ),
    ).thenAnswer((invocation) async {
      membershipsByBookmark
          .putIfAbsent(
            invocation.namedArguments[#bookmarkId] as int,
            () => <int>{},
          )
          .add(invocation.namedArguments[#groupId] as int);
    });
    when(
      () => groupRepository.removeBookmarkFromGroup(
        bookmarkId: any(named: 'bookmarkId'),
        groupId: any(named: 'groupId'),
      ),
    ).thenAnswer((invocation) async {
      membershipsByBookmark[invocation.namedArguments[#bookmarkId] as int]
          ?.remove(invocation.namedArguments[#groupId] as int);
    });
    when(
      () => groupRepository.removeBookmarkFromAllGroups(any()),
    ).thenAnswer((invocation) async {
      membershipsByBookmark.remove(invocation.positionalArguments.first as int);
    });
  });

  ProviderContainer createContainer() {
    final container = ProviderContainer(
      overrides: [
        bookmarkRepoProvider.overrideWith((ref) => bookmarkRepository),
        bookmarkGroupRepoProvider.overrideWith(
          (ref) => groupRepository,
        ),
        bookmarkUrlResolverProvider.overrideWith(
          (ref, booruId) => const DefaultImageUrlResolver(),
        ),
        bookmarkImageCacheManagerProvider.overrideWithValue(null),
        settingsProvider.overrideWithValue(Settings.defaultSettings),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('removing the final named membership deletes the bookmark', () async {
    membershipsByBookmark = {
      bookmark.id: {7},
    };
    final container = createContainer();
    final notifier = container.read(bookmarkProvider.notifier);
    var success = false;

    await notifier.future;
    await notifier.removeBookmarkFromGroup(
      bookmark.uniqueId,
      7,
      onSuccess: () => success = true,
    );

    expect(success, isTrue);
    expect(
      container
          .read(bookmarkProvider)
          .value
          ?.bookmarks
          .contains(
            bookmark.uniqueId,
          ),
      isFalse,
    );
    verify(() => bookmarkRepository.removeBookmarks([bookmark])).called(1);
  });

  test('removing one of several memberships preserves the bookmark', () async {
    membershipsByBookmark = {
      bookmark.id: {7, 8},
    };
    final container = createContainer();
    final notifier = container.read(bookmarkProvider.notifier);
    var success = false;

    await notifier.future;
    await notifier.removeBookmarkFromGroup(
      bookmark.uniqueId,
      7,
      onSuccess: () => success = true,
    );

    expect(success, isTrue);
    expect(
      container
          .read(bookmarkProvider)
          .value
          ?.bookmarks
          .contains(
            bookmark.uniqueId,
          ),
      isTrue,
    );
    expect(
      container.read(bookmarkProvider).value?.memberships[bookmark.uniqueId],
      {8},
    );
    verifyNever(() => bookmarkRepository.removeBookmarks(any()));
  });

  test(
    'adding an existing bookmark to a named group reports success',
    () async {
      final container = createContainer();
      final notifier = container.read(bookmarkProvider.notifier);
      var success = false;

      await notifier.future;
      await notifier.addBookmarkIdToGroup(
        bookmark.uniqueId,
        7,
        onSuccess: () => success = true,
      );

      expect(success, isTrue);
      expect(
        container.read(bookmarkProvider).value?.memberships[bookmark.uniqueId],
        {7},
      );
    },
  );
}
