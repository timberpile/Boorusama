import 'package:flutter/material.dart';

/// A compact, single-color version of the three-faced box in Boorusama's logo.
///
/// The narrow gaps between the faces keep the shape legible at icon sizes
/// without outlines, tape, lettering, or multiple colors.
class BoorusamaBoxIcon extends StatelessWidget {
  const BoorusamaBoxIcon({super.key, this.size, this.color});

  final double? size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final iconTheme = IconTheme.of(context);
    return SizedBox.square(
      dimension: size ?? iconTheme.size ?? 24,
      child: CustomPaint(
        painter: _BoxPainter(
          color ?? iconTheme.color ?? Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }
}

class _BoxPainter extends CustomPainter {
  const _BoxPainter(this.color);

  final Color color;

  // These three faces follow the perspective of assets/images/logo.svg.
  // Small negative-space seams replace the logo's thick dark outlines.
  static final Path _top = Path()
    ..moveTo(1.6, 5.2)
    ..lineTo(12, 1.2)
    ..lineTo(22.4, 5.2)
    ..lineTo(12, 9.1)
    ..close();

  static final Path _left = Path()
    ..moveTo(1.6, 6.4)
    ..lineTo(11.4, 10.2)
    ..lineTo(11.4, 22.8)
    ..lineTo(1.6, 18.1)
    ..close();

  static final Path _right = Path()
    ..moveTo(12.6, 10.2)
    ..lineTo(22.4, 6.4)
    ..lineTo(22.4, 18.1)
    ..lineTo(12.6, 22.8)
    ..close();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    canvas.save();
    canvas.scale(size.width / 24, size.height / 24);
    canvas.drawPath(_top, paint);
    canvas.drawPath(_left, paint);
    canvas.drawPath(_right, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _BoxPainter oldDelegate) =>
      oldDelegate.color != color;
}
