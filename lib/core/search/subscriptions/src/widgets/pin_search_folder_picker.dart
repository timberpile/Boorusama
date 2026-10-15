import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';

import '../../../../groups/folder_navigation.dart';
import '../providers/search_subscriptions_notifier.dart';

class PinSearchFolderPicker extends ConsumerStatefulWidget {
  const PinSearchFolderPicker({
    required this.onSelected,
    this.initialFolderId,
    super.key,
  });
  final String? initialFolderId;
  final void Function(String? folderId, bool isNewFolder) onSelected;
  @override
  ConsumerState<PinSearchFolderPicker> createState() =>
      _PinSearchFolderPickerState();
}

class _PinSearchFolderPickerState extends ConsumerState<PinSearchFolderPicker> {
  static const _newFolderValue = '__new_pin_folder__';
  late String? _selected = widget.initialFolderId;
  var _isNewFolder = false;

  Future<void> _choose() async {
    FocusScope.of(context).unfocus();
    final folders =
        ref
            .read(searchSubscriptionsProvider)
            .valueOrNull
            ?.organization
            .folders ??
        [];
    final choice = await showFolderDestinationPicker(
      context,
      folders: folders,
      initialFolderId: _selected,
      title: context.t.pinned_searches.folder,
      confirmationLabel: context.t.generic.action.select,
      // Existing New Folder saves create a root folder after naming the pin.
      canCreateAt: (id) => id == null,
      onCreate: (_, _) async => _newFolderValue,
    );
    if (choice == null || !mounted) return;
    setState(() {
      _isNewFolder = choice.folderId == _newFolderValue;
      _selected = _isNewFolder ? null : choice.folderId;
    });
    widget.onSelected(_selected, _isNewFolder);
  }

  @override
  Widget build(BuildContext context) {
    final folders =
        ref
            .watch(searchSubscriptionsProvider)
            .valueOrNull
            ?.organization
            .folders ??
        [];
    final selected = folders
        .where((folder) => folder.id == _selected)
        .firstOrNull;
    final label = _isNewFolder
        ? context.t.pinned_searches.new_folder
        : selected?.name ?? context.t.pinned_searches.home;
    return Semantics(
      button: true,
      child: InkWell(
        onTap: _choose,
        borderRadius: BorderRadius.circular(8),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: context.t.pinned_searches.folder,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Icon(Icons.arrow_drop_down),
            ],
          ),
        ),
      ),
    );
  }
}
