// Package imports:
import 'package:foundation/foundation.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';
import 'package:material_symbols_icons/symbols.dart';

// Project imports:
import '../../../../posts/post/src/widgets/thumbnail_overlay.dart';

class VideoPlayDurationIcon extends StatelessWidget {
  const VideoPlayDurationIcon({
    required this.duration,
    required this.hasSound,
    super.key,
  });

  final double duration;
  final bool? hasSound;

  @override
  Widget build(BuildContext context) {
    final durationLabel = formatDurationForMedia(
      Duration(
        seconds: duration < 1 ? 1 : duration.round(),
      ),
    );
    final colors = Kurumi.semanticColorsOf(context);
    final background = colors.overlayDim;
    final foreground = colors.onOverlayDim;

    return Semantics(
      label: durationLabel,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        height: ThumbnailOverlayDimensions.extent,
        decoration: BoxDecoration(
          color: background,
          borderRadius: const BorderRadius.all(Radius.circular(4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  durationLabel,
                  style: TextStyle(
                    color: foreground,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.25,
                  ),
                ),
              ),
            ),
            if (hasSound case final sound?)
              Padding(
                padding: const EdgeInsets.only(left: 1),
                child: Icon(
                  sound
                      ? Symbols.volume_up_rounded
                      : Symbols.volume_off_rounded,
                  color: foreground,
                  size: ThumbnailOverlayDimensions.icon,
                  fill: 1,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
