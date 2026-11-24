import '../../../pools/src/widgets/group_sort_icon.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../content/groups/group_capability.dart';
import '../../../listing/src/widgets/timeline_option_selector.dart';
import '../../../details_pageview/src/viewer_overlay_icon_button.dart';
import '../../../pools/src/types/pool_details_order.dart';
import '../../../related/related_posts_order.dart';
import '../providers/group_reading_provider.dart';
import '../types/viewer_entry.dart';
import 'post_details_page_view_scope.dart';

class GroupViewToggle extends ConsumerWidget {
  const GroupViewToggle({required this.entry, this.overlay = false, super.key});
  final GroupViewerEntry entry;
  final bool overlay;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final single =
        ref.watch(groupReadingProvider(entry)).layout == GroupLayout.mediaPager;
    final label = single
        ? context.t.content_viewer.switch_to_timeline
        : context.t.content_viewer.switch_to_single;
    void toggle() {
      final pager = PostDetailsPageViewScope.maybeOf(context);
      pager?.synchronizeZoom(false);
      ref
          .read(groupReadingProvider(entry).notifier)
          .show(single ? GroupLayout.memberGrid : GroupLayout.mediaPager);
    }

    final icon = Icon(single ? Symbols.grid_view : Symbols.image, size: 24);
    if (!overlay) {
      return IconButton(
        key: const ValueKey('group-view-toggle'),
        tooltip: label,
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        icon: icon,
        onPressed: toggle,
      );
    }
    return Tooltip(
      message: label,
      child: ViewerOverlayIconButton(
        key: const ValueKey('group-view-toggle'),
        semanticLabel: label,
        icon: icon,
        onPressed: toggle,
      ),
    );
  }
}

class GroupOrderSelector extends ConsumerWidget {
  const GroupOrderSelector({
    required this.entry,
    this.compact = false,
    super.key,
  });
  final GroupViewerEntry entry;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reading = ref.watch(groupReadingProvider(entry));
    final key = entry.contentReference.sourceKey;
    if (!key.startsWith('related:') && !key.startsWith('pool:')) {
      return const SizedBox.shrink();
    }
    final related = key.startsWith('related:');
    final options = related
        ? RelatedPostsOrder.values.map((v) => v.name).toList()
        : PoolDetailsOrder.values.map((v) => v.name).toList();
    String label(String value) => related
        ? RelatedPostsOrder.values.byName(value).localize(context)
        : PoolDetailsOrder.values.byName(value).localize(context);
    final selected = reading.orderKey ?? options.first;
    return TimelineOptionSelector<String>(
      key: const ValueKey('group-order-selector'),
      label: label(selected),
      value: selected,
      options: options,
      compact: compact,
      pending: reading.sorting,
      triggerSemanticLabel: compact
          ? '${context.t.sort.short}: ${label(selected)}'
          : null,
      buttonBuilder: compact
          ? (context, onPressed) => ViewerOverlayIconButton(
              icon: reading.sorting
                  ? Stack(
                      clipBehavior: Clip.none,
                      children: [
                        GroupSortIcon(selected),
                        const Positioned(
                          right: -4,
                          bottom: -4,
                          child: SizedBox.square(
                            dimension: 8,
                            child: CircularProgressIndicator(strokeWidth: 1.5),
                          ),
                        ),
                      ],
                    )
                  : GroupSortIcon(selected),
              onPressed: onPressed,
            )
          : null,
      optionLabel: label,
      optionLeading: (order) => GroupSortIcon(order, size: 18),
      onSelected: (order) => requestGroupSort(context, ref, entry, order),
    );
  }
}

Future<bool> requestGroupSort(
  BuildContext context,
  WidgetRef ref,
  GroupViewerEntry entry,
  String order,
) async {
  try {
    final result = await ref
        .read(groupReadingProvider(entry).notifier)
        .setOrder(order);
    if (result == GroupOrderResult.paused && context.mounted) {
      Kurumi.showSimpleSnackBar(
        context: context,
        content: Text(context.t.content_viewer.sort_paused),
      );
    }
    return result == GroupOrderResult.applied;
  } catch (_) {
    if (context.mounted) {
      Kurumi.showErrorToast(
        context,
        context.t.bookmark.groups.operation_failed,
      );
    }
    return false;
  }
}
