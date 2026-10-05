// Package imports:
import 'package:flutter/services.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';

Future<String?> showPinSearchDialog(
  BuildContext context, {
  required String query,
  String? initialName,
  bool isPinned = false,
  Widget? extra,
  Future<bool> Function(BuildContext context, String name)? onSubmit,
}) => showDialog<String>(
  context: context,
  barrierDismissible: onSubmit == null,
  builder: (_) => PinSearchDialog(
    query: query,
    initialName: initialName,
    isPinned: isPinned,
    extra: extra,
    onSubmit: onSubmit,
  ),
);

class PinSearchDialog extends StatefulWidget {
  const PinSearchDialog({
    required this.query,
    this.initialName,
    this.isPinned = false,
    this.extra,
    this.onSubmit,
    super.key,
  });

  final String query;
  final String? initialName;
  final bool isPinned;
  final Widget? extra;
  final Future<bool> Function(BuildContext context, String name)? onSubmit;

  @override
  State<PinSearchDialog> createState() => _PinSearchDialogState();
}

class _PinSearchDialogState extends State<PinSearchDialog> {
  late final _nameController = TextEditingController(text: widget.initialName);
  var _submitting = false;
  var _failed = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final name = _nameController.text.trim();
    setState(() {
      _submitting = true;
      _failed = false;
    });
    try {
      final accepted = await widget.onSubmit?.call(context, name) ?? true;
      if (mounted && accepted) Navigator.pop(context, name);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.t.pinned_searches;
    return PopScope(
      canPop: !_submitting,
      child: KurumiDialog(
        dismissible: !_submitting,
        child: CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.escape): () {
              if (!_submitting) Navigator.pop(context);
            },
          },
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
                Text(strings.query_line(query: widget.query)),
                const SizedBox(height: 16),
                TextField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: strings.name,
                    hintText: widget.query,
                  ),
                  onSubmitted: (_) => _submit(),
                ),
                if (widget.extra case final extra?) ...[
                  const SizedBox(height: 16),
                  extra,
                ],
                if (_failed) ...[
                  const SizedBox(height: 16),
                  Text(
                    strings.save_failed,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Wrap(
                  alignment: WrapAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _submitting
                          ? null
                          : () => Navigator.pop(context),
                      child: Text(context.t.generic.action.cancel),
                    ),
                    FilledButton(
                      onPressed: _submitting ? null : _submit,
                      child: Text(widget.isPinned ? strings.save : strings.pin),
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
}
