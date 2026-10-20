import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';

/// Shows only the entities that the confirmed deletion will remove.
class BookmarkCollectionDeletionSummary extends StatelessWidget {
  const BookmarkCollectionDeletionSummary({
    required this.folders,
    required this.groups,
    required this.uniqueBookmarks,
    super.key,
  });

  final int folders;
  final int groups;
  final int uniqueBookmarks;

  @override
  Widget build(BuildContext context) {
    final strings = context.t.folders;
    final items = [
      if (folders > 0) strings.delete_counts.folders(n: folders),
      if (groups > 0) strings.delete_counts.groups(n: groups),
      if (uniqueBookmarks > 0)
        strings.delete_counts.unique_bookmarks(n: uniqueBookmarks),
    ];
    return Text(
      [
        strings.delete_bookmark_items,
        for (final item in items) '• $item',
      ].join('\n'),
    );
  }
}
