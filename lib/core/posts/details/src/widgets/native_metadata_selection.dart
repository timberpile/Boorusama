import 'package:flutter/rendering.dart' show SelectionRegistrar;
import 'package:kurumi/material.dart';

/// Own selection above the outer Work pager. Its horizontal drag recognizer
/// then wins ordinary touch swipes, while a held word still starts selection.
/// Only native metadata explicitly registers; existing viewer labels and
/// Post-specific selectable widgets retain their previous behavior.
class NativeMetadataSelectionScope extends StatelessWidget {
  const NativeMetadataSelectionScope({required this.child, super.key});
  final Widget child;

  @override
  Widget build(BuildContext context) => SelectionArea(
    child: Builder(
      builder: (context) => _NativeMetadataRegistrar(
        registrar: SelectionContainer.maybeOf(context),
        child: SelectionContainer.disabled(child: child),
      ),
    ),
  );
}

class NativeMetadataText extends StatelessWidget {
  const NativeMetadataText(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    final registrar = context
        .dependOnInheritedWidgetOfExactType<_NativeMetadataRegistrar>()
        ?.registrar;
    // Standalone consumers have no outer Work gesture to arbitrate.
    if (registrar == null) return SelectableText(text);
    return SelectionRegistrarScope(registrar: registrar, child: Text(text));
  }
}

class _NativeMetadataRegistrar extends InheritedWidget {
  const _NativeMetadataRegistrar({
    required this.registrar,
    required super.child,
  });
  final SelectionRegistrar? registrar;
  @override
  bool updateShouldNotify(_NativeMetadataRegistrar oldWidget) =>
      registrar != oldWidget.registrar;
}
