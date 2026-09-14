// Flutter imports:
import 'package:flutter/material.dart';

// Package imports:
import 'package:i18n/i18n.dart';

Future<String?> showBookmarkGroupNameDialog(
  BuildContext context, {
  required String title,
  String? initialName,
}) async {
  final controller = TextEditingController(text: initialName);
  final result = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(hintText: context.t.bookmark.groups.name),
        onSubmitted: (value) => Navigator.pop(context, value.trim()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.t.generic.action.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, controller.text.trim()),
          child: Text(context.t.generic.action.save),
        ),
      ],
    ),
  );
  controller.dispose();
  return switch (result?.trim()) {
    final value? when value.isNotEmpty => value,
    _ => null,
  };
}
