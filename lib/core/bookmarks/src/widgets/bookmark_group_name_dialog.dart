// Flutter imports:
import 'package:flutter/material.dart';

Future<String?> showBookmarkGroupNameDialog(
  BuildContext context, {
  required String title,
  required String saveLabel,
  required String cancelLabel,
  required String hintText,
  String? initialName,
}) async {
  final result = await showDialog<String>(
    context: context,
    builder: (context) => BookmarkGroupNameDialog(
      title: title,
      saveLabel: saveLabel,
      cancelLabel: cancelLabel,
      hintText: hintText,
      initialName: initialName,
    ),
  );

  return result?.isNotEmpty ?? false ? result : null;
}

class BookmarkGroupNameDialog extends StatefulWidget {
  const BookmarkGroupNameDialog({
    required this.title,
    required this.saveLabel,
    required this.cancelLabel,
    required this.hintText,
    super.key,
    this.initialName,
  });

  final String title;
  final String saveLabel;
  final String cancelLabel;
  final String hintText;
  final String? initialName;

  @override
  State<BookmarkGroupNameDialog> createState() =>
      _BookmarkGroupNameDialogState();
}

class _BookmarkGroupNameDialogState extends State<BookmarkGroupNameDialog> {
  late final _controller = TextEditingController(text: widget.initialName);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        onSubmitted: (value) => Navigator.pop(context, value.trim()),
        decoration: InputDecoration(hintText: widget.hintText),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(widget.cancelLabel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _controller.text.trim()),
          child: Text(widget.saveLabel),
        ),
      ],
    );
  }
}
