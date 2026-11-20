import 'dart:async';
import 'dart:math' as math;

import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';

import '../../../details_pageview/src/viewer_media_viewport.dart';
import 'post_details_page_view_scope.dart';

/// A brief reading hint that never changes overlay or Android chrome state.
class MediaGroupPageIndicator extends StatefulWidget {
  const MediaGroupPageIndicator({
    required this.memberKey,
    required this.page,
    required this.total,
    this.disableAnimation = false,
    super.key,
  });

  final String memberKey;
  final int page;
  final int total;
  final bool disableAnimation;

  @override
  State<MediaGroupPageIndicator> createState() =>
      _MediaGroupPageIndicatorState();
}

class _MediaGroupPageIndicatorState extends State<MediaGroupPageIndicator> {
  Timer? _timer;
  var _visible = true;

  void _restart() {
    _timer?.cancel();
    _visible = true;
    _timer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _visible = false);
    });
  }

  @override
  void initState() {
    super.initState();
    _restart();
  }

  @override
  void didUpdateWidget(MediaGroupPageIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.memberKey != widget.memberKey) _restart();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewer = PostDetailsPageViewScope.of(context);
    return IgnorePointer(
      child: ListenableBuilder(
        listenable: Listenable.merge([
          viewer.bottomObstruction,
          viewer.presentationProgress,
        ]),
        builder: (context, _) => LayoutBuilder(
          builder: (context, constraints) {
            final viewport = ViewerMediaViewport.maybeOf(context);
            final host = Offset.zero & constraints.biggest;
            final progress =
                viewport?.progress ?? viewer.presentationProgress.value;
            final safe = MediaQuery.viewPaddingOf(context);
            final visible = Rect.fromLTRB(
              safe.left * (1 - progress),
              safe.top * (1 - progress),
              host.right - safe.right * (1 - progress),
              host.bottom -
                  math.max(
                    safe.bottom * (1 - progress),
                    viewer.bottomObstruction.value,
                  ),
            );
            if (visible.width <= 16 || visible.height <= 16) {
              return const SizedBox.shrink();
            }
            return Stack(
              children: [
                Positioned.fromRect(
                  rect: visible.deflate(8),
                  child: Align(
                    alignment: Alignment.bottomRight,
                    child: ExcludeSemantics(
                      excluding: !_visible,
                      child: AnimatedOpacity(
                        opacity: _visible ? 1 : 0,
                        duration:
                            widget.disableAnimation ||
                                MediaQuery.disableAnimationsOf(context)
                            ? Duration.zero
                            : const Duration(milliseconds: 180),
                        child: Semantics(
                          label:
                              '${context.t.content_viewer.pages}: ${widget.page} / ${widget.total}',
                          child: ExcludeSemantics(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: .28),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                child: Text(
                                  '${widget.page} / ${widget.total}',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
