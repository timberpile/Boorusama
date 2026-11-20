import 'adjacent_group_preparation.dart';

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
    this.onDisplayed,
    this.onOpenMember,
    super.key,
  });
  final ViewerEntry entry;
  final int index;
  final VoidCallback? onDisplayed;
  final ValueChanged<String>? onOpenMember;
  @override
  ConsumerState<ViewerEntryContent> createState() => _ViewerEntryContentState();
}

class _ViewerEntryContentState extends ConsumerState<ViewerEntryContent> {
  @override
  Widget build(BuildContext context) {
    final pager = PostDetailsPageViewScope.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge([
        pager.currentPage,
        pager.precisePage,
        if (pager.pageController.hasClients)
          pager.pageController.position.isScrollingNotifier,
      ]),
      builder: (context, _) {
        final index = widget.index;
        final selected = pager.page == index;
        final prepared = PreparedGroupWindow.keyOf(
          context,
          widget.entry.occurrenceId,
        );
        if (!selected && prepared == null) return const SizedBox.expand();
        final scrolling =
            pager.pageController.hasClients &&
            pager.pageController.position.isScrollingNotifier.value;
        final lifecycle = WidgetsBinding.instance.lifecycleState;
        final active =
            selected &&
            !scrolling &&
            NavigationActivity.of(context) &&
            (ModalRoute.of(context)?.isCurrent ?? true) &&
            (lifecycle == null || lifecycle == AppLifecycleState.resumed);
        final entry = widget.entry;
        return ExcludeSemantics(
          excluding: !active,
          child: ExcludeFocus(
            excluding: !active,
            child: IgnorePointer(
              ignoring: !active,
              child: entry is GroupViewerEntry
                  ? ContentGroupPage(
                      entry: entry,
                      active: active,
                      prepared: prepared,
                      suspendWhenInactive: true,
                      onDisplayed: widget.onDisplayed,
                      onOpenMember: widget.onOpenMember,
                    )
                  : ViewerEntryNavigationStatus(
                      child: Text(
                        entry is UnavailableGroupViewerEntry && entry.related
                            ? context.t.bookmark.related_unavailable
                            : context.t.bookmark.pool_unavailable,
                      ),
                    ),
            ),
          ),
        );
      },
    );
  }
}
