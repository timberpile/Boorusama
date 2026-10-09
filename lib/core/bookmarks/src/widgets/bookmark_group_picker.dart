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
import '../types/bookmark_target.dart';
import 'bookmark_active_target_badge.dart';
import 'bookmark_folder_picker_contents.dart';
import 'bookmark_group_name_dialog.dart';

Future<void> showBookmarkGroupPicker(
  BuildContext context, {
  required BooruConfigAuth config,
  required Post post,
}) => showDialog<void>(
  context: context,
  builder: (_) => BookmarkGroupPicker(config: config, post: post),
);

/// Uses the same anchored surface and compact rows as viewer toolbar menus.
class BookmarkGroupPickerAnchor extends StatefulWidget {
  const BookmarkGroupPickerAnchor({
    required this.config,
    required this.post,
    required this.builder,
    super.key,
  });

  final BooruConfigAuth config;
  final Post post;
  final Widget Function(BuildContext, VoidCallback show) builder;

  @override
  State<BookmarkGroupPickerAnchor> createState() =>
      _BookmarkGroupPickerAnchorState();
}

class _BookmarkGroupPickerAnchorState extends State<BookmarkGroupPickerAnchor> {
  final _controller = AnchorController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => KurumiAnchor(
    controller: _controller,
    overlayBuilder: (context) => Padding(
      padding: const EdgeInsets.all(8),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 200,
          maxHeight: MediaQuery.heightOf(context) * .6,
        ),
        child: BookmarkGroupPicker(
          config: widget.config,
          post: widget.post,
          anchored: true,
          onDismiss: _controller.hide,
        ),
      ),
    ),
    child: widget.builder(context, _controller.show),
  );
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

void _showPickerMissingIdentity(NavigatorState navigator) {
  if (!navigator.mounted) return;
  Kurumi.showErrorToast(
    navigator.context,
    navigator.context.t.bookmark.missing_post_identity,
  );
}

void _showPickerError(NavigatorState navigator) {
  if (!navigator.mounted) return;
  Kurumi.showErrorToast(
    navigator.context,
    navigator.context.t.bookmark.groups.operation_failed,
  );
}

bool _handleToggleOutcome(
  NavigatorState navigator,
  BookmarkToggleOutcome outcome,
) => switch (outcome) {
  BookmarkToggleOutcome.added => (() {
    _showPickerSuccess(navigator, added: true);
    return true;
  })(),
  BookmarkToggleOutcome.removed => (() {
    _showPickerSuccess(navigator, added: false);
    return true;
  })(),
  BookmarkToggleOutcome.missingPostIdentity => (() {
    _showPickerMissingIdentity(navigator);
    return false;
  })(),
  BookmarkToggleOutcome.unavailable || BookmarkToggleOutcome.failed => (() {
    _showPickerError(navigator);
    return false;
  })(),
};

class BookmarkGroupPicker extends ConsumerStatefulWidget {
  const BookmarkGroupPicker({
    required this.config,
    required this.post,
    this.anchored = false,
    this.onDismiss,
    super.key,
  });

  final BooruConfigAuth config;
  final Post post;
  final bool anchored;
  final VoidCallback? onDismiss;

  @override
  ConsumerState<BookmarkGroupPicker> createState() =>
      _BookmarkGroupPickerState();
}

class _BookmarkGroupPickerState extends ConsumerState<BookmarkGroupPicker> {
  BooruConfigAuth get config => widget.config;
  Post get post => widget.post;
  @override
  Widget build(BuildContext context) {
    final library = ref.watch(bookmarkProvider).valueOrNull;
    final uniqueId = bookmarkIdentityForPost(post, config.booruIdHint);
    final bookmark = library?.bookmarksByUniqueId[uniqueId];
    final memberships = library?.membershipsFor(uniqueId) ?? const <String>{};

    Widget activeIndicator() => KurumiTooltip(
      message: context.t.bookmark.groups.active,
      child: Icon(
        Icons.check,
        size: 20,
        semanticLabel: context.t.bookmark.groups.active,
      ),
    );

    final contents = BookmarkFolderPickerContents(
      compact: widget.anchored,
      folders: library?.folders ?? const [],
      groups: library?.groups ?? const [],
      membershipGroupIds: memberships,
      homeChildren: [
        if (bookmark == null || memberships.isEmpty)
          if (widget.anchored)
            BookmarkPickerMenuItem(
              icon: Icon(
                Symbols.bookmark,
                fill: bookmark != null && memberships.isEmpty ? 1 : 0,
              ),
              title: context.t.bookmark.groups.ungrouped,
              trailing: library?.activeTarget.groupId == null
                  ? activeIndicator()
                  : null,
              hideOnTap: false,
              onTap: () => _toggleUngrouped(context, ref),
            )
          else
            ListTile(
              leading: Icon(
                Symbols.bookmark,
                fill: bookmark != null && memberships.isEmpty ? 1 : 0,
              ),
              title: Text(context.t.bookmark.groups.ungrouped),
              trailing: library?.activeTarget.groupId == null
                  ? BookmarkActiveTargetBadge(
                      label: context.t.bookmark.groups.active,
                    )
                  : null,
              onTap: () => _toggleUngrouped(context, ref),
            ),
      ],
      groupBuilder: (context, group) => widget.anchored
          ? BookmarkPickerMenuItem(
              icon: Icon(
                Symbols.bookmarks,
                fill: memberships.contains(group.id) ? 1 : 0,
              ),
              title: group.name,
              trailing: library?.activeTarget.groupId == group.id
                  ? activeIndicator()
                  : null,
              hideOnTap: false,
              onTap: () => _toggleGroup(context, ref, group.id),
            )
          : ListTile(
              leading: Icon(
                Symbols.bookmarks,
                fill: memberships.contains(group.id) ? 1 : 0,
              ),
              title: Text(
                group.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: library?.activeTarget.groupId == group.id
                  ? BookmarkActiveTargetBadge(
                      label: context.t.bookmark.groups.active,
                    )
                  : null,
              onTap: () => _toggleGroup(context, ref, group.id),
            ),
      footerBuilder: (context, folderId) => widget.anchored
          ? BookmarkPickerMenuItem(
              icon: const Icon(Icons.add),
              title: context.t.bookmark.groups.create_new,
              hideOnTap: false,
              onTap: () => _createAndAdd(context, ref, folderId),
            )
          : ListTile(
              leading: const Icon(Icons.add),
              title: Text(context.t.bookmark.groups.create_new),
              onTap: () => _createAndAdd(context, ref, folderId),
            ),
    );
    if (widget.anchored) return contents;
    return AlertDialog(
      title: Text(context.t.bookmark.groups.selector),
      content: SizedBox(width: 360, child: contents),
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
  ) async {
    final navigator = Navigator.of(context, rootNavigator: true);
    final notifier = ref.read(bookmarkProvider.notifier);
    final outcome = await notifier.togglePostTarget(
      config,
      post,
      target: const BookmarkTarget.ungrouped(),
      activateTarget: true,
    );
    final completed = _handleToggleOutcome(navigator, outcome);
    if (completed && navigator.mounted) _dismiss(navigator);
  }

  Future<void> _toggleGroup(
    BuildContext context,
    WidgetRef ref,
    String groupId,
  ) async {
    final navigator = Navigator.of(context, rootNavigator: true);
    final notifier = ref.read(bookmarkProvider.notifier);
    final outcome = await notifier.togglePostTarget(
      config,
      post,
      target: BookmarkTarget.group(groupId),
      activateTarget: true,
    );
    final completed = _handleToggleOutcome(navigator, outcome);
    if (completed && navigator.mounted) _dismiss(navigator);
  }

  Future<void> _createAndAdd(
    BuildContext context,
    WidgetRef ref,
    String? folderId,
  ) async {
    final navigator = Navigator.of(context, rootNavigator: true);
    final notifier = ref.read(bookmarkProvider.notifier);
    // An anchor is an overlay, not a route. Close it before opening the dialog
    // and retain the navigator/notifier because this picker will be disposed.
    final anchored = widget.anchored;
    if (anchored) widget.onDismiss?.call();
    final name = await showBookmarkGroupNameDialog(
      anchored ? navigator.context : context,
      title: context.t.bookmark.groups.create,
    );
    if (name == null || !navigator.mounted || (!anchored && !mounted)) return;
    var completed = false;
    void added() {
      completed = true;
      _showPickerSuccess(navigator, added: true);
    }

    void failed() => _showPickerError(navigator);
    try {
      await notifier.createGroupWithPosts(name, config, [
        post,
      ], folderId: folderId);
      added();
    } catch (_) {
      failed();
    }
    if (completed && !anchored && navigator.mounted) _dismiss(navigator);
  }

  void _dismiss(NavigatorState navigator) {
    if (widget.anchored) {
      widget.onDismiss?.call();
    } else {
      navigator.pop();
    }
  }
}
