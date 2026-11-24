import 'dart:ui' as ui;

import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';

import '../../../themes/theme/types.dart';

/// Media chrome opts into transparent controls without changing other buttons.
class ViewerOverlayIconButton extends StatelessWidget {
  const ViewerOverlayIconButton({
    required this.icon,
    required this.onPressed,
    this.semanticLabel,
    super.key,
  });

  final Widget icon;
  final VoidCallback? onPressed;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return KurumiCircularIconButton(
      semanticLabel: semanticLabel,
      visualSize: 40,
      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      backgroundColor: Colors.transparent,
      onPressed: onPressed,
      icon: IconTheme.merge(
        data: const IconThemeData(
          size: 24,
          shadows: [mediaOverlayIconShadow],
        ),
        child: SizedBox.square(
          dimension: 24,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              // Blur only glyph alpha, including the custom-painted Info glyph.
              if (icon is KurumiInfoCircleIcon)
                Transform.translate(
                  offset: const Offset(0, 1),
                  child: ImageFiltered(
                    imageFilter: ui.ImageFilter.blur(sigmaX: 1.5, sigmaY: 1.5),
                    child: CustomPaint(
                      size: const Size.square(24),
                      painter: KurumiInfoCirclePainter(
                        color: Colors.black54,
                        style: (icon as KurumiInfoCircleIcon).style,
                      ),
                    ),
                  ),
                ),
              icon,
            ],
          ),
        ),
      ),
    );
  }
}
