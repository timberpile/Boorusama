// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foundation/foundation.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';

// Project imports:
import '../../../../videos/player/providers.dart';
import '../../../../videos/player/types.dart';
import '../types/inherited_post.dart';
import '../../../../videos/player/widgets.dart';
import '../../../details_pageview/widgets.dart';
import '../../../post/types.dart';
import 'post_details_controller.dart';

class PostDetailsVideoControlsMobile<T extends Post> extends ConsumerWidget {
  const PostDetailsVideoControlsMobile({
    required this.controller,
    required this.pageIndex,
    super.key,
  });

  final PostDetailsController<T> controller;
  final int pageIndex;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _VideoControls(
      child: LayoutBuilder(
        builder: (context, constraints) => _VideoControlsContent(
          controller: controller,
          pageIndex: pageIndex,
          constraints: constraints,
          playPausePadding: const EdgeInsets.all(8),
          popoverController: null,
        ),
      ),
    );
  }
}

class PostDetailsVideoControlsDesktop<T extends Post> extends StatefulWidget {
  const PostDetailsVideoControlsDesktop({
    required this.controller,
    required this.pageIndex,
    required this.pageViewController,
    super.key,
  });

  final PostDetailsController<T> controller;
  final int pageIndex;
  final PostDetailsPageViewController pageViewController;

  @override
  State<PostDetailsVideoControlsDesktop<T>> createState() =>
      _PostDetailsVideoControlsDesktopState<T>();
}

class _PostDetailsVideoControlsDesktopState<T extends Post>
    extends State<PostDetailsVideoControlsDesktop<T>> {
  final _popoverController = AnchorController();

  @override
  void dispose() {
    _popoverController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: widget.pageViewController.overlay,
      builder: (context, overlay, child) => ListenableBuilder(
        listenable: _popoverController,
        builder: (context, _) => switch ((
          overlay: overlay,
          optionShowing: _popoverController.isShowing,
        )) {
          (overlay: true, optionShowing: _) ||
          (overlay: false, optionShowing: true) => _VideoControls(
            child: LayoutBuilder(
              builder: (context, constraints) => SafeArea(
                top: false,
                bottom: false,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  child: _VideoControlsContent(
                    popoverController: _popoverController,
                    controller: widget.controller,
                    pageIndex: widget.pageIndex,
                    constraints: constraints,
                    playPausePadding: null,
                  ),
                ),
              ),
            ),
          ),
          _ => const SizedBox.shrink(),
        },
      ),
    );
  }
}

class _VideoControls extends StatelessWidget {
  const _VideoControls({
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final surfaceColor = Kurumi.themeOf(context).colorScheme.surface;

    return Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                color: surfaceColor.withValues(alpha: 0.8),
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

class _VideoControlsContent<T extends Post> extends ConsumerWidget {
  const _VideoControlsContent({
    required this.controller,
    required this.pageIndex,
    required this.constraints,
    required this.playPausePadding,
    required this.popoverController,
  });

  final PostDetailsController<T> controller;
  final int pageIndex;
  final BoxConstraints constraints;
  final EdgeInsets? playPausePadding;
  final AnchorController? popoverController;

  @override
  Widget build(BuildContext context, WidgetRef ref) => ListenableBuilder(
    listenable: Listenable.merge([
      controller.currentPost,
      controller.currentSettledPage,
    ]),
    builder: (context, _) {
      final post =
          InheritedPost.maybeOf<T>(context) ?? controller.currentPost.value;
      final active = controller.currentSettledPage.value == pageIndex;
      final duration = post.duration.isFinite && post.duration > 0
          ? Duration(milliseconds: (post.duration * 1000).round())
          : Duration.zero;
      VideoProgress progressFor(VideoProgress progress) =>
          active ? progress : VideoProgress(duration, Duration.zero);
      final rightControls = [
        const SoundControlButton(),
        const SizedBox(width: 8),
        MoreOptionsControlButton(
          post: post,
          popoverController: popoverController,
          speed: ref.watch(playbackSpeedProvider(post.videoUrl)),
          onSpeedChanged: (speed) => ref
              .read(playbackSpeedProvider(post.videoUrl).notifier)
              .setSpeed(speed),
        ),
        const SizedBox(width: 8),
      ];
      return ExcludeFocus(
        excluding: !active,
        child: IgnorePointer(
          ignoring: !active,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Spacer(),
                  if (constraints.maxWidth < _kMinWidth) ...rightControls,
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const SizedBox(width: 4),
                  PlayPauseButton(
                    padding: playPausePadding,
                    isPlaying: active
                        ? controller.isVideoPlaying
                        : const AlwaysStoppedAnimation(false),
                    onPlayingChanged: (playing) {
                      if (playing) {
                        controller.pauseVideo(post, showAnimation: true);
                      } else {
                        controller.playVideo(post, showAnimation: true);
                      }
                    },
                  ),
                  ValueListenableBuilder(
                    valueListenable: controller.videoProgress,
                    builder: (context, progress, _) => VideoTimeText(
                      duration: progressFor(progress).position,
                      forceHigherThanOneSecond: false,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Container(
                      color: Colors.transparent,
                      height: 28,
                      child: ValueListenableBuilder(
                        valueListenable: controller.videoProgress,
                        builder: (context, progress, _) {
                          final boundProgress = progressFor(progress);
                          final colors = Kurumi.themeOf(context).colorScheme;
                          return VideoProgressBar(
                            duration: boundProgress.duration,
                            position: boundProgress.position,
                            buffered: const [],
                            onDragStart: () => controller.pauseVideo(post),
                            onDragEnd: () => controller.playVideo(post),
                            seekTo: (position) =>
                                controller.onVideoSeekTo(position, post),
                            barHeight: 3,
                            handleHeight: 6,
                            drawShadow: true,
                            backgroundColor: colors.hintColor.withValues(
                              alpha: 0.2,
                            ),
                            playedColor: colors.primary,
                            bufferedColor: colors.hintColor,
                            handleColor: colors.primary,
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  ValueListenableBuilder(
                    valueListenable: controller.videoProgress,
                    builder: (context, progress, _) => VideoTimeText(
                      duration: progressFor(progress).duration,
                      forceHigherThanOneSecond:
                          progressFor(progress).duration.inSeconds != 0,
                    ),
                  ),
                  if (constraints.maxWidth >= _kMinWidth) ...rightControls,
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}

const _kMinWidth = 320.0;

class VideoTimeText extends StatelessWidget {
  const VideoTimeText({
    required this.duration,
    super.key,
    this.forceHigherThanOneSecond,
  });

  final Duration duration;
  final bool? forceHigherThanOneSecond;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 40),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            formatDurationForMedia(
              duration,
              forceHigherThanOneSecond: forceHigherThanOneSecond ?? false,
            ),
            style: const TextStyle(
              fontSize: 14,
              fontFeatures: [
                FontFeature.tabularFigures(),
              ],
              letterSpacing: -0.25,
            ),
          ),
        ],
      ),
    );
  }
}
