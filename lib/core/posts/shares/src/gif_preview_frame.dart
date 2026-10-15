import 'dart:math' as math;

import 'package:kurumi/material.dart';

/// Bounds preview height without adding letterboxing to the media surface.
class GifPreviewFrame extends StatelessWidget {
  const GifPreviewFrame({
    required this.aspectRatio,
    required this.maxHeight,
    required this.child,
    super.key,
  });

  final double aspectRatio;
  final double maxHeight;
  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final height = math.min(maxHeight, constraints.maxWidth / aspectRatio);
      return Align(
        heightFactor: 1,
        child: SizedBox(
          width: height * aspectRatio,
          height: height,
          child: child,
        ),
      );
    },
  );
}
