import 'package:flutter/rendering.dart' show SelectionRegistrar;
import 'package:flutter/services.dart';
import 'package:kurumi/material.dart';

/// Own selection above the outer Work pager. Its horizontal drag recognizer
/// then wins ordinary touch swipes, while a held word still starts selection.
/// Only native metadata explicitly registers; existing viewer labels and
/// Post-specific selectable widgets retain their previous behavior.
class NativeMetadataSelectionScope extends StatefulWidget {
  const NativeMetadataSelectionScope({required this.child, super.key});
  final Widget child;

  @override
  State<NativeMetadataSelectionScope> createState() =>
      _NativeMetadataSelectionScopeState();
}

class _NativeMetadataSelectionScopeState
    extends State<NativeMetadataSelectionScope> {
  final _selectionFocus = FocusNode(
    debugLabel: 'NativeMetadataSelection',
    skipTraversal: true,
  );
  final _controlShortcuts = _MetadataControlShortcuts();

  @override
  void dispose() {
    _selectionFocus.dispose();
    _controlShortcuts.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SelectionArea(
    focusNode: _selectionFocus,
    child: Builder(
      builder: (context) => _NativeMetadataRegistrar(
        registrar: SelectionContainer.maybeOf(context),
        child: Shortcuts.manager(
          manager: _controlShortcuts,
          child: SelectionContainer.disabled(child: widget.child),
        ),
      ),
    ),
  );
}

/// SelectionArea enables text-caret actions above every viewer control. Plain
/// arrows on those controls must still traverse; otherwise selection consumes
/// them without moving focus. The selection owner's focus sits above this
/// bridge, so selecting metadata retains native keyboard selection behavior.
class _MetadataControlShortcuts extends ShortcutManager {
  _MetadataControlShortcuts()
    : super(
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.arrowUp): DirectionalFocusIntent(
            TraversalDirection.up,
          ),
          SingleActivator(LogicalKeyboardKey.arrowDown): DirectionalFocusIntent(
            TraversalDirection.down,
          ),
          SingleActivator(LogicalKeyboardKey.arrowLeft): DirectionalFocusIntent(
            TraversalDirection.left,
          ),
          SingleActivator(LogicalKeyboardKey.arrowRight):
              DirectionalFocusIntent(TraversalDirection.right),
        },
      );

  @override
  KeyEventResult handleKeypress(BuildContext context, KeyEvent event) {
    final focused = FocusManager.instance.primaryFocus?.context;
    if (focused?.widget is EditableText ||
        focused?.findAncestorWidgetOfExactType<EditableText>() != null) {
      return KeyEventResult.ignored;
    }
    return super.handleKeypress(context, event);
  }
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
