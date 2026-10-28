import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../types/bookmark.dart';
import '../server_favorites/settings_provider.dart';
import 'bookmark_details_mutation_notifier.dart';
import 'bookmark_group_selectors.dart';
import 'bookmark_provider.dart';

/// Widgets select this value by equality, rather than rebuilding for every
/// library mutation. Membership is independent of the currently browsed group.
class BookmarkButtonState extends Equatable {
  const BookmarkButtonState({
    required this.isLoading,
    this.presentation,
  });

  final bool isLoading;
  final BookmarkMembershipPresentation? presentation;

  @override
  List<Object?> get props => [isLoading, presentation];
}

final bookmarkButtonStateProvider = Provider.autoDispose
    .family<BookmarkButtonState, BookmarkUniqueId>(
      (ref, identity) {
        final asyncLibrary = ref.watch(bookmarkProvider);
        final library = asyncLibrary.valueOrNull;
        if (library == null) return const BookmarkButtonState(isLoading: true);
        final favorites = ref.watch(serverFavoriteSettingsProvider).valueOrNull;
        return BookmarkButtonState(
          isLoading: asyncLibrary.isLoading,
          presentation: ref
              .watch(bookmarkDetailsMutationProvider)
              .presentationFor(
                library,
                identity,
                ignoredGroupIds: favorites?.ignoreBookmarkStatus == true
                    ? favorites!.assignedGroupIds
                    : const {},
              ),
        );
      },
      dependencies: [
        bookmarkProvider,
        bookmarkDetailsMutationProvider,
        serverFavoriteSettingsProvider,
      ],
    );
