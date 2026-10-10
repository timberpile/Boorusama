// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Project imports:
import '../../../configs/config/types.dart';
import '../../../posts/post/types.dart';
import '../data/bookmark_convert.dart';
import '../types/bookmark.dart';
import '../types/bookmark_library_state.dart';
import '../types/bookmark_target.dart';
import '../types/bookmark_view.dart';
import 'bookmark_provider.dart';
import 'bookmark_group_selectors.dart';

final bookmarkDetailsMutationProvider =
    NotifierProvider<
      BookmarkDetailsMutationNotifier,
      BookmarkDetailsMutationState
    >(BookmarkDetailsMutationNotifier.new);

typedef BookmarkDetailsMutationKey = ({
  BookmarkUniqueId bookmarkId,
  BookmarkTarget target,
});

class BookmarkDetailsMutationState {
  const BookmarkDetailsMutationState({
    required this.isVisible,
    this.pending = const {},
    this.sourceView,
  });

  const BookmarkDetailsMutationState.initial()
    : isVisible = false,
      pending = const {},
      sourceView = null;

  final BookmarkView? sourceView;
  final bool isVisible;
  final Map<BookmarkDetailsMutationKey, BookmarkDetailsPendingToggle> pending;

  BookmarkMembershipPresentation presentationFor(
    BookmarkLibraryState library,
    BookmarkUniqueId bookmarkId,
  ) {
    var bookmarked = library.bookmarksByUniqueId.containsKey(bookmarkId);
    final memberships = {...library.membershipsFor(bookmarkId)};
    for (final entry in pending.entries) {
      if (entry.key.bookmarkId != bookmarkId) continue;
      final added = entry.value.outcome == BookmarkToggleOutcome.added;
      {
        final groupId = entry.key.target.groupId;
        if (added) {
          memberships.add(groupId);
          bookmarked = true;
        } else {
          memberships.remove(groupId);
          // Removing the final group also deletes the bookmark at commit.
          bookmarked = memberships.isNotEmpty;
        }
      }
    }
    return selectBookmarkMembershipPresentation(
      library,
      bookmarkId,
      bookmarked: bookmarked,
      groupMemberships: memberships,
    );
  }
}

class BookmarkDetailsPendingToggle {
  const BookmarkDetailsPendingToggle({
    required this.config,
    required this.post,
    required this.target,
    required this.outcome,
  });

  final BooruConfigAuth config;
  final Post post;
  final BookmarkTarget target;
  final BookmarkToggleOutcome outcome;
}

class BookmarkDetailsMutationNotifier
    extends Notifier<BookmarkDetailsMutationState> {
  final _pending = <BookmarkDetailsMutationKey, BookmarkDetailsPendingToggle>{};

  Map<BookmarkDetailsMutationKey, BookmarkDetailsPendingToggle> get pending =>
      Map.unmodifiable(_pending);

  @override
  BookmarkDetailsMutationState build() =>
      const BookmarkDetailsMutationState.initial();

  void begin({BookmarkView? sourceView}) {
    _pending.clear();
    state = BookmarkDetailsMutationState(
      isVisible: true,
      sourceView: sourceView,
    );
  }

  void end() {
    _pending.clear();
    state = const BookmarkDetailsMutationState.initial();
  }

  BookmarkToggleOutcome toggle({
    required BooruConfigAuth config,
    required Post post,
    required BookmarkLibraryState library,
  }) {
    final uniqueId = bookmarkIdentityForPost(post, config.booruIdHint);
    if (uniqueId is UnbookmarkablePostIdentity) {
      return BookmarkToggleOutcome.missingPostIdentity;
    }
    final target = library.activeTarget;
    final key = (bookmarkId: uniqueId, target: target);
    if (_pending.remove(key) case final pending?) {
      _publishPending();
      return switch (pending.outcome) {
        BookmarkToggleOutcome.added => BookmarkToggleOutcome.removed,
        BookmarkToggleOutcome.removed => BookmarkToggleOutcome.added,
        _ => BookmarkToggleOutcome.failed,
      };
    }

    final bookmark = library.bookmarksByUniqueId[uniqueId];
    final memberships = library.membershipsFor(uniqueId);
    final outcome = bookmark != null && memberships.contains(target.groupId)
        ? BookmarkToggleOutcome.removed
        : BookmarkToggleOutcome.added;

    _pending[key] = BookmarkDetailsPendingToggle(
      config: config,
      post: post,
      target: target,
      outcome: outcome,
    );
    _publishPending();
    return outcome;
  }

  void _publishPending() {
    state = BookmarkDetailsMutationState(
      isVisible: state.isVisible,
      pending: pending,
      sourceView: state.sourceView,
    );
  }

  Future<bool> commit(BookmarkLibraryNotifier library) async {
    var succeeded = true;
    for (final entry in _pending.entries.toList(growable: false)) {
      final mutation = entry.value;
      late final BookmarkToggleOutcome outcome;
      try {
        outcome = await library.setPostTargetMembership(
          mutation.config,
          mutation.post,
          target: mutation.target,
          bookmarked: mutation.outcome == BookmarkToggleOutcome.added,
        );
      } catch (_) {
        succeeded = false;
        continue;
      }
      if (outcome == mutation.outcome) {
        _pending.remove(entry.key);
      } else {
        succeeded = false;
      }
    }
    return succeeded;
  }
}
