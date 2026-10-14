// Package imports:
import 'package:flutter/services.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';

// Project imports:
import '../../types/utils.dart';

Future<int?> showPostsPerPageDialog(
  BuildContext context, {
  required int currentValue,
}) {
  return showDialog<int>(
    context: context,
    builder: (context) => PostsPerPageDialog(currentValue: currentValue),
  );
}

class PostsPerPageDialog extends StatefulWidget {
  const PostsPerPageDialog({required this.currentValue, super.key});

  final int currentValue;

  @override
  State<PostsPerPageDialog> createState() => _PostsPerPageDialogState();
}

class _PostsPerPageDialogState extends State<PostsPerPageDialog> {
  late final _controller = TextEditingController(
    text: widget.currentValue.toString(),
  );
  var _hasError = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = parseCustomPostsPerPage(_controller.text);
    if (value == null) {
      setState(() => _hasError = true);
      return;
    }

    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: KurumiDialog(
        width: 360,
        semanticLabel: context.t.settings.performance.posts_per_page,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                context.t.settings.performance.posts_per_page,
                style: Kurumi.themeOf(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              KurumiTextField(
                controller: _controller,
                autofocus: true,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  helperText: '$minPostsPerPage–$maxPostsPerPage',
                  errorText: _hasError
                      ? context.t.settings.performance.posts_per_page_invalid
                      : null,
                ),
                onChanged: (_) {
                  if (_hasError) setState(() => _hasError = false);
                },
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      MaterialLocalizations.of(context).cancelButtonLabel,
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _submit,
                    child: Text(
                      MaterialLocalizations.of(context).okButtonLabel,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
