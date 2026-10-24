// Dart imports:
import 'dart:async';

// Flutter imports:
import 'package:flutter/foundation.dart';

// Project imports:
import '../../../engines/types.dart';
import 'video_progress.dart';

class VideoPlaybackManager extends ChangeNotifier {
  VideoPlaybackManager();

  final Map<String, BooruPlayer> _players = {};
  var _active = true;
  final _resume = <String>{};
  final _requestedPlayback = <String>{};
  void setActive(bool active) {
    if (_active == active) return;
    _active = active;
    if (!active) {
      _resume.addAll(_pendingPlayback);
      _resume.addAll(_requestedPlayback);
      _pendingPlayback.clear();
      for (final entry in _players.entries) {
        if (entry.value.isPlaying) _resume.add(entry.key);
        unawaited(entry.value.pause());
      }
      _isVideoPlaying.value = false;
    } else {
      final resume = _resume.toList();
      _resume.clear();
      for (final id in resume) {
        unawaited(playVideo(id));
      }
    }
  }

  final Set<String> _pendingPlayback = {};
  final _videoProgress = ValueNotifier(VideoProgress.zero);
  final _isVideoPlaying = ValueNotifier<bool>(false);
  final _seekStreamController = StreamController<VideoProgress>.broadcast();

  ValueNotifier<VideoProgress> get videoProgress => _videoProgress;
  ValueNotifier<bool> get isVideoPlaying => _isVideoPlaying;
  Stream<VideoProgress> get seekStream => _seekStreamController.stream;

  void registerPlayer(BooruPlayer player, String id) {
    _players[id] = player;
    if (!_active) {
      unawaited(player.pause());
      return;
    }

    // If playback was requested before registration, play now
    if (_pendingPlayback.contains(id)) {
      _pendingPlayback.remove(id);
      unawaited(_playIfActive(player, id));
    }
  }

  Future<void> _playIfActive(BooruPlayer player, String id) async {
    await player.play();
    // Native initialization can finish after the route was suspended or a
    // different post was selected. Recheck intent after the asynchronous call.
    if (identical(_players[id], player) &&
        (!_active || !_requestedPlayback.contains(id))) {
      await player.pause();
    }
  }

  void unregisterPlayer(String id) {
    _requestedPlayback.remove(id);
    _players.remove(id);
    _resume.remove(id);
    _pendingPlayback.remove(id);
  }

  Future<void> playVideo(String id) async {
    _requestedPlayback.add(id);
    if (!_active) {
      _resume.add(id);
      return;
    }
    _isVideoPlaying.value = true;
    final player = _players[id];
    if (player != null) {
      unawaited(_playIfActive(player, id));
    } else {
      // Player not registered yet, mark for pending playback
      _pendingPlayback.add(id);
    }
  }

  Future<void> pauseVideo(String id) async {
    _requestedPlayback.remove(id);
    _resume.remove(id);
    _pendingPlayback.remove(id);
    _isVideoPlaying.value = false;
    final player = _players[id];
    if (player != null) {
      unawaited(player.pause());
    }
  }

  void seekVideo(Duration position, String id) {
    final player = _players[id];
    if (player != null) {
      player.seek(position);

      _seekStreamController.add(
        VideoProgress(
          position,
          _videoProgress.value.duration,
        ),
      );
    }
  }

  void updateProgress(
    double current,
    double total,
    String currentVideoId,
  ) {
    final currentPlayer = _players[currentVideoId];
    if (currentPlayer != null) {
      final progress = VideoProgress(
        Duration(milliseconds: (total * 1000).toInt()),
        Duration(milliseconds: (current * 1000).toInt()),
      );

      if (progress != _videoProgress.value) {
        _videoProgress.value = progress;
      }
    }
  }

  void resetProgress() {
    _videoProgress.value = VideoProgress.zero;
  }

  BooruPlayer? getPlayer(String id) {
    return _players[id];
  }

  Duration? seekVideoByDirection(
    String playerId,
    bool isForward,
    Duration? postDuration,
    int doubleTapSeekDurationSeconds,
  ) {
    final seekAmount = Duration(seconds: doubleTapSeekDurationSeconds);
    final progress = videoProgress.value;

    final seekPosition = isForward
        ? progress.seekForward(seekAmount)
        : progress.seekBackward(seekAmount);

    seekVideo(seekPosition, playerId);
    return seekPosition;
  }

  @override
  void dispose() {
    for (final player in _players.values) {
      player.dispose();
    }
    _players.clear();
    _pendingPlayback.clear();

    _videoProgress.dispose();
    _isVideoPlaying.dispose();
    _seekStreamController.close();

    super.dispose();
  }
}
