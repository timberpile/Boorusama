// Package imports:
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';

import 'thumbnail_overlay.dart';

class ImageOverlayIcon extends StatelessWidget {
  const ImageOverlayIcon({
    required this.icon,
    super.key,
    this.size,
  });

  final IconData icon;
  final double? size;

  @override
  Widget build(BuildContext context) {
    final colors = Kurumi.semanticColorsOf(context);

    return Container(
      width: ThumbnailOverlayDimensions.extent,
      height: ThumbnailOverlayDimensions.extent,
      decoration: BoxDecoration(
        color: colors.overlayDim,
        borderRadius: const BorderRadius.all(Radius.circular(4)),
      ),
      child: Icon(
        icon,
        color: colors.onOverlayDim,
        size: size ?? ThumbnailOverlayDimensions.icon,
        weight: 700,
      ),
    );
  }
}
