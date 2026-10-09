// Flutter imports:
import 'package:flutter/material.dart';

// Package imports:
import 'package:i18n/i18n.dart';

Future<String?> showBookmarkGroupNameDialog(
  BuildContext context, {
  required String title,
  String? initialName,
  String? hint,
}) async {
  final result = await showDialog<String>(
    context: context,
    builder: (_) => _BookmarkGroupNameDialog(
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

class _BookmarkGroupNameDialog extends StatefulWidget {
  const _BookmarkGroupNameDialog({
    required this.title,
    this.initialName,
    this.hint,
  });

  final String title;
  final String? initialName;
  final String? hint;

  @override
  State<_BookmarkGroupNameDialog> createState() =>
      _BookmarkGroupNameDialogState();
}

class _BookmarkGroupNameDialogState extends State<_BookmarkGroupNameDialog> {
  late final _controller = TextEditingController(text: widget.initialName);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: TextField(
      controller: _controller,
      autofocus: true,
      textCapitalization: TextCapitalization.sentences,
      decoration: InputDecoration(
        hintText: widget.hint ?? context.t.bookmark.groups.name,
      ),
      onSubmitted: (value) => Navigator.pop(context, value.trim()),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(context.t.generic.action.cancel),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, _controller.text.trim()),
        child: Text(context.t.generic.action.save),
      ),
    ],
  );
}
