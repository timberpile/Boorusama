// Dart imports:
import 'dart:async';

// Package imports:
import 'package:flutter/foundation.dart';
import 'package:foundation/foundation.dart';
import 'package:kurumi/material.dart';
import 'package:scroll_to_index/scroll_to_index.dart';

// Project imports:
import '../../../../videos/engines/types.dart';
import '../../../../videos/player/types.dart';
import '../../../post/types.dart';

const kSeekAnimationDuration = Duration(milliseconds: 400);
const kPlayPauseAnimationDuration = Duration(milliseconds: 700);

enum SeekDirection { forward, backward }

enum PlayPauseAction { play, pause }

class PostDetailsController<T extends Post> extends ChangeNotifier {
  PostDetailsController({
    required this.scrollController,
    required int initialPage,
    required this.posts,
    required this.initialThumbnailUrl,
    required this.reduceAnimations,
    required this.dislclaimer,
    required this.doubleTapSeekDuration,
  }) : currentPage = ValueNotifier(initialPage),
       _initialPage = initialPage,
       currentPost = ValueNotifier(posts[initialPage]),
       _playback = VideoPlaybackManager(),
       currentSettledPage = ValueNotifier(null);
  final AutoScrollController? scrollController;
  final bool reduceAnimations;
  final List<T> posts;
  final int _initialPage;
  final String? initialThumbnailUrl;
  final String? dislclaimer;
  final int doubleTapSeekDuration;

  late ValueNotifier<int?> currentSettledPage;
  late ValueNotifier<int> currentPage;
  late ValueNotifier<T> currentPost;
  final VideoPlaybackManager _playback;

  int get initialPage =>
      currentPage.value != _initialPage ? currentPage.value : _initialPage;

  void setPage(int page) {
    currentPage.value = page;
  }

  void updateCurrentPost(int page) {
    final post = posts.getOrNull(page);
    if (post != null && currentPost.value != post) {
      currentPost.value = post;
    }
  }

  void onPageSettled(int page) {
    if (page == currentSettledPage.value) return;

    currentSettledPage.value = page;

    final post = posts.getOrNull(page);

    if (post != null) {
      _playback.resetProgress();

      WidgetsBinding.instance.addPostFrameCallback((_) {
        playVideo(post);
      });
    }
  }

  void onExit() {
    // https://github.com/quire-io/scroll-to-index/issues/44
    // skip scrolling if reduceAnimations is enabled due to a limitation in the package
    if (reduceAnimations) return;

    final page = currentPage.value;

    scrollController?.scrollToIndex(page);
  }

  final _originalImagePostKeys = ValueNotifier<Set<String>>(<String>{});

  ValueListenable<Set<String>> get originalImagePostKeys =>
      _originalImagePostKeys;

  bool usesOriginalImage(Post post) =>
      _originalImagePostKeys.value.contains(postViewerIdentity(post));

  void loadOriginalImage(Post post) {
    if (usesOriginalImage(post)) return;

    _originalImagePostKeys.value = {
      ..._originalImagePostKeys.value,
      postViewerIdentity(post),
    };
  }

  final _seekDirection = ValueNotifier<SeekDirection?>(null);
  final _playPauseAction = ValueNotifier<PlayPauseAction?>(null);

  ValueNotifier<VideoProgress> get videoProgress => _playback.videoProgress;
  ValueNotifier<bool> get isVideoPlaying => _playback.isVideoPlaying;
  ValueNotifier<SeekDirection?> get seekDirection => _seekDirection;
  ValueNotifier<PlayPauseAction?> get playPauseAction => _playPauseAction;
  Stream<VideoProgress> get seekStream => _playback.seekStream;

  void onCurrentPositionChanged(double current, double total, Post post) {
    final currentPost = posts.getOrNull(currentSettledPage.value ?? -1);
    if (currentPost != null &&
        postViewerIdentity(currentPost) == postViewerIdentity(post)) {
      _playback.updateProgress(current, total, postViewerIdentity(post));
    }
  }

  void onVideoSeekTo(Duration position, Post post) {
    _playback.seekVideo(position, postViewerIdentity(post));
  }

  Future<void> playVideo(
    Post post, {
    bool showAnimation = false,
  }) async {
    if (postViewerIdentity(currentPost.value) == postViewerIdentity(post) &&
        showAnimation) {
      _showPlayPauseAnimation(PlayPauseAction.play);
    }
    await _playback.playVideo(postViewerIdentity(post));
  }

  Future<void> playCurrentVideo({
    bool showAnimation = false,
  }) {
    final post = currentPost.value;

    return playVideo(
      post,
      showAnimation: showAnimation,
    );
  }

  Future<void> pauseCurrentVideo({
    bool showAnimation = false,
  }) {
    final post = currentPost.value;

    return pauseVideo(
      post,
      showAnimation: showAnimation,
    );
  }

  Future<void> pauseVideo(
    Post post, {
    bool showAnimation = false,
  }) async {
    if (postViewerIdentity(currentPost.value) == postViewerIdentity(post) &&
        showAnimation) {
      _showPlayPauseAnimation(PlayPauseAction.pause);
    }
    await _playback.pauseVideo(postViewerIdentity(post));
  }

  Future<void> seekFromDoubleTap(Offset tapPosition, Size viewport) async {
    final post = currentPost.value;
    if (!post.isVideo) return;

    final width = viewport.width;
    final leftBoundary = width * 0.5;

    final direction = switch (tapPosition.dx) {
      final x when x < leftBoundary => SeekDirection.backward,
      final x when x >= leftBoundary => SeekDirection.forward,
      _ => null,
    };

    if (direction != null) {
      final isForward = direction == SeekDirection.forward;
      final seekPosition = _playback.seekVideoByDirection(
        postViewerIdentity(post),
        isForward,
        Duration(seconds: post.duration.round()),
        doubleTapSeekDuration,
      );

      if (seekPosition != null) {
        _showSeekAnimation(direction);
      }
    }
  }

  void _showSeekAnimation(SeekDirection direction) {
    _seekDirection.value = direction;

    Timer(kSeekAnimationDuration, () {
      if (_seekDirection.value == direction) {
        _seekDirection.value = null;
      }
    });
  }

  void _showPlayPauseAnimation(PlayPauseAction action) {
    _playPauseAction.value = action;

    Timer(kPlayPauseAnimationDuration, () {
      if (_playPauseAction.value == action) {
        _playPauseAction.value = null;
      }
    });
  }

  void onBooruVideoPlayerCreated(BooruPlayer player, Post post) {
    _playback.registerPlayer(player, postViewerIdentity(post));
  }

  void onBooruVideoPlayerDisposed(Post post) {
    _playback.unregisterPlayer(postViewerIdentity(post));
  }

  Future<void> waitForVideoCompletion(Post post) async {
    final player = _playback.getPlayer(postViewerIdentity(post));
    if (player == null) return;

    return player.waitForCompletion();
  }

  @override
  void dispose() {
    _playback.dispose();
    _seekDirection.dispose();
    _playPauseAction.dispose();

    currentPage.dispose();
    currentPost.dispose();
    currentSettledPage.dispose();

    _originalImagePostKeys.dispose();

    super.dispose();
  }
}
