// Flutter imports:
import 'package:flutter/material.dart';

// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:material_symbols_icons/symbols.dart';

// Project imports:
import '../providers/bookmark_group_selectors.dart';
import '../providers/bookmark_provider.dart';
import '../providers/local_providers.dart';
import '../routes/route_utils.dart';
import '../types/bookmark.dart';
import '../types/bookmark_group.dart';
import '../types/bookmark_view.dart';
import '../widgets/bookmark_group_name_dialog.dart';

class BookmarkGroupBrowserPage extends ConsumerWidget {
  const BookmarkGroupBrowserPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final library = ref.watch(bookmarkProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(context.t.bookmark.title),
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
                    title: group.name,
                    view: BookmarkView.group(group.id),
                    group: group,
                  ),
              ];
          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 220,
              childAspectRatio: 0.82,
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
    if (name != null) {
      await ref.read(bookmarkProvider.notifier).createGroup(name);
    }
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
    if (name != null) {
      await ref.read(bookmarkProvider.notifier).renameGroup(group.id, name);
    }
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
    if (name != null) {
      await ref.read(bookmarkProvider.notifier).duplicateGroup(group.id, name);
    }
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    BookmarkGroup group,
  ) async {
    if (group.bookmarkIds.isNotEmpty) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(
            context.t.bookmark.groups.delete_group_title.replaceAll(
              '{name}',
              group.name,
            ),
          ),
          content: Text(
            context.t.bookmark.groups.delete_group_message.replaceAll(
              '{bookmarks}',
              '${group.bookmarkIds.length}',
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
      if (confirmed != true) return;
    }
    await ref.read(bookmarkProvider.notifier).deleteGroup(group.id);
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
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          children: [
            Expanded(
              child: GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                ),
                itemCount: 4,
                itemBuilder: (_, index) => index < previews.length
                    ? Image.network(
                        previews[index].thumbnailUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const SizedBox.shrink(),
                      )
                    : const SizedBox.shrink(),
              ),
            ),
            ListTile(
              dense: true,
              title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: group == null
                  ? null
                  : PopupMenuButton<String>(
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
    );
  }
}
