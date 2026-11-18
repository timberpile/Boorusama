import 'package:flutter/widgets.dart';

import '../types/image_list_type.dart';

/// Owned by a listing occurrence, rather than a lazily recycled tile. Once the
/// first Masonry layout happens, later media/metadata cannot move its neighbors.
class RelatedGridGeometry {
  static const fallbackAspectRatio = .6;
  double? _aspectRatio;

  static double? validRatio(double? ratio) =>
      ratio != null && ratio.isFinite && ratio > 0 ? ratio : null;

  double capture(double? candidate) =>
      _aspectRatio ??= validRatio(candidate) ?? fallbackAspectRatio;
}

/// Fixed grids supply the full cell. Only Masonry supplies natural geometry;
/// contain also keeps a later differently shaped cover inside that frozen box.
class RelatedGridCard extends StatelessWidget {
  const RelatedGridCard({
    required this.listType,
    required this.geometry,
    required this.aspectRatio,
    required this.builder,
    super.key,
  });

  final ImageListType listType;
  final RelatedGridGeometry geometry;
  final double? aspectRatio;
  final Widget Function(BoxFit fit) builder;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => listType == ImageListType.masonry
        ? AspectRatio(
            aspectRatio: geometry.capture(aspectRatio),
            child: builder(BoxFit.contain),
          )
        : SizedBox.expand(
            child: builder(
              listType == ImageListType.standard
                  ? BoxFit.cover
                  : BoxFit.contain,
            ),
          ),
  );
}
