import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';

import '../types/search_subscription.dart';

Future<void> showEditFeedMemberNameDialog(
  BuildContext context, {
  required SearchSubscription source,
  required String ownerCaption,
  required bool shared,
  required Future<void> Function(String?) onSave,
}) => showDialog<void>(
  context: context,
  barrierDismissible: false,
  builder: (_) => EditFeedMemberNameDialog(
    source: source,
    ownerCaption: ownerCaption,
    shared: shared,
    onSave: onSave,
  ),
);

class EditFeedMemberNameDialog extends StatefulWidget {
  const EditFeedMemberNameDialog({
    required this.source,
    required this.ownerCaption,
    required this.shared,
    required this.onSave,
    super.key,
  });
  final SearchSubscription source;
  final String ownerCaption;
  final bool shared;
  final Future<void> Function(String?) onSave;
  @override
  State<EditFeedMemberNameDialog> createState() =>
      _EditFeedMemberNameDialogState();
}

class _EditFeedMemberNameDialogState extends State<EditFeedMemberNameDialog> {
  late final _name = TextEditingController(text: widget.source.name);
  var _saving = false;
  var _failed = false;
  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _failed = false;
    });
    try {
      await widget.onSave(_name.text);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _failed = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.t.pinned_searches;
    return AlertDialog(
      title: Text(strings.edit_feed_member),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(strings.query_line(query: widget.source.query)),
            Text(widget.ownerCaption),
            const SizedBox(height: 12),
            TextField(
              controller: _name,
              enabled: !_saving,
              decoration: InputDecoration(
                labelText: strings.edit_name,
                hintText: strings.edit_name_hint,
              ),
            ),
            if (widget.shared)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(strings.shared_member_name),
              ),
            if (_failed)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  strings.operation_failed,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: Text(context.t.generic.action.cancel),
        ),
        TextButton(
          onPressed: _saving ? null : _save,
          child: Text(context.t.generic.action.save),
        ),
      ],
    );
  }
}
