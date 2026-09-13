// Dart imports:
import 'dart:math';

// Flutter imports:
import 'package:flutter/material.dart';

class PostViewerTransformationController {
  PostViewerTransformationController(this.transformationController);

  final TransformationController transformationController;

  Size? viewportSize;

  void fitToWidth(Size contentSize) {
    final geometry = _geometry(contentSize);
    if (geometry == null) return;

    final viewportCenter = geometry.viewport.center(Offset.zero);
    final visibleCenter = transformationController.toScene(viewportCenter);
    final targetScale = geometry.viewport.width / geometry.fitted.width;
    final translation = viewportCenter - visibleCenter * targetScale;

    transformationController.value = _constrain(
      geometry: geometry,
      scale: targetScale,
      translation: translation,
    );
  }

  void scrollToTop(Size contentSize) {
    final geometry = _geometry(contentSize);
    if (geometry == null) return;

    final matrix = transformationController.value;
    final scale = matrix.getMaxScaleOnAxis();
    if (!scale.isFinite || scale <= 0) return;

    final currentTranslation = matrix.getTranslation();
    transformationController.value = _constrain(
      geometry: geometry,
      scale: scale,
      translation: Offset(
        currentTranslation.x,
        -scale * geometry.fittedOffset.dy,
      ),
    );
  }

  void startComicStrip(Size contentSize) {
    final geometry = _geometry(contentSize);
    if (geometry == null) return;

    final targetScale = geometry.viewport.width / geometry.fitted.width;
    transformationController.value = _constrain(
      geometry: geometry,
      scale: targetScale,
      translation: Offset(
        -targetScale * geometry.fittedOffset.dx,
        -targetScale * geometry.fittedOffset.dy,
      ),
    );
  }

  _ViewerGeometry? _geometry(Size contentSize) {
    final viewport = viewportSize;
    if (!_isValidSize(viewport) || !_isValidSize(contentSize)) return null;

    final containScale = min(
      viewport!.width / contentSize.width,
      viewport.height / contentSize.height,
    );
    final fitted = Size(
      contentSize.width * containScale,
      contentSize.height * containScale,
    );

    return _ViewerGeometry(
      viewport: viewport,
      fitted: fitted,
      fittedOffset: Offset(
        (viewport.width - fitted.width) / 2,
        (viewport.height - fitted.height) / 2,
      ),
    );
  }
}

class _ViewerGeometry {
  const _ViewerGeometry({
    required this.viewport,
    required this.fitted,
    required this.fittedOffset,
  });

  final Size viewport;
  final Size fitted;
  final Offset fittedOffset;
}

Matrix4 _constrain({
  required _ViewerGeometry geometry,
  required double scale,
  required Offset translation,
}) {
  final constrainedX = _constrainAxis(
    viewportLength: geometry.viewport.width,
    fittedLength: geometry.fitted.width,
    fittedOffset: geometry.fittedOffset.dx,
    scale: scale,
    translation: translation.dx,
  );
  final constrainedY = _constrainAxis(
    viewportLength: geometry.viewport.height,
    fittedLength: geometry.fitted.height,
    fittedOffset: geometry.fittedOffset.dy,
    scale: scale,
    translation: translation.dy,
  );

  return Matrix4.diagonal3Values(scale, scale, 1)
    ..setTranslationRaw(constrainedX, constrainedY, 0);
}

double _constrainAxis({
  required double viewportLength,
  required double fittedLength,
  required double fittedOffset,
  required double scale,
  required double translation,
}) {
  final transformedLength = fittedLength * scale;
  if (transformedLength <= viewportLength) {
    return viewportLength / 2 - scale * (fittedOffset + fittedLength / 2);
  }

  final minimum = viewportLength - scale * (fittedOffset + fittedLength);
  final maximum = -scale * fittedOffset;
  return translation.clamp(minimum, maximum);
}

bool _isValidSize(Size? size) =>
    size != null &&
    size.width.isFinite &&
    size.height.isFinite &&
    size.width > 0 &&
    size.height > 0;
