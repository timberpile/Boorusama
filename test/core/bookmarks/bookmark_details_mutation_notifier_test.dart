import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:boorusama/core/bookmarks/src/providers/bookmark_details_mutation_notifier.dart';
import 'package:boorusama/core/bookmarks/src/providers/bookmark_provider.dart';
import 'package:boorusama/core/bookmarks/src/data/bookmark_convert.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_group.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_library_state.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_target.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/posts/post/types.dart';

void main() {
  final config = BooruConfig.empty.auth;
  final bookmark = Bookmark.empty.copyWith(
    originalUrl: 'https://example.com/deferred.jpg',
    sourceUrl: 'https://example.com',
    postId: () => 1,
  );
  final post = bookmark.toPost();
  final library = BookmarkLibraryState(
    bookmarks: [bookmark],
    groups: const [],
    activeTarget: const BookmarkTarget.ungrouped(),
  );

  test(
    'deferred toggles publish their intent and a second tap cancels them',
    () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(
        bookmarkDetailsMutationProvider.notifier,
      );
      notifier.begin();
      final visibleState = container.read(bookmarkDetailsMutationProvider);

      expect(
        notifier.toggle(config: config, post: post, library: library),
        BookmarkToggleOutcome.removed,
      );
      expect(notifier.pending, hasLength(1));
      expect(
        container.read(bookmarkDetailsMutationProvider).isVisible,
        visibleState.isVisible,
      );
      expect(
        container.read(bookmarkDetailsMutationProvider).pending,
        hasLength(1),
      );

      expect(
        notifier.toggle(config: config, post: post, library: library),
        BookmarkToggleOutcome.added,
      );
      expect(notifier.pending, isEmpty);
    },
  );

  test('a second tap also cancels a deferred bookmark addition', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(
      bookmarkDetailsMutationProvider.notifier,
    );
    final emptyLibrary = BookmarkLibraryState(
      bookmarks: const [],
      groups: const [],
      activeTarget: const BookmarkTarget.ungrouped(),
    );

    expect(
      notifier.toggle(config: config, post: post, library: emptyLibrary),
      BookmarkToggleOutcome.added,
    );
    expect(notifier.pending, hasLength(1));

    expect(
      notifier.toggle(config: config, post: post, library: emptyLibrary),
      BookmarkToggleOutcome.removed,
    );
    expect(notifier.pending, isEmpty);
  });

  test('toggles for different bookmark groups remain independent', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(
      bookmarkDetailsMutationProvider.notifier,
    );
    const groupAId = '11111111-1111-4111-8111-111111111111';
    const groupBId = '22222222-2222-4222-8222-222222222222';
    final groups = [
      BookmarkGroup(id: groupAId, name: 'A', bookmarkIds: {bookmark.id}),
      BookmarkGroup(id: groupBId, name: 'B', bookmarkIds: const {}),
    ];
    final groupALibrary = BookmarkLibraryState(
      bookmarks: [bookmark],
      groups: groups,
      activeTarget: BookmarkTarget.group(groupAId),
    );
    final groupBLibrary = BookmarkLibraryState(
      bookmarks: [bookmark],
      groups: groups,
      activeTarget: BookmarkTarget.group(groupBId),
    );

    expect(
      notifier.toggle(config: config, post: post, library: groupALibrary),
      BookmarkToggleOutcome.removed,
    );
    expect(
      notifier.toggle(config: config, post: post, library: groupBLibrary),
      BookmarkToggleOutcome.added,
    );
    expect(notifier.pending, hasLength(2));
  });

  test('pending group changes update counts without changing other posts', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(bookmarkDetailsMutationProvider.notifier)
      ..begin();
    const first = '11111111-1111-4111-8111-111111111111';
    const second = '22222222-2222-4222-8222-222222222222';
    final grouped = BookmarkLibraryState(
      bookmarks: [bookmark],
      groups: [
        BookmarkGroup(id: first, name: 'First', bookmarkIds: {bookmark.id}),
        BookmarkGroup(id: second, name: 'Second', bookmarkIds: {bookmark.id}),
      ],
      activeTarget: BookmarkTarget.group(first),
    );
    notifier.toggle(config: config, post: post, library: grouped);
    var presentation = container
        .read(bookmarkDetailsMutationProvider)
        .presentationFor(grouped, bookmark.uniqueId);
    expect(presentation.isInActiveTarget, isFalse);
    expect(presentation.namedGroupCount, 1);
    expect(presentation.showNamedGroupCount, isTrue);
    expect(presentation.isBookmarked, isTrue);
    final otherPost = Bookmark.empty
        .copyWith(sourceUrl: 'https://example.com', postId: () => 99)
        .toPost();
    expect(
      container
          .read(bookmarkDetailsMutationProvider)
          .presentationFor(
            grouped,
            BookmarkUniqueId.fromPost(otherPost, config.booruIdHint),
          )
          .isBookmarked,
      isFalse,
    );
    final secondTarget = BookmarkLibraryState(
      bookmarks: grouped.items,
      groups: grouped.groups,
      activeTarget: BookmarkTarget.group(second),
    );
    notifier.toggle(config: config, post: post, library: secondTarget);
    final ungrouped = BookmarkLibraryState(
      bookmarks: grouped.items,
      groups: grouped.groups,
      activeTarget: const BookmarkTarget.ungrouped(),
    );
    presentation = container
        .read(bookmarkDetailsMutationProvider)
        .presentationFor(ungrouped, bookmark.uniqueId);
    expect(presentation.isBookmarked, isFalse);
    expect(presentation.isInActiveTarget, isFalse);
    expect(presentation.namedGroupCount, 0);
    notifier.toggle(config: config, post: post, library: grouped);
    presentation = container
        .read(bookmarkDetailsMutationProvider)
        .presentationFor(grouped, bookmark.uniqueId);
    expect(presentation.isInActiveTarget, isTrue);
    expect(presentation.namedGroupCount, 1);
    expect(grouped.membershipsFor(bookmark.uniqueId), {first, second});
  });

  test('deferred ungrouped addition and cancellation update presentation', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(bookmarkDetailsMutationProvider.notifier)
      ..begin();
    final empty = BookmarkLibraryState(
      bookmarks: const [],
      groups: const [],
      activeTarget: const BookmarkTarget.ungrouped(),
    );
    notifier.toggle(config: config, post: post, library: empty);
    expect(
      container
          .read(bookmarkDetailsMutationProvider)
          .presentationFor(empty, bookmark.uniqueId)
          .isInActiveTarget,
      isTrue,
    );
    notifier.toggle(config: config, post: post, library: empty);
    expect(
      container
          .read(bookmarkDetailsMutationProvider)
          .presentationFor(empty, bookmark.uniqueId)
          .isInActiveTarget,
      isFalse,
    );
  });

  test(
    'committing applies every deferred toggle after the viewer closes',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(
        bookmarkDetailsMutationProvider.notifier,
      );
      final target = _RecordingBookmarkNotifier();

      notifier.toggle(config: config, post: post, library: library);
      expect(await notifier.commit(target), isTrue);

      expect(target.posts, [post]);
      expect(notifier.pending, isEmpty);
    },
  );

  test(
    'a failed commit retains its intent and continues later changes',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(
        bookmarkDetailsMutationProvider.notifier,
      );
      final addedBookmark = Bookmark.empty.copyWith(
        originalUrl: 'https://example.com/added.jpg',
        sourceUrl: 'https://example.com',
        postId: () => 2,
      );
      final addedPost = addedBookmark.toPost();
      final emptyLibrary = BookmarkLibraryState(
        bookmarks: const [],
        groups: const [],
        activeTarget: const BookmarkTarget.ungrouped(),
      );
      final target = _RecordingBookmarkNotifier(failingPosts: {post});

      notifier
        ..toggle(config: config, post: post, library: library)
        ..toggle(config: config, post: addedPost, library: emptyLibrary);

      expect(await notifier.commit(target), isFalse);
      expect(target.posts, [post, addedPost]);
      expect(notifier.pending, hasLength(1));
      expect(notifier.pending.values.single.post, post);
    },
  );
}

final class _RecordingBookmarkNotifier extends BookmarkLibraryNotifier {
  _RecordingBookmarkNotifier({this.failingPosts = const {}});

  final posts = <Post>[];
  final Set<Post> failingPosts;

  @override
  FutureOr<BookmarkLibraryState> build() => BookmarkLibraryState(
    bookmarks: const [],
    groups: const [],
    activeTarget: const BookmarkTarget.ungrouped(),
  );

  @override
  Future<BookmarkToggleOutcome> setPostTargetMembership(
    BooruConfigAuth config,
    Post post, {
    required BookmarkTarget target,
    required bool bookmarked,
  }) async {
    posts.add(post);
    if (failingPosts.contains(post)) return BookmarkToggleOutcome.failed;
    return bookmarked
        ? BookmarkToggleOutcome.added
        : BookmarkToggleOutcome.removed;
  }
}
