// Flutter imports:
import 'package:flutter/material.dart';

// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';
import 'package:material_symbols_icons/symbols.dart';

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
        title: Text(context.t.bookmark.groups.selector),
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
                  sliver: SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => _BookmarkGroupCard(
                        item: items[index],
                        groups: groups,
                        onTap: () => _openGroup(context, ref, items[index]),
                      ),
                      childCount: items.length,
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
      saveLabel: context.t.generic.action.create,
      cancelLabel: context.t.generic.action.cancel,
      hintText: context.t.bookmark.groups.name,
    );
    if (name == null) return;

    try {
      await (await ref.read(
        bookmarkGroupRepoProvider.future,
      )).createGroup(name);
      ref.invalidate(bookmarkGroupsProvider);
      // Creating an empty group does not provide a useful content view yet.
      // Keep the browser open so the user can continue managing groups.
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
    final borderRadius = BorderRadius.circular(12);

    return AspectRatio(
      aspectRatio: 1,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(
            color: Kurumi.themeOf(context).colorScheme.outlineVariant,
          ),
          borderRadius: borderRadius,
        ),
        child: ClipRRect(
          borderRadius: borderRadius,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (item.previews.isNotEmpty)
                    BookmarkGroupPreviewGrid(
                      previews: item.previews,
                      itemBuilder: (context, bookmark) =>
                          _BookmarkGroupPreviewImage(bookmark: bookmark),
                    ),
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

class BookmarkGroupPreviewGrid extends StatelessWidget {
  const BookmarkGroupPreviewGrid({
    required this.previews,
    required this.itemBuilder,
    super.key,
  });

  final List<Bookmark> previews;
  final Widget Function(BuildContext context, Bookmark bookmark) itemBuilder;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(2),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
      ),
      itemCount: previews.length,
      itemBuilder: (context, index) => itemBuilder(context, previews[index]),
    );
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
      imageUrl: bookmark.isVideo ? bookmark.thumbnailUrl : bookmark.sampleUrl,
      config: imageConfig?.auth ?? ref.watchConfigAuth,
      imageCacheManager: ref.watch(bookmarkImageCacheManagerProvider),
      fit: BoxFit.cover,
      placeholderWidget: const SizedBox.expand(),
    );
  }
}
