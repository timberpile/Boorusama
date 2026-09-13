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

Future<bool> showBookmarkMultiSelectionActions(
  BuildContext context, {
  required WidgetRef ref,
  required List<Bookmark> bookmarks,
}) async {
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
    'add' => _add(context, ref, bookmarks),
    'remove' => _remove(context, ref, bookmarks),
    'delete' => _delete(context, ref, bookmarks),
    _ => false,
  };
}

Future<bool> _add(
  BuildContext context,
  WidgetRef ref,
  List<Bookmark> bookmarks,
) async {
  final groupId = await _selectGroup(context, ref, allowCreate: true);
  if (groupId == null) return false;
  await ref
      .read(bookmarkProvider.notifier)
      .addExistingBookmarksToGroup(bookmarks, groupId);
  return false;
}

Future<bool> _remove(
  BuildContext context,
  WidgetRef ref,
  List<Bookmark> bookmarks,
) async {
  final groupId = await _selectGroup(context, ref);
  if (groupId == null) return false;
  await ref.read(bookmarkProvider.notifier).removeFromGroup(bookmarks, groupId);
  return false;
}

Future<bool> _delete(
  BuildContext context,
  WidgetRef ref,
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
  await ref.read(bookmarkProvider.notifier).removeBookmarks(bookmarks);
  return true;
}

Future<String?> _selectGroup(
  BuildContext context,
  WidgetRef ref, {
  bool allowCreate = false,
}) {
  final groups = ref.read(bookmarkProvider).valueOrNull?.groups ?? const [];
  return showDialog<String>(
    context: context,
    builder: (dialogContext) => SimpleDialog(
      title: Text(context.t.bookmark.groups.selector),
      children: [
        for (final group in groups)
          SimpleDialogOption(
            onPressed: () => Navigator.pop(dialogContext, group.id),
            child: Text(group.name),
          ),
        if (allowCreate)
          SimpleDialogOption(
            onPressed: () async {
              final name = await showBookmarkGroupNameDialog(
                dialogContext,
                title: context.t.bookmark.groups.create,
              );
              if (name == null || !dialogContext.mounted) return;
              final group = await ref
                  .read(bookmarkProvider.notifier)
                  .createGroup(name, activate: true);
              if (dialogContext.mounted) {
                Navigator.pop(dialogContext, group.id);
              }
            },
            child: Text(context.t.bookmark.groups.create_new),
          ),
      ],
    ),
  );
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
      final id = post is BookmarkPost
          ? post.bookmark.uniqueId
          : BookmarkUniqueId.fromPost(post, booruId);
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
  const BookmarkGroupSelectionTarget(this.id, this.name);

  final String? id;
  final String name;
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
        if (summary.membershipCounts.isNotEmpty)
          KurumiPopupMenuItem(
            title: Text(context.t.bookmark.bulk.remove),
            trailing: const Icon(Icons.chevron_right),
            onTap: () =>
                _select(context, ref, BookmarkMultiSelectionOperation.remove),
          ),
        if (summary.bookmarkedPosts > 0) ...[
          const Divider(),
          KurumiPopupMenuItem(
            icon: const Icon(Symbols.delete),
            title: Text(context.t.bookmark.bulk.delete),
            onTap: () => _delete(context, ref, summary.bookmarkedPosts),
          ),
        ],
      ],
    );
  }

  Future<void> _select(
    BuildContext context,
    WidgetRef ref,
    BookmarkMultiSelectionOperation operation,
  ) async {
    final navigator = Navigator.of(context, rootNavigator: true);
    final target = await showBookmarkGroupSelectionDialog(
      navigator.context,
      operation: operation,
      posts: posts,
      config: config,
    );
    if (target == null || !navigator.mounted) return;
    try {
      if (operation == BookmarkMultiSelectionOperation.add) {
        final changed = await ref
            .read(bookmarkProvider.notifier)
            .addPostsToGroup(config, posts, target.id);
        if (!navigator.mounted) return;
        Kurumi.showSuccessToast(
          navigator.context,
          navigator.context.t.bookmark.bulk.add_success
              .replaceAll('{0}', '$changed')
              .replaceAll('{1}', target.name),
        );
      } else {
        final result = await ref
            .read(bookmarkProvider.notifier)
            .removePostsFromGroup(config, posts, target.id!);
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
      final changed = await ref
          .read(bookmarkProvider.notifier)
          .deleteBookmarksForPosts(config, posts);
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
        width: double.maxFinite,
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                context.t.bookmark.bulk.selection_summary
                    .replaceAll('{0}', '${summary.bookmarkedPosts}')
                    .replaceAll('{1}', '${summary.totalPosts}'),
              ),
            ),
            if (add)
              _tile(
                context,
                BookmarkGroupSelectionTarget(
                  null,
                  context.t.bookmark.groups.ungrouped,
                ),
                summary.ungroupedBookmarks,
              ),
            for (final group in visibleGroups)
              _tile(
                context,
                BookmarkGroupSelectionTarget(group.id, group.name),
                summary.countFor(group.id),
              ),
            if (!add && visibleGroups.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(context.t.bookmark.bulk.no_applicable),
              ),
            if (add) ...[
              const Divider(),
              ListTile(
                leading: const Icon(Symbols.create_new_folder),
                title: Text(context.t.bookmark.bulk.create_group),
                onTap: () => _create(context, ref),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _tile(
    BuildContext context,
    BookmarkGroupSelectionTarget target,
    int count,
  ) => ListTile(
    leading: Icon(target.id == null ? Symbols.bookmark : Symbols.bookmarks),
    title: Text(target.name),
    subtitle: Text(
      context.t.bookmark.bulk.membership_count
          .replaceAll('{0}', '$count')
          .replaceAll('{1}', '${posts.length}'),
    ),
    onTap: () => Navigator.pop(context, target),
  );

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final name = await showBookmarkGroupNameDialog(
      context,
      title: context.t.bookmark.groups.create,
    );
    if (name == null || !context.mounted) return;
    try {
      final group = await ref
          .read(bookmarkProvider.notifier)
          .createGroup(name, activate: true);
      if (context.mounted) {
        Navigator.pop(
          context,
          BookmarkGroupSelectionTarget(group.id, group.name),
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
