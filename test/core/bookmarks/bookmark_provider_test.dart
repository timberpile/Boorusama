// Package imports:
import 'package:foundation/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

// Project imports:
import 'package:boorusama/core/bookmarks/src/data/providers.dart';
import 'package:boorusama/core/bookmarks/src/data/bookmark_convert.dart';
import 'package:boorusama/core/bookmarks/src/providers/bookmark_provider.dart';
import 'package:boorusama/core/bookmarks/src/providers/local_providers.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_group_repository.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_repository.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/posts/post/providers.dart';
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
        postLinkGeneratorProvider.overrideWith(
          (ref, config) => const NoLinkPostLinkGenerator(),
        ),
        bookmarkImageCacheManagerProvider.overrideWithValue(null),
        settingsProvider.overrideWithValue(Settings.defaultSettings),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test(
    'removing the final named membership deletes the bookmark for single-post editing',
    () async {
      membershipsByBookmark = {
        bookmark.id: {7},
      };
      final container = createContainer();
      final notifier = container.read(bookmarkProvider.notifier);
      var success = false;

      await notifier.future;
      await notifier.removeFromGroupAndDeleteIfLast(
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
    },
  );

  test(
    'removing the final named membership for bulk editing preserves the bookmark',
    () async {
      membershipsByBookmark = {
        bookmark.id: {7},
      };
      final container = createContainer();
      final notifier = container.read(bookmarkProvider.notifier);

      await notifier.future;
      await notifier.removeBookmarkFromGroup(bookmark.uniqueId, 7);

      final state = container.read(bookmarkProvider).value;
      expect(state?.bookmarks.contains(bookmark.uniqueId), isTrue);
      expect(state?.memberships[bookmark.uniqueId], isEmpty);
      expect(
        filterBookmarks(
          bookmarks: storedBookmarks,
          selectedTags: const [],
          sortType: BookmarkSortType.newest,
          membershipsByBookmark: membershipsByBookmark,
          selectedBookmarkGroupId: -1,
        ),
        contains(bookmark),
      );
      verifyNever(() => bookmarkRepository.removeBookmarks(any()));
    },
  );

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

  test(
    'adding selected bookmarks to a named group preserves other memberships',
    () async {
      membershipsByBookmark = {
        bookmark.id: {8},
      };
      final container = createContainer();
      final notifier = container.read(bookmarkProvider.notifier);

      await notifier.future;
      final changed = await notifier.addPostsToGroup(
        BooruConfigAuth.fromConfig(BooruConfig.empty),
        [bookmark.toPost()],
        7,
      );

      expect(changed, 1);
      expect(
        container.read(bookmarkProvider).value?.memberships[bookmark.uniqueId],
        {7, 8},
      );
    },
  );

  test(
    'bulk removal leaves a final membership as an ungrouped bookmark',
    () async {
      membershipsByBookmark = {
        bookmark.id: {7},
      };
      final container = createContainer();
      final notifier = container.read(bookmarkProvider.notifier);

      await notifier.future;
      final result = await notifier.removePostsFromGroup(
        BooruConfigAuth.fromConfig(BooruConfig.empty),
        [bookmark.toPost()],
        7,
      );

      final state = container.read(bookmarkProvider).value;
      expect(result.removedCount, 1);
      expect(result.movedToNoGroupCount, 1);
      expect(state?.bookmarks.contains(bookmark.uniqueId), isTrue);
      expect(state?.memberships[bookmark.uniqueId], isEmpty);
      verifyNever(() => bookmarkRepository.removeBookmarks(any()));
    },
  );

  test(
    'bulk removal counts only memberships in the selected group',
    () async {
      final otherBookmark = Bookmark.empty.copyWith(id: 2);
      storedBookmarks = [bookmark, otherBookmark];
      membershipsByBookmark = {
        bookmark.id: {7, 8},
        otherBookmark.id: {8},
      };
      final container = createContainer();
      final notifier = container.read(bookmarkProvider.notifier);

      await notifier.future;
      final result = await notifier.removePostsFromGroup(
        BooruConfigAuth.fromConfig(BooruConfig.empty),
        [bookmark.toPost(), otherBookmark.toPost(), DemoPost()],
        7,
      );

      expect(result.removedCount, 1);
      expect(result.movedToNoGroupCount, 0);
      expect(membershipsByBookmark[bookmark.id], {8});
      expect(membershipsByBookmark[otherBookmark.id], {8});
    },
  );

  test(
    'adding selected grouped bookmarks to No Group does not clear memberships',
    () async {
      membershipsByBookmark = {
        bookmark.id: {8},
      };
      final container = createContainer();
      final notifier = container.read(bookmarkProvider.notifier);

      await notifier.future;
      final changed = await notifier.addPostsToGroup(
        BooruConfigAuth.fromConfig(BooruConfig.empty),
        [bookmark.toPost()],
        -1,
      );

      expect(changed, 0);
      expect(
        container.read(bookmarkProvider).value?.memberships[bookmark.uniqueId],
        {8},
      );
    },
  );

  test('adding an unbookmarked post to No Group creates a bookmark', () async {
    storedBookmarks = [];
    final addedBookmark = bookmark.copyWith(id: 2);
    when(
      () => bookmarkRepository.addBookmarks(
        any(),
        any(),
        imageUrlResolver: any(named: 'imageUrlResolver'),
        postLinkGenerator: any(named: 'postLinkGenerator'),
      ),
    ).thenAnswer((_) async {
      storedBookmarks.add(addedBookmark);
      return [addedBookmark];
    });

    final container = createContainer();
    final notifier = container.read(bookmarkProvider.notifier);

    await notifier.future;
    final changed = await notifier.addPostsToGroup(
      BooruConfigAuth.fromConfig(BooruConfig.empty),
      [DemoPost()],
      -1,
    );

    expect(changed, 1);
    expect(
      container.read(bookmarkProvider).value?.bookmarks,
      contains(addedBookmark.uniqueId),
    );
    verify(
      () => bookmarkRepository.addBookmarks(
        any(),
        any(),
        imageUrlResolver: any(named: 'imageUrlResolver'),
        postLinkGenerator: any(named: 'postLinkGenerator'),
      ),
    ).called(1);
  });
}
