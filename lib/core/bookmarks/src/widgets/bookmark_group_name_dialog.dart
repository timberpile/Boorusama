import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';

Future<String?> showBookmarkGroupNameDialog(
  BuildContext context, {
  required String title,
  String? initialName,
  String? hint,
}) async {
  final result = await showDialog<String>(
    context: context,
    builder: (_) => BookmarkGroupNameDialog(
      title: title,
      initialName: initialName,
      hint: hint,
    ),
  );
  return switch (result?.trim()) {
    final value? when value.isNotEmpty => value,
    _ => null,
  };
}

/// A shared name editor; optional creation work remains owned by this route.
class BookmarkGroupNameDialog extends StatefulWidget {
  const BookmarkGroupNameDialog({
    required this.title,
    this.initialName,
    this.hint,
    this.onSave,
    this.canDismiss = true,
    super.key,
  });
  final String title;
  final String? initialName;
  final String? hint;
  final Future<void> Function(String)? onSave;
  final bool canDismiss;
  @override
  State<BookmarkGroupNameDialog> createState() =>
      _BookmarkGroupNameDialogState();
}

class _BookmarkGroupNameDialogState extends State<BookmarkGroupNameDialog> {
  late final _controller = TextEditingController(text: widget.initialName);
  var _saving = false;
  bool get _active => mounted && (ModalRoute.of(context)?.isCurrent ?? false);
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _controller.text.trim();
    if (_saving || name.isEmpty || !_active) return;
    setState(() => _saving = true);
    try {
      await widget.onSave?.call(name);
      if (_active) Navigator.pop(context, name);
    } catch (_) {
      if (_active)
        Kurumi.showErrorToast(
          context,
          context.t.bookmark.groups.operation_failed,
        );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: widget.canDismiss,
    child: Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: KurumiDialog(
        width: 360,
        dismissible: widget.canDismiss,
        semanticLabel: widget.title,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.title,
                style: Kurumi.themeOf(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _controller,
                autofocus: true,
                enabled: widget.canDismiss,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: widget.hint ?? context.t.bookmark.groups.name,
                ),
                onSubmitted: (_) => _save(),
              ),
              const SizedBox(height: 16),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                runSpacing: 8,
                children: [
                  TextButton(
                    onPressed: widget.canDismiss
                        ? () => Navigator.pop(context)
                        : null,
                    child: Text(context.t.generic.action.cancel),
                  ),
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    child: Text(context.t.generic.action.save),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
