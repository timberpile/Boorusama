import 'package:kurumi/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../providers/bookmark_provider.dart';
import '../widgets/bookmark_folder_picker_contents.dart';
import '../widgets/bookmark_group_label.dart';
import '../widgets/bookmark_group_name_dialog.dart';
import '../widgets/bookmark_batch_dialog.dart';
import 'target_settings.dart';

Future<ServerFavoriteTarget?> showServerFavoriteTargetPicker(
  BuildContext context, {
  required ServerFavoriteTarget selected,
}) => showDialog<ServerFavoriteTarget>(
  context: context,
  builder: (_) => _ServerFavoriteTargetPicker(
    selected: selected,
  ),
);

class _ServerFavoriteTargetPicker extends ConsumerStatefulWidget {
  const _ServerFavoriteTargetPicker({
    required this.selected,
  });

  final ServerFavoriteTarget selected;

  @override
  ConsumerState<_ServerFavoriteTargetPicker> createState() =>
      _ServerFavoriteTargetPickerState();
}

class _ServerFavoriteTargetPickerState
    extends ConsumerState<_ServerFavoriteTargetPicker> {
  var _creating = false;
  var _failed = false;

  @override
  Widget build(BuildContext context) {
    final library = ref.watch(bookmarkLibraryProvider).valueOrNull;
    BookmarkPickerMenuItem option(
      ServerFavoriteTarget target,
      String label,
      IconData icon,
    ) => BookmarkPickerMenuItem(
      icon: Icon(icon),
      title: label,
      trailing: widget.selected == target ? const Icon(Icons.check) : null,
      hideOnTap: false,
      onTap: _creating ? null : () => Navigator.pop(context, target),
    );
    return BookmarkBatchDialog(
      title: context.t.bookmark.groups.selector,
      child: BookmarkFolderPickerContents(
        folders: library?.folders ?? const [],
        groups: library?.groups ?? const [],
        membershipGroupIds: {?widget.selected.groupId},
        homeChildren: [
          option(
            const ServerFavoriteTarget.none(),
            context.t.bookmark.server_favorites.none,
            Icons.block_outlined,
          ),
        ],
        onCreateGroup: _create,
        createGroupEnabled: !_creating,
        footerBuilder: _failed
            ? (context, parentGroupId) => Padding(
                padding: const EdgeInsets.all(16),
                child: Text(context.t.bookmark.groups.operation_failed),
              )
            : null,
        groupBuilder: (context, group) => option(
          ServerFavoriteTarget.group(group.id),
          group.displayName(context),
          Symbols.bookmarks,
        ),
      ),
    );
  }

  Future<void> _create(String? parentGroupId) async {
    if (_creating) return;
    setState(() {
      _creating = true;
      _failed = false;
    });
    final result = await showBookmarkGroupNameDialog(
      context,
      title: context.t.bookmark.groups.create,
    );
    final name = result?.trim();
    if (!mounted) return;
    if (name == null ||
        name.isEmpty ||
        !(ModalRoute.of(context)?.isCurrent ?? false)) {
      setState(() => _creating = false);
      return;
    }
    try {
      final group = await ref
          .read(bookmarkLibraryProvider.notifier)
          .createGroup(name, parentGroupId: parentGroupId);
      if (mounted && (ModalRoute.of(context)?.isCurrent ?? false))
        Navigator.pop(context, ServerFavoriteTarget.group(group.id));
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }
}
