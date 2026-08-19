// Flutter imports:
import 'package:flutter/material.dart';

// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:sliver_masonry_grid/sliver_masonry_grid.dart';

// Project imports:
import '../../../configs/config/providers.dart';
import '../../../configs/config/types.dart';
import '../../../images/booru_image.dart';
import '../data/providers.dart';
import '../providers/bookmark_group_browser_provider.dart';
import '../providers/bookmark_group_providers.dart';
import '../providers/local_providers.dart';
import '../routes/route_utils.dart';
import '../types/bookmark_group.dart';
import '../types/bookmark_group_browser.dart';
import '../types/bookmark.dart';
import '../widgets/bookmark_group_name_dialog.dart';
import '../widgets/bookmark_group_selector.dart';

class BookmarkGroupBrowserPage extends ConsumerWidget {
  const BookmarkGroupBrowserPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sortType = ref.watch(selectedBookmarkSortTypeProvider);
    final items = ref.watch(bookmarkGroupBrowserItemsProvider(sortType));
    final groups = ref.watch(bookmarkGroupsProvider).valueOrNull ?? const [];

    return Scaffold(
      appBar: AppBar(
        title: Text(context.t.bookmark.title),
        actions: [
          IconButton(
            icon: const Icon(Symbols.add),
            tooltip: context.t.bookmark.groups.create,
            onPressed: () => _createGroup(context, ref),
          ),
        ],
      ),
      body: items.when(
        data: (items) => LayoutBuilder(
          builder: (context, constraints) {
            final crossAxisCount = switch (constraints.maxWidth) {
              < 500 => 2,
              < 850 => 3,
              _ => 4,
            };

            return CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.all(12),
                  sliver: SliverMasonryGrid.count(
                    crossAxisCount: crossAxisCount,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childCount: items.length,
                    itemBuilder: (context, index) => _BookmarkGroupCard(
                      item: items[index],
                      groups: groups,
                      onTap: () => _openGroup(context, ref, items[index]),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
        error: (error, _) => Center(child: Text(error.toString())),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  Future<void> _openGroup(
    BuildContext context,
    WidgetRef ref,
    BookmarkGroupBrowserItem item,
  ) async {
    ref.read(selectedBookmarkGroupIdProvider.notifier).state = item.groupId;
    if (item.groupId != null) {
      await setActiveBookmarkGroupId(ref, item.groupId!);
    }

    if (context.mounted) {
      await goToBookmarkGroupViewPage(ref, item.groupId);
    }
  }

  Future<void> _createGroup(BuildContext context, WidgetRef ref) async {
    final name = await showBookmarkGroupNameDialog(
      context,
      title: context.t.bookmark.groups.create,
      saveLabel: context.t.generic.action.save,
      cancelLabel: context.t.generic.action.cancel,
      hintText: context.t.bookmark.groups.name,
    );
    if (name == null) return;

    try {
      final group = await (await ref.read(
        bookmarkGroupRepoProvider.future,
      )).createGroup(name);
      ref.invalidate(bookmarkGroupsProvider);
      ref.read(selectedBookmarkGroupIdProvider.notifier).state = group.id;
      await setActiveBookmarkGroupId(ref, group.id);
      if (context.mounted) {
        await goToBookmarkGroupViewPage(ref, group.id);
      }
    } catch (error) {
      if (!context.mounted) return;
      Kurumi.showErrorToast(context, error.toString());
    }
  }
}

class _BookmarkGroupCard extends StatelessWidget {
  const _BookmarkGroupCard({
    required this.item,
    required this.groups,
    required this.onTap,
  });

  final BookmarkGroupBrowserItem item;
  final List<BookmarkGroup> groups;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final preview = item.preview;
    final aspectRatio = preview == null || preview.height <= 0
        ? 1.2
        : (preview.width / preview.height).clamp(0.7, 1.6);

    return AspectRatio(
      aspectRatio: aspectRatio,
      child: Card(
        clipBehavior: Clip.antiAlias,
        margin: EdgeInsets.zero,
        child: InkWell(
          onTap: onTap,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (preview != null)
                _BookmarkGroupPreviewImage(bookmark: preview)
              else
                const _EmptyBookmarkGroupPreview(),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0x99000000),
                      Color(0x00000000),
                      Color(0x66000000),
                    ],
                    stops: [0, 0.45, 1],
                  ),
                ),
              ),
              Positioned(
                top: 12,
                left: 12,
                right: item.group == null ? 12 : 52,
                child: Text(
                  _name(context),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Kurumi.themeOf(context).textTheme.titleMedium
                      ?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        shadows: const [
                          Shadow(blurRadius: 4),
                        ],
                      ),
                ),
              ),
              if (item.group != null)
                Positioned(
                  top: 4,
                  right: 4,
                  child: BookmarkGroupManagementButton(
                    groups: groups,
                    selectedGroupId: item.groupId,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _name(BuildContext context) {
    return switch (item.groupId) {
      null => context.t.bookmark.groups.all,
      kUngroupedBookmarkGroupId => context.t.bookmark.groups.ungrouped,
      _ => item.group!.name,
    };
  }
}

class _BookmarkGroupPreviewImage extends ConsumerWidget {
  const _BookmarkGroupPreviewImage({required this.bookmark});

  final Bookmark bookmark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final host = Uri.tryParse(bookmark.sourceUrl)?.host ?? '';
    final imageConfig = ref.watch(
      firstMatchingConfigByBooruTypeProvider((bookmark.booruId, host)),
    );

    return BooruImage(
      imageUrl: bookmark.thumbnailUrl,
      config: imageConfig?.auth ?? ref.watchConfigAuth,
      imageCacheManager: ref.watch(bookmarkImageCacheManagerProvider),
      fit: BoxFit.cover,
      placeholderWidget: const _EmptyBookmarkGroupPreview(),
    );
  }
}

class _EmptyBookmarkGroupPreview extends StatelessWidget {
  const _EmptyBookmarkGroupPreview();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Kurumi.themeOf(context).colorScheme.surfaceContainerHighest,
      child: Center(
        child: Icon(
          Symbols.bookmarks,
          size: 42,
          color: Kurumi.themeOf(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
