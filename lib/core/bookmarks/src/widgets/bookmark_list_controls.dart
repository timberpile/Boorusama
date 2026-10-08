// Package imports:
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';

// Project imports:
import 'bookmark_booru_type_selector.dart';
import 'bookmark_shuffle_button.dart';
import 'bookmark_sort_button.dart';

class BookmarkListControls extends StatelessWidget {
  const BookmarkListControls({required this.count, this.gridConfig, super.key});

  final int count;
  final Widget? gridConfig;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Kurumi.themeOf(context).colorScheme.surface,
      child: Padding(
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
                        const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            BookmarkSortButton(),
                            BookmarkShuffleButton(),
                            BookmarkBooruSourceUrlSelector(),
                          ],
                        ),
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
            ?gridConfig,
          ],
        ),
      ),
    );
  }
}
