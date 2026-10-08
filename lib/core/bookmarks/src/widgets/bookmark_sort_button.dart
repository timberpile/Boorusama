// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';

// Project imports:
import '../providers/bookmark_shuffle_provider.dart';
import '../providers/local_providers.dart';
import 'bookmark_option_selector.dart';

class BookmarkSortButton extends ConsumerWidget {
  const BookmarkSortButton({
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shuffleProvider = ref.watch(bookmarkShuffleProvider.notifier);

    String label(BookmarkSortType value) => switch (value) {
      BookmarkSortType.newest => context.t.explore.newest,
      BookmarkSortType.oldest => context.t.explore.oldest,
      BookmarkSortType.random => context.t.explore.random,
    };
    final selected = ref.watch(selectedBookmarkSortTypeProvider);

    return BookmarkOptionSelector<BookmarkSortType>(
      label: label(selected),
      value: selected,
      options: BookmarkSortType.values,
      optionLabel: label,
      onSelected: (value) {
        if (value == selected) return;
        ref.read(selectedBookmarkSortTypeProvider.notifier).state = value;
        if (value == BookmarkSortType.random) {
          shuffleProvider.shuffle();
        } else {
          shuffleProvider.reset();
        }
      },
    );
  }
}
