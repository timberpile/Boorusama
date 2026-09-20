import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';

Future<String?> showSearchFolderNameDialog(
  BuildContext context, {
  String? name,
}) => showDialog<String>(
  context: context,
  builder: (_) => _SearchFolderNameDialog(name: name),
);

class _SearchFolderNameDialog extends StatefulWidget {
  const _SearchFolderNameDialog({this.name});
  final String? name;
  @override
  State<_SearchFolderNameDialog> createState() =>
      _SearchFolderNameDialogState();
}

class _SearchFolderNameDialogState extends State<_SearchFolderNameDialog> {
  late final _controller = TextEditingController(text: widget.name);
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.name == null
          ? context.t.pinned_searches.create_folder
          : context.t.pinned_searches.rename,
    ),
    content: TextField(
      controller: _controller,
      decoration: InputDecoration(
        labelText: context.t.pinned_searches.folder_name,
      ),
      onChanged: (_) => setState(() {}),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(context.t.generic.action.cancel),
      ),
      FilledButton(
        onPressed: _controller.text.trim().isEmpty
            ? null
            : () => Navigator.pop(context, _controller.text.trim()),
        child: Text(context.t.pinned_searches.save),
      ),
    ],
  );
}
