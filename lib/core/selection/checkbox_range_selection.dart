import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:selection_mode/selection_mode.dart';

import 'ordered_selection_controller.dart';

/// Controlled projection for existing checkbox collections. The owner keeps
/// its domain state (including choices outside the displayed folder).
class CheckboxRangeSelection<K extends Object> extends StatefulWidget {
  const CheckboxRangeSelection({
    required this.entries,
    required this.selected,
    required this.onChanged,
    required this.child,
    super.key,
  });
  final List<K> entries;
  final Set<K> selected;
  final ValueChanged<Set<K>> onChanged;
  final Widget child;
  @override
  State<CheckboxRangeSelection<K>> createState() =>
      _CheckboxRangeSelectionState<K>();
}

class _CheckboxRangeSelectionState<K extends Object>
    extends State<CheckboxRangeSelection<K>> {
  final _controller = _CheckboxRangeController<K>();
  var _syncing = false;
  @override
  void initState() {
    super.initState();
    _sync();
    _controller.addListener(_changed);
  }

  void _sync() {
    _syncing = true;
    try {
      _controller.reconcileDuringBuild(widget.entries);
      final selected = widget.selected.intersection(widget.entries.toSet());
      if (!_controller.isDragInProgress &&
          !setEquals(selected, _controller.selectedKeys)) {
        _controller.synchronizeDuringBuild(() {
          _controller.enable();
          _controller.deselectAll();
          _controller.selectAll([
            for (final key in selected) _controller.indexOf(key)!,
          ]);
          _controller.disable(clearSelection: false);
        });
      }
    } finally {
      _syncing = false;
    }
  }

  void _changed() {
    if (_syncing) return;
    final visible = widget.entries.toSet();
    final selected = {
      ...widget.selected.difference(visible),
      ..._controller.selectedKeys,
    };
    if (!setEquals(selected, widget.selected)) widget.onChanged(selected);
  }

  @override
  void didUpdateWidget(CheckboxRangeSelection<K> oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  @override
  void dispose() {
    _controller.removeListener(_changed);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SelectionMode(
    controller: _controller,
    // Auto-enable is local to this transient checkbox drag, never the app default.
    // Release returns Back ownership to the dialog without clearing its choices.
    options: const SelectionOptions(
      tapBehavior: TapBehavior.disabled,
      dragSelection: DragSelectionOptions(),
      autoScroll: null,
    ),
    child: _CheckboxRangeScope(
      controller: _controller,
      child: SelectionCanvas(child: widget.child),
    ),
  );
}

class _CheckboxRangeController<K extends Object>
    extends OrderedSelectionController<K> {
  @override
  void endRangeSelection() {
    super.endRangeSelection();
    disable(clearSelection: false);
  }
}

class _CheckboxRangeScope extends InheritedWidget {
  const _CheckboxRangeScope({required this.controller, required super.child});
  final OrderedSelectionController controller;
  @override
  bool updateShouldNotify(_CheckboxRangeScope oldWidget) =>
      controller != oldWidget.controller;
}

class CheckboxRangeItem extends StatelessWidget {
  const CheckboxRangeItem({
    required this.value,
    required this.child,
    super.key,
  });
  final Object value;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final controller = context
        .dependOnInheritedWidgetOfExactType<_CheckboxRangeScope>()
        ?.controller;
    final index = controller?.indexOf(value);
    return index == null
        ? child
        : SelectableBuilder(
            key: ValueKey(index),
            index: index,
            builder: (_, _) => child,
          );
  }
}
