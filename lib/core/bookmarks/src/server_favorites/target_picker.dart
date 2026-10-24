import 'package:kurumi/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../providers/bookmark_provider.dart';
import '../widgets/bookmark_folder_picker_contents.dart';
import '../widgets/bookmark_group_label.dart';
import '../widgets/bookmark_group_name_dialog.dart';
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
    Widget option(ServerFavoriteTarget target, String label, IconData icon) =>
        ListTile(
          leading: Icon(icon),
          title: Text(label, maxLines: 2, overflow: TextOverflow.ellipsis),
          selected: widget.selected == target,
          trailing: widget.selected == target ? const Icon(Icons.check) : null,
          onTap: _creating ? null : () => Navigator.pop(context, target),
        );
    return AlertDialog(
      scrollable: true,
      title: Text(context.t.bookmark.groups.selector),
      content: SizedBox(
        width: 360,
        // AlertDialog can query both intrinsic dimensions. Bound the viewport
        // in both axes so those queries never reach its lazy list.
        height: 320,
        // The shared folder rows still use Flutter Material. Keep their legacy
        // dependencies local instead of relying on the caller's route scope.
        // ignore: deprecated_member_use
        child: MaterialUiCompatibilityBridge(
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
            footerBuilder: (context, folderId) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_failed) Text(context.t.bookmark.groups.operation_failed),
                ListTile(
                  leading: const Icon(Icons.add),
                  title: Text(context.t.bookmark.groups.create_new),
                  onTap: _creating ? null : () => _create(folderId),
                ),
              ],
            ),
            groupBuilder: (context, group) => option(
              ServerFavoriteTarget.group(group.id),
              group.displayName(context),
              Symbols.bookmarks,
            ),
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

  Future<void> _create(String? folderId) async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) =>
          // ignore: deprecated_member_use
          MaterialUiCompatibilityBridge(
            child: BookmarkGroupNameDialog(
              title: context.t.bookmark.groups.create,
            ),
          ),
    );
    final name = result?.trim();
    if (name == null || name.isEmpty || !mounted) return;
    setState(() {
      _creating = true;
      _failed = false;
    });
    try {
      final group = await ref
          .read(bookmarkLibraryProvider.notifier)
          .createGroup(name, folderId: folderId);
      if (mounted) Navigator.pop(context, ServerFavoriteTarget.group(group.id));
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }
}
