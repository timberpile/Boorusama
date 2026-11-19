// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';

// Project imports:
import '../../../settings/providers.dart';
import '../types/bookmark_view.dart';
import 'bookmark_booru_type_selector.dart';
import 'bookmark_shuffle_button.dart';
import 'bookmark_sort_button.dart';

class BookmarkListControls extends ConsumerWidget {
  const BookmarkListControls({
    required this.count,
    this.view = const BookmarkView.all(),
    this.gridConfig,
    this.unavailableIndicator,
    this.seenFilter,
    super.key,
  });

  final int count;
  final BookmarkView view;
  final Widget? gridConfig;
  final Widget? unavailableIndicator;
  final Widget? seenFilter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showCount = ref.watch(
      settingsProvider.select((s) => s.showBookmarkCount),
    );
    final groups = <Widget>[
      ?seenFilter,
      const Row(
        mainAxisSize: MainAxisSize.min,
        children: [BookmarkSortButton(), BookmarkShuffleButton()],
      ),
      BookmarkBooruSourceUrlSelector(view: view),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: constraints.maxWidth),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (final (index, group) in groups.indexed) ...[
                            if (index > 0)
                              const SizedBox(
                                height: 24,
                                child: VerticalDivider(width: 12, thickness: 1),
                              ),
                            group,
                          ],
                        ],
                      ),
                      if (showCount)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 8,
                          ),
                          child: Text(
                            context.t.bookmark.counter(n: count),
                            maxLines: 1,
                            style: Kurumi.themeOf(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Kurumi.themeOf(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          ?unavailableIndicator,
          ?gridConfig,
        ],
      ),
    );
  }
}
