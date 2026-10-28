import 'dart:math' as math;

// Flutter imports:
import 'package:flutter/material.dart';

// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:anchor_ui/anchor_ui.dart' show AnchorData;
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:material_symbols_icons/symbols.dart';

// Project imports:
import 'bookmark_group_label.dart';
import '../../../groups/folder_tree.dart';
import '../types/bookmark_group.dart';
import '../providers/recent_bookmark_groups_provider.dart';
import '../../../configs/config/types.dart';
import '../../../posts/post/types.dart';
import '../data/bookmark_convert.dart';
import '../providers/bookmark_provider.dart';
import '../types/bookmark_target.dart';
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
          maxWidth: 280,
          maxHeight: _maxHeight(context),
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

  double _maxHeight(BuildContext context) {
    final media = MediaQuery.of(context);
    final bounds = AnchorData.of(context).geometry.childBounds;
    final top = media.padding.top + 12;
    final bottom =
        media.size.height -
        math.max(media.padding.bottom, media.viewInsets.bottom) -
        12;
    final above = bounds == null ? 0.0 : bounds.top - top;
    final below = bounds == null ? bottom - top : bottom - bounds.bottom;
    // Fit on one side of the toolbar, including the anchor gap and padding.
    // A whole-screen cap alone lets centered anchors extend past the top edge.
    final available = math.max(above, below) - 4 - 16;
    final cap =
        (media.size.height - media.viewInsets.bottom - media.padding.vertical) *
        .75;
    return math.min(available, cap).clamp(0.0, double.infinity);
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
    // The serialized removal publishes its Undo toast.
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
    final memberships = library?.membershipsFor(uniqueId) ?? const <String>{};

    final recentGroups =
        ref.watch(recentBookmarkGroupsProvider).valueOrNull ??
        const <BookmarkGroup>[];
    final folders = FolderTree(library?.folders ?? const []);
    Widget groupRow(
      BuildContext context,
      BookmarkGroup group, {
      bool recent = false,
    }) => widget.anchored
        ? BookmarkPickerMenuItem(
            icon: Icon(
              Symbols.bookmarks,
              fill: memberships.contains(group.id) ? 1 : 0,
            ),
            title: group.displayName(context),
            detail: recent && group.folderId != null
                ? folders.path(group.folderId)
                : null,
            hideOnTap: false,
            onTap: () => _toggleGroup(context, ref, group.id),
          )
        : ListTile(
            leading: Icon(
              Symbols.bookmarks,
              fill: memberships.contains(group.id) ? 1 : 0,
            ),
            title: BookmarkPickerLabel(
              label: group.displayName(context),
              detail: recent && group.folderId != null
                  ? folders.path(group.folderId)
                  : null,
            ),
            onTap: () => _toggleGroup(context, ref, group.id),
          );

    final contents = BookmarkFolderPickerContents(
      compact: widget.anchored,
      folders: library?.folders ?? const [],
      groups: library?.groups ?? const [],
      membershipGroupIds: memberships,
      groupBuilder: (context, group) => groupRow(context, group),
      pinnedFooter: recentGroups.isEmpty
          ? null
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                KurumiContextMenuDivider(
                  title: context.t.bookmark.groups.recent,
                ),
                for (final group in recentGroups)
                  groupRow(context, group, recent: true),
              ],
            ),
      onCreateGroup: (folderId) => _createAndAdd(context, ref, folderId),
    );
    if (widget.anchored) return contents;
    return AlertDialog(
      title: Text(context.t.bookmark.groups.selector),
      content: SizedBox(
        width: 360,
        height:
            (MediaQuery.heightOf(context) -
                MediaQuery.viewInsetsOf(context).bottom) *
            .6,
        child: contents,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.t.generic.action.cancel),
        ),
      ],
    );
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
      onRemoved: (r) {
        if (navigator.mounted) notifier.showRemovalUndo(navigator.context, r);
      },
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
      await notifier.createGroupWithPosts(
        name,
        config,
        [
          post,
        ],
        folderId: folderId,
      );
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
