import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';
import 'package:selection_mode/selection_mode.dart';

import '../../../configs/manage/providers.dart';
import '../../../configs/config/types.dart';
import '../../../images/booru_image.dart';
import '../../../posts/pools/pool_grid_item.dart';
import '../../../selection/selection_input.dart';
import '../../../settings/providers.dart';
import '../providers/bookmark_provider.dart';
import '../providers/pool_bookmark_provider.dart';
import '../types/pool_bookmark.dart';
import '../types/pool_bookmark_capability.dart';
import 'bookmark_group_picker.dart';

class BookmarkPoolCard extends ConsumerStatefulWidget {
  const BookmarkPoolCard({
    required this.pool,
    required this.index,
    this.groupId,
    this.projected = false,
    super.key,
  });
  final PoolBookmark pool;
  final int index;
  final String? groupId;
  final bool projected;

  @override
  ConsumerState<BookmarkPoolCard> createState() => _BookmarkPoolCardState();
}

class _BookmarkPoolCardState extends ConsumerState<BookmarkPoolCard> {
  var _busy = false;

  @override
  Widget build(BuildContext context) {
    final pool = widget.pool;
    final selection = SelectionMode.of(context);
    final profile = resolvePoolBookmarkProfile(
      pool,
      ref.watch(booruConfigProvider),
    );
    final card = PoolGridItem(
      total: pool.total,
      name: pool.title,
      category: switch (pool.category) {
        BookmarkedPoolCategory.series => context.t.pool.category.series,
        BookmarkedPoolCategory.collection => context.t.pool.category.collection,
        BookmarkedPoolCategory.unknown => null,
      },
      image: BookmarkPoolCoverImage(pool: pool, showLabel: true),
      onTap: () {
        if (!handleSelectionTap(context, widget.index)) _open();
      },
    );
    return KurumiContextMenu(
      triggers: !selection.isActive,
      menuItemsBuilder: (_) => [
        KurumiContextMenuTile(
          title: context.t.generic.action.view,
          onTap: _open,
        ),
        if (!widget.projected) ...[
          KurumiContextMenuTile(
            title: context.t.post.action.bookmark,
            onTap: () => showDialog<void>(
              context: context,
              builder: (_) => BookmarkGroupPicker.pool(
                config: profile?.auth ?? BooruConfig.empty.auth,
                pool: pool,
              ),
            ),
          ),
          KurumiContextMenuTile(
            title: context.t.bookmark.pool_refresh,
            onTap: _refresh,
          ),
          if (widget.groupId != null)
            KurumiContextMenuTile(
              title: context.t.generic.action.remove,
              onTap: _remove,
            ),
        ],
        KurumiContextMenuTile(
          title: context.t.generic.action.select,
          onTap: () => selection.enable(initialSelected: [widget.index]),
        ),
      ],
      child: GestureDetector(
        onLongPress:
            selection.isActive || ref.watch(postGridLongPressOpensMenuProvider)
            ? null
            : () => selection.enable(initialSelected: [widget.index]),
        child: SelectableBuilder(
          index: widget.index,
          builder: (_, selected) => KurumiSelectableItem(
            item: AspectRatio(aspectRatio: .6, child: card),
            onPreview: _open,
            isInSelectionMode: selection.isActive,
            isSelected: selected,
          ),
        ),
      ),
    );
  }

  Future<void> _open() => _perform(
    (profile, capability) =>
        capability.openBookmarkPool(ref, profile, widget.pool.poolId),
  );

  Future<void> _refresh() => _perform((profile, capability) async {
    final remote = await capability.getBookmarkPool(
      profile,
      widget.pool.poolId,
    );
    if (remote == null || !mounted) throw StateError('Pool unavailable');
    final summary = await ref.read(
      poolBookmarkDraftProvider((profile, remote)).future,
    );
    if (!mounted) return;
    if (resolvePoolBookmarkProfile(
          widget.pool,
          ref.read(booruConfigProvider),
        ) !=
        profile) {
      throw StateError('Pool profile changed');
    }
    await ref.read(bookmarkProvider.notifier).refreshPoolBookmark(summary);
  });

  Future<void> _perform(
    Future<void> Function(BooruConfig, PoolBookmarkCapability) action,
  ) async {
    if (_busy) return;
    _busy = true;
    try {
      final profile = resolvePoolBookmarkProfile(
        widget.pool,
        ref.read(booruConfigProvider),
      );
      final capability = profile == null
          ? null
          : ref.read(poolBookmarkCapabilityProvider(profile));
      if (profile == null || capability == null)
        throw StateError('Pool profile unavailable');
      await action(profile, capability);
    } catch (_) {
      if (mounted)
        Kurumi.showErrorToast(context, context.t.bookmark.pool_unavailable);
    } finally {
      _busy = false;
    }
  }

  Future<void> _remove() async {
    if (_busy) return;
    _busy = true;
    final notifier = ref.read(bookmarkProvider.notifier);
    try {
      final result = await notifier.removePostsFromGroup(
        BooruConfig.empty.auth,
        [],
        widget.groupId!,
        poolLocalIds: {widget.pool.localId},
      );
      if (mounted) notifier.showRemovalUndo(context, result);
    } catch (_) {
      if (mounted)
        Kurumi.showErrorToast(
          context,
          context.t.bookmark.groups.operation_failed,
        );
    } finally {
      _busy = false;
    }
  }
}

class BookmarkPoolCoverImage extends ConsumerWidget {
  const BookmarkPoolCoverImage({
    required this.pool,
    this.showLabel = false,
    super.key,
  });
  final PoolBookmark pool;
  final bool showLabel;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = resolvePoolBookmarkProfile(
      pool,
      ref.watch(booruConfigProvider),
    );
    final policy = profile == null
        ? null
        : ref.watch(poolCoverPolicyProvider(profile)).valueOrNull;
    final radius = ref.watch(
      imageListingSettingsProvider.select((s) => s.imageBorderRadius),
    );
    if (profile != null &&
        pool.coverUrl != null &&
        pool.coverPolicy != null &&
        pool.coverPolicy == policy) {
      return BooruImage(
        config: profile.auth,
        imageUrl: pool.coverUrl!,
        aspectRatio: .6,
        fit: BoxFit.cover,
        borderRadius: BorderRadius.circular(radius),
      );
    }
    return ColoredBox(
      color: Kurumi.themeOf(context).colorScheme.surfaceContainerLow,
      child: showLabel
          ? Center(
              child: Text(
                context.t.pool.no_cover_image,
                textAlign: TextAlign.center,
              ),
            )
          : const SizedBox.expand(),
    );
  }
}
