// Flutter imports:
import 'package:flutter/material.dart';

// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:material_symbols_icons/symbols.dart';

// Project imports:
import '../../../configs/config/types.dart';
import '../../../posts/post/types.dart';
import '../providers/bookmark_provider.dart';
import '../types/bookmark.dart';
import '../types/bookmark_target.dart';
import 'bookmark_group_name_dialog.dart';

Future<void> showBookmarkGroupPicker(
  BuildContext context, {
  required WidgetRef ref,
  required BooruConfigAuth config,
  required Post post,
}) => showDialog<void>(
  context: context,
  builder: (_) => BookmarkGroupPicker(config: config, post: post),
);

Future<void> showAnchoredBookmarkGroupPicker(
  BuildContext context, {
  required WidgetRef ref,
  required BooruConfigAuth config,
  required Post post,
  required Offset position,
}) async {
  final library = ref.read(bookmarkProvider).valueOrNull;
  if (library == null) return;
  final uniqueId = BookmarkUniqueId.fromPost(post, config.booruIdHint);
  final bookmark = library.bookmarksByUniqueId[uniqueId];
  final memberships = library.membershipsFor(uniqueId);
  final overlay = Overlay.of(context).context.findRenderObject()! as RenderBox;
  final selected = await showMenu<String>(
    context: context,
    position: RelativeRect.fromRect(
      Rect.fromCenter(center: position, width: 1, height: 1),
      Offset.zero & overlay.size,
    ),
    items: [
      if (bookmark == null || memberships.isEmpty)
        PopupMenuItem(
          value: 'ungrouped',
          child: Text(context.t.bookmark.groups.ungrouped),
        ),
      for (final group in library.groups)
        CheckedPopupMenuItem(
          value: group.id,
          checked: memberships.contains(group.id),
          child: Text(group.name),
        ),
      PopupMenuItem(
        value: 'create',
        child: Text(context.t.bookmark.groups.create_new),
      ),
    ],
  );
  if (selected == null || !context.mounted) return;
  final notifier = ref.read(bookmarkProvider.notifier);
  if (selected == 'create') {
    final name = await showBookmarkGroupNameDialog(
      context,
      title: context.t.bookmark.groups.create,
    );
    if (name == null) return;
    final group = await notifier.createGroup(name, activate: true);
    return bookmark == null
        ? notifier.addBookmarkToGroup(config, post, group.id)
        : notifier.addExistingBookmarkToGroup(bookmark, group.id);
  }
  if (selected == 'ungrouped') {
    await notifier.setActiveTarget(const BookmarkTarget.ungrouped());
    return bookmark == null
        ? notifier.addBookmark(config, post)
        : notifier.removeBookmark(bookmark);
  }
  await notifier.setActiveTarget(BookmarkTarget.group(selected));
  return switch ((bookmark, memberships.contains(selected))) {
    (final Bookmark bookmark, true) => notifier.removeFromGroup(
      [bookmark],
      selected,
      deleteWhenMembershipBecomesEmpty: true,
    ),
    (final Bookmark bookmark, false) => notifier.addExistingBookmarkToGroup(
      bookmark,
      selected,
    ),
    _ => notifier.addBookmarkToGroup(config, post, selected),
  };
}

class BookmarkGroupPicker extends ConsumerWidget {
  const BookmarkGroupPicker({
    required this.config,
    required this.post,
    super.key,
  });

  final BooruConfigAuth config;
  final Post post;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final library = ref.watch(bookmarkProvider).valueOrNull;
    final uniqueId = BookmarkUniqueId.fromPost(post, config.booruIdHint);
    final bookmark = library?.bookmarksByUniqueId[uniqueId];
    final memberships = library?.membershipsFor(uniqueId) ?? const <String>{};
    return AlertDialog(
      title: Text(context.t.bookmark.groups.selector),
      content: SizedBox(
        width: 360,
        child: ListView(
          shrinkWrap: true,
          children: [
            if (bookmark == null || memberships.isEmpty)
              CheckboxListTile(
                value: bookmark != null && memberships.isEmpty,
                title: Text(context.t.bookmark.groups.ungrouped),
                onChanged: (_) => _toggleUngrouped(context, ref, bookmark),
              ),
            for (final group in library?.groups ?? const [])
              CheckboxListTile(
                value: memberships.contains(group.id),
                title: Text(group.name),
                secondary: library?.activeTarget.groupId == group.id
                    ? const Icon(Symbols.check_circle)
                    : null,
                onChanged: (_) => _toggleGroup(
                  context,
                  ref,
                  bookmark,
                  group.id,
                  memberships.contains(group.id),
                ),
              ),
            ListTile(
              leading: const Icon(Symbols.create_new_folder),
              title: Text(context.t.bookmark.groups.create_new),
              onTap: () => _createAndAdd(context, ref, bookmark),
            ),
          ],
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

  Future<void> _toggleUngrouped(
    BuildContext context,
    WidgetRef ref,
    Bookmark? bookmark,
  ) async {
    final notifier = ref.read(bookmarkProvider.notifier);
    await notifier.setActiveTarget(const BookmarkTarget.ungrouped());
    if (bookmark == null) {
      await notifier.addBookmark(config, post);
    } else {
      await notifier.removeBookmark(bookmark);
    }
    if (context.mounted) Navigator.pop(context);
  }

  Future<void> _toggleGroup(
    BuildContext context,
    WidgetRef ref,
    Bookmark? bookmark,
    String groupId,
    bool contains,
  ) async {
    final notifier = ref.read(bookmarkProvider.notifier);
    await notifier.setActiveTarget(BookmarkTarget.group(groupId));
    if (contains && bookmark != null) {
      await notifier.removeFromGroup(
        [bookmark],
        groupId,
        deleteWhenMembershipBecomesEmpty: true,
      );
    } else if (bookmark != null) {
      await notifier.addExistingBookmarkToGroup(bookmark, groupId);
    } else {
      await notifier.addBookmarkToGroup(config, post, groupId);
    }
    if (context.mounted) Navigator.pop(context);
  }

  Future<void> _createAndAdd(
    BuildContext context,
    WidgetRef ref,
    Bookmark? bookmark,
  ) async {
    final name = await showBookmarkGroupNameDialog(
      context,
      title: context.t.bookmark.groups.create,
    );
    if (name == null || !context.mounted) return;
    final notifier = ref.read(bookmarkProvider.notifier);
    final group = await notifier.createGroup(name, activate: true);
    if (bookmark != null) {
      await notifier.addExistingBookmarkToGroup(bookmark, group.id);
    } else {
      await notifier.addBookmarkToGroup(config, post, group.id);
    }
    if (context.mounted) Navigator.pop(context);
  }
}
