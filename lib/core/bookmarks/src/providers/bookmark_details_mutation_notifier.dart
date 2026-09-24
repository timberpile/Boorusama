// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Project imports:
import '../../../configs/config/types.dart';
import '../../../posts/post/types.dart';
import '../data/bookmark_convert.dart';
import '../types/bookmark.dart';
import '../types/bookmark_library_state.dart';
import '../types/bookmark_target.dart';
import 'bookmark_provider.dart';

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
  const BookmarkDetailsMutationState({required this.isVisible});

  const BookmarkDetailsMutationState.initial() : isVisible = false;

  final bool isVisible;
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

  void begin() {
    _pending.clear();
    state = const BookmarkDetailsMutationState(isVisible: true);
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
    final target = library.activeTarget;
    final key = (bookmarkId: uniqueId, target: target);
    if (_pending.remove(key) case final pending?) {
      return switch (pending.outcome) {
        BookmarkToggleOutcome.added => BookmarkToggleOutcome.removed,
        BookmarkToggleOutcome.removed => BookmarkToggleOutcome.added,
        _ => BookmarkToggleOutcome.failed,
      };
    }

    final bookmark = library.bookmarksByUniqueId[uniqueId];
    final memberships = library.membershipsFor(uniqueId);
    final outcome = switch (target.groupId) {
      final groupId? =>
        bookmark != null && memberships.contains(groupId)
            ? BookmarkToggleOutcome.removed
            : BookmarkToggleOutcome.added,
      null when bookmark != null && memberships.isNotEmpty =>
        BookmarkToggleOutcome.unavailable,
      null when bookmark != null => BookmarkToggleOutcome.removed,
      null => BookmarkToggleOutcome.added,
    };
    if (outcome == BookmarkToggleOutcome.unavailable) return outcome;

    _pending[key] = BookmarkDetailsPendingToggle(
      config: config,
      post: post,
      target: target,
      outcome: outcome,
    );
    return outcome;
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
