import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';
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
  static final _newFolderValue = Object();
  late String? _selected = widget.initialFolderId;
  var _isNewFolder = false;
  @override
  Widget build(BuildContext context) {
    final folders =
        ref
            .watch(searchSubscriptionsProvider)
            .valueOrNull
            ?.organization
            .folders ??
        [];
    return DropdownButtonFormField<Object>(
      isExpanded: true,
      decoration: InputDecoration(labelText: context.t.pinned_searches.folder),
      initialValue: _isNewFolder
          ? _newFolderValue
          : folders.any((f) => f.id == _selected)
          ? _selected
          : '',
      items: [
        DropdownMenuItem(
          value: '',
          child: Text(context.t.pinned_searches.home),
        ),
        DropdownMenuItem(
          value: _newFolderValue,
          child: Text(context.t.pinned_searches.new_folder),
        ),
        for (final f in folders)
          DropdownMenuItem(value: f.id, child: Text(f.name)),
      ],
      selectedItemBuilder: (_) => [
        Text(context.t.pinned_searches.home),
        Text(context.t.pinned_searches.new_folder),
        for (final f in folders) Text(f.name),
      ],
      onChanged: (value) {
        setState(() {
          _selected = switch (value) {
            final String id when id.isNotEmpty => id,
            _ => null,
          };
          _isNewFolder = value == _newFolderValue;
        });
        widget.onSelected(_selected, _isNewFolder);
      },
    );
  }
}
