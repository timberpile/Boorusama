import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';
import 'package:kurumi/kurumi.dart';

import '../services/bookmark_read_projection.dart';
import 'bookmark_option_selector.dart';

class BookmarkSeenFilterButton extends StatelessWidget {
  const BookmarkSeenFilterButton({
    required this.value,
    required this.onSelected,
    super.key,
  });
  final BookmarkSeenFilter value;
  final ValueChanged<BookmarkSeenFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    String label(BookmarkSeenFilter filter) => switch (filter) {
      BookmarkSeenFilter.all => context.t.mitemite.read_filter_all,
      BookmarkSeenFilter.unseen => context.t.mitemite.unseen,
      BookmarkSeenFilter.seen => context.t.mitemite.seen,
    };
    return BookmarkOptionSelector<BookmarkSeenFilter>(
      label: label(value),
      value: value,
      options: BookmarkSeenFilter.values,
      optionLabel: label,
      optionIcon: (_) => Icons.visibility_outlined,
      optionSemanticLabel: (filter) =>
          context.t.mitemite.read_status(value: label(filter)),
      onSelected: onSelected,
    );
  }
}

class BookmarkReadIndicator extends StatelessWidget {
  const BookmarkReadIndicator({
    required this.unseen,
    required this.selecting,
    required this.child,
    super.key,
  });
  final bool unseen;
  final bool selecting;
  final Widget child;

  @override
  Widget build(BuildContext context) => Semantics(
    label: unseen ? context.t.mitemite.unseen : context.t.mitemite.seen,
    child: Stack(
      children: [
        child,
        if (unseen && !selecting)
          Positioned(
            top: 6,
            right: 6,
            child: IgnorePointer(
              child: ExcludeSemantics(
                child: Container(
                  key: const ValueKey('bookmark-unseen-dot'),
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Kurumi.themeOf(context).colorScheme.primary,
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}
