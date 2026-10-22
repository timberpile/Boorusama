import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../types/bookmark.dart';
import 'bookmark_details_mutation_notifier.dart';
import 'bookmark_group_selectors.dart';
import 'bookmark_provider.dart';

/// Widgets select this value by equality, rather than rebuilding for every
/// library mutation. Default-group translation remains in the widget context.
class BookmarkButtonState extends Equatable {
  const BookmarkButtonState({
    required this.isLoading,
    this.presentation,
    this.activeGroupName,
  });

  final bool isLoading;
  final BookmarkMembershipPresentation? presentation;
  final String? activeGroupName;

  @override
  List<Object?> get props => [isLoading, presentation, activeGroupName];
}

final bookmarkButtonStateProvider = Provider.autoDispose
    .family<BookmarkButtonState, BookmarkUniqueId>(
      (ref, identity) {
        final asyncLibrary = ref.watch(bookmarkProvider);
        final library = asyncLibrary.valueOrNull;
        if (library == null) return const BookmarkButtonState(isLoading: true);
        final group = library.groupsById[library.activeTarget.groupId];
        return BookmarkButtonState(
          isLoading: asyncLibrary.isLoading,
          presentation: ref
              .watch(bookmarkDetailsMutationProvider)
              .presentationFor(library, identity),
          activeGroupName: group == null || group.isDefault ? null : group.name,
        );
      },
      dependencies: [bookmarkProvider, bookmarkDetailsMutationProvider],
    );
