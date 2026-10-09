// Flutter imports:
import 'package:flutter/material.dart';

// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:material_symbols_icons/symbols.dart';

// Project imports:
import '../providers/bookmark_provider.dart';
import '../data/bookmark_convert.dart';
import '../types/bookmark_group.dart';
import '../types/bookmark_library_state.dart';
import '../../../configs/config/types.dart';
import '../../../posts/post/types.dart';
import '../types/bookmark.dart';
import 'bookmark_group_name_dialog.dart';
import 'bookmark_folder_picker_contents.dart';

Future<bool> showBookmarkMultiSelectionActions(
  BuildContext context, {
  required WidgetRef ref,
  required List<Bookmark> bookmarks,
}) async {
  final container = ProviderScope.containerOf(context, listen: false);
  final action = await showModalBottomSheet<String>(
    context: context,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: Text(context.t.bookmark.bulk.add),
            onTap: () => Navigator.pop(context, 'add'),
          ),
          ListTile(
            title: Text(context.t.bookmark.bulk.remove),
            onTap: () => Navigator.pop(context, 'remove'),
          ),
          ListTile(
            title: Text(context.t.bookmark.bulk.delete),
            onTap: () => Navigator.pop(context, 'delete'),
          ),
        ],
      ),
    ),
  );
  if (!context.mounted) return false;
  return switch (action) {
    'add' => _add(context, container, bookmarks),
    'remove' => _remove(context, container, bookmarks),
    'delete' => _delete(context, container, bookmarks),
    _ => false,
  };
}

Future<bool> _add(
  BuildContext context,
  ProviderContainer container,
  List<Bookmark> bookmarks,
) async {
  final groupId = await _selectGroup(context, bookmarks, allowCreate: true);
  if (groupId == null) return false;
  await container
      .read(bookmarkProvider.notifier)
      .addExistingBookmarksToGroup(bookmarks, groupId);
  return false;
}

Future<bool> _remove(
  BuildContext context,
  ProviderContainer container,
  List<Bookmark> bookmarks,
) async {
  final groupId = await _selectGroup(context, bookmarks);
  if (groupId == null) return false;
  await container
      .read(bookmarkProvider.notifier)
      .removeFromGroup(bookmarks, groupId);
  return false;
}

Future<bool> _delete(
  BuildContext context,
  ProviderContainer container,
  List<Bookmark> bookmarks,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(context.t.bookmark.bulk.delete_title),
      content: Text(
        context.t.bookmark.bulk.delete_message.replaceAll(
          '{count}',
          '${bookmarks.length}',
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
  if (confirmed != true) return false;
  await container.read(bookmarkProvider.notifier).removeBookmarks(bookmarks);
  return true;
}

Future<String?> _selectGroup(
  BuildContext context,
  List<Bookmark> bookmarks, {
  bool allowCreate = false,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _ExistingBookmarkGroupSelectionDialog(
      allowCreate: allowCreate,
      bookmarks: bookmarks,
    ),
  );
}

class _ExistingBookmarkGroupSelectionDialog extends ConsumerWidget {
  const _ExistingBookmarkGroupSelectionDialog({
    required this.allowCreate,
    required this.bookmarks,
  });
  final bool allowCreate;
  final List<Bookmark> bookmarks;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final library = ref.watch(bookmarkProvider).valueOrNull;
    final singleMemberships = bookmarks.length == 1
        ? library?.membershipsFor(bookmarks.single.uniqueId)
        : null;
    return AlertDialog(
      title: Text(context.t.bookmark.groups.selector),
      content: SizedBox(
        width: 360,
        child: BookmarkFolderPickerContents(
          folders: library?.folders ?? const [],
          groups: library?.groups ?? const [],
          membershipGroupIds: singleMemberships,
          groupBuilder: (context, group) => ListTile(
            leading: Icon(
              Symbols.bookmarks,
              fill: (singleMemberships?.contains(group.id) ?? false) ? 1 : 0,
            ),
            title: Text(
              group.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            onTap: () => Navigator.pop(context, group.id),
          ),
          footerBuilder: allowCreate
              ? (context, folderId) => ListTile(
                  leading: const Icon(Icons.add),
                  title: Text(context.t.bookmark.groups.create_new),
                  onTap: () async {
                    final name = await showBookmarkGroupNameDialog(
                      context,
                      title: context.t.bookmark.groups.create,
                    );
                    if (name == null || !context.mounted) return;
                    try {
                      final group = await ref
                          .read(bookmarkProvider.notifier)
                          .createGroup(
                            name,
                            activate: true,
                            folderId: folderId,
                          );
                      if (context.mounted) {
                        Navigator.pop(context, group.id);
                      }
                    } catch (_) {
                      if (context.mounted) {
                        Kurumi.showErrorToast(
                          context,
                          context.t.bookmark.groups.operation_failed,
                        );
                      }
                    }
                  },
                )
              : null,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.t.generic.action.cancel),
        ),
      ],
    );
  }
}

class BookmarkGroupSelectionSummary {
  const BookmarkGroupSelectionSummary({
    required this.totalPosts,
    required this.bookmarkedPosts,
    required this.ungroupedBookmarks,
    required this.membershipCounts,
  });

  factory BookmarkGroupSelectionSummary.fromPosts({
    required Iterable<Post> posts,
    required BookmarkLibraryState? state,
    required int booruId,
  }) {
    var bookmarked = 0;
    var ungrouped = 0;
    final counts = <String, int>{};
    for (final post in posts) {
      final id = bookmarkIdentityForPost(post, booruId);
      if (state?.bookmarksByUniqueId[id] == null) continue;
      bookmarked++;
      final memberships = state?.membershipsFor(id) ?? const <String>{};
      if (memberships.isEmpty) ungrouped++;
      for (final groupId in memberships) {
        counts.update(groupId, (value) => value + 1, ifAbsent: () => 1);
      }
    }
    return BookmarkGroupSelectionSummary(
      totalPosts: posts.length,
      bookmarkedPosts: bookmarked,
      ungroupedBookmarks: ungrouped,
      membershipCounts: Map.unmodifiable(counts),
    );
  }

  final int totalPosts;
  final int bookmarkedPosts;
  final int ungroupedBookmarks;
  final Map<String, int> membershipCounts;

  int countFor(String groupId) => membershipCounts[groupId] ?? 0;
}

enum BookmarkMultiSelectionOperation { add, remove }

class BookmarkGroupSelectionTarget {
  const BookmarkGroupSelectionTarget(
    this.id,
    this.name, {
    this.appliedCount,
  });

  final String? id;
  final String name;
  final int? appliedCount;
}

class BookmarkMultiSelectionMenu extends ConsumerWidget {
  const BookmarkMultiSelectionMenu({
    required this.posts,
    required this.config,
    required this.onCompleted,
    super.key,
  });

  final List<Post> posts;
  final BooruConfigAuth config;
  final Future<void> Function() onCompleted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(bookmarkProvider).valueOrNull;
    final summary = BookmarkGroupSelectionSummary.fromPosts(
      posts: posts,
      state: state,
      booruId: config.booruIdHint,
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        KurumiPopupMenuItem(
          title: Text(context.t.bookmark.bulk.add),
          trailing: const Icon(Icons.chevron_right),
          onTap: () =>
              _select(context, ref, BookmarkMultiSelectionOperation.add),
        ),
        KurumiPopupMenuItem(
          title: Text(context.t.bookmark.bulk.remove),
          trailing: const Icon(Icons.chevron_right),
          onTap: () =>
              _select(context, ref, BookmarkMultiSelectionOperation.remove),
        ),
        const Divider(),
        KurumiPopupMenuItem(
          icon: const Icon(Symbols.delete),
          title: Text(context.t.bookmark.bulk.delete),
          onTap: () => _delete(context, ref, summary.bookmarkedPosts),
        ),
      ],
    );
  }

  Future<void> _select(
    BuildContext context,
    WidgetRef ref,
    BookmarkMultiSelectionOperation operation,
  ) async {
    final navigator = Navigator.of(context, rootNavigator: true);
    final notifier = ref.read(bookmarkProvider.notifier);
    final target = await showBookmarkGroupSelectionDialog(
      navigator.context,
      operation: operation,
      posts: posts,
      config: config,
    );
    if (target == null || !navigator.mounted) return;
    try {
      if (operation == BookmarkMultiSelectionOperation.add) {
        final changed =
            target.appliedCount ??
            await notifier.addPostsToGroup(config, posts, target.id);
        if (!navigator.mounted) return;
        Kurumi.showSuccessToast(
          navigator.context,
          navigator.context.t.bookmark.bulk.add_success
              .replaceAll('{0}', '$changed')
              .replaceAll('{1}', target.name),
        );
      } else {
        final result = await notifier.removePostsFromGroup(
          config,
          posts,
          target.id!,
        );
        if (!navigator.mounted) return;
        final template = result.movedToNoGroupCount > 0
            ? navigator.context.t.bookmark.bulk.remove_success_ungrouped
            : navigator.context.t.bookmark.bulk.remove_success;
        Kurumi.showSuccessToast(
          navigator.context,
          template
              .replaceAll('{0}', '${result.removedCount}')
              .replaceAll('{1}', target.name)
              .replaceAll('{2}', '${result.movedToNoGroupCount}'),
        );
      }
      await onCompleted();
    } catch (_) {
      if (!navigator.mounted) return;
      Kurumi.showErrorToast(
        navigator.context,
        operation == BookmarkMultiSelectionOperation.add
            ? navigator.context.t.bookmark.bulk.failed_to_add
            : navigator.context.t.bookmark.bulk.failed_to_remove,
      );
    }
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    int count,
  ) async {
    final navigator = Navigator.of(context, rootNavigator: true);
    final notifier = ref.read(bookmarkProvider.notifier);
    final confirmed = await showDialog<bool>(
      context: navigator.context,
      builder: (context) => AlertDialog(
        title: Text(context.t.bookmark.bulk.delete_title),
        content: Text(
          context.t.bookmark.bulk.delete_message.replaceAll(
            '{count}',
            '$count',
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
    try {
      final changed = await notifier.deleteBookmarksForPosts(config, posts);
      if (!navigator.mounted) return;
      Kurumi.showSuccessToast(
        navigator.context,
        navigator.context.t.bookmark.bulk.delete_success.replaceAll(
          '{0}',
          '$changed',
        ),
      );
      await onCompleted();
    } catch (_) {
      if (navigator.mounted) {
        Kurumi.showErrorToast(
          navigator.context,
          navigator.context.t.bookmark.bulk.failed_to_delete,
        );
      }
    }
  }
}

Future<BookmarkGroupSelectionTarget?> showBookmarkGroupSelectionDialog(
  BuildContext context, {
  required BookmarkMultiSelectionOperation operation,
  required List<Post> posts,
  required BooruConfigAuth config,
}) => showDialog<BookmarkGroupSelectionTarget>(
  context: context,
  builder: (_) => _BookmarkGroupSelectionDialog(
    operation: operation,
    posts: posts,
    config: config,
  ),
);

class _BookmarkGroupSelectionDialog extends ConsumerWidget {
  const _BookmarkGroupSelectionDialog({
    required this.operation,
    required this.posts,
    required this.config,
  });

  final BookmarkMultiSelectionOperation operation;
  final List<Post> posts;
  final BooruConfigAuth config;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(bookmarkProvider).valueOrNull;
    final groups = state?.groups ?? const <BookmarkGroup>[];
    final summary = BookmarkGroupSelectionSummary.fromPosts(
      posts: posts,
      state: state,
      booruId: config.booruIdHint,
    );
    final add = operation == BookmarkMultiSelectionOperation.add;
    final visibleGroups = groups
        .where((group) => add || summary.countFor(group.id) > 0)
        .toList();
    return AlertDialog(
      title: Text(
        add
            ? context.t.bookmark.bulk.add_title
            : context.t.bookmark.bulk.remove_title,
      ),
      content: SizedBox(
        width: 360,
        child: BookmarkFolderPickerContents(
          folders: state?.folders ?? const [],
          groups: visibleGroups,
          membershipGroupIds: posts.length == 1
              ? state?.membershipsFor(
                  bookmarkIdentityForPost(posts.single, config.booruIdHint),
                )
              : null,
          homeChildren: [
            if (add)
              _tile(
                context,
                BookmarkGroupSelectionTarget(
                  null,
                  context.t.bookmark.groups.ungrouped,
                ),
                summary.ungroupedBookmarks,
              ),
          ],
          groupBuilder: (context, group) => _tile(
            context,
            BookmarkGroupSelectionTarget(group.id, group.name),
            summary.countFor(group.id),
          ),
          footerBuilder: (context, folderId) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!add && visibleGroups.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(context.t.bookmark.bulk.no_applicable),
                ),
              if (add)
                ListTile(
                  leading: const Icon(Icons.add),
                  title: Text(context.t.bookmark.bulk.create_group),
                  onTap: () => _create(context, ref, folderId),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.t.generic.action.cancel),
        ),
      ],
    );
  }

  Widget _tile(
    BuildContext context,
    BookmarkGroupSelectionTarget target,
    int count,
  ) => ListTile(
    leading: Icon(
      target.id == null ? Symbols.bookmark : Symbols.bookmarks,
      fill: posts.length == 1 && count > 0 ? 1 : 0,
    ),
    title: Text(target.name),
    subtitle: Text(
      context.t.bookmark.bulk.membership_count
          .replaceAll('{0}', '$count')
          .replaceAll('{1}', '${posts.length}'),
    ),
    onTap: () => Navigator.pop(context, target),
  );

  Future<void> _create(
    BuildContext context,
    WidgetRef ref,
    String? folderId,
  ) async {
    final name = await showBookmarkGroupNameDialog(
      context,
      title: context.t.bookmark.groups.create,
    );
    if (name == null || !context.mounted) return;
    try {
      final result = await ref
          .read(bookmarkProvider.notifier)
          .createGroupWithPosts(name, config, posts, folderId: folderId);
      if (context.mounted) {
        Navigator.pop(
          context,
          BookmarkGroupSelectionTarget(
            result.group.id,
            result.group.name,
            appliedCount: result.addedCount,
          ),
        );
      }
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
