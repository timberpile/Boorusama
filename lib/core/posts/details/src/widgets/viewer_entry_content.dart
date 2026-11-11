import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';

import '../../../../navigation/destination_activity.dart';
import '../types/viewer_entry.dart';
import 'content_group_page.dart';
import 'post_details_page_view_scope.dart';
import 'viewer_entry_navigation_header.dart';

/// One registered Group dispatch, visited lazily within the established outer
/// sequence. Galleries retain their own lightweight PageStorage checkpoints.
class ViewerEntryContent extends ConsumerStatefulWidget {
  const ViewerEntryContent({
    required this.entry,
    required this.index,
    super.key,
  });
  final ViewerEntry entry;
  final int index;
  @override
  ConsumerState<ViewerEntryContent> createState() => _ViewerEntryContentState();
}

class _ViewerEntryContentState extends ConsumerState<ViewerEntryContent> {
  var _visited = false;
  @override
  Widget build(BuildContext context) {
    final pager = PostDetailsPageViewScope.of(context);
    return ValueListenableBuilder(
      valueListenable: pager.currentPage,
      builder: (context, page, _) {
        _visited |= page == widget.index;
        if (!_visited) return const SizedBox.expand();
        final entry = widget.entry;
        return entry is GroupViewerEntry
            ? ContentGroupPage(
                entry: entry,
                active: page == widget.index && NavigationActivity.of(context),
              )
            : ViewerEntryNavigationStatus(
                child: Text(
                  entry is UnavailableGroupViewerEntry && entry.related
                      ? context.t.bookmark.related_unavailable
                      : context.t.bookmark.pool_unavailable,
                ),
              );
      },
    );
  }
}
