// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';

// Project imports:
import '../../../search/options/labels.dart';
import '../../../search/options/search_option.dart';
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
      BookmarkSortType.newestUpload ||
      BookmarkSortType.newest => context.t.explore.newest,
      BookmarkSortType.oldestUpload ||
      BookmarkSortType.oldest => context.t.explore.oldest,
      BookmarkSortType.random => context.t.explore.random,
      BookmarkSortType.scoreDescending => searchOptionChoiceLabel(
        context,
        const SearchOptionChoice('score:desc', 'score:desc'),
      ),
      BookmarkSortType.scoreAscending => searchOptionChoiceLabel(
        context,
        const SearchOptionChoice('score:asc', 'score:asc'),
      ),
    };
    IconData icon(BookmarkSortType value) => switch (value) {
      BookmarkSortType.newestUpload ||
      BookmarkSortType.oldestUpload => Icons.file_upload_outlined,
      BookmarkSortType.newest ||
      BookmarkSortType.oldest => Icons.bookmark_border,
      BookmarkSortType.random => Icons.shuffle,
      BookmarkSortType.scoreDescending => Icons.arrow_downward,
      BookmarkSortType.scoreAscending => Icons.arrow_upward,
    };
    String semanticLabel(BookmarkSortType value) => switch (value) {
      BookmarkSortType.newestUpload || BookmarkSortType.oldestUpload =>
        '${context.t.post.detail.upload_date}: ${label(value)}',
      BookmarkSortType.newest ||
      BookmarkSortType.oldest => '${context.t.bookmark.title}: ${label(value)}',
      BookmarkSortType.random => context.t.explore.random,
      BookmarkSortType.scoreAscending ||
      BookmarkSortType.scoreDescending => label(value),
    };
    final selected = ref.watch(selectedBookmarkSortTypeProvider);

    return BookmarkOptionSelector<BookmarkSortType>(
      label: label(selected),
      prefixLabel: context.t.sort.short,
      value: selected,
      options: BookmarkSortType.values,
      optionLabel: label,
      optionIcon: icon,
      optionSemanticLabel: semanticLabel,
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
