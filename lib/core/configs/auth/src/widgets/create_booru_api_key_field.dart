// Package imports:
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';

// Project imports:

class CreateBooruApiKeyField extends StatefulWidget {
  const CreateBooruApiKeyField({
    super.key,
    this.onChanged,
    this.hintText,
    this.labelText,
    this.text,
    this.controller,
    this.validator,
    this.autovalidateMode,
  });

  final void Function(String value)? onChanged;
  final String? text;
  final String? labelText;
  final String? hintText;
  final TextEditingController? controller;
  final String? Function(String?)? validator;
  final AutovalidateMode? autovalidateMode;

  @override
  State<CreateBooruApiKeyField> createState() => _CreateBooruApiKeyFieldState();
}

class _CreateBooruApiKeyFieldState extends State<CreateBooruApiKeyField> {
  var revealKey = false;
  late var controller =
      widget.controller ?? TextEditingController(text: widget.text);

  @override
  void didUpdateWidget(CreateBooruApiKeyField oldWidget) {
    super.didUpdateWidget(oldWidget);
    final text = widget.text ?? '';
    if (widget.controller == null &&
        widget.text != oldWidget.text &&
        text != controller.text) {
      controller.text = text;
    }
  }

  @override
  void dispose() {
    super.dispose();
    if (widget.controller == null) {
      controller.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AutofillGroup(
      child: KurumiTextFormField(
        controller: controller,
        validator: widget.validator,
        autovalidateMode: widget.autovalidateMode,
        autofillHints: const [
          AutofillHints.password,
        ],
        obscureText: !revealKey,
        onChanged: widget.onChanged,
        decoration: InputDecoration(
          labelText: widget.labelText ?? context.t.booru.password_api_key_label,
          hintText: widget.hintText,
          errorMaxLines: 2,
          suffixIcon: IconButton(
            splashColor: Colors.transparent,
            icon: revealKey
                ? const FaIcon(
                    FontAwesomeIcons.solidEyeSlash,
                    size: 18,
                  )
                : const FaIcon(
                    FontAwesomeIcons.solidEye,
                    size: 18,
                  ),
            onPressed: () => setState(() => revealKey = !revealKey),
          ),
        ),
      ),
    );
  }
}
