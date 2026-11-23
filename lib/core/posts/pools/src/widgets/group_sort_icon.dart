import 'package:kurumi/material.dart';
import 'package:material_symbols_icons/symbols.dart';

/// The applied order uses the same glyph in the viewer and the gallery menu.
class GroupSortIcon extends StatelessWidget {
  const GroupSortIcon(this.order, {this.size = 24, super.key});

  final String order;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (order == 'order') {
      return Icon(Symbols.format_list_numbered, size: size);
    }
    final theme = IconTheme.of(context);
    return CustomPaint(
      size: Size.square(size),
      painter: _DirectionPainter(
        ascending: order == 'oldest',
        color: theme.color ?? Theme.of(context).colorScheme.onSurface,
        shadows: theme.shadows ?? const [],
      ),
    );
  }
}

class _DirectionPainter extends CustomPainter {
  const _DirectionPainter({
    required this.ascending,
    required this.color,
    required this.shadows,
  });

  final bool ascending;
  final Color color;
  final List<Shadow> shadows;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24, size.height / 24);
    final tip = ascending ? 5.0 : 19.0;
    final wing = ascending ? 8.5 : 15.5;
    final lines = Path()
      ..moveTo(3, 6)
      ..lineTo(12, 6)
      ..moveTo(3, 12)
      ..lineTo(12, 12)
      ..moveTo(3, 18)
      ..lineTo(12, 18)
      ..moveTo(18, 5)
      ..lineTo(18, 19)
      ..moveTo(14.5, wing)
      ..lineTo(18, tip)
      ..lineTo(21.5, wing);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = 2;
    for (final shadow in shadows) {
      canvas.drawPath(
        lines.shift(shadow.offset),
        stroke
          ..color = shadow.color
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, shadow.blurSigma),
      );
    }
    canvas.drawPath(
      lines,
      stroke
        ..color = color
        ..maskFilter = null,
    );
  }

  @override
  bool shouldRepaint(_DirectionPainter oldDelegate) =>
      ascending != oldDelegate.ascending ||
      color != oldDelegate.color ||
      shadows != oldDelegate.shadows;
}
