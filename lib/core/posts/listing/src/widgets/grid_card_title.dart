import 'package:kurumi/material.dart';

class GridCardTitle extends StatelessWidget {
  const GridCardTitle(this.title, {super.key});

  final String title;

  static const _padding = EdgeInsets.only(left: 8);
  static const _style = TextStyle(fontWeight: FontWeight.w600);
  static const _maxLines = 2;

  static String _displayText(String title) => title.replaceAll('_', ' ');

  static double measureHeight(
    BuildContext context,
    String title,
    double width,
  ) {
    final painter =
        TextPainter(
          text: TextSpan(
            text: _displayText(title),
            style: DefaultTextStyle.of(context).style.merge(_style),
          ),
          maxLines: _maxLines,
          ellipsis: '…',
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout(
          maxWidth: (width - _padding.horizontal).clamp(0, double.infinity),
        );
    final height = painter.height;
    painter.dispose();
    return height;
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: _padding,
    child: Text(
      _displayText(title),
      style: _style,
      maxLines: _maxLines,
      overflow: TextOverflow.ellipsis,
    ),
  );
}
