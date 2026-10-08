// Package imports:
import 'package:kurumi/material.dart';

/// Dimensions shared by overlays drawn on post thumbnails only.
abstract final class ThumbnailOverlayDimensions {
  static const extent = 20.0;
  static const icon = 16.0;
  static const favoriteIcon = 20.0;
  static const favoritePadding = 2.0;
  static const favoriteTouchTarget = 48.0;
}

/// Fits source/profile icons and their placeholders without changing their
/// dimensions elsewhere in the app.
class ThumbnailOverlayBox extends StatelessWidget {
  const ThumbnailOverlayBox({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: ThumbnailOverlayDimensions.extent,
    child: FittedBox(child: child),
  );
}
