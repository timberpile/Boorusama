import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';

import 'service.dart';

/// Shared alias workflow for Devices and the receiver's Bookmark Home header.
/// The caller provides normal error feedback; saving uses only local storage.
Future<void> editSyncDeviceAlias(
  BuildContext context, {
  required MiteMiteService service,
  required String publisher,
  required String? alias,
}) async {
  final value = await showSyncNameDialog(
    context,
    title: context.t.mitemite.alias,
    initial: alias ?? '',
    hint: context.t.mitemite.alias_hint,
    allowEmpty: true,
  );
  if (value != null && context.mounted) {
    await service.setDeviceAlias(publisher, value);
  }
}

Future<String?> showSyncNameDialog(
  BuildContext context, {
  required String title,
  required String initial,
  String? hint,
  bool allowEmpty = false,
  String? sourceName,
}) => showDialog<String>(
  context: context,
  builder: (_) => _SyncNameDialog(
    title: title,
    initial: initial,
    hint: hint,
    allowEmpty: allowEmpty,
    sourceName: sourceName,
  ),
);

class _SyncNameDialog extends StatefulWidget {
  const _SyncNameDialog({
    required this.title,
    required this.initial,
    this.hint,
    this.allowEmpty = false,
    this.sourceName,
  });
  final String title;
  final String initial;
  final String? hint;
  final bool allowEmpty;
  final String? sourceName;
  @override
  State<_SyncNameDialog> createState() => _SyncNameDialogState();
}

class _SyncNameDialogState extends State<_SyncNameDialog> {
  late final _controller = TextEditingController(text: widget.initial);
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: KurumiDialog(
      semanticLabel: widget.title,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.sourceName case final sourceName?) ...[
              Text(
                context.t.mitemite.collection_alias_source(name: sourceName),
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: _controller,
              maxLength: 160,
              decoration: InputDecoration(
                labelText: widget.title,
                helperText: widget.hint,
                helperMaxLines: 3,
              ),
              onChanged: (_) => setState(() {}),
            ),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(context.t.generic.action.cancel),
                ),
                FilledButton(
                  onPressed:
                      !widget.allowEmpty && _controller.text.trim().isEmpty
                      ? null
                      : () => Navigator.pop(context, _controller.text.trim()),
                  child: Text(context.t.generic.action.save),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
