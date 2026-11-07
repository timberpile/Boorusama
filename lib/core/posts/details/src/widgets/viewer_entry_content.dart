import '../../../related/related_family.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';

import '../../../../boorus/engine/providers.dart';
import '../../../../configs/config/types.dart';
import '../../../../configs/manage/widgets.dart';
import '../../../../navigation/destination_activity.dart';
import '../types/viewer_entry.dart';
import '../providers/viewer_source_access_provider.dart';
import 'post_details_page_view_scope.dart';
import 'viewer_entry_navigation_header.dart';

abstract interface class ViewerEntryContentCapability {
  Widget buildViewerEntry(ViewerEntry entry);
}

final viewerEntryContentCapabilityProvider =
    Provider.family<ViewerEntryContentCapability?, BooruConfig>((ref, config) {
      final repository = ref.watch(booruRepoProvider(config.auth));
      return switch (repository) {
        final ViewerEntryContentCapability capability => capability,
        _ => null,
      };
    });

/// Engine-specific content is mounted only after visiting its page. PageStorage
/// keeps lightweight checkpoints when PageView evicts a gallery.
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
    final binding = widget.entry.source;
    final access = binding == null
        ? null
        : ref.watch(viewerSourceAccessProvider(binding));
    final config = access?.config;
    final repo = config == null
        ? null
        : ref.watch(viewerEntryContentCapabilityProvider(config));
    return ValueListenableBuilder(
      valueListenable: pager.currentPage,
      builder: (context, page, _) {
        _visited |= page == widget.index;
        if (config == null || repo == null) {
          final unavailable = Text(
            widget.entry is RelatedViewerEntry
                ? context.t.bookmark.related_unavailable
                : context.t.bookmark.pool_unavailable,
          );
          return widget.entry.usesContentNavigationHeader
              ? ViewerEntryNavigationStatus(child: unavailable)
              : SafeArea(child: Center(child: unavailable));
        }
        if (!_visited) return const SizedBox.expand();
        return CurrentBooruConfigScope(
          config: config,
          accessKey: access?.key,
          requireAccess: true,
          bookmarkId: binding?.bookmarkId,
          child: NavigationActivity(
            active: page == widget.index && NavigationActivity.of(context),
            child: repo.buildViewerEntry(
              widget.entry,
            ),
          ),
        );
      },
    );
  }
}
