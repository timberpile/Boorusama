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
import '../providers/bookmark_group_selectors.dart';
import '../providers/bookmark_provider.dart';
import '../providers/bookmark_shuffle_provider.dart';
import '../providers/local_providers.dart';
import '../routes/route_utils.dart';
import '../types/bookmark.dart';
import '../types/bookmark_group.dart';
import '../types/bookmark_view.dart';
import '../widgets/bookmark_group_name_dialog.dart';
import '../widgets/bookmark_group_label.dart';

class BookmarkGroupBrowserPage extends ConsumerWidget {
  const BookmarkGroupBrowserPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final library = ref.watch(bookmarkProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(context.t.bookmark.groups.selector),
        actions: [
          IconButton(
            tooltip: context.t.bookmark.groups.create,
            icon: const Icon(Symbols.create_new_folder),
            onPressed: () => _create(context, ref),
          ),
        ],
      ),
      body: library.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Center(child: Icon(Icons.error_outline)),
        data: (state) {
          final sort = ref.watch(selectedBookmarkSortTypeProvider);
          final shuffle = ref.watch(bookmarkShuffleProvider);
          final labels = bookmarkGroupLabels(state.groups);
          final entries =
              <({String title, BookmarkView view, BookmarkGroup? group})>[
                (
                  title: context.t.bookmark.groups.all,
                  view: const BookmarkView.all(),
                  group: null,
                ),
                (
                  title: context.t.bookmark.groups.ungrouped,
                  view: const BookmarkView.ungrouped(),
                  group: null,
                ),
                for (final group in state.groups)
                  (
                    title: labels[group.id]!,
                    view: BookmarkView.group(group.id),
                    group: group,
                  ),
              ];
          return LayoutBuilder(
            builder: (context, constraints) => GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: switch (constraints.maxWidth) {
                  < 500 => 2,
                  < 850 => 3,
                  _ => 4,
                },
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: entries.length,
              itemBuilder: (context, index) {
                final entry = entries[index];
                final previews = selectBookmarkPreviews(
                  state: state,
                  view: entry.view,
                  sortType: sort,
                  shuffleState: shuffle,
                );
                return _GroupCard(
                  title: entry.title,
                  previews: previews,
                  group: entry.group,
                  onTap: () => goToBookmarkGroupPage(
                    ref,
                    entry.view,
                    title: entry.title,
                  ),
                  onRename: entry.group == null
                      ? null
                      : () => _rename(context, ref, entry.group!),
                  onDuplicate: entry.group == null
                      ? null
                      : () => _duplicate(context, ref, entry.group!),
                  onDelete: entry.group == null
                      ? null
                      : () => _delete(context, ref, entry.group!),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final name = await showBookmarkGroupNameDialog(
      context,
      title: context.t.bookmark.groups.create,
    );
    if (name == null) return;
    if (!context.mounted) return;
    await _runGroupAction(
      context,
      () => ref.read(bookmarkProvider.notifier).createGroup(name),
    );
  }

  Future<void> _rename(
    BuildContext context,
    WidgetRef ref,
    BookmarkGroup group,
  ) async {
    final name = await showBookmarkGroupNameDialog(
      context,
      title: context.t.bookmark.groups.rename,
      initialName: group.name,
    );
    if (name == null) return;
    if (!context.mounted) return;
    await _runGroupAction(
      context,
      () => ref.read(bookmarkProvider.notifier).renameGroup(group.id, name),
    );
  }

  Future<void> _duplicate(
    BuildContext context,
    WidgetRef ref,
    BookmarkGroup group,
  ) async {
    final name = await showBookmarkGroupNameDialog(
      context,
      title: context.t.bookmark.groups.duplicate,
      initialName: group.name,
    );
    if (name == null) return;
    if (!context.mounted) return;
    await _runGroupAction(
      context,
      () => ref.read(bookmarkProvider.notifier).duplicateGroup(group.id, name),
    );
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    BookmarkGroup group,
  ) async {
    var current = group;
    while (true) {
      if (current.bookmarkIds.isNotEmpty) {
        if (!context.mounted) return;
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(
              context.t.bookmark.groups.delete_group_title.replaceAll(
                '{name}',
                current.name,
              ),
            ),
            content: Text(
              context.t.bookmark.groups.delete_group_message.replaceAll(
                '{bookmarks}',
                '${current.bookmarkIds.length}',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(context.t.generic.action.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(context.t.generic.action.delete),
              ),
            ],
          ),
        );
        if (confirmed != true || !context.mounted) return;
      }
      try {
        await ref
            .read(bookmarkProvider.notifier)
            .deleteGroup(
              current.id,
              expectedBookmarkIds: current.bookmarkIds,
            );
        return;
      } on BookmarkGroupChangedException catch (error) {
        current = error.group;
      } catch (_) {
        if (context.mounted) {
          Kurumi.showErrorToast(
            context,
            context.t.bookmark.groups.operation_failed,
          );
        }
        return;
      }
    }
  }

  Future<void> _runGroupAction(
    BuildContext context,
    Future<Object?> Function() action,
  ) async {
    try {
      await action();
    } catch (_) {
      if (context.mounted) {
        Kurumi.showErrorToast(
          context,
          context.t.bookmark.groups.operation_failed,
        );
      }
    }
  }
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({
    required this.title,
    required this.previews,
    required this.group,
    required this.onTap,
    required this.onRename,
    required this.onDuplicate,
    required this.onDelete,
  });

  final String title;
  final List<Bookmark> previews;
  final BookmarkGroup? group;
  final VoidCallback onTap;
  final VoidCallback? onRename;
  final VoidCallback? onDuplicate;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(12);
    return DecoratedBox(
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
                BookmarkGroupPreviewGrid(
                  previews: previews,
                  itemBuilder: (_, bookmark) =>
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
                  right: group == null ? 12 : 52,
                  child: Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Kurumi.themeOf(context).textTheme.titleMedium
                        ?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          shadows: const [Shadow(blurRadius: 4)],
                        ),
                  ),
                ),
                if (group != null)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: PopupMenuButton<String>(
                      onSelected: (action) => switch (action) {
                        'rename' => onRename?.call(),
                        'duplicate' => onDuplicate?.call(),
                        'delete' => onDelete?.call(),
                        _ => null,
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'rename',
                          child: Text(context.t.bookmark.groups.rename),
                        ),
                        PopupMenuItem(
                          value: 'duplicate',
                          child: Text(context.t.bookmark.groups.duplicate),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Text(context.t.bookmark.groups.delete),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
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
  Widget build(BuildContext context) => GridView.builder(
    physics: const NeverScrollableScrollPhysics(),
    padding: const EdgeInsets.all(2),
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 2,
      crossAxisSpacing: 2,
      mainAxisSpacing: 2,
    ),
    itemCount: 4,
    itemBuilder: (context, index) => index < previews.length
        ? itemBuilder(context, previews[index])
        : const SizedBox.shrink(),
  );
}

String bookmarkGroupPreviewUrl(Bookmark bookmark) =>
    bookmark.isVideo ? bookmark.thumbnailUrl : bookmark.sampleUrl;

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
      imageUrl: bookmarkGroupPreviewUrl(bookmark),
      config: imageConfig?.auth ?? ref.watchConfigAuth,
      imageCacheManager: ref.watch(bookmarkImageCacheManagerProvider),
      fit: BoxFit.cover,
      placeholderWidget: const SizedBox.expand(),
    );
  }
}
