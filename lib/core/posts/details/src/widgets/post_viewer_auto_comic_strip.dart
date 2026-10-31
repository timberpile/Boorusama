// Flutter imports:
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

// Package imports:
import 'package:i18n/i18n.dart';
import 'package:oktoast/oktoast.dart';

// Project imports:
import 'post_viewer_transformation_scope.dart';

class PostViewerAutoComicStrip extends StatelessWidget {
  const PostViewerAutoComicStrip({
    required this.index,
    required this.postId,
    required this.contentSize,
    required this.currentSettledPage,
    required this.enabled,
    required this.child,
    this.onStarted,
    super.key,
  });

  final int index;
  final int postId;
  final Size contentSize;
  final ValueListenable<int?> currentSettledPage;
  final bool enabled;
  final Widget child;
  final VoidCallback? onStarted;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: currentSettledPage,
      child: child,
      builder: (context, settledPage, child) {
        if (settledPage == index) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!context.mounted || currentSettledPage.value != index) return;

            final started =
                PostViewerTransformationScope.maybeOf(
                  context,
                )?.tryAutoStartComicStrip(
                  postId: postId,
                  contentSize: contentSize,
                  enabled: enabled,
                ) ??
                false;

            if (started) {
              final callback = onStarted;
              if (callback != null) {
                callback();
              } else {
                _showComicStripToast(context);
              }
            }
          });
        }

        return child!;
      },
    );
  }
}

void _showComicStripToast(BuildContext context) {
  final colorScheme = Theme.of(context).colorScheme;

  showToastWidget(
    DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              context.t.settings.image_viewer.comic_strip,
              textAlign: TextAlign.center,
              style: TextStyle(color: colorScheme.onSurface),
            ),
            Text(
              context.t.settings.image_viewer.scroll_down,
              textAlign: TextAlign.center,
              style: TextStyle(color: colorScheme.onSurface),
            ),
          ],
        ),
      ),
    ),
    context: context,
    position: ToastPosition.bottom,
    duration: const Duration(seconds: 2),
    dismissOtherToast: true,
  );
}
