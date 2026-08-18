// Flutter imports:
import 'package:flutter/material.dart';

// Package imports:
import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';
import 'package:material_symbols_icons/symbols.dart';

// Project imports:
import '../../../configs/config/types.dart';
import '../../../posts/post/types.dart';
import '../data/providers.dart';
import '../providers/bookmark_group_providers.dart';
import '../providers/bookmark_provider.dart';
import '../types/bookmark.dart';
import '../types/bookmark_group.dart';

/// The local bookmark actions shared by post-thumbnail context menus.
class BookmarkContextMenuSection extends ConsumerWidget {
  const BookmarkContextMenuSection({
    required this.post,
    required this.config,
    super.key,
    this.bookmark,
    this.onBookmarkDeleted,
  });

  final Post post;
  final BooruConfigAuth config;
  final Bookmark? bookmark;
  final VoidCallback? onBookmarkDeleted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(bookmarkProvider).valueOrNull;
    final groups = ref.watch(bookmarkGroupsProvider).valueOrNull ?? const [];
    final bookmarkId =
        bookmark?.uniqueId ??
        BookmarkUniqueId.fromPost(post, config.booruIdHint);
    final isBookmarked =
        bookmark != null || (state?.bookmarks.contains(bookmarkId) ?? false);
    final memberships = state?.memberships[bookmarkId] ?? const <int>{};
    final activeTarget = ref.watch(effectiveActiveBookmarkGroupIdProvider);
    final activeName = _targetName(context, activeTarget, groups);
    final activeMembership = activeTarget == kUngroupedBookmarkGroupId
        ? isBookmarked && memberships.isEmpty
        : memberships.contains(activeTarget);
    final addActive =
        !activeMembership &&
        (activeTarget != kUngroupedBookmarkGroupId || !isBookmarked);
    final removeActive =
        activeTarget != kUngroupedBookmarkGroupId &&
        memberships.contains(activeTarget);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const KurumiContextMenuDivider(),
        KurumiContextMenuTile(
          title: context.t.bookmark.groups.add_to,
          onTap: () => _showGroupPicker(
            context,
            ref,
            groups: groups,
            memberships: memberships,
            isBookmarked: isBookmarked,
            add: true,
          ),
        ),
        if (addActive)
          KurumiContextMenuTile(
            title: context.t.bookmark.groups.add_to_target(target: activeName),
            onTap: () => _addToTarget(
              context,
              ref,
              activeTarget,
            ),
          ),
        if (memberships.isNotEmpty)
          KurumiContextMenuTile(
            title: context.t.bookmark.groups.remove_from,
            onTap: () => _showGroupPicker(
              context,
              ref,
              groups: groups,
              memberships: memberships,
              isBookmarked: isBookmarked,
              add: false,
            ),
          ),
        if (removeActive)
          KurumiContextMenuTile(
            title: context.t.bookmark.groups.remove_from_target(
              target: activeName,
            ),
            onTap: () => _removeFromGroup(
              context,
              ref,
              activeTarget,
            ),
          ),
        if (isBookmarked) ...[
          const KurumiContextMenuDivider(),
          KurumiContextMenuTile(
            title: context.t.bookmark.groups.delete_completely,
            onTap: () => _deleteBookmark(context, ref, bookmarkId),
          ),
        ],
      ],
    );
  }

  Future<void> _showGroupPicker(
    BuildContext context,
    WidgetRef ref, {
    required List<BookmarkGroup> groups,
    required Set<int> memberships,
    required bool isBookmarked,
    required bool add,
  }) async {
    final availableGroups = groups.isNotEmpty
        ? groups
        : await ref.read(bookmarkGroupsProvider.future);
    if (!context.mounted) return;
    final choices = add
        ? availableGroups
              .where((group) => !memberships.contains(group.id))
              .toList()
        : availableGroups
              .where((group) => memberships.contains(group.id))
              .toList();

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            if (add)
              ListTile(
                leading: const Icon(Symbols.create_new_folder),
                title: Text(context.t.bookmark.groups.create_new),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  await _createGroupAndAdd(context, ref);
                },
              ),
            if (add && !isBookmarked)
              ListTile(
                leading: const Icon(Symbols.bookmark_add),
                title: Text(context.t.bookmark.groups.ungrouped),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _addToTarget(context, ref, kUngroupedBookmarkGroupId);
                },
              ),
            ...choices.map(
              (group) => ListTile(
                leading: const Icon(Symbols.bookmarks),
                title: Text(group.name),
                onTap: () {
                  Navigator.pop(sheetContext);
                  if (add) {
                    _addToTarget(context, ref, group.id);
                  } else {
                    _removeFromGroup(context, ref, group.id);
                  }
                },
              ),
            ),
            if (choices.isEmpty && !(add && !isBookmarked))
              ListTile(
                enabled: false,
                title: Text(context.t.bookmark.groups.no_applicable),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _addToTarget(
    BuildContext context,
    WidgetRef ref,
    int groupId,
  ) async {
    await setActiveBookmarkGroupId(ref, groupId);

    if (groupId == kUngroupedBookmarkGroupId) {
      await ref.bookmarks.addBookmark(
        config,
        post,
        onError: () =>
            _showError(context, context.t.bookmark.groups.failed_to_add),
      );
      return;
    }

    void onError() =>
        _showError(context, context.t.bookmark.groups.failed_to_add_to_group);
    if (bookmark case final existing?) {
      await ref.bookmarks.addExistingBookmarkToGroup(
        existing,
        groupId,
        onError: onError,
      );
    } else {
      await ref.bookmarks.addBookmarkToGroup(
        config,
        post,
        groupId,
        onError: onError,
      );
    }
  }

  Future<void> _removeFromGroup(
    BuildContext context,
    WidgetRef ref,
    int groupId,
  ) async {
    final id =
        bookmark?.uniqueId ??
        BookmarkUniqueId.fromPost(post, config.booruIdHint);
    await ref.bookmarks.removeBookmarkFromGroup(
      id,
      groupId,
      onError: () => _showError(
        context,
        context.t.bookmark.groups.failed_to_remove_from_group,
      ),
    );
  }

  Future<void> _createGroupAndAdd(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final name = await _showGroupNameDialog(context);
    if (name == null) return;

    try {
      final group = await (await ref.read(
        bookmarkGroupRepoProvider.future,
      )).createGroup(name);
      await setActiveBookmarkGroupId(ref, group.id);

      if (bookmark case final existing?) {
        await ref.bookmarks.addExistingBookmarkToGroup(existing, group.id);
      } else {
        await ref.bookmarks.addBookmarkToGroup(config, post, group.id);
      }
      refreshBookmarkGroupProviders(ref);
    } catch (error) {
      if (context.mounted) _showError(context, error.toString());
    }
  }

  Future<void> _deleteBookmark(
    BuildContext context,
    WidgetRef ref,
    BookmarkUniqueId bookmarkId,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.t.bookmark.groups.delete_completely_title),
        content: Text(
          context.t.bookmark.groups.delete_completely_message,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.t.generic.action.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(context.t.generic.action.delete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await ref.bookmarks.removeBookmarkWithToast(
      bookmarkId,
      onSuccess: onBookmarkDeleted,
    );
  }

  Future<String?> _showGroupNameDialog(BuildContext context) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.t.bookmark.groups.create),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: context.t.bookmark.groups.name,
          ),
          onSubmitted: (value) => Navigator.pop(dialogContext, value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(context.t.generic.action.cancel),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: Text(context.t.generic.action.create),
          ),
        ],
      ),
    );
    controller.dispose();
    return result?.isNotEmpty ?? false ? result : null;
  }

  void _showError(BuildContext context, String message) {
    if (context.mounted) Kurumi.showErrorToast(context, message);
  }

  String _targetName(
    BuildContext context,
    int target,
    List<BookmarkGroup> groups,
  ) {
    if (target == kUngroupedBookmarkGroupId) {
      return context.t.bookmark.groups.ungrouped;
    }
    return groups
            .where((group) => group.id == target)
            .map((group) => group.name)
            .firstOrNull ??
        context.t.bookmark.groups.ungrouped;
  }
}
