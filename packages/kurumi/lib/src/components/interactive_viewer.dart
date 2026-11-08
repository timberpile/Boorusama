// Dart imports:
import 'dart:async';
import 'dart:math';

// Flutter imports:
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

// Project imports:
import '../vendor/flutter/interactive_viewer.dart' as vendor;

/// Fallback max zoom scale when content size is unknown. Limits zoom-in.
const _kFallbackMaxScale = 10.0;

/// Fallback min zoom scale when content size is unknown. Limits zoom-out.
const _kFallbackMinScale = 0.6;

/// Multiplier to adjust max zoom based on the ratio between content and container sizes.
const _kScaleMultiplier = 5.0;

/// Default zoom scale for double tap if content and container sizes are unknown.
const _kDoubleTapScale = 3.0;

const _kContentConstraintTolerance = 0.5;

const _kSnapToFitTolerance = 0.10;

/// Conservative detail zoom for ordinary media; extreme media instead uses
/// readability targets based on its displayed image footprint.
const _kClassicDetailZoom = 2.25;
const _kClassicSquareBoost = 0.20;
const _kClassicNormalMaxZoom = 2.50;
const _kClassicComicDetailMultiplier = 2.0;

const _kScaleChangeTolerance = 1e-10;

const _kSnapSettleDuration = Duration(milliseconds: 50);

class KurumiTransformationDetails {
  const KurumiTransformationDetails({
    required this.scale,
    required this.translation,
    required this.contentSize,
    required this.containerSize,
    required this.maxScale,
    required this.minScale,
    required this.transformationMatrix,
    required this.isZoomed,
  });

  final double scale;
  final Offset translation;
  final Size? contentSize;
  final Size? containerSize;
  final double maxScale;
  final double minScale;
  final Matrix4 transformationMatrix;
  final bool isZoomed;

  /// Whether the content is at maximum zoom level
  bool get isAtMaxZoom => scale >= maxScale * 0.95;

  /// Whether the content is at minimum zoom level
  bool get isAtMinZoom => scale <= minScale * 1.05;

  /// Calculate the maximum translation bounds for the current scale
  Offset get maxTranslation {
    final containter = containerSize;
    final content = contentSize;

    if (content == null || containter == null) return Offset.zero;

    if (!_isValidSize(contentSize) || !_isValidSize(containerSize)) {
      return Offset.zero;
    }

    final scaledWidth = content.width * scale;
    final scaledHeight = content.height * scale;

    final double maxX = max(0, (scaledWidth - containter.width) / 2);
    final double maxY = max(0, (scaledHeight - containter.height) / 2);

    return Offset(maxX, maxY);
  }

  /// Whether the current translation has hit the left boundary
  bool get isAtLeftBoundary => translation.dx >= maxTranslation.dx - 1;

  /// Whether the current translation has hit the right boundary
  bool get isAtRightBoundary => translation.dx <= -maxTranslation.dx + 1;

  /// Whether the current translation has hit the top boundary
  bool get isAtTopBoundary => translation.dy >= maxTranslation.dy - 1;

  /// Whether the current translation has hit the bottom boundary
  bool get isAtBottomBoundary => translation.dy <= -maxTranslation.dy + 1;

  /// Whether any boundary is currently hit
  bool get isAtAnyBoundary =>
      isAtLeftBoundary ||
      isAtRightBoundary ||
      isAtTopBoundary ||
      isAtBottomBoundary;

  @override
  String toString() =>
      'KurumiTransformationDetails(scale: $scale, translation: $translation, '
      'isZoomed: $isZoomed, isAtMaxZoom: $isAtMaxZoom, isAtAnyBoundary: $isAtAnyBoundary)';
}

class KurumiInteractiveViewer extends StatelessWidget {
  const KurumiInteractiveViewer({
    required this.child,
    super.key,
    this.onTap,
    this.onDoubleTap,
    this.onLongPress,
    this.controller,
    this.onTransformationChanged,
    this.enable = true,
    this.contentSize,
    this.enableHapticFeedback = false,
    this.panEnabled = true,
    this.scaleEnabled = true,
    this.constrainPanToContent = false,
    this.snapZoomToFit = false,
  });

  final Widget child;
  final VoidCallback? onTap;
  final void Function(TapDownDetails?)? onDoubleTap;
  final VoidCallback? onLongPress;
  final void Function(KurumiTransformationDetails details)?
  onTransformationChanged;
  final TransformationController? controller;
  final bool enable;
  final Size? contentSize;
  final bool enableHapticFeedback;
  final bool panEnabled;
  final bool scaleEnabled;

  final bool constrainPanToContent;
  final bool snapZoomToFit;

  @override
  Widget build(BuildContext context) {
    return KurumiRawInteractiveViewer(
      onTap: onTap,
      onDoubleTap: onDoubleTap,
      onLongPress: onLongPress,
      controller: controller,
      onTransformationChanged: onTransformationChanged,
      enable: enable,
      contentSize: contentSize,
      enableHapticFeedback: enableHapticFeedback,
      panEnabled: panEnabled,
      scaleEnabled: scaleEnabled,
      constrainPanToContent: constrainPanToContent,
      snapZoomToFit: snapZoomToFit,
      child: child,
    );
  }
}

class KurumiRawInteractiveViewer extends StatefulWidget {
  const KurumiRawInteractiveViewer({
    required this.child,
    super.key,
    this.onTap,
    this.onDoubleTap,
    this.onLongPress,
    this.controller,
    this.onTransformationChanged,
    this.enable = true,
    this.contentSize,
    this.enableHapticFeedback = false,
    this.panEnabled = true,
    this.scaleEnabled = true,
    this.constrainPanToContent = false,
    this.snapZoomToFit = false,
  });

  final Widget child;
  final VoidCallback? onTap;
  final void Function(TapDownDetails?)? onDoubleTap;
  final VoidCallback? onLongPress;
  final void Function(KurumiTransformationDetails details)?
  onTransformationChanged;
  final TransformationController? controller;

  // This is needed to keep the state of the child widget, remove this widget will cause its child to be recreated
  final bool enable;

  // The intrinsic size (e.g. resolution) of the content
  final Size? contentSize;

  // Enable haptic feedback for interactions
  final bool enableHapticFeedback;

  // Enable/disable panning
  final bool panEnabled;

  // Enable/disable scaling
  final bool scaleEnabled;

  final bool constrainPanToContent;
  final bool snapZoomToFit;

  @override
  State<KurumiRawInteractiveViewer> createState() =>
      _KurumiRawInteractiveViewerState();
}

class _KurumiRawInteractiveViewerState extends State<KurumiRawInteractiveViewer>
    with SingleTickerProviderStateMixin {
  late var _controller = widget.controller ?? TransformationController();
  TapDownDetails? _doubleTapDetails;
  Matrix4? _classicReturnMatrix;

  late final AnimationController _animationController;
  late Animation<Matrix4> _animation;

  late var enable = widget.enable;

  late var _enableHapticFeedback = widget.enableHapticFeedback;

  // Store the latest layout constraints.
  Size? _containerSize;

  var _contentConstraintScheduled = false;

  // Track if max zoom haptic feedback has been triggered
  var _hasTriggeredMaxZoomHaptic = false;

  var _applyingContentConstraint = false;

  double? _interactionStartScale;
  var _interactionWasPinch = false;
  Timer? _snapTimer;

  // Single-finger drags at rest belong to the surrounding PageView. Panning
  // becomes available only after the image has actually been zoomed.
  late var _isZoomed = _computeIsZoomed();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    )..addListener(_onAnimationChanged);

    _controller.addListener(_onChanged);
  }

  @override
  void didUpdateWidget(covariant KurumiRawInteractiveViewer oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Loading a higher-resolution representation can change contentSize
    // while the same image and its saved return position remain active.
    if (oldWidget.controller != widget.controller) {
      _classicReturnMatrix = null;
    }

    // Handle controller changes
    if (oldWidget.controller != widget.controller) {
      _controller.removeListener(_onChanged);
      if (oldWidget.controller == null) {
        _controller.dispose();
      }

      final newController = widget.controller ?? TransformationController();
      _controller = newController;
      _controller.addListener(_onChanged);
      _setZoomed(_computeIsZoomed());
    }

    if (oldWidget.enable != widget.enable) {
      setState(() {
        enable = widget.enable;
      });
    }

    if (oldWidget.enableHapticFeedback != widget.enableHapticFeedback) {
      _enableHapticFeedback = widget.enableHapticFeedback;
      _hasTriggeredMaxZoomHaptic = false;
    }

    if (oldWidget.controller != widget.controller ||
        oldWidget.contentSize != widget.contentSize ||
        oldWidget.constrainPanToContent != widget.constrainPanToContent) {
      _scheduleContentConstraint();
    }
  }

  void _onAnimationChanged() => _controller.value = _animation.value;

  void _onChanged() {
    if (!_animationController.isAnimating && _controller.value.isIdentity()) {
      _classicReturnMatrix = null;
    }
    if (_snapTimer != null) {
      _scheduleSnap();
    }

    if (_applyContentConstraint()) return;

    final currentScale = _controller.value.getMaxScaleOnAxis();
    final translationVector = _controller.value.getTranslation();
    final containerSize = _containerSize;
    final contentSize = widget.contentSize;

    final maxScale = _calcMaxScale(widget.contentSize, containerSize);

    final details = KurumiTransformationDetails(
      scale: currentScale,
      translation: Offset(translationVector.x, translationVector.y),
      contentSize: contentSize,
      containerSize: containerSize,
      maxScale: maxScale,
      minScale: _kFallbackMinScale,
      transformationMatrix: _controller.value,
      isZoomed: !Matrix4.diagonal3Values(
        _controller.value.right.x,
        _controller.value.up.y,
        _controller.value.forward.z,
      ).isIdentity(),
    );

    _setZoomed(details.isZoomed);

    if (_enableHapticFeedback) {
      if (details.isAtMaxZoom && !_hasTriggeredMaxZoomHaptic) {
        HapticFeedback.selectionClick();
        _hasTriggeredMaxZoomHaptic = true;
      } else if (currentScale < maxScale * 0.9) {
        _hasTriggeredMaxZoomHaptic = false;
      }
    }

    widget.onTransformationChanged?.call(details);
  }

  bool _computeIsZoomed() => !Matrix4.diagonal3Values(
    _controller.value.right.x,
    _controller.value.up.y,
    _controller.value.forward.z,
  ).isIdentity();

  void _setZoomed(bool value) {
    if (value == _isZoomed) return;

    void apply() {
      if (!mounted || value == _isZoomed) return;
      setState(() => _isZoomed = value);
    }

    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) => apply());
    } else {
      apply();
    }
  }

  bool _applyContentConstraint() {
    if (!widget.constrainPanToContent || _applyingContentConstraint) {
      return false;
    }

    final constrainedMatrix = _constrainPanToContent(
      matrix: _controller.value,
      contentSize: widget.contentSize,
      containerSize: _containerSize,
    );
    if (constrainedMatrix == null) return false;

    _applyingContentConstraint = true;
    try {
      _controller.value = constrainedMatrix;
    } finally {
      _applyingContentConstraint = false;
    }
    return true;
  }

  void _scheduleContentConstraint() {
    if (!widget.constrainPanToContent || _contentConstraintScheduled) return;

    _contentConstraintScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _contentConstraintScheduled = false;
      if (!mounted) return;

      _applyContentConstraint();
    });
  }

  @override
  void dispose() {
    _snapTimer?.cancel();
    _animationController
      ..removeListener(_onAnimationChanged)
      ..dispose();

    _controller.removeListener(_onChanged);
    if (widget.controller == null) {
      _controller.dispose();
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final containerSize = Size(
          constraints.maxWidth,
          constraints.maxHeight,
        );

        if (_containerSize != containerSize) {
          _classicReturnMatrix = null;
          _containerSize = containerSize;
          _scheduleContentConstraint();
        }

        final interactiveChild = GestureDetector(
          onDoubleTapDown: enable
              ? (details) => _doubleTapDetails = details
              : null,
          onDoubleTap: enable
              ? () {
                  if (widget.onDoubleTap case final cb?) {
                    cb(_doubleTapDetails);
                  } else {
                    _handleDoubleTap();
                  }
                }
              : null,
          onLongPress: enable ? widget.onLongPress : null,
          onTap: enable ? widget.onTap : null,
          child: widget.child,
        );

        final actionable =
            enable && (widget.onTap != null || widget.onLongPress != null);
        // Keep the media subtree mounted when a details panel disables gestures.
        // Inserting/removing this wrapper would recreate a playing video.
        final child = Semantics(
          button: actionable ? true : null,
          enabled: actionable ? true : null,
          onTap: actionable ? widget.onTap : null,
          onLongPress: actionable ? widget.onLongPress : null,
          child: interactiveChild,
        );

        return vendor.InteractiveViewer(
          minScale: _kFallbackMinScale,
          maxScale: _calcMaxScale(widget.contentSize, containerSize),
          transformationController: _controller,
          panEnabled: enable && widget.panEnabled && _isZoomed,
          scaleEnabled: enable && widget.scaleEnabled,
          onInteractionStart: enable ? _handleInteractionStart : null,
          onInteractionUpdate: enable
              ? (details) => _interactionWasPinch |= details.pointerCount >= 2
              : null,
          onInteractionEnd: enable ? (_) => _handleInteractionEnd() : null,
          child: child,
        );
      },
    );
  }

  void _handleInteractionStart(ScaleStartDetails details) {
    if (_snapTimer != null && details.pointerCount == 1) return;

    _snapTimer?.cancel();
    _snapTimer = null;
    _interactionStartScale = _scale2D(_controller.value);
    _interactionWasPinch = details.pointerCount >= 2;
  }

  void _handleInteractionEnd() {
    final startScale = _interactionStartScale;
    _interactionStartScale = null;
    final wasPinch = _interactionWasPinch;
    _interactionWasPinch = false;
    if (!widget.snapZoomToFit || !wasPinch || startScale == null) return;

    final currentScale = _scale2D(_controller.value);
    if ((currentScale - startScale).abs() <= _kScaleChangeTolerance) return;

    _scheduleSnap();
  }

  void _scheduleSnap() {
    _snapTimer?.cancel();
    _snapTimer = Timer(_kSnapSettleDuration, () {
      _snapTimer = null;
      if (!mounted || !widget.snapZoomToFit) return;

      final snapped = _snapTransformationToViewport(
        matrix: _controller.value,
        contentSize: widget.contentSize,
        containerSize: _containerSize,
        minScale: _kFallbackMinScale,
        maxScale: _calcMaxScale(widget.contentSize, _containerSize),
      );
      if (snapped != null) {
        _controller.value = snapped;
      }
    });
  }

  Matrix4 _calculateClassicDoubleTapMatrix(Offset tapPosition) {
    final previousBaseline = _classicReturnMatrix;
    if (previousBaseline != null) {
      _classicReturnMatrix = null;
      return previousBaseline.clone();
    }

    final content = widget.contentSize;
    final viewport = _containerSize;
    if (!_isValidSize(content) || !_isValidSize(viewport)) {
      if (!_controller.value.isIdentity()) return Matrix4.identity();
      _classicReturnMatrix = Matrix4.identity();
      return _calcZoomMatrixFromZoomValue(
        focalPoint: tapPosition,
        zoomValue: _kDoubleTapScale,
      );
    }

    final image = content!;
    final bounds = viewport!;
    final baseline = _controller.value;
    final initialScale = _scale2D(baseline);
    final comicWidthFit = _calcOtherDimensionFitScale(
      viewport: bounds,
      content: image,
    );

    // Auto Comic may already have fitted a tall image to width. Treat that
    // transform (including its reading position) as the starting state.
    final isComicReadingBaseline =
        image.aspectRatio < 0.25 &&
        initialScale > 1 &&
        (initialScale - comicWidthFit).abs() <=
            comicWidthFit * _kSnapToFitTolerance;

    if (!baseline.isIdentity() && !isComicReadingBaseline) {
      return Matrix4.identity();
    }

    final viewportAspect = bounds.aspectRatio;
    // Very narrow viewports may already fit the tall image's width. A
    // double tap must still zoom in rather than shrink below contain fit.
    var targetScale = max(
      1.15,
      _calcAspectAwareClassicZoom(content: image, viewport: bounds),
    );

    if (isComicReadingBaseline &&
        viewportAspect < 1 &&
        targetScale <= initialScale * 1.05) {
      // Width is already filled; offer a modest detail step on first tap.
      targetScale = initialScale * _kClassicComicDetailMultiplier;
    }

    final otherFit = comicWidthFit;
    final ordinary = image.aspectRatio >= 0.55 && image.aspectRatio <= 2.40;
    // Automatic fit snapping must never enlarge the requested zoom.
    // Snap down to an exact width/height fit to avoid needless 2D panning.
    if (otherFit > 1.15 &&
        targetScale >= otherFit &&
        (!ordinary || otherFit <= _kClassicNormalMaxZoom) &&
        targetScale - otherFit <= otherFit * _kSnapToFitTolerance) {
      targetScale = otherFit;
    }

    final maximumScale = _calcMaxScale(image, bounds);
    if (maximumScale.isFinite && maximumScale > 1) {
      targetScale = min(targetScale, maximumScale);
    }

    _classicReturnMatrix = baseline.clone();
    return _calcZoomMatrixForTargetScale(
      focalPoint: tapPosition,
      targetScale: targetScale,
    );
  }

  Matrix4 _calcZoomMatrixForTargetScale({
    required Offset focalPoint,
    required double targetScale,
  }) {
    final scenePoint = _controller.toScene(focalPoint);

    return Matrix4.identity()
      ..translateByDouble(focalPoint.dx, focalPoint.dy, 0, 1)
      ..scaleByDouble(targetScale, targetScale, targetScale, 1)
      ..translateByDouble(-scenePoint.dx, -scenePoint.dy, 0, 1);
  }

  void _handleDoubleTap() {
    if (_doubleTapDetails == null) return;

    final position = _doubleTapDetails!.localPosition;
    final endMatrix = _calculateClassicDoubleTapMatrix(position);

    _animation =
        Matrix4Tween(
          begin: _controller.value,
          end: endMatrix,
        ).animate(
          CurveTween(curve: Curves.easeInOut).animate(_animationController),
        );
    _animationController.forward(from: 0);
  }
}

// Target scale relative to contain-fit. Normal images get a conservative
// detail zoom; extreme shapes fill a useful image band or reading column.
double _calcAspectAwareClassicZoom({
  required Size content,
  required Size viewport,
}) {
  final imageAspect = content.aspectRatio;
  final viewportAspect = viewport.aspectRatio;

  if (viewportAspect >= 1) {
    final otherFit = _calcOtherDimensionFitScale(
      viewport: viewport,
      content: content,
    );
    final normal = otherFit.clamp(1.15, _kClassicNormalMaxZoom).toDouble();

    if (imageAspect >= 1.75) {
      // Fade from a modest detail zoom to a full-height panorama, without
      // introducing a discontinuity when a picture crosses a ratio boundary.
      final wideHeightFit = max(1.15, imageAspect / viewportAspect);
      return _lerpClassicZoom(
        normal,
        wideHeightFit,
        _classicSmoothstep(1.75, 2.40, imageAspect),
      );
    }
    if (imageAspect >= 0.55) return normal;

    return _lerpClassicZoom(
      1 / imageAspect,
      normal,
      _classicSmoothstep(0.30, 0.55, imageAspect),
    );
  }

  final squareDistance = log(imageAspect) / 0.13;
  final detail =
      _kClassicDetailZoom +
      _kClassicSquareBoost * exp(-0.5 * squareDistance * squareDistance);

  if (imageAspect < 0.55) {
    return _lerpClassicZoom(
      viewportAspect / imageAspect,
      detail,
      _classicSmoothstep(0.30, 0.55, imageAspect),
    );
  }
  if (imageAspect > 1.75) {
    return _lerpClassicZoom(
      detail,
      1.10 * imageAspect,
      _classicSmoothstep(1.75, 2.40, imageAspect),
    );
  }
  return detail;
}

double _classicSmoothstep(double start, double end, double value) {
  final t = ((value - start) / (end - start)).clamp(0.0, 1.0).toDouble();
  return t * t * (3 - 2 * t);
}

double _lerpClassicZoom(double from, double to, double factor) =>
    from + (to - from) * factor;

double _calcOtherDimensionFitScale({
  required Size viewport,
  required Size content,
}) {
  final fitWidthScale = viewport.width / content.width;
  final fitHeightScale = viewport.height / content.height;

  return max(fitWidthScale, fitHeightScale) /
      min(fitWidthScale, fitHeightScale);
}

Matrix4 _calcZoomMatrixFromZoomValue({
  required Offset focalPoint,
  required double zoomValue,
}) {
  return Matrix4.identity()
    ..translateByDouble(focalPoint.dx, focalPoint.dy, 0, 1)
    ..scaleByDouble(zoomValue, zoomValue, zoomValue, 1)
    ..translateByDouble(-focalPoint.dx, -focalPoint.dy, 0, 1);
}

double _calcMaxScale(Size? contentSize, Size? containerSize) {
  if (contentSize == null || containerSize == null) {
    return _kFallbackMaxScale;
  }

  if (!_isValidSize(contentSize) || !_isValidSize(containerSize)) {
    return _kFallbackMaxScale;
  }

  // The viewport displays even tiny images at contain fit. Keep a useful
  // relative zoom range and ensure maxScale never falls below minScale.
  return max(
    _kDoubleTapScale,
    max(
          contentSize.width / containerSize.width,
          contentSize.height / containerSize.height,
        ) *
        _kScaleMultiplier,
  );
}

bool _isValidSize(Size? size) =>
    size != null &&
    size.width.isFinite &&
    size.height.isFinite &&
    size.width > 0 &&
    size.height > 0;

Matrix4? _snapTransformationToViewport({
  required Matrix4 matrix,
  required Size? contentSize,
  required Size? containerSize,
  required double minScale,
  required double maxScale,
}) {
  if (!_isValidSize(contentSize) || !_isValidSize(containerSize)) return null;

  final content = contentSize!;
  final container = containerSize!;
  final currentScale = _scale2D(matrix);
  if (!currentScale.isFinite || currentScale <= 0) return null;

  final containScale = min(
    container.width / content.width,
    container.height / content.height,
  );
  final fittedSize = Size(
    content.width * containScale,
    content.height * containScale,
  );
  final widthRatio = fittedSize.width * currentScale / container.width;
  final heightRatio = fittedSize.height * currentScale / container.height;
  final widthQualifies = _qualifiesForSnap(widthRatio);
  final heightQualifies = _qualifiesForSnap(heightRatio);
  if (!widthQualifies && !heightQualifies) return null;

  final targetRatio = switch ((widthQualifies, heightQualifies)) {
    (true, true) =>
      (widthRatio - 1).abs() <= (heightRatio - 1).abs()
          ? widthRatio
          : heightRatio,
    (true, false) => widthRatio,
    (false, true) => heightRatio,
    _ => throw StateError('At least one dimension must qualify'),
  };
  final scaleFactor = 1 / targetRatio;
  final targetScale = currentScale * scaleFactor;
  if (targetScale < minScale || targetScale > maxScale) return null;

  final center = container.center(Offset.zero);
  final translation = matrix.getTranslation();

  return matrix.clone()
    ..setEntry(0, 0, targetScale)
    ..setEntry(1, 1, targetScale)
    ..setEntry(2, 2, targetScale)
    ..setTranslationRaw(
      center.dx + (translation.x - center.dx) * scaleFactor,
      center.dy + (translation.y - center.dy) * scaleFactor,
      translation.z,
    );
}

bool _qualifiesForSnap(double ratio) =>
    ratio >= 1 - _kSnapToFitTolerance && ratio <= 1 + _kSnapToFitTolerance;

double _scale2D(Matrix4 matrix) {
  final scaleX = matrix.entry(0, 0);
  final scaleY = matrix.entry(1, 0);
  return sqrt(scaleX * scaleX + scaleY * scaleY);
}

Matrix4? _constrainPanToContent({
  required Matrix4 matrix,
  required Size? contentSize,
  required Size? containerSize,
}) {
  if (!_isValidSize(contentSize) || !_isValidSize(containerSize)) return null;

  final content = contentSize!;
  final container = containerSize!;
  final scale = matrix.getMaxScaleOnAxis();
  if (!scale.isFinite || scale <= 0) return null;

  final containScale = min(
    container.width / content.width,
    container.height / content.height,
  );
  final fittedSize = Size(
    content.width * containScale,
    content.height * containScale,
  );
  final fittedOffset = Offset(
    (container.width - fittedSize.width) / 2,
    (container.height - fittedSize.height) / 2,
  );
  final translation = matrix.getTranslation();
  final constrainedX = _constrainContentAxis(
    viewportLength: container.width,
    fittedLength: fittedSize.width,
    fittedOffset: fittedOffset.dx,
    scale: scale,
    translation: translation.x,
  );
  final constrainedY = _constrainContentAxis(
    viewportLength: container.height,
    fittedLength: fittedSize.height,
    fittedOffset: fittedOffset.dy,
    scale: scale,
    translation: translation.y,
  );

  if ((constrainedX - translation.x).abs() <= _kContentConstraintTolerance &&
      (constrainedY - translation.y).abs() <= _kContentConstraintTolerance) {
    return null;
  }

  return matrix.clone()
    ..setTranslationRaw(constrainedX, constrainedY, translation.z);
}

double _constrainContentAxis({
  required double viewportLength,
  required double fittedLength,
  required double fittedOffset,
  required double scale,
  required double translation,
}) {
  final transformedLength = fittedLength * scale;

  if (transformedLength <= viewportLength + _kContentConstraintTolerance) {
    return viewportLength / 2 - scale * (fittedOffset + fittedLength / 2);
  }

  final minimum = viewportLength - scale * (fittedOffset + fittedLength);
  final maximum = -scale * fittedOffset;
  return translation.clamp(minimum, maximum);
}
