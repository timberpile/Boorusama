// Flutter imports:
import 'package:flutter/material.dart';

// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:material_symbols_icons/symbols.dart';

// Project imports:
import '../../../configs/config/types.dart';
import '../../../posts/post/types.dart';
import '../data/bookmark_convert.dart';
import '../data/providers.dart';
import '../providers/bookmark_group_providers.dart';
import '../providers/bookmark_provider.dart';
import '../types/bookmark.dart';
import '../types/bookmark_group.dart';
import 'bookmark_group_name_dialog.dart';

enum BookmarkMultiSelectionOperation {
  add,
  remove,
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
    required BookmarkState? state,
    required int booruId,
  }) {
    var bookmarkedPosts = 0;
    var ungroupedBookmarks = 0;
    final membershipCounts = <int, int>{};

    for (final post in posts) {
      final bookmarkId = switch (post) {
        BookmarkPost(:final bookmark) => bookmark.uniqueId,
        _ => BookmarkUniqueId.fromPost(post, booruId),
      };
      final isBookmarked = state?.bookmarks.contains(bookmarkId) ?? false;
      final memberships = state?.memberships[bookmarkId] ?? const <int>{};

      if (!isBookmarked) continue;

      bookmarkedPosts++;
      if (memberships.isEmpty) ungroupedBookmarks++;
      for (final groupId in memberships) {
        membershipCounts.update(
          groupId,
          (count) => count + 1,
          ifAbsent: () => 1,
        );
      }
    }

    return BookmarkGroupSelectionSummary(
      totalPosts: posts.length,
      bookmarkedPosts: bookmarkedPosts,
      ungroupedBookmarks: ungroupedBookmarks,
      membershipCounts: membershipCounts,
    );
  }

  final int totalPosts;
  final int bookmarkedPosts;
  final int ungroupedBookmarks;
  final Map<int, int> membershipCounts;

  int countFor(int groupId) => membershipCounts[groupId] ?? 0;
}

String formatBookmarkGroupRemovalSuccessMessage(
  BuildContext context,
  BookmarkGroupRemovalResult result,
  String groupName,
) {
  if (result.movedToNoGroupCount > 0) {
    return context.t.bookmark.bulk.remove_success_ungrouped
        .replaceAll('{0}', '${result.removedCount}')
        .replaceAll('{1}', groupName)
        .replaceAll('{2}', '${result.movedToNoGroupCount}');
  }

  return context.t.bookmark.bulk.remove_success
      .replaceAll('{0}', '${result.removedCount}')
      .replaceAll('{1}', groupName);
}

class BookmarkMultiSelectionMenu extends ConsumerWidget {
  const BookmarkMultiSelectionMenu({
    required this.posts,
    required this.config,
    super.key,
    this.onCompleted,
  });

  final List<Post> posts;
  final BooruConfigAuth config;
  final Future<void> Function()? onCompleted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final navigator = Navigator.of(context, rootNavigator: true);
    final container = ProviderScope.containerOf(context, listen: false);
    final state = ref.watch(bookmarkProvider).valueOrNull;
    final summary = BookmarkGroupSelectionSummary.fromPosts(
      posts: posts,
      state: state,
      booruId: config.booruIdHint,
    );
    final hasBookmarkedPosts = summary.bookmarkedPosts > 0;
    final hasGroupedPosts = summary.membershipCounts.values.any(
      (count) => count > 0,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        KurumiPopupMenuItem(
          title: Text(context.t.bookmark.bulk.add),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _openGroupSelection(
            navigator,
            container,
            BookmarkMultiSelectionOperation.add,
          ),
        ),
        if (hasGroupedPosts)
          KurumiPopupMenuItem(
            title: Text(context.t.bookmark.bulk.remove),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _openGroupSelection(
              navigator,
              container,
              BookmarkMultiSelectionOperation.remove,
            ),
          ),
        if (hasBookmarkedPosts) ...[
          const Divider(),
          KurumiPopupMenuItem(
            icon: const Icon(Symbols.delete),
            title: Text(context.t.bookmark.bulk.delete),
            onTap: () => _confirmDelete(
              navigator,
              container,
              summary.bookmarkedPosts,
            ),
          ),
        ],
      ],
    );
  }

  void _openGroupSelection(
    NavigatorState navigator,
    ProviderContainer container,
    BookmarkMultiSelectionOperation operation,
  ) {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!navigator.mounted) return;

      final target = await showBookmarkGroupSelectionDialog(
        navigator.context,
        operation: operation,
        posts: posts,
        config: config,
      );
      if (target == null || !navigator.mounted) return;

      try {
        final notifier = container.read(bookmarkProvider.notifier);
        if (!navigator.mounted) return;
        late final String message;
        switch (operation) {
          case BookmarkMultiSelectionOperation.add:
            final changed = await notifier.addPostsToGroup(
              config,
              posts,
              target.id,
            );
            if (!navigator.mounted) return;
            message = navigator.context.t.bookmark.bulk.add_success
                .replaceAll('{0}', '$changed')
                .replaceAll('{1}', target.name);
          case BookmarkMultiSelectionOperation.remove:
            final result = await notifier.removePostsFromGroup(
              config,
              posts,
              target.id,
            );
            if (!navigator.mounted) return;
            message = formatBookmarkGroupRemovalSuccessMessage(
              navigator.context,
              result,
              target.name,
            );
        }
        Kurumi.showSuccessToast(navigator.context, message);
        await onCompleted?.call();
      } catch (_) {
        if (!navigator.mounted) return;
        final message = switch (operation) {
          BookmarkMultiSelectionOperation.add =>
            navigator.context.t.bookmark.bulk.failed_to_add,
          BookmarkMultiSelectionOperation.remove =>
            navigator.context.t.bookmark.bulk.failed_to_remove,
        };
        Kurumi.showErrorToast(navigator.context, message);
      }
    });
  }

  void _confirmDelete(
    NavigatorState navigator,
    ProviderContainer container,
    int bookmarkedPosts,
  ) {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!navigator.mounted) return;

      final confirmed = await showDialog<bool>(
        context: navigator.context,
        builder: (context) => AlertDialog(
          title: Text(context.t.bookmark.bulk.delete_title),
          content: Text(
            context.t.bookmark.bulk.delete_message.replaceAll(
              '{0}',
              '$bookmarkedPosts',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(context.t.generic.action.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(context.t.bookmark.bulk.delete),
            ),
          ],
        ),
      );
      if (confirmed != true || !navigator.mounted) return;

      try {
        final changed = await container
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
        await onCompleted?.call();
      } catch (_) {
        if (navigator.mounted) {
          Kurumi.showErrorToast(
            navigator.context,
            navigator.context.t.bookmark.bulk.failed_to_delete,
          );
        }
      }
    });
  }
}

Future<BookmarkGroup?> showBookmarkGroupSelectionDialog(
  BuildContext context, {
  required BookmarkMultiSelectionOperation operation,
  required List<Post> posts,
  required BooruConfigAuth config,
}) {
  return showDialog<BookmarkGroup>(
    context: context,
    builder: (context) => _BookmarkGroupSelectionDialog(
      operation: operation,
      posts: posts,
      config: config,
    ),
  );
}

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
    final groups = ref.watch(bookmarkGroupsProvider).valueOrNull ?? const [];
    final state = ref.watch(bookmarkProvider).valueOrNull;
    final summary = BookmarkGroupSelectionSummary.fromPosts(
      posts: posts,
      state: state,
      booruId: config.booruIdHint,
    );
    final add = operation == BookmarkMultiSelectionOperation.add;
    final groupRows = groups
        .where((group) => add || summary.countFor(group.id) > 0)
        .map(
          (group) => _buildGroupTile(
            context,
            group,
            summary.countFor(group.id),
            enabled: add || summary.countFor(group.id) > 0,
          ),
        )
        .toList();

    if (!add && groupRows.isEmpty) {
      groupRows.add(
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(context.t.bookmark.groups.no_applicable),
        ),
      );
    }

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
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                context.t.bookmark.bulk.selection_summary
                    .replaceAll('{0}', '${summary.bookmarkedPosts}')
                    .replaceAll('{1}', '${summary.totalPosts}'),
              ),
            ),
            if (summary.ungroupedBookmarks > 0)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(
                  context.t.bookmark.bulk.ungrouped_summary.replaceAll(
                    '{0}',
                    '${summary.ungroupedBookmarks}',
                  ),
                ),
              ),
            if (add)
              _buildGroupTile(
                context,
                BookmarkGroup(
                  id: kUngroupedBookmarkGroupId,
                  name: context.t.bookmark.groups.ungrouped,
                ),
                summary.ungroupedBookmarks,
              ),
            ...groupRows,
            if (add) ...[
              const Divider(),
              ListTile(
                leading: const Icon(Symbols.create_new_folder),
                title: Text(context.t.bookmark.bulk.create_group),
                onTap: () => _createGroup(context, ref),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildGroupTile(
    BuildContext context,
    BookmarkGroup group,
    int count, {
    bool enabled = true,
  }) {
    return ListTile(
      enabled: enabled,
      leading: Icon(
        group.id == kUngroupedBookmarkGroupId
            ? Symbols.bookmark
            : Symbols.bookmarks,
      ),
      title: Text(group.name),
      subtitle: Text(
        context.t.bookmark.bulk.membership_count
            .replaceAll(
              '{0}',
              '$count',
            )
            .replaceAll('{1}', '${posts.length}'),
      ),
      onTap: enabled ? () => Navigator.pop(context, group) : null,
    );
  }

  Future<void> _createGroup(BuildContext context, WidgetRef ref) async {
    final name = await showBookmarkGroupNameDialog(
      context,
      title: context.t.bookmark.groups.create,
      saveLabel: context.t.generic.action.create,
      cancelLabel: context.t.generic.action.cancel,
      hintText: context.t.bookmark.groups.name,
    );
    if (name == null || !context.mounted) return;

    try {
      final group = await (await ref.read(
        bookmarkGroupRepoProvider.future,
      )).createGroup(name);
      ref.invalidate(bookmarkGroupsProvider);
      if (context.mounted) Navigator.pop(context, group);
    } catch (error) {
      if (context.mounted) Kurumi.showErrorToast(context, error.toString());
    }
  }
}
