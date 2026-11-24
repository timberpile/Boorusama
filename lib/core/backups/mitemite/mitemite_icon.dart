import 'package:flutter_svg/flutter_svg.dart';
import 'package:kurumi/material.dart';

/// The exact owner-supplied vector; tint belongs to the containing surface.
class MiteMiteIcon extends StatelessWidget {
  const MiteMiteIcon({this.size = 24, this.color, super.key});
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: SvgPicture.asset(
      'assets/icon/mitemite.svg',
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(
        color ??
            IconTheme.of(context).color ??
            Theme.of(context).colorScheme.onSurface,
        BlendMode.srcIn,
      ),
      excludeFromSemantics: true,
    ),
  );
}
