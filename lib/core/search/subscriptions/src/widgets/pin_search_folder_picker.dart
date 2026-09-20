import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';
import '../providers/search_subscriptions_notifier.dart';
import 'search_folder_dialog.dart';

class PinSearchFolderPicker extends ConsumerStatefulWidget {
  const PinSearchFolderPicker({
    required this.onSelected,
    this.initialFolderId,
    super.key,
  });
  final String? initialFolderId;
  final ValueChanged<String?> onSelected;
  @override
  ConsumerState<PinSearchFolderPicker> createState() =>
      _PinSearchFolderPickerState();
}

class _PinSearchFolderPickerState extends ConsumerState<PinSearchFolderPicker> {
  late String? _selected = widget.initialFolderId;
  @override
  Widget build(BuildContext context) {
    final folders =
        ref
            .watch(searchSubscriptionsProvider)
            .valueOrNull
            ?.organization
            .folders ??
        [];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        DropdownButton<String>(
          isExpanded: true,
          value: folders.any((f) => f.id == _selected) ? _selected : '',
          items: [
            DropdownMenuItem(
              value: '',
              child: Text(context.t.pinned_searches.home),
            ),
            for (final f in folders)
              DropdownMenuItem(value: f.id, child: Text(f.name)),
          ],
          onChanged: (value) {
            setState(() => _selected = value == '' ? null : value);
            widget.onSelected(_selected);
          },
        ),
        TextButton(
          onPressed: () async {
            final name = await showSearchFolderNameDialog(context);
            if (name == null || !mounted) return;
            try {
              final folder = await ref
                  .read(searchSubscriptionsProvider.notifier)
                  .createSharedFolder(name);
              if (!mounted) return;
              setState(() => _selected = folder.id);
              widget.onSelected(folder.id);
            } catch (_) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(context.t.pinned_searches.operation_failed),
                  ),
                );
              }
            }
          },
          child: Text(context.t.pinned_searches.create_folder),
        ),
      ],
    );
  }
}
