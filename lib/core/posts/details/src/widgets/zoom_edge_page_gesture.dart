// Dart imports:
import 'dart:async';

// Flutter imports:
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/semantics.dart';

// Package imports:
import 'package:kurumi/material.dart';

// Project imports:
import '../../../details_pageview/widgets.dart';
import '../types/post_viewer_transformation_controller.dart';

const _edgeDragThreshold = 160.0;
const _horizontalDominance = 1.5;
const _reverseTolerance = 2.0;

class ZoomEdgePageGesture extends StatefulWidget {
  const ZoomEdgePageGesture({
    required this.transform,
    required this.pageController,
    required this.currentSettledPage,
    required this.pageIndex,
    required this.contentSize,
    required this.navigation,
    required this.enabled,
    required this.child,
    super.key,
    this.mediaState,
  });

  final PostViewerTransformationController transform;
  final PostDetailsPageViewController pageController;
  final ValueListenable<int?> currentSettledPage;
  final int pageIndex;
  final Size contentSize;
  final ZoomPageNavigationScope navigation;
  final bool enabled;
  final Widget child;
  final Listenable? mediaState;

  @override
  State<ZoomEdgePageGesture> createState() => _ZoomEdgePageGestureState();
}

class _ZoomEdgePageGestureState extends State<ZoomEdgePageGesture> {
  final _pointers = <int>{};
  int? _activePointer;
  Offset? _start;
  double? _edgePointerX;
  _PendingEdgeMove? _pendingMove;
  var _moveSerial = 0;
  var _cancelled = false;
  int? _direction;
  double _outwardDistance = 0;
  double _farthestOutwardDisplacement = 0;
  var _ringUpdateScheduled = false;

  @override
  void initState() {
    super.initState();
    _listenToViewerState(widget);
  }

  @override
  void didUpdateWidget(ZoomEdgePageGesture oldWidget) {
    super.didUpdateWidget(oldWidget);
    _stopListeningToViewerState(oldWidget);
    _listenToViewerState(widget);
    if (oldWidget.enabled != widget.enabled ||
        oldWidget.pageController != widget.pageController ||
        oldWidget.currentSettledPage != widget.currentSettledPage ||
        oldWidget.pageIndex != widget.pageIndex ||
        oldWidget.contentSize != widget.contentSize ||
        oldWidget.transform != widget.transform ||
        oldWidget.mediaState != widget.mediaState ||
        oldWidget.navigation.previousActionId !=
            widget.navigation.previousActionId ||
        oldWidget.navigation.nextActionId != widget.navigation.nextActionId ||
        (oldWidget.navigation.onPrevious == null) !=
            (widget.navigation.onPrevious == null) ||
        (oldWidget.navigation.onNext == null) !=
            (widget.navigation.onNext == null) ||
        oldWidget.navigation.previousLabel != widget.navigation.previousLabel ||
        oldWidget.navigation.nextLabel != widget.navigation.nextLabel) {
      _cancelActiveGesture();
    }
  }

  @override
  void dispose() {
    _stopListeningToViewerState(widget);
    super.dispose();
  }

  void _listenToViewerState(ZoomEdgePageGesture source) {
    for (final signal in _viewerSignals(source)) {
      signal.addListener(_cancelActiveGesture);
    }
  }

  void _stopListeningToViewerState(ZoomEdgePageGesture source) {
    for (final signal in _viewerSignals(source)) {
      signal.removeListener(_cancelActiveGesture);
    }
  }

  List<Listenable> _viewerSignals(ZoomEdgePageGesture source) => [
    source.pageController.zoom,
    source.pageController.currentPage,
    source.pageController.sheetState,
    source.currentSettledPage,
    ?source.mediaState,
  ];

  void _cancelActiveGesture() {
    if (_activePointer == null) return;
    _cancelled = true;
    _notifyRingChanged();
  }

  void _finishPendingMove(int serial) {
    final move = _pendingMove;
    if (move == null || move.serial != serial) return;
    _pendingMove = null;
    if (_cancelled || _activePointer == null || !_eligible) return;

    final direction = _direction;
    if (direction == null) return;
    final edges = widget.transform.horizontalEdges(widget.contentSize);
    final atEdge = edges != null && (direction < 0 ? edges.right : edges.left);
    if (!atEdge) {
      _edgePointerX = null;
      _outwardDistance = 0;
    } else {
      if (_edgePointerX == null) {
        final translation = widget.transform.transformationController.value
            .getTranslation()
            .x;
        final imagePan = (translation - move.beforeTranslationX) * direction;
        final outwardMove = move.deltaX * direction;
        final excess = move.startedAtEdge
            ? outwardMove
            : imagePan > 0
            ? outwardMove - imagePan
            : 0.0;
        if (excess > 0) {
          _edgePointerX = move.positionX - direction * excess;
        }
      }
      _outwardDistance = _edgePointerX == null
          ? 0
          : ((move.positionX - _edgePointerX!) * direction).clamp(
              0.0,
              double.infinity,
            );
    }
    _notifyRingChanged();
  }

  void _notifyRingChanged() {
    if (_ringUpdateScheduled) return;
    _ringUpdateScheduled = true;
    scheduleMicrotask(() {
      _ringUpdateScheduled = false;
      if (mounted) setState(() {});
    });
  }

  bool get _showRing {
    final direction = _direction;
    if (!_eligible ||
        _cancelled ||
        direction == null ||
        _outwardDistance <= 0) {
      return false;
    }
    final isNext = Directionality.of(context) == TextDirection.ltr
        ? direction < 0
        : direction > 0;
    return isNext
        ? widget.navigation.onNext != null
        : widget.navigation.onPrevious != null;
  }

  Widget _buildRing() {
    final direction = _direction!;
    final isNext = Directionality.of(context) == TextDirection.ltr
        ? direction < 0
        : direction > 0;
    final icon = switch (isNext
        ? widget.navigation.nextEdgeAction
        : ZoomPageEdgeAction.page) {
      ZoomPageEdgeAction.retry => Icons.refresh,
      ZoomPageEdgeAction.loadMore => Icons.expand_more,
      ZoomPageEdgeAction.page =>
        direction < 0 ? Icons.chevron_right : Icons.chevron_left,
    };
    final progress = (_outwardDistance / _edgeDragThreshold).clamp(0.0, 1.0);
    return Positioned(
      top: 0,
      bottom: 0,
      left: direction > 0 ? 8 : null,
      right: direction < 0 ? 8 : null,
      child: IgnorePointer(
        child: Center(
          child: Opacity(
            opacity: (progress * 2).clamp(0.0, 1.0),
            child: Semantics(
              label: isNext
                  ? widget.navigation.nextLabel
                  : widget.navigation.previousLabel,
              child: SizedBox.square(
                dimension: 30,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 2.5,
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                    ),
                    Icon(icon, size: 18),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  bool get _eligible =>
      widget.enabled &&
      widget.pageController.zoom.value &&
      !widget.pageController.isExpanded &&
      widget.pageController.page == widget.pageIndex &&
      widget.currentSettledPage.value == widget.pageIndex;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: Listenable.merge([
      widget.pageController.zoom,
      widget.pageController.currentPage,
      widget.pageController.sheetState,
      widget.currentSettledPage,
    ]),
    builder: (context, _) {
      final actions = <CustomSemanticsAction, VoidCallback>{};
      if (_eligible) {
        if (widget.navigation.onPrevious case final previous?) {
          actions[CustomSemanticsAction(
                label: widget.navigation.previousLabel,
              )] =
              previous;
        }
        if (widget.navigation.onNext case final next?) {
          actions[CustomSemanticsAction(label: widget.navigation.nextLabel)] =
              next;
        }
      }

      return Semantics(
        customSemanticsActions: actions,
        child: Listener(
          onPointerDown: _onPointerDown,
          onPointerMove: _onPointerMove,
          onPointerUp: _onPointerUp,
          onPointerCancel: _onPointerCancel,
          child: Stack(
            fit: StackFit.expand,
            children: [
              widget.child,
              if (_showRing) _buildRing(),
            ],
          ),
        ),
      );
    },
  );

  void _onPointerDown(PointerDownEvent event) {
    _pointers.add(event.pointer);
    if (_pointers.length > 1 ||
        !_eligible ||
        (event.kind != PointerDeviceKind.touch &&
            event.kind != PointerDeviceKind.stylus)) {
      _cancelled = true;
      _activePointer = null;
      _notifyRingChanged();
      return;
    }

    _activePointer = event.pointer;
    _start = event.position;
    _edgePointerX = null;
    _pendingMove = null;
    _moveSerial++;
    _direction = null;
    _outwardDistance = 0;
    _farthestOutwardDisplacement = 0;
    _cancelled = false;
    _notifyRingChanged();
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (_cancelled || event.pointer != _activePointer) return;
    _finishPendingMove(_moveSerial);
    if (!_eligible) {
      _cancelled = true;
      _notifyRingChanged();
      return;
    }

    final start = _start;
    if (start == null) return;
    final displacement = event.position - start;
    final lockedDirection = _direction;
    if (lockedDirection != null &&
        _farthestOutwardDisplacement - displacement.dx * lockedDirection >
            _reverseTolerance) {
      _cancelled = true;
      _notifyRingChanged();
      return;
    }
    if (displacement.dy.abs() > 12 &&
        displacement.dy.abs() * _horizontalDominance > displacement.dx.abs()) {
      _cancelled = true;
      _notifyRingChanged();
      return;
    }
    if (displacement.dx.abs() < 12 ||
        displacement.dx.abs() < displacement.dy.abs() * _horizontalDominance) {
      return;
    }

    final direction = lockedDirection ?? displacement.dx.sign.toInt();
    _direction = direction;
    final outwardDisplacement = displacement.dx * direction;
    if (outwardDisplacement > _farthestOutwardDisplacement) {
      _farthestOutwardDisplacement = outwardDisplacement;
    }

    final edges = widget.transform.horizontalEdges(widget.contentSize);
    final startedAtEdge =
        edges != null && (direction < 0 ? edges.right : edges.left);
    final serial = ++_moveSerial;
    _pendingMove = _PendingEdgeMove(
      serial: serial,
      positionX: event.position.dx,
      deltaX: event.delta.dx,
      beforeTranslationX: widget.transform.transformationController.value
          .getTranslation()
          .x,
      startedAtEdge: startedAtEdge,
    );
    scheduleMicrotask(() => _finishPendingMove(serial));
  }

  void _onPointerUp(PointerUpEvent event) {
    _finishPendingMove(_moveSerial);
    final direction = _direction;
    final shouldNavigate =
        !_cancelled &&
        event.pointer == _activePointer &&
        _pointers.length == 1 &&
        _eligible &&
        direction != null &&
        _outwardDistance >= _edgeDragThreshold;
    final isNext =
        direction != null &&
        (Directionality.of(context) == TextDirection.ltr
            ? direction < 0
            : direction > 0);
    final action = shouldNavigate
        ? isNext
              ? widget.navigation.onEdgeNext ?? widget.navigation.onNext
              : widget.navigation.onEdgePrevious ?? widget.navigation.onPrevious
        : null;

    _pointers.remove(event.pointer);
    if (_pointers.isEmpty) _reset();
    _notifyRingChanged();
    if (action != null) {
      scheduleMicrotask(() {
        if (mounted && _eligible) action();
      });
    }
  }

  void _onPointerCancel(PointerCancelEvent event) {
    _pointers.remove(event.pointer);
    _cancelled = true;
    if (_pointers.isEmpty) _reset();
    _notifyRingChanged();
  }

  void _reset() {
    _activePointer = null;
    _start = null;
    _edgePointerX = null;
    _pendingMove = null;
    _moveSerial++;
    _direction = null;
    _outwardDistance = 0;
    _farthestOutwardDisplacement = 0;
    _cancelled = false;
  }
}

class _PendingEdgeMove {
  const _PendingEdgeMove({
    required this.serial,
    required this.positionX,
    required this.deltaX,
    required this.beforeTranslationX,
    required this.startedAtEdge,
  });

  final int serial;
  final double positionX;
  final double deltaX;
  final double beforeTranslationX;
  final bool startedAtEdge;
}
