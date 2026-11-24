import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/configs/config/types.dart';

import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';

import '../../../core/posts/details/src/providers/group_reading_provider.dart';
import '../../../core/posts/details/src/providers/media_group_provider.dart';
import '../../../core/posts/details/src/widgets/group_bookmark_button.dart';
import '../../../core/posts/details/src/widgets/group_viewer_scope.dart';
import '../../../core/posts/details/src/widgets/viewer_entry_navigation_header.dart';
import '../../../core/posts/details/src/types/viewer_entry.dart';
import '../../../core/posts/listing/src/widgets/post_grid_item.dart';
import '../../../core/posts/links/share_group_link_button.dart';
import '../../../core/content/groups/group_members_provider.dart';
import '../favorites/favorite_control.dart';
import 'work_mapper.dart';

/// A Work's author slots remain visible even when a Page is unavailable.
/// It uses the Single pager's membership observer and real Post media widgets.
class PixivWorkTimeline extends ConsumerStatefulWidget {
  const PixivWorkTimeline({required this.entry, super.key});
  final GroupViewerEntry entry;
  @override
  ConsumerState<PixivWorkTimeline> createState() => _PixivWorkTimelineState();
}

class _PixivWorkTimelineState extends ConsumerState<PixivWorkTimeline> {
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
            if (pixivWorkIllustId(widget.entry.contentReference) case final id?
                when !state.failed && state.access != null)
              PixivFavoriteControl(
                key: ValueKey((state.access!.key, id)),
                access: state.access,
                illustId: id,
              ),
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
