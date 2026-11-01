import 'package:flutter/gestures.dart';
import 'package:kurumi/material.dart';

/// Pages only after a deliberate horizontal gesture over the details content.
/// Participating in the arena lets nested scrolling, controls and text selection
/// win their own gestures before this wider threshold is reached.
class DetailsPageSwipeDetector extends StatelessWidget {
  const DetailsPageSwipeDetector({
    required this.enabled,
    required this.onSwipe,
    required this.child,
    super.key,
  });

  final bool enabled;
  final ValueChanged<int> onSwipe;
  final Widget child;

  @override
  Widget build(BuildContext context) => RawGestureDetector(
    excludeFromSemantics: true,
    gestures: {
      if (enabled)
        _DetailsPageSwipeRecognizer:
            GestureRecognizerFactoryWithHandlers<_DetailsPageSwipeRecognizer>(
              _DetailsPageSwipeRecognizer.new,
              (recognizer) => recognizer.onSwipe = onSwipe,
            ),
    },
    child: child,
  );
}

class _DetailsPageSwipeRecognizer extends OneSequenceGestureRecognizer {
  _DetailsPageSwipeRecognizer()
    : super(allowedButtonsFilter: (buttons) => buttons == kPrimaryButton);

  static const _distance = 48.0;
  static const _horizontalDominance = 2.0;
  final _pointers = <int>{};
  Offset? _origin;
  var _offset = Offset.zero;
  var _cancelled = false;
  var _accepted = false;
  late ValueChanged<int> onSwipe;

  bool get _isHorizontal =>
      _offset.dx.abs() >= _offset.dy.abs() * _horizontalDominance;
  bool get _isSwipe => _offset.dx.abs() >= _distance && _isHorizontal;

  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    _pointers.add(event.pointer);
    _origin ??= event.position;
    if (_pointers.length > 1) {
      _cancelled = true;
      resolve(GestureDisposition.rejected);
    }
  }

  @override
  void handleEvent(PointerEvent event) {
    if (event is PointerMoveEvent && !_cancelled) {
      _offset = event.position - _origin!;
      if (_offset.dy.abs() >= kTouchSlop && !_isHorizontal) {
        _cancelled = true;
        resolve(GestureDisposition.rejected);
      } else if (_isSwipe) {
        resolve(GestureDisposition.accepted);
      }
    }
    if (event is PointerUpEvent || event is PointerCancelEvent) {
      final navigate =
          event is PointerUpEvent && !_cancelled && _accepted && _isSwipe;
      final direction = _offset.dx < 0 ? 1 : -1;
      _pointers.remove(event.pointer);
      stopTrackingPointer(event.pointer);
      if (navigate) onSwipe(direction);
    }
  }

  @override
  void acceptGesture(int pointer) => _accepted = true;

  @override
  void rejectGesture(int pointer) => _cancelled = true;

  @override
  void didStopTrackingLastPointer(int pointer) {
    resolve(GestureDisposition.rejected);
    _origin = null;
    _offset = Offset.zero;
    _cancelled = false;
    _accepted = false;
  }

  @override
  String get debugDescription => 'details page swipe';
}
