import 'package:flutter/widgets.dart';
import 'package:selection_mode/selection_mode.dart';

import 'ordered_selection_controller.dart';

/// The pinned package compares canvas-local row bounds and viewport size with
/// pointer coordinates. Normalize once so headers/insets do not shift its edges.
class OrderedSelectionCanvas extends StatefulWidget {
  const OrderedSelectionCanvas({
    required this.controller,
    required this.child,
    super.key,
  });
  final SelectionModeController controller;
  final Widget child;
  @override
  State<OrderedSelectionCanvas> createState() => _OrderedSelectionCanvasState();
}

class _OrderedSelectionCanvasState extends State<OrderedSelectionCanvas> {
  final _canvasKey = GlobalKey();
  Offset _local(Offset position) {
    final box = _canvasKey.currentContext?.findRenderObject();
    return box is RenderBox ? box.globalToLocal(position) : position;
  }

  void _attach() {
    if (widget.controller case final OrderedSelectionController controller) {
      controller.dragPositionToLocal = _local;
    }
  }

  @override
  void initState() {
    super.initState();
    _attach();
  }

  @override
  void didUpdateWidget(OrderedSelectionCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      if (oldWidget.controller
          case final OrderedSelectionController controller) {
        controller.dragPositionToLocal = null;
      }
      _attach();
    }
  }

  @override
  void dispose() {
    if (widget.controller case final OrderedSelectionController controller) {
      controller.dragPositionToLocal = null;
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      SelectionCanvas(key: _canvasKey, child: widget.child);
}
