import 'dart:async';

import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';

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
        listenable: Listenable.merge([viewer.overlay, viewer.sheetState]),
        builder: (context, _) {
          final overlay = viewer.overlay.value;
          final details = viewer.isExpanded;
          return SafeArea(
            top: overlay,
            minimum: EdgeInsets.only(
              top: overlay ? 12 : 4,
              left: 12,
              right: 12,
              bottom: 12,
            ),
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                // Leave the existing Info/Back overlay's hit areas unobstructed.
                padding: EdgeInsets.only(top: overlay && !details ? 52 : 0),
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
          );
        },
      ),
    );
  }
}
