// Package imports:
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';

Future<String?> showPinSearchDialog(
  BuildContext context, {
  required String query,
  String? initialName,
  bool isPinned = false,
}) => showDialog<String>(
  context: context,
  builder: (_) => PinSearchDialog(
    query: query,
    initialName: initialName,
    isPinned: isPinned,
  ),
);

class PinSearchDialog extends StatefulWidget {
  const PinSearchDialog({
    required this.query,
    this.initialName,
    this.isPinned = false,
    super.key,
  });

  final String query;
  final String? initialName;
  final bool isPinned;

  @override
  State<PinSearchDialog> createState() => _PinSearchDialogState();
}

class _PinSearchDialogState extends State<PinSearchDialog> {
  late final _nameController = TextEditingController(text: widget.initialName);

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _submit() => Navigator.pop(context, _nameController.text.trim());

  @override
  Widget build(BuildContext context) {
    final strings = context.t.pinned_searches;
    return KurumiDialog(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.isPinned ? strings.manage_title : strings.pin_title,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Text(strings.query_label),
            Text(widget.query),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: strings.optional_name,
                hintText: strings.name_hint,
              ),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(context.t.generic.action.cancel),
                ),
                FilledButton(
                  onPressed: _submit,
                  child: Text(widget.isPinned ? strings.save : strings.pin),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
