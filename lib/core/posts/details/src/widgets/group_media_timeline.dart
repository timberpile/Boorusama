import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../configs/config/types.dart';

import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';

import '../providers/group_reading_provider.dart';
import '../providers/media_group_provider.dart';
import 'group_bookmark_button.dart';
import 'group_viewer_scope.dart';
import 'viewer_entry_navigation_header.dart';
import '../types/viewer_entry.dart';
import '../../../listing/src/widgets/post_grid_item.dart';
import '../../../links/share_group_link_button.dart';
import '../../../../content/groups/group_members_provider.dart';

/// Source Page slots remain visible even when their media is unavailable.
/// It uses the Single pager's membership observer and real Post media widgets.
class GroupMediaTimeline extends ConsumerStatefulWidget {
  const GroupMediaTimeline({required this.entry, this.favorite, super.key});
  final GroupViewerEntry entry;
  final Widget? Function(MediaGroupState state)? favorite;
  @override
  ConsumerState<GroupMediaTimeline> createState() => _GroupMediaTimelineState();
}

class _GroupMediaTimelineState extends ConsumerState<GroupMediaTimeline> {
  late final _checkpoint = ref
      .read(groupReadingProvider(widget.entry))
      .checkpoint;
  late final _scroll = ScrollController(
    initialScrollOffset: _checkpoint.timelineOffset,
    keepScrollOffset: false,
  )..addListener(_save);
  void _save() {
    if (_scroll.hasClients) _checkpoint.timelineOffset = _scroll.offset;
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(mediaGroupProvider(widget.entry));
    final details = state.details;
    final members = state.members?.members ?? const [];
    return CustomScrollView(
      controller: _scroll,
      slivers: [
        ViewerEntryNavigationHeader(
          actions: [
            ?widget.favorite?.call(state),
            GroupScopedBookmarkButton(entry: widget.entry, wholeGroup: true),
            const GroupLinkShareButton(),
          ],
        ),
        SliverPadding(
          padding: const EdgeInsets.all(12),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (details?.summary.title ?? widget.entry.summary.title
                    case final title?)
                  Text(title, style: Theme.of(context).textTheme.titleLarge),
                for (final creator in details?.creators ?? [])
                  Text(
                    creator.displayName,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                const SizedBox(height: 8),
                Text(
                  context.t.content_viewer.page_counter(
                    n:
                        state.members?.sourceTotal ??
                        details?.summary.memberCount ??
                        members.length,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (state.failed || (state.members != null && members.isEmpty))
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Text(context.t.content_viewer.page_unavailable),
            ),
          )
        else if (state.members == null)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: CircularProgressIndicator()),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            sliver: SliverGrid.builder(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 240,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: members.length,
              itemBuilder: (context, index) {
                final post = state.postAt(index);
                final pageNumber = (members[index].sourcePosition ?? index) + 1;
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    if (post == null)
                      Center(
                        child: Text(context.t.content_viewer.page_unavailable),
                      )
                    else
                      PostGridItem(
                        post: post,
                        index: index,
                        config: state.access!.config!.auth,
                        useHero: false,
                        multiSelectEnabled: false,
                        selectionEnabled: false,
                        quickActionButton: const SizedBox.shrink(),
                        onTap: (_) =>
                            GroupViewerScope.maybeOf(context)?.onOpenMember
                                ?.call(members[index].memberKey),
                      ),
                    PositionedDirectional(
                      start: 4,
                      bottom: 4,
                      child: IgnorePointer(
                        child: Material(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            child: Text('$pageNumber'),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        if (state.members?.next != null || state.members?.nextPageError != null)
          SliverToBoxAdapter(
            child: Center(
              child: TextButton(
                onPressed:
                    (state.members?.loadingMore ?? false) ||
                        state.loadKey == null
                    ? null
                    : () => ref
                          .read(groupMembersProvider(state.loadKey!).notifier)
                          .loadNext(),
                child: Text(
                  state.members?.nextPageError != null
                      ? context.t.generic.action.retry
                      : context.t.generic.action.more,
                ),
              ),
            ),
          ),
        SliverToBoxAdapter(
          child: SizedBox(height: MediaQuery.paddingOf(context).bottom + 12),
        ),
      ],
    );
  }
}
