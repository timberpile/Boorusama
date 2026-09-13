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
import '../providers/bookmark_provider.dart';
import '../types/bookmark.dart';
import '../types/bookmark_target.dart';
import 'bookmark_group_name_dialog.dart';

Future<void> showBookmarkGroupPicker(
  BuildContext context, {
  required BooruConfigAuth config,
  required Post post,
}) => showDialog<void>(
  context: context,
  builder: (_) => BookmarkGroupPicker(config: config, post: post),
);

Future<void> showAnchoredBookmarkGroupPicker(
  BuildContext context, {
  required BooruConfigAuth config,
  required Post post,
  required Offset position,
}) async {
  final container = ProviderScope.containerOf(context, listen: false);
  final navigator = Navigator.of(context, rootNavigator: true);
  final library = container.read(bookmarkProvider).valueOrNull;
  if (library == null) return;
  final uniqueId = switch (post) {
    BookmarkPost(:final bookmark) => bookmark.uniqueId,
    _ => BookmarkUniqueId.fromPost(post, config.booruIdHint),
  };
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
  if (selected == null || !navigator.mounted) return;
  final notifier = container.read(bookmarkProvider.notifier);
  void added() => _showPickerSuccess(navigator, added: true);
  void removed() => _showPickerSuccess(navigator, added: false);
  void failed() => _showPickerError(navigator);
  try {
    if (selected == 'create') {
      final name = await showBookmarkGroupNameDialog(
        navigator.context,
        title: navigator.context.t.bookmark.groups.create,
      );
      if (name == null) return;
      await notifier.createGroupWithPosts(name, config, [post]);
      added();
      return;
    }
    final target = selected == 'ungrouped'
        ? const BookmarkTarget.ungrouped()
        : BookmarkTarget.group(selected);
    if (!await notifier.setActiveTarget(target)) {
      failed();
      return;
    }
    if (selected == 'ungrouped') {
      if (bookmark == null) {
        await notifier.addBookmark(
          config,
          post,
          onSuccess: added,
          onError: failed,
        );
      } else {
        await notifier.removeBookmark(
          bookmark,
          onSuccess: removed,
          onError: failed,
        );
      }
      return;
    }
    if (bookmark == null) {
      await notifier.addBookmarkToGroup(
        config,
        post,
        selected,
        onSuccess: added,
        onError: failed,
      );
    } else if (memberships.contains(selected)) {
      await notifier.removeFromGroup(
        [bookmark],
        selected,
        deleteWhenMembershipBecomesEmpty: true,
        onSuccess: removed,
        onError: failed,
      );
    } else {
      await notifier.addExistingBookmarkToGroup(
        bookmark,
        selected,
        onSuccess: added,
        onError: failed,
      );
    }
  } catch (_) {
    failed();
  }
}

void _showPickerSuccess(NavigatorState navigator, {required bool added}) {
  if (!navigator.mounted) return;
  Kurumi.showSuccessToast(
    navigator.context,
    added
        ? navigator.context.t.bookmark.added
        : navigator.context.t.bookmark.removed,
  );
}

void _showPickerError(NavigatorState navigator) {
  if (!navigator.mounted) return;
  Kurumi.showErrorToast(
    navigator.context,
    navigator.context.t.bookmark.groups.operation_failed,
  );
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
    final uniqueId = switch (post) {
      BookmarkPost(:final bookmark) => bookmark.uniqueId,
      _ => BookmarkUniqueId.fromPost(post, config.booruIdHint),
    };
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
              onTap: () => _createAndAdd(context, ref),
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
    final navigator = Navigator.of(context, rootNavigator: true);
    final notifier = ref.read(bookmarkProvider.notifier);
    if (!await notifier.setActiveTarget(const BookmarkTarget.ungrouped())) {
      _showPickerError(navigator);
      return;
    }
    var completed = false;
    if (bookmark == null) {
      await notifier.addBookmark(
        config,
        post,
        onSuccess: () {
          completed = true;
          _showPickerSuccess(navigator, added: true);
        },
        onError: () => _showPickerError(navigator),
      );
    } else {
      await notifier.removeBookmark(
        bookmark,
        onSuccess: () {
          completed = true;
          _showPickerSuccess(navigator, added: false);
        },
        onError: () => _showPickerError(navigator),
      );
    }
    if (completed && navigator.mounted) navigator.pop();
  }

  Future<void> _toggleGroup(
    BuildContext context,
    WidgetRef ref,
    Bookmark? bookmark,
    String groupId,
    bool contains,
  ) async {
    final navigator = Navigator.of(context, rootNavigator: true);
    final notifier = ref.read(bookmarkProvider.notifier);
    if (!await notifier.setActiveTarget(BookmarkTarget.group(groupId))) {
      _showPickerError(navigator);
      return;
    }
    var completed = false;
    void added() {
      completed = true;
      _showPickerSuccess(navigator, added: true);
    }

    void removed() {
      completed = true;
      _showPickerSuccess(navigator, added: false);
    }

    void failed() => _showPickerError(navigator);
    if (contains && bookmark != null) {
      await notifier.removeFromGroup(
        [bookmark],
        groupId,
        deleteWhenMembershipBecomesEmpty: true,
        onSuccess: removed,
        onError: failed,
      );
    } else if (bookmark != null) {
      await notifier.addExistingBookmarkToGroup(
        bookmark,
        groupId,
        onSuccess: added,
        onError: failed,
      );
    } else {
      await notifier.addBookmarkToGroup(
        config,
        post,
        groupId,
        onSuccess: added,
        onError: failed,
      );
    }
    if (completed && navigator.mounted) navigator.pop();
  }

  Future<void> _createAndAdd(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final navigator = Navigator.of(context, rootNavigator: true);
    final name = await showBookmarkGroupNameDialog(
      context,
      title: context.t.bookmark.groups.create,
    );
    if (name == null || !context.mounted) return;
    final notifier = ref.read(bookmarkProvider.notifier);
    var completed = false;
    void added() {
      completed = true;
      _showPickerSuccess(navigator, added: true);
    }

    void failed() => _showPickerError(navigator);
    try {
      await notifier.createGroupWithPosts(name, config, [post]);
      added();
    } catch (_) {
      failed();
    }
    if (completed && navigator.mounted) navigator.pop();
  }
}
